//
//  OCHTTPPipeline.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 04.02.19.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2019, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCHTTPPipeline.h"
#import "OCHTTPPipelineTask.h"
#import "OCProcessManager.h"

@interface OCHTTPPipeline ()
- (void)queueBlock:(dispatch_block_t)block;
@end

@implementation OCHTTPPipeline

#pragma mark - Init
- (instancetype)initWithIdentifier:(OCHTTPPipelineID)identifier backend:(nullable OCHTTPPipelineBackend *)backend configuration:(NSURLSessionConfiguration *)sessionConfiguration;
{
	if ((self = [super init]) != nil)
	{
		// Set up internals
		_attachedParititionHandlerIDs = [NSMutableArray new];
		_partitionHandlersByID = [NSMutableDictionary new];
		_recentlyScheduledGroupIDs = [NSMutableArray new];

		// Set identifiers
		_identifier = identifier;
		_bundleIdentifier = NSBundle.mainBundle.bundleIdentifier;

		// Set backend
		if (backend == nil)
		{
			backend = [[OCHTTPPipelineBackend alloc] initWithSQLDB:nil];
		}

		_backend = backend;

		// Change sessionConfiguration to not store any session-related data on disk
		sessionConfiguration.URLCredentialStorage = nil; // Do not use credential store at all
		sessionConfiguration.URLCache = nil; // Do not cache responses
		sessionConfiguration.HTTPCookieStorage = nil; // Do not store cookies

		// Grab the session identifier for those sessions that have it
		_urlSessionIdentifier = sessionConfiguration.identifier;

		// Create URL session
		_urlSession = [NSURLSession sessionWithConfiguration:sessionConfiguration
							    delegate:self
						       delegateQueue:nil];
	}

	return (self);
}

#pragma mark - Request handling
- (void)enqueueRequest:(OCHTTPRequest *)request forPartitionID:(OCHTTPPipelinePartitionID)partitionID
{
	OCHTTPPipelineTask *pipelineTask;

	if ((pipelineTask = [[OCHTTPPipelineTask alloc] initWithRequest:request pipeline:self partition:partitionID]) != nil)
	{
		[_backend addPipelineTask:pipelineTask];

		[self setPipelineNeedsScheduling];
	}
}

- (void)cancelRequest:(OCHTTPRequest *)request
{

}

- (void)cancelRequestsForPartitionID:(OCHTTPPipelinePartitionID)partitionID queuedOnly:(BOOL)queuedOnly
{

}

#pragma mark - Scheduling
- (void)setPipelineNeedsScheduling
{
	@synchronized(self)
	{
		if (!_needsScheduling)
		{
			_needsScheduling = YES;

			[self queueBlock:^{
				[self _schedule];
			}];
		}
	}
}

- (void)_schedule
{
	__block NSUInteger remainingSlots = NSUIntegerMax;

	/*
		Scheduling goals:
		- the number of running requests doesn't exceed the limit imposed by .maximumConcurrentRequests at any time
		- requests are scheduled fairly: the scheduler guarantees that for N groups, every group will get one request scheduled after N slots have become available (doesn't need to be in the same scheduling run)
		- only one request can be running per group
		- request not belonging to a group are assigned to the default group:
			- any number of requests can be running for the default group at the same time
			- any spots remaining after fair scheduling are filled with requests from the default group
			- requests with a higher priority are scheduled sooner
		- requests are only considered for scheduling if a partitionHandler is attached for them - or they have the .requestFinal flag set
	*/

	// Enforce .maximumConcurrentRequests
	if (self.maximumConcurrentRequests != 0)
	{
		NSNumber *runningRequestsCount;

		if ((runningRequestsCount = [_backend numberOfRequestsWithState:OCHTTPPipelineTaskStateRunning inPipeline:self error:NULL]) != nil)
		{
			if (runningRequestsCount.unsignedIntegerValue >= self.maximumConcurrentRequests)
			{
				// Maximum number of concurrent requests reached => exit early
				return;
			}
			else
			{
				// Adjust number of remaining slots
				remainingSlots = self.maximumConcurrentRequests - runningRequestsCount.unsignedIntegerValue;
			}
		}
	}

	// Enumerate tasks in pipeline and pick ones for scheduling
	__block NSMutableDictionary <OCHTTPRequestGroupID, NSMutableArray<OCHTTPPipelineTask *> *> *schedulableTasksByGroupID = [NSMutableDictionary new];
	__block NSMutableSet <OCHTTPRequestGroupID> *activeGroupIDs = [NSMutableSet new];
	const OCHTTPRequestGroupID defaultGroupID = @"_default_";

	[_backend enumerateTasksForPipeline:self enumerator:^(OCHTTPPipelineTask *task, BOOL *stop) {
		BOOL isRelevant = YES;
		OCHTTPPipelinePartitionID partitionID;

		// Check if a partitionHandler is attached for this task - or if the task is deemed final and can be scheduled without
		if ((partitionID = task.partitionID) == nil)
		{
			// No partitionID?! => skip
			return;
		}

		if (!task.requestFinal)
		{
			// Request isn't final
			@synchronized(self)
			{
				if (self->_attachedParititionHandlerIDs[partitionID] == nil)
				{
					// No partitionHandler for this task => skip
					return;
				}
			}
		}

		// Check if this task originates from our process
		if (isRelevant)
		{
			if (![task.bundleID isEqual:self->_bundleIdentifier])
			{
				// Task originates from a different process. Only process it, if that other process is no longer around
				OCProcessSession *processSession;

				if ((processSession = [[OCProcessManager sharedProcessManager] findLatestSessionForProcessWithBundleIdentifier:task.bundleID]) != nil)
				{
					isRelevant = ![[OCProcessManager sharedProcessManager] isAnyInstanceOfSessionProcessRunning:processSession];
				}
			}
		}

		// Task is relevant
		if (isRelevant)
		{
			OCHTTPRequestGroupID taskGroupID = task.groupID;

			if (taskGroupID == nil)
			{
				// Task doesn't belong to a group. Assign default ID.
				taskGroupID = defaultGroupID;
			}
			else
			{
				// Task belongs to group
				if ([activeGroupIDs containsObject:taskGroupID])
				{
					// Another task for the same task.groupID is already active
					return;
				}
			}

			switch (task.state)
			{
				case OCHTTPPipelineTaskStatePending:
					// Task is pending
					if (taskGroupID != nil)
					{
						NSMutableArray <OCHTTPPipelineTask *> *schedulableTasks;

						if ((schedulableTasks = schedulableTasksByGroupID[taskGroupID]) == nil)
						{
							// First pending task with this taskGroupID
							schedulableTasks = [[NSMutableArray alloc] initWithObjects:task, nil];
							schedulableTasksByGroupID[taskGroupID] = schedulableTasks;
						}
						else if (task.groupID == nil)
						{
							// Pending task without groupID (ignore tasks with groupID here, as it'd be the second with the groupID or later)
							[schedulableTasks addObject:task];
						}
					}
				break;

				case OCHTTPPipelineTaskStateRunning:
					// Task is running
					if (task.groupID != nil)
					{
						// Add groupID to active group ID
						[activeGroupIDs addObject:task.groupID];

						[schedulableTasksByGroupID removeObjectForKey:task.groupID];
					}

					return;
				break;

				case OCHTTPPipelineTaskStateCompleted:
					// Task is completed
					return;
				break;
			}
		}
	}];

	// Filter and sort tasks
	if (schedulableTasksByGroupID.count > 0)
	{
		NSMutableArray <OCHTTPPipelineTask *> *scheduleTasks = [NSMutableArray new];
		NSMutableArray <OCHTTPRequestGroupID> *schedulableGroupIDs = [schedulableTasksByGroupID.allKeys mutableCopy];

		NSComparator sortTasksByRequestPriorityComparator = ^NSComparisonResult(OCHTTPPipelineTask *task1, OCHTTPPipelineTask *task2) {
			OCHTTPRequestPriority task1Priority, task2Priority;

			task1Priority = task1.request.priority;
			task2Priority = task2.request.priority;

			if (task1Priority == task2Priority)
			{
				return (NSOrderedSame);
			}

			return ((task1Priority < task2Priority) ? NSOrderedAscending : NSOrderedDescending);
		};

		// Sort defaultGroup requests by request.priority
		[schedulableTasksByGroupID[defaultGroupID] sortUsingComparator:sortTasksByRequestPriorityComparator];

		// Prioritize requests from groups whose requests haven't been scheduled the longest
		for (OCHTTPRequestGroupID groupID in _recentlyScheduledGroupIDs)
		{
			NSMutableArray <OCHTTPPipelineTask *> *tasks;

			if ((tasks = schedulableTasksByGroupID[groupID]) != nil)
			{
				OCHTTPPipelineTask *task;

				// Add the oldest task from this group
				if ((task = tasks.firstObject) != nil)
				{
					[scheduleTasks insertObject:task atIndex:0];
					[tasks removeObjectAtIndex:0];
				}

				[schedulableGroupIDs removeObject:groupID]; // Done with this group
			}
		}

		// Prioritize requests from groups whose requests have never been scheduled even higher (by inserting them at the top)
		for (OCHTTPRequestGroupID groupID in schedulableGroupIDs)
		{
			NSMutableArray <OCHTTPPipelineTask *> *tasks;

			if ((tasks = schedulableTasksByGroupID[groupID]) != nil)
			{
				OCHTTPPipelineTask *task;

				// Add the oldest task from this group
				if ((task = tasks.firstObject) != nil)
				{
					[scheduleTasks insertObject:task atIndex:0];
					[tasks removeObjectAtIndex:0];
				}
			}
		}

		// Fill remaining spots (if any) with defaultGroup tasks
		NSMutableArray <OCHTTPPipelineTask *> *tasks;

		if ((tasks = schedulableTasksByGroupID[defaultGroupID]) != nil)
		{
			[scheduleTasks addObjectsFromArray:tasks];
		}

		// Reduce to maximum of remainingSlots
		if (scheduleTasks.count > remainingSlots)
		{
			[scheduleTasks removeObjectsInRange:NSMakeRange(remainingSlots, scheduleTasks.count-remainingSlots)];
		}

		// Update recentlyScheduledGroupIDs
		for (OCHTTPPipelineTask *task in scheduleTasks)
		{
			OCHTTPRequestGroupID taskGroupID = task.groupID;

			if (taskGroupID == nil)
			{
				// Task doesn't belong to a group. Assign default ID.
				taskGroupID = defaultGroupID;
			}

			// Move taskGroupID to the end of recently scheduled group IDs
			// Eventually, every taskGroupID will bubble up to the top, even if only one slot was available
			[_recentlyScheduledGroupIDs removeObject:taskGroupID];
			[_recentlyScheduledGroupIDs addObject:taskGroupID];
		}

		// Schedule tasks
		for (OCHTTPPipelineTask *task in scheduleTasks)
		{
			[self _scheduleTask:task];
		}
	}
}

- (void)_scheduleTask:(OCHTTPPipelineTask *)task
{

}

- (void)_deliverResultForTask:(OCHTTPPipelineTask *)task
{

}

- (void)_deliverResultsForPartition:(OCHTTPPipelinePartitionID)partitionID
{

}

#pragma mark - Attach & detach partition handlers
- (void)attachPartitionHandler:(id<OCHTTPPipelinePartitionHandler>)partitionHandler completionHandler:(nullable OCCompletionHandler)completionHandler
{
	[self queueBlock:^{
		OCHTTPPipelinePartitionID partitionID;

		if ((partitionID = [partitionHandler partitionID]) != nil)
		{
			id<OCHTTPPipelinePartitionHandler> existingPartitionHandler;

			@synchronized(self)
			{
				// Check for duplicate handlers
				if ((existingPartitionHandler = self->_partitionHandlersByID[partitionID]) != nil)
				{
					OCLogWarning(@"Attempt to attach a handler (%@) for partition %@ for which one is already attached (%@). Detaching previous one.", partitionHandler, partitionID, existingPartitionHandler);

					// Detach existing one
					[self detachPartitionHandler:existingPartitionHandler completionHandler:^(id sender, NSError *error) {
						// Once detached, attach the new one
						[self attachPartitionHandler:partitionHandler completionHandler:completionHandler];
					}];

					return;
				}

				// Add handler
				[self->_attachedParititionHandlerIDs addObject:partitionID];
				self->_partitionHandlersByID[partitionID] = partitionHandler;
			}

			// Deliver pending results
			[self queueBlock:^{
				[self _deliverResultsForPartition:partitionID];
			}];

			// Schedule any queued requests in the pipeline waiting for this partition handler
			[self setPipelineNeedsScheduling];
		}

		if (completionHandler != nil)
		{
			completionHandler(self, nil);
		}
	}];
}

- (void)detachPartitionHandler:(id<OCHTTPPipelinePartitionHandler>)partitionHandler completionHandler:(nullable OCCompletionHandler)completionHandler
{
	[self queueBlock:^{
		OCHTTPPipelinePartitionID partitionID;

		if ((partitionID = [partitionHandler partitionID]) != nil)
		{
			@synchronized(self)
			{
				if (partitionHandler == self->_partitionHandlersByID[partitionID])
				{
					[self->_partitionHandlersByID removeObjectForKey:partitionID];
					[self->_attachedParititionHandlerIDs removeObject:partitionID];
				}
				else
				{
					OCLogWarning(@"Attempt to detach a handler (%@) for partition %@ that wasn't attached.", partitionHandler, partitionID);
				}
			}
		}

		if (completionHandler != nil)
		{
			completionHandler(self, nil);
		}
	}];
}

- (void)detachPartitionHandlerForPartitionID:(OCHTTPPipelinePartitionID)partitionID completionHandler:(nullable OCCompletionHandler)completionHandler
{
	if (partitionID != nil)
	{
		id<OCHTTPPipelinePartitionHandler> partitionHandler;

		@synchronized(self)
		{
			partitionHandler = _partitionHandlersByID[partitionID];
		}

		if (partitionHandler != nil)
		{
			[self detachPartitionHandler:partitionHandler completionHandler:completionHandler];
		}
	}
}

#pragma mark - Shutdown
- (void)finishTasksAndInvalidateWithCompletionHandler:(dispatch_block_t)completionHandler
{
}

- (void)invalidateAndCancelWithCompletionHandler:(dispatch_block_t)completionHandler
{
}

- (void)cancelNonCriticalRequests
{
}

#pragma mark - NSURLSessionDelegate

#pragma mark - NSURLSessionTaskDelegate
#pragma mark - NSURLSessionDataDelegate
#pragma mark - NSURLSessionDownloadDelegate

#pragma mark - Queue
- (void)queueBlock:(dispatch_block_t)block
{
	[_backend queueBlock:block];
}

@end
