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
#import "NSString+OCParentPath.h"
#import "OCQuery+Internal.h"
#import "OCCore+FileProvider.h"
#import "OCCore+ItemUpdates.h"

@implementation OCCore (ItemList)

#pragma mark - Item List Tasks
- (void)scheduleItemListTaskForPath:(OCPath)path forQuery:(BOOL)forQuery
{
	BOOL putInQueue = YES;

	if (path != nil)
	{
		@synchronized(_queuedItemListTaskPaths)
		{
			if (forQuery)
			{
				putInQueue = NO;

				for (OCCoreItemListTask *task in _scheduledItemListTasks)
				{
					if ([task.path isEqual:path])
					{
						putInQueue = YES;
					}
				}
			}

			if (putInQueue)
			{
				[_queuedItemListTaskPaths addObject:path];
			}
			else
			{
				[self _scheduleItemListTaskForPath:path];
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
	OCPath nextItemListTaskPath = nil;

	@synchronized(_queuedItemListTaskPaths)
	{
		if (_scheduledItemListTasks.count == 0)
		{
			if ((nextItemListTaskPath = _queuedItemListTaskPaths.firstObject) != nil)
			{
				// Remove the path and any duplicates (effectively coalescating the tasks)
				[_queuedItemListTaskPaths removeObject:nextItemListTaskPath];
			}

			if (nextItemListTaskPath != nil)
			{
				OCCoreItemListTask *task;

				if ((task = [self _scheduleItemListTaskForPath:nextItemListTaskPath]) != nil)
				{
					[_scheduledItemListTasks addObject:task];
				}
			}
		}
	}
}

- (OCCoreItemListTask *)_scheduleItemListTaskForPath:(OCPath)path
{
	OCCoreItemListTask *task = nil;

	if (path!=nil)
	{
		if ((task = _itemListTasksByPath[path]) != nil)
		{
			// Don't start a new item list task if one is already running for the path
			// Instead, "handle" the running task again so that a new query is immediately updated
			[self handleUpdatedTask:task];
			return (nil);
		}

		if ((task = [[OCCoreItemListTask alloc] initWithCore:self path:path]) != nil)
		{
			_itemListTasksByPath[task.path] = task;

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
		@synchronized(_queuedItemListTaskPaths)
		{
			[_scheduledItemListTasks removeObject:finishedTask];

			if (_scheduledItemListTasks.count == 0)
			{
				[self scheduleNextItemListTask];
			}
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
	OCItem *taskRootItem = nil;
	NSString *taskPath = task.path;
	__block OCSyncAnchor querySyncAnchor = nil;
	OCCoreItemListTask *nextTask = nil;

	OCLogDebug(@"Cached Set(%lu): %@", (unsigned long)task.cachedSet.state, OCLogPrivate(task.cachedSet.items));
	OCLogDebug(@"Retrieved Set(%lu): %@", (unsigned long)task.retrievedSet.state, OCLogPrivate(task.retrievedSet.items));

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

		if ((existingTask = _itemListTasksByPath[task.path]) != nil)
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
				return;
			}
		}
		else
		{
			_itemListTasksByPath[task.path] = task;
		}
	}

	if (performMerge)
	{
		// Perform merge
		OCCoreItemList *cacheSet = task.cachedSet;
		OCCoreItemList *retrievedSet = task.retrievedSet;
		NSMutableDictionary <OCPath, OCItem *> *cacheItemsByFileID = cacheSet.itemsByFileID;
		NSMutableDictionary <OCPath, OCItem *> *retrievedItemsByFileID = retrievedSet.itemsByFileID;
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
									=> prepare retrievedItem to replace cacheItem
									- fileID matches ?
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
						cacheItem.remoteItem = retrievedItem;

						// Return updated cached version
						[queryResults addObject:cacheItem];

						// Update cache
						[changedCacheItems addObject:cacheItem];
					}
					else
					{
						// Attach databaseID of cached items to the retrieved items
						[retrievedItem prepareToReplace:cacheItem];

						retrievedItem.localRelativePath = cacheItem.localRelativePath;
						retrievedItem.localCopyVersionIdentifier = cacheItem.localCopyVersionIdentifier;

						if (![retrievedItem.itemVersionIdentifier isEqual:cacheItem.itemVersionIdentifier] || ![retrievedItem.name isEqualToString:cacheItem.name])
						{
							// Update item in the cache if the server has a different version
							if ([cacheItem.fileID isEqual:retrievedItem.fileID])
							{
								[changedCacheItems addObject:retrievedItem];
							}
							else
							{
								[deletedCacheItems addObject:cacheItem];
								retrievedItem.databaseID = nil;
								[newItems addObject:retrievedItem];
							}
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

			// Export sync anchor value
			querySyncAnchor = newSyncAnchor;

			// Commit changes to the cache
			if (queryState == OCQueryStateIdle)
			{
				// Fully merged => use for updating existing queries that have already gone through their complete, initial update
				NSMutableArray <OCPath> *refreshPaths = nil;

				if (self.automaticItemListUpdatesEnabled)
				{
					refreshPaths = [NSMutableArray new];

					// Determine refreshPaths if automatic item list updates are enabled
					for (OCItem *item in newItems)
					{
						if ((item.type == OCItemTypeCollection) && (item.path != nil) && (item.fileID!=nil) && (item.eTag!=nil) && ![item.path isEqual:task.path])
						{
							[refreshPaths addObject:item.path];
						}
					}

					for (OCItem *item in changedCacheItems)
					{
						if ((item.type == OCItemTypeCollection) && (item.path != nil) && (item.fileID!=nil) && (item.eTag!=nil) && ![item.path isEqual:task.path])
						{
							OCItem *cacheItem = cacheItemsByFileID[item.fileID];

							// Do not trigger refreshes if only the name changed (TODO: update database of items contained in folder on name changes)
							if ((cacheItem==nil) || ((cacheItem != nil) && ![cacheItem.itemVersionIdentifier isEqual:item.itemVersionIdentifier]))
							{
								[refreshPaths addObject:item.path];
							}
						}
					}

					if (refreshPaths.count == 0)
					{
						refreshPaths = nil;
					}
				}

				[self performUpdatesForAddedItems:newItems
						     removedItems:deletedCacheItems
						     updatedItems:changedCacheItems
						     refreshPaths:refreshPaths
						    newSyncAnchor:newSyncAnchor
					       beforeQueryUpdates:^(dispatch_block_t  _Nonnull completionHandler) {
							// Called AFTER the database has been updated, but before UPDATING queries
							OCWaitDidFinishTask(cacheUpdateGroup);
							completionHandler();
					       }
						afterQueryUpdates:^(dispatch_block_t  _Nonnull completionHandler) {
							[self _finalizeQueryUpdatesWithQueryResults:queryResults queryResultsChangedItems:queryResultsChangedItems queryState:queryState querySyncAnchor:querySyncAnchor task:task taskPath:taskPath taskRootItem:taskRootItem targetRemoved:targetRemoved];
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

				[task _updateCacheSet];
				[self handleUpdatedTask:task];
			}
			else
			{
				// Actual error
				OCLogError(@"Error updating metaData cache: %@", cacheUpdateError);
			}

			[self endActivity:@"item list task"];

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

	if (queryState != OCQueryStateIdle)
	{
		[self beginActivity:@"item list task - update queries"];

		[self queueBlock:^{
			// Update non-idle queries
			[self _finalizeQueryUpdatesWithQueryResults:queryResults queryResultsChangedItems:queryResultsChangedItems queryState:queryState querySyncAnchor:querySyncAnchor task:task taskPath:taskPath taskRootItem:taskRootItem targetRemoved:targetRemoved];

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
}

- (void)_finalizeQueryUpdatesWithQueryResults:(NSMutableArray<OCItem *> *)queryResults queryResultsChangedItems:(NSMutableArray<OCItem *> *)queryResultsChangedItems queryState:(OCQueryState)queryState querySyncAnchor:(OCSyncAnchor)querySyncAnchor task:(OCCoreItemListTask * _Nonnull)task taskPath:(NSString *)taskPath taskRootItem:(OCItem *)taskRootItem targetRemoved:(BOOL)targetRemoved {
	NSMutableDictionary <OCPath, OCItem *> *queryResultItemsByPath = nil;
	NSMutableArray <OCItem *> *queryResultWithoutRootItem = nil;
	OCQueryState setQueryState = queryState;
	// NSString *parentTaskPath = [taskPath parentPath];

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
	for (OCQuery *query in self->_queries)
	{
		NSMutableArray <OCItem *> *useQueryResults = nil;
		OCItem *queryRootItem = nil;

		// Queries targeting the path
		if ([query.queryPath isEqual:taskPath])
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
			OCPath queryItemPath = nil;
			OCSyncAnchor syncAnchor = nil;

			// Queries targeting a particular item
			if ((queryItemPath = query.queryItem.path) != nil)
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
						useQueryResults = [[NSMutableArray alloc] initWithObjects:itemAtPath, nil];
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
			if (((syncAnchor = query.querySinceSyncAnchor) != nil) &&
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
		[self signalChangesForItems:@[ taskRootItem ]];
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
		[self _checkForUpdatesNotBefore:nil];
	}];
}

- (void)_checkForUpdatesNotBefore:(NSDate *)notBefore
{
	OCEventTarget *eventTarget;

	if (self.state != OCCoreStateRunning)
	{
		return;
	}

	[self beginActivity:@"Check for updates"];

	eventTarget = [OCEventTarget eventTargetWithEventHandlerIdentifier:self.eventHandlerIdentifier userInfo:nil ephermalUserInfo:@{ @"endActivity" : @(YES)  }];

	[self.connection retrieveItemListAtPath:@"/" depth:0 notBefore:notBefore options:((notBefore != nil) ? @{ OCConnectionOptionIsNonCriticalKey : @(YES) } : nil) resultTarget:eventTarget];
}

- (void)_handleRetrieveItemListEvent:(OCEvent *)event sender:(id)sender
{
	OCLogDebug(@"Handling background retrieved items: error=%@, path=%@, depth=%d, items=%@", OCLogPrivate(event.error), OCLogPrivate(event.path), event.depth, OCLogPrivate(event.result));

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

			if ((cacheItems = [self.database retrieveCacheItemsSyncAtPath:event.path itemOnly:YES error:&error syncAnchor:NULL]) != nil)
			{
				if ((cacheItem = cacheItems.firstObject) != nil)
				{
					if (![cacheItem.itemVersionIdentifier isEqual:remoteItem.itemVersionIdentifier])
					{
						// Folder's etag or fileID differ -> fetch full update for this folder
						[self scheduleItemListTaskForPath:event.path forQuery:NO];
					}
					else
					{
						// No changes. We're done.
					}
				}
			}
		}
	}

	// Schedule next
	if ((event.depth == 0) && ([event.path isEqual:@"/"]))
	{
		// Check again in 10 seconds (TOOD: add configurable timing and option to enable/disable)
		NSTimeInterval minimumTimeInterval = 10;

		if (self.state == OCCoreStateRunning)
		{
			@synchronized([OCCoreItemList class])
			{
				if ((_lastScheduledItemListUpdateDate==nil) || ([_lastScheduledItemListUpdateDate timeIntervalSinceNow]<-(minimumTimeInterval-1)))
				{
					_lastScheduledItemListUpdateDate = [NSDate date];

					[self _checkForUpdatesNotBefore:[NSDate dateWithTimeIntervalSinceNow:minimumTimeInterval]];
				}
			}
		}
	}

	// End activity
	if (event.ephermalUserInfo[@"endActivity"])
	{
		[self endActivity:@"Check for updates"];
	}
}

@end
