//
//  OCCore+ItemList.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 23.07.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2018, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCCore+ItemList.h"
#import "OCCoreItemListTask.h"
#import "OCCore+SyncEngine.h"
#import "OCCore+Internal.h"
#import "OCLogger.h"
#import "OCMacros.h"
#import "OCQuery.h"
#import "NSError+OCError.h"
#import "NSString+OCPath.h"
#import "OCQuery+Internal.h"
#import "OCCore+FileProvider.h"
#import "OCCore+ItemUpdates.h"
#import "OCBackgroundManager.h"
#import "NSProgress+OCExtensions.h"
#import "OCCore+ItemPolicies.h"
#import "NSError+OCNetworkFailure.h"
#import "OCScanJobActivity.h"
#import "OCMeasurement.h"
#import "OCCoreUpdateScheduleRecord.h"
#import "OCLockManager.h"
#import "OCLockRequest.h"
#import <objc/runtime.h>

static OCHTTPRequestGroupID OCCoreItemListTaskGroupQueryTasks = @"queryItemListTasks";
static OCHTTPRequestGroupID OCCoreItemListTaskGroupBackgroundTasks = @"backgroundItemListTasks";

@implementation OCCore (ItemList)

- (NSUInteger)parallelItemListTaskCount
{
	switch (self.memoryConfiguration)
	{
		case OCCoreMemoryConfigurationMinimum:
			return (1);
		break;

		case OCCoreMemoryConfigurationDefault:
		default:
			return (2);
		break;
	}
}

#pragma mark - Item List Tasks
- (void)scheduleItemListTaskForPath:(OCPath)path forDirectoryUpdateJob:(nullable OCCoreDirectoryUpdateJob *)directoryUpdateJob withMeasurement:(nullable OCMeasurement *)measurement
{
	BOOL putInQueue = YES;

	if (path != nil)
	{
		if (directoryUpdateJob == nil)
		{
			directoryUpdateJob = [OCCoreDirectoryUpdateJob withPath:path];
			[directoryUpdateJob attachMeasurement:measurement];
		}

		@synchronized(_queuedItemListTaskUpdateJobs)
		{
			BOOL forQuery = directoryUpdateJob.isForQuery;
			OCCoreItemListTask *existingQueryTask = nil;

			if (forQuery)
			{
				putInQueue = NO;

				@synchronized(_itemListTasksByPath)
				{
					if ((existingQueryTask = _itemListTasksByPath[path]) != nil)
					{
						putInQueue = YES;
					}
				}
			}

			if ((self.state == OCCoreStateStopping) || (self.state == OCCoreStateStopped) || (!forQuery && (self.connectionStatus != OCCoreConnectionStatusOnline)))
			{
				putInQueue = YES;
			}

			if (putInQueue)
			{
				[_queuedItemListTaskUpdateJobs addObject:directoryUpdateJob];

				if (existingQueryTask != nil)
				{
					if ((existingQueryTask.cachedSet.state == OCCoreItemListStateSuccess) ||
					    (existingQueryTask.cachedSet.state == OCCoreItemListStateFailed))
					{
						// Make sure a new query is not waiting for a queued update job
						// by notifying the core of changes to the existing query task
						// for the same target, which triggers an OCQuery update with
						// the existing content
						// [self handleUpdatedTask:existingQueryTask];

						// Instead, force an update of the cache set, due to the possibility of
						// changes having occured since the cachedSet was first requested. Once
						// finished, that'll also trigger -handleUpdatedTask:
						[existingQueryTask forceUpdateCacheSet];
					}
				}
			}
			else
			{
				OCCoreItemListTask *task;

				if ((task = [self _scheduleItemListTaskForDirectoryUpdateJob:directoryUpdateJob]) != nil)
				{
					[_scheduledItemListTasks addObject:task];
				}
			}
		}

		if (putInQueue)
		{
			[self scheduleNextItemListTask];
		}
	}
}

- (void)scheduleNextItemListTask
{
	OCCoreDirectoryUpdateJob *nextUpdateJob = nil;

	@synchronized(_queuedItemListTaskUpdateJobs)
	{
		if ((self.state != OCCoreStateStopping) && (self.state != OCCoreStateStopped))
		{
			// Check for tasks waiting to be (re)started
			if (_scheduledItemListTasks.count != 0)
			{
				for (OCCoreItemListTask *itemListTask in _scheduledItemListTasks)
				{
					[itemListTask updateIfNew];
				}
			}

			// Check for free capacities and try to fill them
			if (_scheduledItemListTasks.count < self.parallelItemListTaskCount)
			{
				// Check for high-priority query item list update jobs
				for (OCCoreDirectoryUpdateJob *updateJob in _queuedItemListTaskUpdateJobs)
				{
					if (updateJob.isForQuery)
					{
						nextUpdateJob = updateJob;
						break;
					}
				}

				if (nextUpdateJob == nil)
				{
					// If no high-priority query item list update job has been found => proceed with top of the list
					nextUpdateJob = _queuedItemListTaskUpdateJobs.firstObject;
				}

				if (nextUpdateJob != nil)
				{
					// Remove the update job and any targeting the same path (effectively coalescating the tasks)
					NSMutableIndexSet *removeIndexes = [NSMutableIndexSet new];

					[_queuedItemListTaskUpdateJobs enumerateObjectsUsingBlock:^(OCCoreDirectoryUpdateJob * _Nonnull updateJob, NSUInteger idx, BOOL * _Nonnull stop) {
						if (nextUpdateJob == updateJob)
						{
							[removeIndexes addIndex:idx];
						}
						else
						{
							if ([updateJob.path isEqual:nextUpdateJob.path])
							{
								// Add to represented array, so the database can be cleaned up properly
								[nextUpdateJob addRepresentedJobID:updateJob.identifier];
								[removeIndexes addIndex:idx];
							}
						}
					}];

					[_queuedItemListTaskUpdateJobs removeObjectsAtIndexes:removeIndexes];
				}

				if (nextUpdateJob != nil)
				{
					OCCoreItemListTask *task;

					if ((task = [self _scheduleItemListTaskForDirectoryUpdateJob:nextUpdateJob]) != nil)
					{
						[_scheduledItemListTasks addObject:task];
					}
				}
			}
		}
	}
}

- (OCCoreItemListTask *)_scheduleItemListTaskForDirectoryUpdateJob:(OCCoreDirectoryUpdateJob *)updateJob
{
	OCCoreItemListTask *task = nil;
	OCHTTPRequestGroupID groupID = nil;
	OCPath path = updateJob.path;

	if (updateJob.identifier != nil)
	{
		 groupID = OCCoreItemListTaskGroupBackgroundTasks;
	}
	else
	{
		 groupID = OCCoreItemListTaskGroupQueryTasks;
	}

	if (path!=nil)
	{
		@synchronized(_itemListTasksByPath)
		{
			task = _itemListTasksByPath[path];
		}

		if (task != nil)
		{
			// Don't start a new item list task if one is already running for the path
			// Instead, "handle" the running task again so that a new query is immediately updated
			[self handleUpdatedTask:task];

			// Transfer represented job IDs to job of the task, so these job(s) will also finish
			// and the database be updated respectively
			for (OCCoreDirectoryUpdateJobID jobID in updateJob.representedJobIDs)
			{
				[task.updateJob addRepresentedJobID:jobID];
			}

			return (nil);
		}

		if ((task = [[OCCoreItemListTask alloc] initWithCore:self path:path updateJob:updateJob]) != nil)
		{
			task.groupID = groupID;

			[task attachMeasurement:updateJob.extractedMeasurement];

			@synchronized(_itemListTasksByPath)
			{
				_itemListTasksByPath[task.path] = task;
			}

			if (updateJob.isForQuery)
			{
				[self.activityManager update:[OCActivityUpdate publishingActivityFor:task]];
			}
			else
			{
				[self _updateBackgroundScanActivityWithIncrement:NO currentPathChange:path];
			}

			// Start item list task
			if (task.syncAnchorAtStart == nil)
			{
				task.changeHandler = ^(OCCore *core, OCCoreItemListTask *task) {
					// Changehandler is executed wrapped into -queueBlock: so this is executed on the core's queue
					[core handleUpdatedTask:task];
				};

				// Retrieve and store current sync anchor value
				[self retrieveLatestSyncAnchorWithCompletionHandler:^(NSError *error, OCSyncAnchor syncAnchor) {
					task.syncAnchorAtStart = syncAnchor;

					[task update];
				}];
			}
			else
			{
				[task update];
			}
		}
	}

	return (task);
}

- (void)_finishedItemListTask:(OCCoreItemListTask *)finishedTask
{
	if (finishedTask != nil)
	{
		@synchronized(_queuedItemListTaskUpdateJobs)
		{
			BOOL removeJobFromDatabase = YES;

			[_scheduledItemListTasks removeObject:finishedTask];

			if (_scheduledItemListTasks.count < self.parallelItemListTaskCount)
			{
				[self scheduleNextItemListTask];
			}

			if ((!finishedTask.updateJob.isForQuery) && (finishedTask.retrievedSet.error != nil))
			{
				// Task is not for query (=> background scan) and terminated due to an error
				OCLog(@"Removing update job for %@ with cacheError=%@, retrieveError=%@", finishedTask.path, finishedTask.cachedSet.error, finishedTask.retrievedSet.error);

				if (finishedTask.retrievedSet.error.isNetworkFailureError)
				{
					// Task should be repeated when connectivity comes back online
					removeJobFromDatabase = NO;
				}
			}

			for (OCCoreDirectoryUpdateJobID doneJobID in finishedTask.updateJob.representedJobIDs)
			{
				if (removeJobFromDatabase)
				{
					[self.vault.database removeDirectoryUpdateJobWithID:doneJobID completionHandler:^(OCDatabase *db, NSError *error) {
						[self _handleCompletionOfUpdateJobWithID:doneJobID];
					}];
				}
				else
				{
					[self _handleCompletionOfUpdateJobWithID:doneJobID];
				}
			}
		}

		if (finishedTask.updateJob.isForQuery)
		{
			[self.activityManager update:[OCActivityUpdate unpublishActivityFor:finishedTask]];
		}
	}
}

- (void)handleUpdatedTask:(OCCoreItemListTask *)task
{
	OCQueryState queryState = OCQueryStateStarted;
	BOOL performMerge = NO;
	__block BOOL removeTask = NO;
	BOOL targetRemoved = NO;
	NSMutableArray <OCItem *> *queryResults = nil;
	__block NSMutableArray <OCItem *> *queryResultsChangedItems = nil;
	NSString *taskPath = task.path;
	__block OCSyncAnchor querySyncAnchor = nil;
	OCCoreItemListTask *nextTask = nil;

	OCLogDebug(@"Cached Set(%lu): %@", (unsigned long)task.cachedSet.state, OCLogPrivate(task.cachedSet.items));
	OCLogDebug(@"Retrieved Set(%lu): %@", (unsigned long)task.retrievedSet.state, OCLogPrivate(task.retrievedSet.items));

	OCMeasureEventBegin(task, @"core.task-update", taskUpdateEventRef, nil);

	[self beginActivity:@"item list task"];

	switch (task.cachedSet.state)
	{
		case OCCoreItemListStateSuccess:
			if (task.retrievedSet.state == OCCoreItemListStateSuccess)
			{
				// Merge item sets to final result and update cache
				queryState = OCQueryStateIdle;
				performMerge = YES;
				removeTask = YES;
			}
			else
			{
				// Use items from cache
				if (task.retrievedSet.state == OCCoreItemListStateStarted)
				{
					queryState = OCQueryStateWaitingForServerReply;
				}
				else
				{
					queryState = OCQueryStateContentsFromCache;

					if (task.retrievedSet.state == OCCoreItemListStateFailed)
					{
						if (task.retrievedSet.error != nil)
						{
							// Not Found => removed
							if (IsHTTPErrorWithStatus(task.retrievedSet.error, OCHTTPStatusCodeNOT_FOUND))
							{
								queryState = OCQueryStateTargetRemoved;
								targetRemoved = YES;
								performMerge = YES;
							}
						}

						removeTask = YES;
					}
				}
			}
		break;

		case OCCoreItemListStateFailed:
			// Error retrieving items from cache. This should never happen.
			OCLogError(@"Error retrieving items from cache for %@: %@", OCLogPrivate(task.path), OCLogPrivate(task.cachedSet.error));
			performMerge = YES;
			removeTask = YES;
		break;

		default:
		break;
	}

	if (performMerge && (task.path!=nil))
	{
		OCCoreItemListTask *existingTask;

		@synchronized(_itemListTasksByPath)
		{
			existingTask = _itemListTasksByPath[task.path];
		}

		if (existingTask != nil)
		{
			if (existingTask != task)
			{
				// Find end of chain
				while (existingTask.nextItemListTask != nil)
				{
					existingTask = existingTask.nextItemListTask;

					if (existingTask == task)
					{
						// Avoid adding the same task more than once into the chain
						goto earlyExit;
					}
				}

				// Link task at end of the chain
				existingTask.nextItemListTask = task;

				// Handle this task after the existingTask has finished (makes no sense to have two tasks concurrently update the same path)
				earlyExit:
				
				[self endActivity:@"item list task"];
				OCMeasureEventEnd(task, @"core.task-update", taskUpdateEventRef, nil);
				return;
			}
		}
		else
		{
			@synchronized(_itemListTasksByPath)
			{
				_itemListTasksByPath[task.path] = task;
			}
		}
	}

	if (performMerge)
	{
		// Perform merge
		OCCoreItemList *cacheSet = task.cachedSet;
		OCCoreItemList *retrievedSet = task.retrievedSet;
		NSMutableDictionary <OCFileID, OCItem *> *cacheItemsByFileID = cacheSet.itemsByFileID;
		NSMutableDictionary <OCFileID, OCItem *> *retrievedItemsByFileID = retrievedSet.itemsByFileID;
		NSMutableDictionary <OCPath, OCItem *> *cacheItemsByPath = cacheSet.itemsByPath;
		NSMutableDictionary <OCPath, OCItem *> *retrievedItemsByPath = retrievedSet.itemsByPath;

		NSMutableArray <OCItem *> *changedCacheItems = [NSMutableArray new];
		NSMutableArray <OCItem *> *deletedCacheItems = [NSMutableArray new];
		NSMutableArray <OCItem *> *newItems = [NSMutableArray new];

		__block NSError *cacheUpdateError = nil;

		queryResults = [NSMutableArray new];

		OCWaitInit(cacheUpdateGroup);

		OCWaitWillStartTask(cacheUpdateGroup);

		[self incrementSyncAnchorWithProtectedBlock:^NSError *(OCSyncAnchor previousSyncAnchor, OCSyncAnchor newSyncAnchor) {
			if (![previousSyncAnchor isEqualToNumber:task.syncAnchorAtStart])
			{
				// Out of sync - trigger catching the latest from the cache again, rinse and repeat
				OCLogDebug(@"IL[%@, path=%@]: Sync anchor changed before task finished: previousSyncAnchor=%@ != task.syncAnchorAtStart=%@", task, task.path, previousSyncAnchor, task.syncAnchorAtStart);

				task.syncAnchorAtStart = newSyncAnchor; // Update sync anchor before triggering the reload from cache

				cacheUpdateError = OCError(OCErrorOutdatedCache);
				OCWaitDidFinishTask(cacheUpdateGroup);

				return(nil);
			}

			/*
				Merge algorithm:
					- retrievedItem
						- corresponding cacheItem
							- with SAME fileID or SAME path
								- cacheItem has local changes or active sync status
									=> update cacheItem.remoteItem with retrievedItem
									=> changedItems += cacheItem

								- cacheItem has NO local changes or active sync status
									- fileID matches ?
										=> prepare retrievedItem to replace cacheItem
										=> changedItems += cacheItem
									- fileID doesn't match
										=> removedItems += cacheItem
										=> newItems += retrievedItem

						- no corresponding cacheItem
							=> newItems += retrievedItem

					- cacheItem
						- no corresponding retrievedItem with SAME fileID or SAME path
							- has been locally modified or has active sync records
								=> keep around
							- has neither
								=> remove
			*/

			// Iterate retrieved set
			[retrievedItemsByFileID enumerateKeysAndObjectsUsingBlock:^(OCFileID  _Nonnull retrievedFileID, OCItem * _Nonnull retrievedItem, BOOL * _Nonnull stop) {
				OCItem *cacheItem;

				// Item for this fileID already in the cache?
				if ((cacheItem = cacheItemsByFileID[retrievedFileID]) == nil)
				{
					// Alternatively: is there an item with the same path (but a different fileID)?
					cacheItem = cacheItemsByPath[retrievedItem.path];
				}

				// Found a corresponding cache item?
				if (cacheItem != nil)
				{
					// Overriding local item?
					if ((cacheItem.locallyModified && (cacheItem.localRelativePath!=nil)) || // Reason 1: existing local version that's been modified
  				            (cacheItem.activeSyncRecordIDs.count > 0)				 // Reason 2: item has active sync records
					   )
					{
						// Preserve local item, but merge in info on latest server version
						retrievedItem.localID = cacheItem.localID;
						cacheItem.remoteItem = retrievedItem;

						// Return updated cached version
						[queryResults addObject:cacheItem];

						// Update cache
						[changedCacheItems addObject:cacheItem];
					}
					else
					{
						if ([cacheItem.fileID isEqual:retrievedItem.fileID])
						{
							// Same item (identical fileID) at same or different path

							// Attach databaseID of cached items to the retrieved items
							[retrievedItem prepareToReplace:cacheItem];

							retrievedItem.localRelativePath = cacheItem.localRelativePath;
							retrievedItem.localCopyVersionIdentifier = cacheItem.localCopyVersionIdentifier;
							retrievedItem.downloadTriggerIdentifier = cacheItem.downloadTriggerIdentifier;

							if (![retrievedItem.itemVersionIdentifier isEqual:cacheItem.itemVersionIdentifier] || 	// ETag or FileID mismatch
							    ![retrievedItem.name isEqualToString:cacheItem.name] ||				// Name mismatch

							    (retrievedItem.shareTypesMask != cacheItem.shareTypesMask) ||			// Share types mismatch
							    (retrievedItem.permissions != cacheItem.permissions) ||				// Permissions mismatch
							    (retrievedItem.isFavorite != cacheItem.isFavorite))					// Favorite mismatch
							{
								// Update item in the cache if the server has a different version
								[changedCacheItems addObject:retrievedItem];
							}
						}
						else
						{
							// Different item (different fileID) at same path

							// It is important that the localID is NOT shared in that case, to deal with these edge cases:
							// - the original file still exists but has just been moved elsewhere
							// - the original file has really beeen deleted and replaced, in which case there would be a complication if
							//    a) the original file was downloaded
							//    b) the original file was then moved to "deleted"
							//    c) the new file uses the same localID and therefore the same item folder
							//    d) the new file is downloaded
							//    e) the original file entry is vacuumed and its folder (same as for new file because of same localID) is deleted
							//
							//    Result: new file's item still points to the local copy it downloaded, but which has been removed by vacuuming of the OLD file -> viewing and other actions requiring the local copy fail unexpectedly

							// Remove cacheItem (with different fileID)
							[deletedCacheItems addObject:cacheItem];

							// Add retrievedItem (with different fileID + different localID)
							retrievedItem.databaseID = nil;
							[newItems addObject:retrievedItem];
						}

						// Return server version
						[queryResults addObject:retrievedItem];
					}
				}
				else
				{
					// New item!
					[queryResults addObject:retrievedItem];
					[newItems addObject:retrievedItem];
				}
			}];

			// Iterate cache set
			[cacheItemsByFileID enumerateKeysAndObjectsUsingBlock:^(OCFileID  _Nonnull cacheFileID, OCItem * _Nonnull cacheItem, BOOL * _Nonnull stop) {
				OCItem *retrievedItem;

				// Item for this cached fileID or path on the server?
				if ((retrievedItem = retrievedItemsByFileID[cacheFileID]) == nil)
				{
					retrievedItem = retrievedItemsByPath[cacheItem.path];
				}

				if (retrievedItem == nil)
				{
					// Cache item no longer on the server
					if ((cacheItem.locallyModified && (cacheItem.localRelativePath!=nil)) || // Reason 1: existing local version that's been modified
  				            (cacheItem.activeSyncRecordIDs.count > 0)				 // Reason 2: item has active sync records
					   )
					{
						// Preserve locally modified items
						[queryResults addObject:cacheItem];
					}
					else
					{
						// Remove item
						[deletedCacheItems addObject:cacheItem];
					}
				}
			}];

			// Delete items located in deleted folders
			{
				__block NSMutableArray <OCItem *> *recursivelyDeletedItems = nil;

				for (OCItem *deletedItem in deletedCacheItems)
				{
					if (deletedItem.type == OCItemTypeCollection)
					{
						[self.database retrieveCacheItemsRecursivelyBelowPath:deletedItem.path includingPathItself:NO includingRemoved:NO completionHandler:^(OCDatabase *db, NSError *error, OCSyncAnchor syncAnchor, NSArray<OCItem *> *items) {
							if (items.count > 0)
							{
								if (recursivelyDeletedItems == nil)
								{
									recursivelyDeletedItems = [NSMutableArray new];
								}

								[recursivelyDeletedItems addObjectsFromArray:items];
							}
						}];
					}
				}

				if (recursivelyDeletedItems != nil)
				{
					[deletedCacheItems addObjectsFromArray:recursivelyDeletedItems];
				}
			}

			// Preserve localID for remotely moved, known items / preserve .removed status for locally removed items while deletion is in progress
			{
				NSMutableIndexSet *removeItemsFromDeletedItemsIndexes = nil;
				NSMutableIndexSet *removeItemsFromNewItemsIndexes = nil;

				NSUInteger newItemIndex = 0;

				for (OCItem *newItem in newItems)
				{
					__block OCItem *knownItem = nil;
					__block BOOL knownItemRemoved = NO;

					[self.database retrieveCacheItemForFileID:newItem.fileID includingRemoved:YES completionHandler:^(OCDatabase *db, NSError *error, OCSyncAnchor syncAnchor, OCItem *item) {
						knownItem = item;
						knownItemRemoved = knownItem.removed;
						knownItem.removed = NO;
					}];

					if (knownItem != nil)
					{
						NSUInteger index = 0;

						// Move over metaData
						OCLocalID parentLocalID = newItem.parentLocalID;

						[newItem prepareToReplace:knownItem];
						newItem.parentLocalID = parentLocalID; // Make sure the new parent localID is used

						newItem.locallyModified = knownItem.locallyModified; // Keep metadata on local copy
						newItem.localRelativePath = knownItem.localRelativePath;
						newItem.localCopyVersionIdentifier = knownItem.localCopyVersionIdentifier;
						newItem.downloadTriggerIdentifier = knownItem.downloadTriggerIdentifier;

						if (![knownItem.path isEqual:newItem.path])
						{
							// If paths aren't identical => pass along metadata
							newItem.previousPath = knownItem.path;
						}
						else
						{
							// Prevent files in process of deletion from re-appearing
							if (knownItemRemoved && // known item was marked removed
							   (knownItem.syncActivity & OCItemSyncActivityDeleting)) // known item is still in the process of removal
							{
								newItem.removed = knownItemRemoved; // carry over the removed status
								[queryResults removeObject:newItem]; // remove from query results
							}
						}

						// Remove from deletedCacheItems
						for (OCItem *deletedItem in deletedCacheItems)
						{
							if ([deletedItem.databaseID isEqual:newItem.databaseID])
							{
								if (removeItemsFromDeletedItemsIndexes == nil)
								{
									removeItemsFromDeletedItemsIndexes = [[NSMutableIndexSet alloc] initWithIndex:index];
								}
								else
								{
									[removeItemsFromDeletedItemsIndexes addIndex:index];
								}
							}

							index++;
						}

						// Remove from newItems
						if (removeItemsFromNewItemsIndexes == nil)
						{
							removeItemsFromNewItemsIndexes = [[NSMutableIndexSet alloc] initWithIndex:newItemIndex];
						}
						else
						{
							[removeItemsFromNewItemsIndexes addIndex:newItemIndex];
						}

						// Add to updatedItems
						[changedCacheItems addObject:newItem];
					}

					newItemIndex++;
				}

				// Commit changes
				if (removeItemsFromDeletedItemsIndexes != nil)
				{
					[deletedCacheItems removeObjectsAtIndexes:removeItemsFromDeletedItemsIndexes];
				}

				if (removeItemsFromNewItemsIndexes != nil)
				{
					[newItems removeObjectsAtIndexes:removeItemsFromNewItemsIndexes];
				}
			}

			// Export sync anchor value
			querySyncAnchor = newSyncAnchor;

			// Commit changes to the cache
			if (queryState == OCQueryStateIdle)
			{
				// Fully merged => use for updating existing queries that have already gone through their complete, initial update
				NSMutableArray<OCPath> *refreshPaths = [NSMutableArray new];
				NSMutableArray<OCItem *> *movedItems = [NSMutableArray new];
				BOOL fetchUpdatesRunning = NO;

				@synchronized(self->_fetchUpdatesCompletionHandlers)
				{
					fetchUpdatesRunning = (self->_fetchUpdatesCompletionHandlers.count > 0);
				}

				BOOL allowRefreshPathAddition = (self.automaticItemListUpdatesEnabled || fetchUpdatesRunning);

				// Determine refreshPaths if automatic item list updates are enabled
				for (OCItem *item in newItems)
				{
					if ((item.type == OCItemTypeCollection) && (item.path != nil) && (item.fileID!=nil) && (item.eTag!=nil) && ![item.path isEqual:task.path])
					{
						// Moved items are removed from newItems, updated and moved to changedCacheItems above, so that
						// such items should not end up ending up their item.path to refreshPaths here. Only truly new-
						// discovered collections will.
						if (allowRefreshPathAddition)
						{
							[refreshPaths addObject:item.path];
						}
					}
				}

				for (OCItem *item in changedCacheItems)
				{
					if ((item.type == OCItemTypeCollection) && (item.path != nil) && (item.fileID!=nil) && (item.eTag!=nil) && ![item.path isEqual:task.path])
					{
						__block OCItem *cacheItem = cacheItemsByFileID[item.fileID];

						if (cacheItem == nil)
						{
							[self.database retrieveCacheItemForFileID:item.fileID includingRemoved:YES completionHandler:^(OCDatabase *db, NSError *error, OCSyncAnchor syncAnchor, OCItem *item) {
								cacheItem = item;
							}];
						}

						// Do not trigger refreshes if only the name changed
						if ((cacheItem==nil) || ((cacheItem != nil) && ![cacheItem.itemVersionIdentifier isEqual:item.itemVersionIdentifier]))
						{
							if (allowRefreshPathAddition)
							{
								[refreshPaths addObject:item.path];
							}
						}

						// Check for (remotely) moved folders
						if ((cacheItem != nil) && [cacheItem.itemVersionIdentifier isEqual:item.itemVersionIdentifier] && // Folder unmodified
						    (![cacheItem.path isEqual:item.path]) && // Folder path changed
						    (cacheItem.activeSyncRecordIDs.count == 0)) // Folder has no ongoing sync activity (=> skips LOCALLY moved/renamed folders)
						{
							// Folder contents didn't change, but folder path did change
							// => update all contained items' path in the database
							[self.database iterateCacheItemsForQueryCondition:[OCQueryCondition where:OCItemPropertyNamePath startsWith:cacheItem.path] excludeRemoved:NO withIterator:^(NSError *error, OCSyncAnchor syncAnchor, OCItem *containedItem, BOOL *stop) {
								if ((containedItem != nil) && (containedItem.path != nil) && (containedItem.fileID != nil))
								{
									if (![containedItem.fileID isEqual:cacheItem.fileID])
									{
										if (item.activeSyncRecordIDs.count == 0)
										{
											// Item has no sync activity
											containedItem.previousPath = containedItem.path;
											containedItem.path = [item.path stringByAppendingPathComponent:[containedItem.path substringFromIndex:cacheItem.path.length]];

											if ([containedItem countOfSyncRecordsWithSyncActivity:OCItemSyncActivityDeleting] == 0)
											{
												containedItem.removed = NO;
											}

											[movedItems addObject:containedItem];
										}
										else
										{
											// Item with sync activity => skip
										}
									}
								}
							}];
						}
					}
				}

				if (refreshPaths.count == 0)
				{
					refreshPaths = nil;
				}

				if (movedItems.count > 0)
				{
					OCLogDebug(@"Moved items: %@", OCLogPrivate(movedItems));
					[changedCacheItems addObjectsFromArray:movedItems];
				}

				// Perform updates
				__block OCMeasurementEventReference coreQueueRef = 0;

				[self performUpdatesForAddedItems:newItems
						     removedItems:deletedCacheItems
						     updatedItems:changedCacheItems
						     refreshPaths:refreshPaths
						    newSyncAnchor:newSyncAnchor
					       beforeQueryUpdates:^(dispatch_block_t  _Nonnull completionHandler) {
							// Called AFTER the database has been updated, but before UPDATING queries
							OCWaitDidFinishTask(cacheUpdateGroup);

							OCMeasureEventBegin(task, @"itemlist.query-update", tmpCoreQueueRef, @"Perform query updates");
							coreQueueRef = tmpCoreQueueRef;

							completionHandler();
					       }
						afterQueryUpdates:^(dispatch_block_t  _Nonnull completionHandler) {
							OCMeasureEventEnd(task, @"itemlist.query-update", coreQueueRef, @"Done with query updates");

							OCMeasureEventBegin(task, @"itemlist.query-updates.finalize", finalizeQueryUpdateRef, @"Finalize query updates");
							[self _finalizeQueryUpdatesWithQueryResults:queryResults queryResultsChangedItems:queryResultsChangedItems queryState:queryState querySyncAnchor:querySyncAnchor task:task taskPath:taskPath targetRemoved:targetRemoved];
							OCMeasureEventEnd(task, @"itemlist.query-updates.finalize", finalizeQueryUpdateRef, @"Finalized query updates");
							OCMeasureLog(task);
							completionHandler();
						}
					       queryPostProcessor:nil
    					             skipDatabase:NO
				];
			}
			else
			{
				OCWaitDidFinishTask(cacheUpdateGroup);
			}

			return (nil);
		} completionHandler:^(NSError *error, OCSyncAnchor previousSyncAnchor, OCSyncAnchor newSyncAnchor) {
			OCLogDebug(@"Sync anchor increase result: %@ for %@ => %@", error, previousSyncAnchor, newSyncAnchor);
		}];

		OCWaitForCompletion(cacheUpdateGroup);

		if (cacheUpdateError != nil)
		{
			// An error occured updating the cache, so don't update queries either, log the error and return here
			if ([cacheUpdateError isOCErrorWithCode:OCErrorOutdatedCache])
			{
				// Sync anchor value increased while fetching data from the server
				OCLogDebug(@"Sync anchor changed, refreshing from cache before merge..");

				removeTask = NO; // Don't remove task just yet, we're still busy here

				OCMeasureEvent(task, @"core.task-update", @"Sync anchor induced update");

				[task _updateCacheSet];
				[self handleUpdatedTask:task];
			}
			else
			{
				// Actual error
				OCLogError(@"Error updating metaData cache: %@", cacheUpdateError);
			}

			[self endActivity:@"item list task"];
			OCMeasureEventEnd(task, @"core.task-update", taskUpdateEventRef, nil);

			return;
		}
	}
	else
	{
		if (task.cachedSet.state == OCCoreItemListStateSuccess)
		{
			// Use cache
			queryResults = (task.cachedSet.items != nil) ? [[NSMutableArray alloc] initWithArray:task.cachedSet.items] : [NSMutableArray new];
		}
		else
		{
			// No result (yet)
		}
	}

	// Remove task
	if (removeTask)
	{
		if (task.path != nil)
		{
			@synchronized(_itemListTasksByPath)
			{
				if (_itemListTasksByPath[task.path] == task)
				{
					if (task.nextItemListTask != nil)
					{
						_itemListTasksByPath[task.path] = task.nextItemListTask;
						nextTask = task.nextItemListTask;
						task.nextItemListTask = nil;
					}
					else
					{
						[_itemListTasksByPath removeObjectForKey:task.path];
					}
				}
			}
		}
	}

	if (queryState != OCQueryStateIdle)
	{
		[self beginActivity:@"item list task - update queries"];

		[self queueBlock:^{
			// Update non-idle queries
			[self _finalizeQueryUpdatesWithQueryResults:queryResults queryResultsChangedItems:queryResultsChangedItems queryState:queryState querySyncAnchor:querySyncAnchor task:task taskPath:taskPath targetRemoved:targetRemoved];

			if (removeTask)
			{
				[self _finishedItemListTask:task];
			}

			[self endActivity:@"item list task - update queries"];
		}];
	}
	else
	{
		if (removeTask)
		{
			[self _finishedItemListTask:task];
		}
	}

	// Handle next task in the chain (if any)
	if (nextTask != nil)
	{
		[self handleUpdatedTask:nextTask];
	}

	[self endActivity:@"item list task"];
	OCMeasureEventEnd(task, @"core.task-update", taskUpdateEventRef, nil);
}

- (void)_finalizeQueryUpdatesWithQueryResults:(NSMutableArray<OCItem *> *)queryResults queryResultsChangedItems:(NSMutableArray<OCItem *> *)queryResultsChangedItems queryState:(OCQueryState)queryState querySyncAnchor:(OCSyncAnchor)querySyncAnchor task:(OCCoreItemListTask * _Nonnull)task taskPath:(NSString *)taskPath targetRemoved:(BOOL)targetRemoved
{
	NSMutableDictionary <OCPath, OCItem *> *queryResultItemsByPath = nil;
	NSMutableArray <OCItem *> *queryResultWithoutRootItem = nil;
	OCItem *taskRootItem = nil;

	// Determine root item
	if ((taskPath != nil) && !targetRemoved)
	{
		OCItem *cacheRootItem = nil, *retrievedRootItem = nil;

		retrievedRootItem = task.retrievedSet.itemsByPath[taskPath];
		cacheRootItem = task.cachedSet.itemsByPath[taskPath];

		if ((taskRootItem==nil) && (cacheRootItem!=nil) && ([queryResults indexOfObjectIdenticalTo:cacheRootItem]!=NSNotFound))
		{
			taskRootItem = cacheRootItem;
		}

		if ((taskRootItem==nil) && (retrievedRootItem!=nil) && ([queryResults indexOfObjectIdenticalTo:retrievedRootItem]!=NSNotFound))
		{
			taskRootItem = retrievedRootItem;
		}
	}

	// Update queries
	NSArray *queries;

	@synchronized(self->_queries)
	{
		queries = [self->_queries copy];
	}

	for (OCQuery *query in queries)
	{
		NSMutableArray <OCItem *> *useQueryResults = nil;
		OCItem *queryRootItem = nil;
		OCPath queryPath = query.queryPath;
		OCPath queryItemPath = query.queryItem.path;
		BOOL taskPathIsAncestorOfQueryPath = (taskPath!=nil) && [queryPath hasPrefix:taskPath] && taskPath.isNormalizedDirectoryPath && ![queryPath isEqual:taskPath];
		OCQueryState setQueryState = (([queryPath isEqual:taskPath] || [queryItemPath isEqual:taskPath] || taskPathIsAncestorOfQueryPath) && !query.isCustom) ?
						queryState :
						query.state;

		// Queries targeting the path
		if ([queryPath isEqual:taskPath])
		{
			if (query.state != OCQueryStateIdle)	// Keep updating queries that have not gone through its complete, initial content update
			{
				OCLogDebug(@"Task root item: %@, include root item: %d", taskRootItem, query.includeRootItem);

				if (query.includeRootItem || (taskRootItem==nil))
				{
					useQueryResults = queryResults;
				}
				else
				{
					if (queryResultWithoutRootItem == nil)
					{
						queryResultWithoutRootItem = [[NSMutableArray alloc] initWithArray:queryResults];

						if (taskRootItem != nil)
						{
							[queryResultWithoutRootItem removeObjectIdenticalTo:taskRootItem];
						}
					}

					useQueryResults = queryResultWithoutRootItem;
				}

				queryRootItem = taskRootItem;
			}
		}
		else
		{
			// Queries targeting an item in a subdirectory of taskPath: check if that subdirectory exists
			if (taskPathIsAncestorOfQueryPath)
			{
				if ((task.cachedSet.state == OCCoreItemListStateSuccess) && (task.retrievedSet.state == OCCoreItemListStateSuccess) && (query.state != OCQueryStateIdle))
				{
					NSString *queryPathSubfolder;

					if ((queryPathSubfolder = [[queryPath substringFromIndex:taskPath.length] componentsSeparatedByString:@"/"].firstObject) != nil)
					{
						NSString *queryPathSubpath;

						if (queryResultItemsByPath == nil)
						{
							queryResultItemsByPath = [OCCoreItemList itemListWithItems:queryResults].itemsByPath;
						}

						if ((queryPathSubpath = [taskPath stringByAppendingPathComponent:queryPathSubfolder]) != nil)
						{
							if ((queryResultItemsByPath[queryPathSubpath] == nil) &&
							    (queryResultItemsByPath[queryPathSubpath.normalizedDirectoryPath] == nil))
							{
								// Relevant parent folder is missing
								queryResultItemsByPath = nil;

								useQueryResults = [NSMutableArray new];
								setQueryState = OCQueryStateTargetRemoved;
							}
						}
					}
				}

				if (targetRemoved && (queryState == OCQueryStateTargetRemoved))
				{
					// Relevant ancestor folder has been removed
					queryResultItemsByPath = nil;

					useQueryResults = [NSMutableArray new];
					setQueryState = OCQueryStateTargetRemoved;
				}
			}

			// Queries targeting a particular item
			if (queryItemPath != nil)
			{
				if (query.state != OCQueryStateIdle)	// Keep updating queries that have not gone through its complete, initial content update
				{
					OCItem *itemAtPath;

					if (queryResultItemsByPath == nil)
					{
						queryResultItemsByPath = [OCCoreItemList itemListWithItems:queryResults].itemsByPath;
					}

					if ((itemAtPath = queryResultItemsByPath[queryItemPath]) != nil)
					{
						// Item contained in queried directory, new info may be available
						if (itemAtPath.removed)
						{
							// Item was removed
							useQueryResults = [NSMutableArray new];
							setQueryState = OCQueryStateTargetRemoved;
						}
						else
						{
							// Use item for query
							useQueryResults = [[NSMutableArray alloc] initWithObjects:itemAtPath, nil];

							if (query.state == OCQueryStateStarted)
							{
								// Initial query results
								setQueryState = OCQueryStateIdle;
							}
						}
					}
					else
					{
						if ([[queryItemPath parentPath] isEqual:task.path])
						{
							// Item was contained in queried directory, but is no longer there
							useQueryResults = [NSMutableArray new];
							setQueryState = OCQueryStateTargetRemoved;
						}
					}
				}
			}

			// Queries targeting a sync anchor
			if ((query.querySinceSyncAnchor != nil) &&
			    (querySyncAnchor!=nil) &&
			    (taskRootItem!=nil) &&
			    (queryResultsChangedItems!=nil) &&
			    (queryResultsChangedItems.count > 0))
			{
				query.state = OCQueryStateWaitingForServerReply;

				[query mergeItemsToFullQueryResults:queryResultsChangedItems syncAnchor:querySyncAnchor];

				query.state = OCQueryStateIdle;

				[query setNeedsRecomputation];
			}
		}

		if (useQueryResults != nil)
		{
			@synchronized(query) // Protect full query results against modification (-setFullQueryResults: is protected using @synchronized(query), too)
			{
				query.state = setQueryState;
				query.rootItem = queryRootItem;
				query.fullQueryResults = useQueryResults;
			}
		}
	}

	// File provider signaling
	if ((self.postFileProviderNotifications) && (queryResultsChangedItems!=nil) && (queryResultsChangedItems.count > 0) && (taskRootItem!=nil))
	{
		[self signalChangesToFileProviderForItems:@[ taskRootItem ]];
	}
}

- (void)queueRequestJob:(OCAsyncSequentialQueueJob)requestJob
{
	[_itemListTasksRequestQueue async:requestJob];
}

#pragma mark - Check for updates
- (void)startCheckingForUpdates
{
	[self queueBlock:^{
		if (self->_directoryUpdateStartTime == 0)
		{
			OCTLog(@[@"ScanChanges"], @"Starting update scan");
			self->_directoryUpdateStartTime = NSDate.timeIntervalSinceReferenceDate;
		}

		[self coordinatedScanForChanges];
	}];
}

- (void)fetchUpdatesWithCompletionHandler:(OCCoreItemListFetchUpdatesCompletionHandler)completionHandler
{
	completionHandler = [completionHandler copy];

	[self queueConnectivityBlock:^{	// Make sure _attemptConnect has finished
		if (self.state != OCCoreStateRunning)
		{
			// Core not running even after waiting on connectivity queue / any pending _attemptConnect has finished
			if (completionHandler != nil)
			{
				completionHandler(OCError(OCErrorInternal), nil);
			}
			return;
		}

		[self queueBlock:^{
			@synchronized(self->_scheduledDirectoryUpdateJobIDs)
			{
				if (self->_scheduledDirectoryUpdateJobActivity == nil)
				{
					// If none is ongoing, start a new check for updates
					[self _checkForUpdatesNonCritical:NO inBackground:OCBackgroundManager.sharedBackgroundManager.isBackgrounded completionHandler:completionHandler];
				}
				else
				{
					if (completionHandler != nil)
					{
						@synchronized(self->_fetchUpdatesCompletionHandlers)
						{
							[self->_fetchUpdatesCompletionHandlers addObject:completionHandler];
						}
					}
				}
			}
		}];
	}];
}

- (void)_checkForUpdatesNonCritical:(BOOL)nonCritical inBackground:(BOOL)inBackground completionHandler:(OCCoreItemListFetchUpdatesCompletionHandler)completionHandler
{
	if (self.state != OCCoreStateRunning)
	{
		if (completionHandler != nil)
		{
			completionHandler(OCError(OCErrorInternal), NO);
		}
		return;
	}

	if (completionHandler != nil)
	{
		@synchronized(self->_fetchUpdatesCompletionHandlers)
		{
			[self->_fetchUpdatesCompletionHandlers addObject:completionHandler];
		}
	}

	__weak OCCore *weakSelf = self;

	[[OCBackgroundManager sharedBackgroundManager] scheduleBlock:^{
		OCCore *strongSelf = weakSelf;

		if (strongSelf != nil)
		{
			if (strongSelf.state == OCCoreStateRunning)
			{
				OCEventTarget *eventTarget;

				eventTarget = [OCEventTarget eventTargetWithEventHandlerIdentifier:strongSelf.eventHandlerIdentifier userInfo:nil ephermalUserInfo:nil];

				NSDictionary<OCConnectionOptionKey,id> *options = nil;

				if (nonCritical)
				{
					options = @{
						OCConnectionOptionIsNonCriticalKey : @(YES),
					};
				}

				[strongSelf.connection retrieveItemListAtPath:@"/" depth:0 options:options resultTarget:eventTarget];
			}
		}
	} inBackground:inBackground];
}

- (void)_handleRetrieveItemListEvent:(OCEvent *)event sender:(id)sender
{
	OCLogDebug(@"Handling background retrieved items: error=%@, path=%@, depth=%lu, items=%@", OCLogPrivate(event.error), OCLogPrivate(event.path), event.depth, OCLogPrivate(event.result));

	// Handle result
	if (event.error == nil)
	{
		// Single item change observation
		if ((event.result != nil) && (event.depth == 0) && (self.state == OCCoreStateRunning))
		{
			NSArray <OCItem *> *items = (NSArray <OCItem *> *)event.result;
			NSError *error = nil;
			OCItem *cacheItem = nil;
			OCItem *remoteItem = items.firstObject;
			NSArray<OCItem*> *cacheItems = nil;
			BOOL updateQuotaTotal = NO;

			if ([remoteItem.path isEqual:@"/"])
			{
				// Update root quota properties

				if (((_rootQuotaBytesRemaining != nil) != (remoteItem.quotaBytesRemaining != nil)) || (_rootQuotaBytesRemaining.integerValue != remoteItem.quotaBytesRemaining.integerValue))
				{
					[self willChangeValueForKey:@"rootQuotaBytesRemaining"];
					_rootQuotaBytesRemaining = remoteItem.quotaBytesRemaining;
					[self didChangeValueForKey:@"rootQuotaBytesRemaining"];

					updateQuotaTotal = YES;
				}

				if (((_rootQuotaBytesUsed != nil) != (remoteItem.quotaBytesUsed != nil)) || (_rootQuotaBytesUsed.integerValue != remoteItem.quotaBytesUsed.integerValue))
				{
					[self willChangeValueForKey:@"rootQuotaBytesUsed"];
					_rootQuotaBytesUsed = remoteItem.quotaBytesUsed;
					[self didChangeValueForKey:@"rootQuotaBytesUsed"];

					updateQuotaTotal = YES;
				}

				if (updateQuotaTotal)
				{
					[self willChangeValueForKey:@"rootQuotaBytesTotal"];
					_rootQuotaBytesTotal = (_rootQuotaBytesRemaining != nil) ?
							@(_rootQuotaBytesUsed.integerValue + _rootQuotaBytesRemaining.integerValue) :
							nil;
					[self didChangeValueForKey:@"rootQuotaBytesTotal"];
				}
			}

			if ((cacheItems = [self.database retrieveCacheItemsSyncAtPath:event.path itemOnly:YES error:&error syncAnchor:NULL]) != nil)
			{
				BOOL doSchedule = NO;

				if ((cacheItem = cacheItems.firstObject) != nil)
				{
					if (![cacheItem.itemVersionIdentifier isEqual:remoteItem.itemVersionIdentifier])
					{
						// Folder's etag or fileID differ -> fetch full update for this folder
						doSchedule = YES;
					}
				}
				else
				{
					// Root item not yet known in database
					if (event.path.isRootPath)
					{
						doSchedule = YES;
					}
				}

				if (doSchedule)
				{
					[self scheduleUpdateScanForPath:event.path waitForNextQueueCycle:NO];
				}
				else
				{
					// No changes. We're done.
					if (event.path.isRootPath)
					{
						@synchronized(_scheduledDirectoryUpdateJobIDs)
						{
							if (_scheduledDirectoryUpdateJobActivity == nil)
							{
								[self _finishedUpdateScanWithError:nil foundChanges:NO];
							}
						}
					}
				}
			}
		}
	}
	else
	{
		// Handle certificate errors while connected
		if (([event.error isOCErrorWithCode:OCErrorRequestServerCertificateRejected]) && (self.connectionStatus == OCCoreConnectionStatusOnline))
		{
			OCCertificate *certificate;
			OCIssue *certificateIssue = event.error.embeddedIssue;

			if ((certificateIssue != nil) && ((certificate = certificateIssue.certificate) != nil))
			{
				BOOL sendIssueToDelegate = NO;

				@synchronized(_warnedCertificates)
				{
					if (![_warnedCertificates containsObject:certificate])
					{
						[_warnedCertificates addObject:certificate];

						sendIssueToDelegate = YES;
					}
				}

				if (sendIssueToDelegate)
				{
					[self sendError:event.error issue:certificateIssue];
				}
			}
		}
	}

	// Schedule next
	if ((event.depth == 0) && ([event.path isEqual:@"/"]))
	{
		[self coordinatedScanForChangesDidFinish];
	}
}

- (NSTimeInterval)effectivePollForChangesInterval
{
	if (_effectivePollForChangesInterval == 0)
	{
		const NSTimeInterval defaultMinimumPollInterval = 10.0, minimumAllowedPollInterval = 5.0, warnPollIntervalThreshold = 60.0;
		NSTimeInterval effectivePollInterval = defaultMinimumPollInterval;
		NSString *effectivePollIntervalSource = @"default";
		BOOL loggedPollIntervalWarning = NO;

		// Capabilities
		if (self.connection.capabilities.pollInterval != nil)
		{
			// Server default is 60 seconds, but iOS default is 10 seconds
			// also the capability is no longer in seconds, but milliseconds,
			// so ignore anything less than 5 seconds, warn for anything greater
			// than 60 seconds

			NSTimeInterval configuredTimeInterval = self.connection.capabilities.pollInterval.doubleValue / 1000.0;

			if (configuredTimeInterval < minimumAllowedPollInterval)
			{
				if (self.connection.capabilities.pollInterval.integerValue != 60)
				{
					OCTLogError(@[@"ScanChanges"], @"Poll interval in capabilities (%@) not server legacy default (60 (sec)), and - as milliseconds - less than minimum allowed poll interval (%.02f sec). Ignoring value.", self.connection.capabilities.pollInterval, minimumAllowedPollInterval);
					loggedPollIntervalWarning = YES;
				}
			}
			else
			{
				effectivePollInterval = configuredTimeInterval;
				effectivePollIntervalSource = @"capabilities";
			}
		}

		// Class Settings
		NSNumber *classSettingsInterval;

		if ((classSettingsInterval = [self classSettingForOCClassSettingsKey:OCCoreScanForChangesInterval]) != nil)
		{
			NSTimeInterval configuredTimeInterval = classSettingsInterval.doubleValue / 1000.0;

			if (configuredTimeInterval < minimumAllowedPollInterval)
			{
				OCTLogError(@[@"ScanChanges"], @"MDM/Branding: poll interval %.03f less than minimum allowed poll interval (%.02f sec). Ignoring value.", configuredTimeInterval, minimumAllowedPollInterval);
				loggedPollIntervalWarning = YES;
			}
			else
			{
				effectivePollInterval = configuredTimeInterval;
				effectivePollIntervalSource = @"ClassSettings";
			}
		}

		// Log warning when exceeding threshold
		if (effectivePollInterval > warnPollIntervalThreshold)
		{
			OCTLogWarning(@[@"ScanChanges"], @"Poll interval (%@) of %.02f sec > %.02f sec", effectivePollIntervalSource, effectivePollInterval, warnPollIntervalThreshold);
			loggedPollIntervalWarning = YES;
		}

		if (loggedPollIntervalWarning)
		{
			OCTLog(@[@"ScanChanges"], @"Using poll interval of %.02f sec (%@)", effectivePollInterval, effectivePollIntervalSource);
		}

		_effectivePollForChangesInterval = effectivePollInterval;
	}

	return (_effectivePollForChangesInterval);
}

#pragma mark - Update Scan finish
- (void)_finishedUpdateScanWithError:(nullable NSError *)error foundChanges:(BOOL)foundChanges
{
	NSArray<OCCoreItemListFetchUpdatesCompletionHandler> *completionHandlers = nil;

	@synchronized(self->_fetchUpdatesCompletionHandlers)
	{
		completionHandlers = [_fetchUpdatesCompletionHandlers copy];
		[_fetchUpdatesCompletionHandlers removeAllObjects];
	}

	if (foundChanges || !_itemPoliciesAppliedInitially)
	{
		_itemPoliciesAppliedInitially = YES;

		[self runProtectedPolicyProcessorsForTrigger:OCItemPolicyProcessorTriggerItemListUpdateCompleted];
	}
	else
	{
		[self runProtectedPolicyProcessorsForTrigger:OCItemPolicyProcessorTriggerItemListUpdateCompletedWithoutChanges];
	}

	if (_directoryUpdateStartTime != 0)
	{
		OCTLog(@[@"ScanChanges"], @"Finished update scan in %.1f sec", NSDate.timeIntervalSinceReferenceDate - _directoryUpdateStartTime);
		_directoryUpdateStartTime = 0;
	}

	for (OCCoreItemListFetchUpdatesCompletionHandler completionHandler in completionHandlers)
	{
		completionHandler(error, foundChanges);
	}
}

#pragma mark - Update Scans
- (void)scheduleUpdateScanForPath:(OCPath)path waitForNextQueueCycle:(BOOL)waitForNextQueueCycle
{
	OCCoreDirectoryUpdateJob *updateScanPath;

	OCLogDebug(@"Scheduling scan for path=%@, waitForNextCycle: %d", path, waitForNextQueueCycle);

	if ((updateScanPath = [OCCoreDirectoryUpdateJob withPath:path]) != nil)
	{
		[self beginActivity:@"Scheduling update scan"];

		dispatch_block_t doneSchedulingPendingDirectoryUpdateJob = ^{
			@synchronized(self->_scheduledDirectoryUpdateJobIDs)
			{
				self->_pendingScheduledDirectoryUpdateJobs--;
			}

			[self endActivity:@"Scheduling update scan"];
		};

		@synchronized(_scheduledDirectoryUpdateJobIDs)
		{
			_pendingScheduledDirectoryUpdateJobs++;
		}

		[self.database retrieveDirectoryUpdateJobsAfter:nil forPath:path maximumJobs:1 completionHandler:^(OCDatabase *db, NSError *error, NSArray<OCCoreDirectoryUpdateJob *> *updateJobs) {
			if (updateJobs.count > 0)
			{
				// Don't schedule
				OCLogDebug(@"Skipping duplicate update job for path=%@", path);
				doneSchedulingPendingDirectoryUpdateJob();
				[self _checkForUpdateJobsCompletion];

				return;
			}

			[self.database addDirectoryUpdateJob:updateScanPath completionHandler:^(OCDatabase *db, NSError *error, OCCoreDirectoryUpdateJob *scanPath) {
				if (error == nil)
				{
					if (waitForNextQueueCycle)
					{
						[self queueBlock:^{
							[self _scheduleUpdateJob:updateScanPath];
							doneSchedulingPendingDirectoryUpdateJob();
						}];
					}
					else
					{
						[self _scheduleUpdateJob:updateScanPath];
						doneSchedulingPendingDirectoryUpdateJob();
					}
				}
			}];
		}];
	}
}

- (void)recoverPendingUpdateJobs
{
	[self.database retrieveDirectoryUpdateJobsAfter:nil forPath:nil maximumJobs:0 completionHandler:^(OCDatabase *db, NSError *error, NSArray<OCCoreDirectoryUpdateJob *> *updateJobs) {
		OCLogDebug(@"Recovering pending update jobs");

		for (OCCoreDirectoryUpdateJob *job in updateJobs)
		{
			[self _scheduleUpdateJob:job];
		}
	}];
}

- (void)_scheduleUpdateJob:(OCCoreDirectoryUpdateJob *)job
{
	BOOL schedule = YES;

	OCLogDebug(@"Scheduling update job %@", job);

	@synchronized (_scheduledDirectoryUpdateJobIDs)
	{
		if (job.identifier != nil)
		{
			schedule = ![_scheduledDirectoryUpdateJobIDs containsObject:job.identifier];

			if (schedule)
			{
				[_scheduledDirectoryUpdateJobIDs addObject:job.identifier];

				[self _updateBackgroundScanActivityWithIncrement:YES currentPathChange:nil];
			}
		}
	}

	if (schedule)
	{
		[self scheduleItemListTaskForPath:job.path forDirectoryUpdateJob:job withMeasurement:nil];
	}
}

- (void)_updateBackgroundScanActivityWithIncrement:(BOOL)increment currentPathChange:(OCPath)currentPathChange
{
	@synchronized(_scheduledDirectoryUpdateJobIDs)
	{
		NSUInteger activeScheduledJobsCount = _scheduledDirectoryUpdateJobIDs.count;

		if ((activeScheduledJobsCount > 0) || (_pendingScheduledDirectoryUpdateJobs > 0))
		{
			const int64_t progressTotalUnitCount = 1000;

			// Publish background scan activity
			if (_scheduledDirectoryUpdateJobActivity == nil)
			{
				_scheduledDirectoryUpdateJobActivity = [OCScanJobActivity withIdentifier:OCActivityIdentifierPendingServerScanJobsSummary description:OCLocalizedString(@"Fetching updates…", @"") statusMessage:nil ranking:0];
				_scheduledDirectoryUpdateJobActivity.state = OCActivityStateRunning;
				_scheduledDirectoryUpdateJobActivity.progress = [NSProgress new];
				_scheduledDirectoryUpdateJobActivity.isCancellable = NO;

				_scheduledDirectoryUpdateJobActivity.progress.totalUnitCount = progressTotalUnitCount;
				_scheduledDirectoryUpdateJobActivity.progress.completedUnitCount = 0;
				_scheduledDirectoryUpdateJobActivity.progress.cancellable = NO;

				[self.activityManager update:[OCActivityUpdate publishingActivity:_scheduledDirectoryUpdateJobActivity]];
			}

			// Update background scan activity
			if (increment)
			{
				_totalScheduledDirectoryUpdateJobs++;
			}

			if (currentPathChange != nil)
			{
				_scheduledDirectoryUpdateJobActivity.completedUpdateJobs = _totalScheduledDirectoryUpdateJobs - activeScheduledJobsCount;
				_scheduledDirectoryUpdateJobActivity.totalUpdateJobs = _totalScheduledDirectoryUpdateJobs;
			}

			_scheduledDirectoryUpdateJobActivity.progress.completedUnitCount = (((_totalScheduledDirectoryUpdateJobs + _pendingScheduledDirectoryUpdateJobs) - activeScheduledJobsCount) * progressTotalUnitCount) / (_totalScheduledDirectoryUpdateJobs + _pendingScheduledDirectoryUpdateJobs);
		}
		else
		{
			// Unpublish background scan activity
			[self.activityManager update:[OCActivityUpdate unpublishActivityForIdentifier:_scheduledDirectoryUpdateJobActivity.identifier]];
			_scheduledDirectoryUpdateJobActivity = nil;
			_totalScheduledDirectoryUpdateJobs = 0;

			[self _finishedUpdateScanWithError:nil foundChanges:YES];
		}
	}
}

- (void)_handleCompletionOfUpdateJobWithID:(OCCoreDirectoryUpdateJobID)doneJobID
{
	@synchronized (_scheduledDirectoryUpdateJobIDs)
	{
		[_scheduledDirectoryUpdateJobIDs removeObject:doneJobID];

		[self _updateBackgroundScanActivityWithIncrement:NO currentPathChange:nil];
	}

	[self _checkForUpdateJobsCompletion];
}

- (void)_checkForUpdateJobsCompletion
{
	@synchronized(_scheduledDirectoryUpdateJobIDs)
	{
		if (OCLogger.logLevel == OCLogLevelVerbose)
		{
			OCLogVerbose(@"Remaining scheduled directory update jobs: %@ - pendingScheduledDirectoryUpdateJobs: %lu", _scheduledDirectoryUpdateJobIDs, _pendingScheduledDirectoryUpdateJobs);
		}
		else
		{
			OCLogDebug(@"Remaining scheduled directory update jobs: %lu - pendingScheduledDirectoryUpdateJobs: %lu", (unsigned long)_scheduledDirectoryUpdateJobIDs.count, _pendingScheduledDirectoryUpdateJobs);
		}

		// Check local count
		if ((_scheduledDirectoryUpdateJobIDs.count == 0) && (_pendingScheduledDirectoryUpdateJobs == 0))
		{
			// Check database
			OCLogDebug(@"Completed scheduled directory update jobs!");
		}
	}
}

#pragma mark - Periodic scan coordination
/*
	CONCEPT : Strategy to avoid parallel scans from several processes

	- expiring OCLock on the scan itself
		- will be kept alive as long as the process performing the scan is still active
		- will eventually expire if the performing process is killed, paused or terminated
	- shared records
		- record when the last scan was started ($beginScanTime) and ended ($endScanTime), to coordinate poll intervals
		- record of when each component (per OCAppIdentity.componentIdentifier) last did, or would like to have performed, an update scan ($lastComponentAttemptTimestamp)
			- to establish priorities
			- as continuously updated vital sign for a component
	- algorithm for "considerScan":
		- check last time the last scan ended or, where not available, began
			- otherwise schedule considerScan again in $secondsRemainigUntilPollInterval is up, update $lastComponentAttemptTimestamp
			- if more than $pollInterval seconds ago, proceed \/
		- priority: check the $lastComponentAttemptTimestamp of other components
			- if a higher-ranking component (using OCAppIdentity.componentIdentifier: app, fileprovider, * (anything else)) saved a timestamp less than ($pollInterval * 2) seconds ago, update own $lastComponentAttemptTimestamp and reschedule considerScan in (($pollInterval * 2) + 2)
			- otherwhise proceed \/
		- attempt to acquire shared lock
			- if it can't be acquired, schedule another considerScan in $pollInterval seconds, update $lastComponentAttemptTimestamp
			- if it can be acquired, proceed \/
		- update $lastComponentAttemptTimestamp
		- update $beginScanTime
		- perform scan
		- update $endScanTime
*/
- (void)_retryCoordinatedScanForChangesIn:(NSTimeInterval)delay
{
	__weak OCCore *weakSelf = self;

	if (self.state == OCCoreStateRunning)
	{
		@synchronized([OCCoreItemList class])
		{
			NSTimeInterval _nextRetryDate = NSDate.timeIntervalSinceReferenceDate;

			if (_nextCoordinatedScanRetryTime < _nextRetryDate)
			{
				_nextRetryDate += delay;
				_nextCoordinatedScanRetryTime = _nextRetryDate;
			}
			else
			{
				OCTLogDebug(@[@"ScanChanges"], @"Consolidating retries (skipping retry in %f sec, another is already scheduled in %f sec)", delay, (_nextCoordinatedScanRetryTime - _nextRetryDate));
				return;
			}
		}

		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
			OCCore *core;

			if (((core = weakSelf) != nil) &&
			    (core.state == OCCoreStateRunning))
			{
				OCWTLogDebug(@[@"ScanChanges"], @"Retry of coordinated scan scheduled %f sec ago:", delay);
				[core coordinatedScanForChanges];
			}
		});
	}
}

- (void)coordinatedScanForChanges
{
	// Ensure execution on OCCore queue, where all OCKeyValueStore operations happen
	[self queueBlock:^{
		[self _coordinatedScanForChanges];
	} allowInlining:YES];
}

- (void)_coordinatedScanForChanges
{
	__weak OCCore *weakSelf = self;

	OCTLogDebug(@[@"ScanChanges"], @"Entering coordinated scan for changes…");

	if (self.state == OCCoreStateRunning)
	{
		NSDate *nextScanDate;

		if ((_scanForChangesLock != nil) && !_scanForChangesLock.isValid)
		{
			// Dispose lock if invalid
			[_scanForChangesLock releaseLock];
			_scanForChangesLock = nil;
		}

		// Determine next scan date
		if ((nextScanDate = [self nextCoordinatedScanForChangesDateWithLock:_scanForChangesLock]) == nil)
		{
			// Attempt scan now
			if (_scanForChangesLock.isValid)
			{
				// Scan now, but not in the background (=> would lead to force termination by iOS)
				OCTLogDebug((@[@"ScanChanges", @"PerformScan"]), @"## Initiating scan, with valid lock %@", _scanForChangesLock);
				[self _checkForUpdatesNonCritical:YES inBackground:NO completionHandler:nil];
			}
			else
			{
				// Dispose of invalid lock (if any)
				[_scanForChangesLock releaseLock];
				_scanForChangesLock = nil;
			}

			if (_scanForChangesLock == nil)
			{
				// Acquire lock first, then retry

				if (_scanForChangesLockRequest == nil) // do not make second request if another one is already in progress - do nothing in that case
				{
					_scanForChangesLockRequest = [[OCLockRequest alloc] initWithResourceIdentifier:[OCLockResourceIdentifierCoreUpdateScan stringByAppendingFormat:@":%@",_bookmark.uuid.UUIDString] tryAcquireHandler:^(NSError * _Nullable error, OCLock * _Nullable lock) {
						OCCore *core;

						if ((core = weakSelf) != nil)
						{
							[core queueBlock:^{
								OCCore *core;

								// Set _scanForChangesLockRequest to nil to allow scans after that
								if ((core = weakSelf) != nil)
								{
									OCWTLogDebug(@[@"ScanChanges"], @"Release lock request %@", core->_scanForChangesLockRequest);
									core->_scanForChangesLockRequest = nil;
								}
							} allowInlining:YES];

							if ((error == nil) && (lock != nil))
							{
								// Lock could be acquired
								if (core.state == OCCoreStateRunning)
								{
									// Try scan again, this time with lock
									core->_scanForChangesLock = lock;

									OCWTLogDebug(@[@"ScanChanges"], @"Acquired lock %@, retrying", core->_scanForChangesLock);

									[core coordinatedScanForChanges];
								}
								else
								{
									// Release lock immediately
									OCWTLogDebug(@[@"ScanChanges"], @"Core not running, release lock");
									[lock releaseLock];
								}
							}
							else if (core.state == OCCoreStateRunning)
							{
								// Lock could not be acquired, try again in $pollInterval
								OCWTLogDebug(@[@"ScanChanges"], @"Retrying after poll interval of %f (error: %@)", core.effectivePollForChangesInterval, error);
								[core _retryCoordinatedScanForChangesIn:core.effectivePollForChangesInterval];
							}
						}
					}];

					OCTLogDebug(@[@"ScanChanges"], @"Scan now - request lock %@", _scanForChangesLockRequest);

					[OCLockManager.sharedLockManager requestLock:_scanForChangesLockRequest];
				}
				else
				{
					OCTLogDebug(@[@"ScanChanges"], @"Scan now - do nothing since a lock request is still pending");
				}
			}
		}
		else
		{
			// Retry at nextScanDate
			NSTimeInterval remainingTime = [nextScanDate timeIntervalSinceNow];

			if (remainingTime < 1.0)
			{
				remainingTime = 1.0;
			}

			OCTLogDebug(@[@"ScanChanges"], @"Retrying at %@ (in %f seconds)", nextScanDate, remainingTime);

			[self _retryCoordinatedScanForChangesIn:remainingTime];
		}
	}
	else
	{
		OCTLogDebug(@[@"ScanChanges"], @"Coordinated scan for changes skipped because state is %lu", (unsigned long)self.state);
	}
}

- (void)coordinatedScanForChangesDidFinish
{
	OCKeyValueStore *keyValueStore = self.vault.keyValueStore;

	OCTLogDebug(@[@"ScanChanges"], @"Coordinated scan for changes finished");

	if (_scanForChangesLock.isValid) {
		[keyValueStore updateObjectForKey:OCKeyValueStoreKeyCoreUpdateScheduleRecord usingModifier:^id _Nullable(OCCoreUpdateScheduleRecord *updateScheduleRecord, BOOL * _Nonnull outDidModify) {
			[updateScheduleRecord endCheck];

			*outDidModify = YES;

			return (updateScheduleRecord);
		}];
	}

	[_scanForChangesLock releaseLock];
	_scanForChangesLock = nil;

	[self coordinatedScanForChanges];
}

- (nullable NSDate *)nextCoordinatedScanForChangesDateWithLock:(OCLock *)scanLock
{
	OCKeyValueStore *keyValueStore = self.vault.keyValueStore;
	__block NSDate *nextScanDate = nil; // Scan now

	[keyValueStore updateObjectForKey:OCKeyValueStoreKeyCoreUpdateScheduleRecord usingModifier:^id _Nullable(OCCoreUpdateScheduleRecord *updateScheduleRecord, BOOL * _Nonnull outDidModify) {
		// Check last time the last scan ended or, where not available, began
		//	- otherwise schedule considerScan again in $secondsRemainigUntilPollInterval is up, update $lastComponentAttemptTimestamp
		//	- if more than $pollInterval seconds ago, proceed \/
		if (updateScheduleRecord != nil)
		{
			updateScheduleRecord.pollInterval = [self effectivePollForChangesInterval];
			nextScanDate = [updateScheduleRecord nextDateByBeginAndEndDate];
		}
		else
		{
			updateScheduleRecord = [OCCoreUpdateScheduleRecord new];
			updateScheduleRecord.pollInterval = [self effectivePollForChangesInterval];
		}

		// Priority: check the $lastComponentAttemptTimestamp of other components
		// - if a higher-ranking component (using OCAppIdentity.componentIdentifier: app, fileprovider, * (anything else))
		//   saved a timestamp less than ($pollInterval * 2) seconds ago, update own $lastComponentAttemptTimestamp and
		//   reschedule considerScan in (($pollInterval * 2) + 2)
		// - otherwhise proceed \/
		if (nextScanDate == nil)
		{
			NSString *prioritizedComponent = nil;

			if ((nextScanDate = [updateScheduleRecord nextDateByPrioritizedComponents:&prioritizedComponent]) != nil)
			{
				OCTLogDebug(@[@"ScanChanges"], @"Postponing coordinated scan because of higher priority of other component: %@", prioritizedComponent);
			}
		}

		if ((nextScanDate == nil) && (scanLock != nil))
		{
			if (scanLock.isValid)
			{
				// Register start of scan if no nextScanDate has been returned yet
				[updateScheduleRecord beginCheck];
			}
			else
			{
				// No valid lock, reschedule in pollInterval
				nextScanDate = [NSDate dateWithTimeIntervalSinceNow:updateScheduleRecord.pollInterval];
			}
		}

		// Update component timestamp
		[updateScheduleRecord updateComponentTimestamp];
		*outDidModify = YES;

		return (updateScheduleRecord);
	}];

	return (nextScanDate);
}

- (void)shutdownCoordinatedScanForChanges
{
	[_scanForChangesLock releaseLock];
	_scanForChangesLock = nil;
}

@end

OCActivityIdentifier OCActivityIdentifierPendingServerScanJobsSummary = @"_pendingUpdateJobsSummary";

OCKeyValueStoreKey OCKeyValueStoreKeyCoreUpdateScheduleRecord = @"lastPollForChangesDate";
OCLockResourceIdentifier OCLockResourceIdentifierCoreUpdateScan = @"coreUpdateScan";
