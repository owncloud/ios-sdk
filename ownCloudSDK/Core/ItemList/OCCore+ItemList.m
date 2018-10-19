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
#import "OCQuery.h"
#import "NSError+OCError.h"
#import "NSString+OCParentPath.h"
#import "OCQuery+Internal.h"
#import "OCCore+FileProvider.h"

@implementation OCCore (ItemList)

#pragma mark - Item List Tasks
- (OCCoreItemListTask *)scheduleItemListTaskForPath:(OCPath)path
{
	OCCoreItemListTask *task = nil;

	if (path!=nil)
	{
		if ((task = _itemListTasksByPath[path]) == nil) // Don't start a new item list task if one is already running for the path
		{
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
	}

	return (task);
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
		NSMutableDictionary <OCPath, OCItem *> *cacheItemsByPath = cacheSet.itemsByPath;
		NSMutableDictionary <OCPath, OCItem *> *retrievedItemsByPath = retrievedSet.itemsByPath;

		NSMutableArray <OCItem *> *changedCacheItems = [NSMutableArray new];
		NSMutableArray <OCItem *> *deletedCacheItems = [NSMutableArray new];
		NSMutableArray <OCItem *> *newItems = [NSMutableArray new];

		__block NSError *cacheUpdateError = nil;

		queryResults = [NSMutableArray new];

		dispatch_group_t cacheUpdateGroup = dispatch_group_create();

		dispatch_group_enter(cacheUpdateGroup);

		[self incrementSyncAnchorWithProtectedBlock:^NSError *(OCSyncAnchor previousSyncAnchor, OCSyncAnchor newSyncAnchor) {
			if (![previousSyncAnchor isEqualToNumber:task.syncAnchorAtStart])
			{
				// Out of sync - trigger catching the latest from the cache again, rinse and repeat
				OCLogDebug(@"IL[%@, path=%@]: Sync anchor changed before task finished: previousSyncAnchor=%@ != task.syncAnchorAtStart=%@", task, task.path, previousSyncAnchor, task.syncAnchorAtStart);

				task.syncAnchorAtStart = newSyncAnchor; // Update sync anchor before triggering the reload from cache

				cacheUpdateError = OCError(OCErrorOutdatedCache);
				dispatch_group_leave(cacheUpdateGroup);

				return(nil);
			}

			// Iterate retrieved set
			[retrievedSet.itemsByPath enumerateKeysAndObjectsUsingBlock:^(OCPath  _Nonnull retrievedPath, OCItem * _Nonnull retrievedItem, BOOL * _Nonnull stop) {
				OCItem *cacheItem;

				// Item for this path already in the cache?
				if ((cacheItem = cacheItemsByPath[retrievedPath]) != nil)
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
						retrievedItem.databaseID = cacheItem.databaseID;
						retrievedItem.parentFileID = cacheItem.parentFileID;
						retrievedItem.localRelativePath = cacheItem.localRelativePath;

						if (![retrievedItem.itemVersionIdentifier isEqual:cacheItem.itemVersionIdentifier])
						{
							// Update item in the cache if the server has a different version
							[changedCacheItems addObject:retrievedItem];
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
			[cacheSet.itemsByPath enumerateKeysAndObjectsUsingBlock:^(OCPath  _Nonnull cachePath, OCItem * _Nonnull cacheItem, BOOL * _Nonnull stop) {
				OCItem *retrievedItem;

				// Item for this cached path still on the server?
				if ((retrievedItem = retrievedItemsByPath[cachePath]) == nil)
				{
					// Cache item no longer on the server
					if (cacheItem.locallyModified)
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

			// Commit changes to the cache
			[self.database performBatchUpdates:^(OCDatabase *database){
				__block NSError *returnError = nil;

				if ((deletedCacheItems.count > 0) && (returnError==nil))
				{
					[self.database removeCacheItems:deletedCacheItems syncAnchor:newSyncAnchor completionHandler:^(OCDatabase *db, NSError *error) {
						returnError = error;
					}];

					if (queryResultsChangedItems == nil)
					{
						queryResultsChangedItems = [[NSMutableArray alloc] initWithArray:deletedCacheItems];
					}
					else
					{
						[queryResultsChangedItems addObjectsFromArray:deletedCacheItems];
					}
				}

				if ((changedCacheItems.count > 0) && (returnError==nil))
				{
					[self.database updateCacheItems:changedCacheItems syncAnchor:newSyncAnchor completionHandler:^(OCDatabase *db, NSError *error) {
						returnError = error;
					}];

					if (queryResultsChangedItems == nil)
					{
						queryResultsChangedItems = [[NSMutableArray alloc] initWithArray:changedCacheItems];
					}
					else
					{
						[queryResultsChangedItems addObjectsFromArray:changedCacheItems];
					}
				}

				if ((newItems.count > 0) && (returnError==nil))
				{
					[self.database addCacheItems:newItems syncAnchor:newSyncAnchor completionHandler:^(OCDatabase *db, NSError *error) {
						returnError = error;
					}];

					if (queryResultsChangedItems == nil)
					{
						queryResultsChangedItems = [[NSMutableArray alloc] initWithArray:newItems];
					}
					else
					{
						[queryResultsChangedItems addObjectsFromArray:newItems];
					}
				}

				return (returnError);
			} completionHandler:^(OCDatabase *db, NSError *error) {
				cacheUpdateError = error;
				dispatch_group_leave(cacheUpdateGroup);
			}];

			// In parallel: remove thumbnails from in-memory cache
			dispatch_group_enter(cacheUpdateGroup);

			dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
				for (OCItem *deleteItem in deletedCacheItems)
				{
					[self->_thumbnailCache removeObjectForKey:deleteItem.fileID];
				}

				dispatch_group_leave(cacheUpdateGroup);
			});

			querySyncAnchor = newSyncAnchor;

			return (nil);
		} completionHandler:^(NSError *error, OCSyncAnchor previousSyncAnchor, OCSyncAnchor newSyncAnchor) {
			NSLog(@"Sync anchor increase result: %@ for %@ => %@", error, previousSyncAnchor, newSyncAnchor);
		}];

		dispatch_group_wait(cacheUpdateGroup, DISPATCH_TIME_FOREVER);

		if (cacheUpdateError != nil)
		{
			// An error occured updating the cache, so don't update queries either, log the error and return here
			if ([cacheUpdateError isOCErrorWithCode:OCErrorOutdatedCache])
			{
				// Sync anchor value increased while fetching data from the server
				OCLogDebug(@"Sync anchor changed, refreshing from cache before merge..");

//				double randomDelay = ((double)arc4random() / (double)UINT32_MAX) / 2.0; // Avoid race conditions with external or competing updates and the resulting infinite loops by delaying forced cache update by up to 0.5 secs, so other updates have a chence to settle inbetween (and don't interleave each other, which leads to an infinite loop)
//				int64_t randomDelayDelta = (int64_t)(randomDelay * (double)NSEC_PER_SEC);
//
//				dispatch_after(dispatch_time(DISPATCH_TIME_NOW, randomDelayDelta), _queue, ^{
//					[task forceUpdateCacheSet];
//				});

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

	// Update queries
	NSMutableDictionary <OCPath, OCItem *> *queryResultItemsByPath = nil;
	NSMutableArray <OCItem *> *queryResultWithoutRootItem = nil;
	NSString *parentTaskPath = [taskPath parentPath];

	for (OCQuery *query in _queries)
	{
		NSMutableArray <OCItem *> *useQueryResults = nil;
		OCItem *queryRootItem = nil;

		// Queries targeting the path
		if ([query.queryPath isEqual:taskPath])
		{
			if ( (query.state != OCQueryStateIdle) ||	// Keep updating queries that have not gone through its complete, initial content update
			    ((query.state == OCQueryStateIdle) && (queryState == OCQueryStateIdle))) // Don't update queries that have previously gotten a complete, initial content update with content from the cache (as that cache content is prone to be identical with what we already have in it). Instead, update these queries only if we have an idle ("finished") queryResult again.
			{
				NSLog(@"Task root item: %@, include root item: %d", taskRootItem, query.includeRootItem);

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

			// Queries targeting the parent directory of taskPath
			if ([query.queryPath isEqual:parentTaskPath])
			{
				// Should contain taskRootItem
				if (taskRootItem != nil)
				{
					@synchronized(query) // Protect full query results against modification (-setFullQueryResults: is protected using @synchronized(query), too)
					{
						NSMutableArray <OCItem *> *fullQueryResults;

						if ((fullQueryResults = query.fullQueryResults) != nil)
						{
							OCPath taskRootItemPath;

							if ((taskRootItemPath = taskRootItem.path) != nil)
							{
								NSUInteger itemIndex = 0, replaceAtIndex = NSNotFound;

								// Find root item
								for (OCItem *item in fullQueryResults)
								{
									if ([item.path isEqual:taskRootItemPath])
									{
										replaceAtIndex = itemIndex;
										break;
									}

									itemIndex++;
								}

								// Replace if found
								if (replaceAtIndex != NSNotFound)
								{
									[fullQueryResults removeObjectAtIndex:replaceAtIndex];
									[fullQueryResults insertObject:taskRootItem atIndex:replaceAtIndex];

									[query setNeedsRecomputation];
								}
							}
						}
					}
				}
				else
				{
					if (targetRemoved)
					{
						// Task's root item was removed
						@synchronized(query) // Protect full query results against modification (-setFullQueryResults: is protected using @synchronized(query), too)
						{
							NSMutableArray <OCItem *> *fullQueryResults;

							if ((fullQueryResults = query.fullQueryResults) != nil)
							{
								NSUInteger itemIndex = 0, removeAtIndex = NSNotFound;

								// Find root item
								for (OCItem *item in fullQueryResults)
								{
									if ([item.path isEqual:taskPath])
									{
										removeAtIndex = itemIndex;
										break;
									}

									itemIndex++;
								}

								// Remove if found
								if (removeAtIndex != NSNotFound)
								{
									[fullQueryResults removeObjectAtIndex:removeAtIndex];

									[query setNeedsRecomputation];
								}
							}
						}

					}
				}
			}

			// Queries targeting a particular item
			if ((queryItemPath = query.queryItem.path) != nil)
			{
				OCItem *itemAtPath;

				if (queryResultItemsByPath == nil)
				{
					OCCoreItemList *queryResultSet = [OCCoreItemList new];
					[queryResultSet updateWithError:nil items:queryResults];

					queryResultItemsByPath = queryResultSet.itemsByPath;
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
						queryState = OCQueryStateTargetRemoved;
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
			query.state = queryState;
			query.rootItem = queryRootItem;
			query.fullQueryResults = useQueryResults;
		}
	}

	// File provider signaling
	if ((self.postFileProviderNotifications) && (queryResultsChangedItems!=nil) && (queryResultsChangedItems.count > 0) && (taskRootItem!=nil))
	{
		[self signalChangesForItems:@[ taskRootItem ]];
	}

	// Handle next task in the chain (if any)
	if (nextTask != nil)
	{
		[self handleUpdatedTask:nextTask];
	}

	[self endActivity:@"item list task"];
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

	eventTarget = [OCEventTarget eventTargetWithEventHandlerIdentifier:self.eventHandlerIdentifier userInfo:nil ephermalUserInfo:nil];

	[self.connection retrieveItemListAtPath:@"/" depth:0 notBefore:notBefore options:nil resultTarget:eventTarget];
}

- (void)_handleRetrieveItemListEvent:(OCEvent *)event sender:(id)sender
{
	OCLogDebug(@"Handling background retrieved items: error=%@, path=%@, depth=%d, items=%@", OCLogPrivate(event.error), OCLogPrivate(event.path), event.depth, OCLogPrivate(event.result));

	// Handle result
	if (event.error == nil)
	{
		if (event.result != nil)
		{
			NSArray <OCItem *> *items = (NSArray <OCItem *> *)event.result;

			// Root item change observation
			if (event.depth == 0)
			{
				NSError *error = nil;
				OCItem *cacheItem = nil;
				OCItem *remoteItem = items.firstObject;

				if ((cacheItem = [self.database retrieveCacheItemsSyncAtPath:event.path itemOnly:YES error:&error syncAnchor:NULL].firstObject) != nil)
				{
					if (![cacheItem.itemVersionIdentifier isEqual:remoteItem.itemVersionIdentifier])
					{
						// Folder's etag or fileID differ -> fetch full update for this folder
						OCEventTarget *eventTarget;

						eventTarget = [OCEventTarget eventTargetWithEventHandlerIdentifier:self.eventHandlerIdentifier userInfo:nil ephermalUserInfo:nil];

						[self.connection retrieveItemListAtPath:event.path depth:1 notBefore:nil options:nil resultTarget:eventTarget];
					}
					else
					{
						// No changes. We're done.
					}
				}
			}

			// File list traversal
			if (event.depth == 1)
			{
				NSError *error = nil;
				NSArray <OCItem *> *cacheItems;

				NSMutableArray <OCPath> *pathsNeedingUpdates = [NSMutableArray new];

				OCCoreItemListTask *itemListTask = [[OCCoreItemListTask alloc] initWithCore:self path:event.path];

				itemListTask.syncAnchorAtStart = [self retrieveLatestSyncAnchorWithError:NULL];
				cacheItems = [self.database retrieveCacheItemsSyncAtPath:event.path itemOnly:NO error:&error syncAnchor:NULL];

				[itemListTask.cachedSet updateWithError:error items:cacheItems];
				[itemListTask.retrievedSet updateWithError:event.error items:event.result];

				// Find new folders and folders with changes
				for (OCItem *item in items)
				{
					if ((item.type == OCItemTypeCollection) && (item.path != nil))
					{
						OCItem *cacheItem = itemListTask.cachedSet.itemsByPath[item.path];

						if (cacheItem != nil)
						{
							if (![cacheItem.itemVersionIdentifier isEqual:item.itemVersionIdentifier])
							{
								// Folder version differs -> fetch full list for that folder
								[pathsNeedingUpdates addObject:item.path];
							}
						}
						else
						{
							// New folder -> fetch full list for that folder
							[pathsNeedingUpdates addObject:item.path];
						}
					}
				}

				// Update cache with new results
				if (_itemListTasksByPath[itemListTask.path] != nil)
				{
					OCLogWarning(@"Concurrent item list tasks: %@ (background) vs %@ (queries)", itemListTask, _itemListTasksByPath[itemListTask.path]);
				}

				// Add a change handler in case another OCCoreItemListTask is already running for this path
				itemListTask.changeHandler = ^(OCCore *core, OCCoreItemListTask *task) {
					// Changehandler is executed wrapped into -queueBlock: so this is executed on the core's queue
					[core handleUpdatedTask:task];
				};

				[self handleUpdatedTask:itemListTask];

				// Trigger fetching file lists for updated/new folders
				for (OCPath path in pathsNeedingUpdates)
				{
					OCEventTarget *eventTarget;

					eventTarget = [OCEventTarget eventTargetWithEventHandlerIdentifier:self.eventHandlerIdentifier userInfo:nil ephermalUserInfo:nil];

					[self.connection retrieveItemListAtPath:path depth:1 notBefore:nil options:nil resultTarget:eventTarget];
				}
			}
		}
	}

	// Schedule next
	if ((event.depth == 0) && ([event.path isEqual:@"/"]))
	{
		// Check again in 10 seconds (TOOD: add configurable timing and option to enable/disable)
		if (self.state == OCCoreStateRunning)
		{
			[self _checkForUpdatesNotBefore:[NSDate dateWithTimeIntervalSinceNow:10]];
		}
	}
}

@end
