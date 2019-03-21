//
//  OCCore+ItemUpdates.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 24.10.18.
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

#import "OCMacros.h"
#import "OCLogger.h"

#import "OCCore+SyncEngine.h"
#import "OCCore+ItemUpdates.h"
#import "OCCore+Internal.h"
#import "OCCore+ItemList.h"
#import "OCQuery+Internal.h"
#import "OCCore+FileProvider.h"

@implementation OCCore (ItemUpdates)

- (void)performUpdatesForAddedItems:(nullable NSArray<OCItem *> *)addedItems
		       removedItems:(nullable NSArray<OCItem *> *)removedItems
		       updatedItems:(nullable NSArray<OCItem *> *)updatedItems
		       refreshPaths:(nullable NSArray <OCPath> *)refreshPaths
		      newSyncAnchor:(nullable OCSyncAnchor)newSyncAnchor
		 beforeQueryUpdates:(nullable OCCoreItemUpdateAction)beforeQueryUpdatesAction
		  afterQueryUpdates:(nullable OCCoreItemUpdateAction)afterQueryUpdatesAction
		 queryPostProcessor:(nullable OCCoreItemUpdateQueryPostProcessor)queryPostProcessor
		       skipDatabase:(BOOL)skipDatabase
{
	// Discard empty updates
	if ((addedItems.count==0) && (removedItems.count == 0) && (updatedItems.count == 0) && (refreshPaths.count == 0) &&
	     (beforeQueryUpdatesAction == nil) && (afterQueryUpdatesAction == nil) && (queryPostProcessor == nil))
	{
		return;
	}

	// Begin
	[self beginActivity:@"Perform item and query updates"];

	// Ensure protection
	if (newSyncAnchor == nil)
	{
		// Make sure updates are wrapped into -incrementSyncAnchorWithProtectedBlock
		[self incrementSyncAnchorWithProtectedBlock:^NSError *(OCSyncAnchor previousSyncAnchor, OCSyncAnchor newSyncAnchor) {
			[self performUpdatesForAddedItems:addedItems removedItems:removedItems updatedItems:updatedItems refreshPaths:refreshPaths newSyncAnchor:newSyncAnchor beforeQueryUpdates:beforeQueryUpdatesAction afterQueryUpdates:afterQueryUpdatesAction queryPostProcessor:queryPostProcessor skipDatabase:skipDatabase];

			return ((NSError *)nil);
		} completionHandler:^(NSError *error, OCSyncAnchor previousSyncAnchor, OCSyncAnchor newSyncAnchor) {
			[self endActivity:@"Perform item and query updates"];
		}];

		return;
	}

	// Remove outdated versions of updated items
	if (updatedItems.count > 0)
	{
		for (OCItem *updateItem in updatedItems)
		{
			if ((!updateItem.locallyModified) && // don't delete local modified versions
			    (updateItem.localRelativePath != nil) && // is there a local copy to delete?
			    (updateItem.localCopyVersionIdentifier != nil) && // is there anything to compare against?
			    (![updateItem.itemVersionIdentifier isEqual:updateItem.localCopyVersionIdentifier])) // different versions?
			{
				// delete local copy
				NSURL *deleteFileURL;

				if ((deleteFileURL = [self localURLForItem:updateItem]) != nil)
				{
					NSError *deleteError = nil;

					OCLogDebug(@"Deleting outdated local copy of %@ (%@ vs %@)", updateItem, updateItem.itemVersionIdentifier, updateItem.localCopyVersionIdentifier);

					updateItem.localRelativePath = nil;
					updateItem.localCopyVersionIdentifier = nil;

					if ([[NSFileManager defaultManager] removeItemAtURL:deleteFileURL error:&deleteError])
					{
						OCLogError(@"Error removing %@: %@", deleteFileURL, deleteError);
					}
				}
			}
		}
	}

	// Update metaData table and queries
	if ((addedItems.count > 0) || (removedItems.count > 0) || (updatedItems.count > 0) || (beforeQueryUpdatesAction!=nil))
	{
		__block NSError *databaseError = nil;

		OCWaitInit(cacheUpdatesGroup);

		// Update metaData table with changes from the parameter set
		if (!skipDatabase)
		{
			OCWaitWillStartTask(cacheUpdatesGroup);

			[self.database performBatchUpdates:^(OCDatabase *database){
				if (removedItems.count > 0)
				{
					[self.database removeCacheItems:removedItems syncAnchor:newSyncAnchor completionHandler:^(OCDatabase *db, NSError *error) {
						if (error != nil) { databaseError = error; }
					}];
				}

				if (addedItems.count > 0)
				{
					[self.database addCacheItems:addedItems syncAnchor:newSyncAnchor completionHandler:^(OCDatabase *db, NSError *error) {
						if (error != nil) { databaseError = error; }
					}];
				}

				if (updatedItems.count > 0)
				{
					[self.database updateCacheItems:updatedItems syncAnchor:newSyncAnchor completionHandler:^(OCDatabase *db, NSError *error) {
						if (error != nil) { databaseError = error; }
					}];
				}

				// Run preflight action
				if (beforeQueryUpdatesAction != nil)
				{
					OCWaitWillStartTask(cacheUpdatesGroup);

					beforeQueryUpdatesAction(^{
						OCWaitDidFinishTask(cacheUpdatesGroup);
					});
				}

				return ((NSError *)nil);
			} completionHandler:^(OCDatabase *db, NSError *error) {
				if (error != nil)
				{
					OCLogError(@"IU: error updating metaData database after sync engine result handler pass: %@", error);
				}

				OCWaitDidFinishTask(cacheUpdatesGroup);
			}];
		}

		// In parallel: remove thumbnails from in-memory cache for removed items
		OCWaitWillStartTask(cacheUpdatesGroup);

		dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
			for (OCItem *removeItem in removedItems)
			{
				[self->_thumbnailCache removeObjectForKey:removeItem.fileID];
			}

			OCWaitDidFinishTask(cacheUpdatesGroup);
		});

		// Wait for updates to complete
		OCWaitForCompletion(cacheUpdatesGroup);
	}

	if ((beforeQueryUpdatesAction!=nil) && skipDatabase)
	{
		// Run preflight action when database should be skipped and beforeQueryUpdatesAction did not yet run
		OCSyncExec(waitForUpdates, {
			beforeQueryUpdatesAction(^{
				OCSyncExecDone(waitForUpdates);
			});
		});
	}

	// Update queries
	if ((addedItems.count > 0) || (removedItems.count > 0) || (updatedItems.count > 0) || (afterQueryUpdatesAction!=nil) || (queryPostProcessor!=nil))
	{
		NSArray <OCItem *> *theRemovedItems = removedItems;

		[self beginActivity:@"Item Updates - update queries"];

		[self queueBlock:^{
			OCCoreItemList *addedItemList   = nil;
			OCCoreItemList *removedItemList = nil;
			OCCoreItemList *updatedItemList = nil;
			NSArray <OCItem *> *removedItems = theRemovedItems;
			__block NSMutableArray <OCItem *> *addedUpdatedRemovedItems = nil;
			NSMutableArray <OCItem *> *relocatedItems = nil;

			// Support for relocated items
			for (OCItem *updatedItem in updatedItems)
			{
				// Item has previous path
				if (updatedItem.previousPath != nil)
				{
					// Has the parent folder changed?
					if (![updatedItem.path.stringByDeletingLastPathComponent isEqual:updatedItem.previousPath.stringByDeletingLastPathComponent])
					{
						OCItem *reMovedItem;

						// Make a decoupled copy of the item, replace its path and add it to relocatedItems
						if ((reMovedItem = [OCItem itemFromSerializedData:updatedItem.serializedData]) != nil)
						{
							reMovedItem.path = updatedItem.previousPath;
							reMovedItem.removed = YES;

							if (relocatedItems == nil) { relocatedItems = [NSMutableArray new]; }
							[relocatedItems addObject:reMovedItem];
						}
					}
				}
			}

			if (relocatedItems != nil)
			{
				// Add any specially prepared relocatedItems to the list of removedItems
				if (removedItems != nil)
				{
					[relocatedItems addObjectsFromArray:removedItems];
				}

				removedItems = relocatedItems;
			}

			// Populate item lists
			addedItemList   = ((addedItems.count>0)   ? [OCCoreItemList itemListWithItems:addedItems]   : nil);
			removedItemList = ((removedItems.count>0) ? [OCCoreItemList itemListWithItems:removedItems] : nil);
			updatedItemList = ((updatedItems.count>0) ? [OCCoreItemList itemListWithItems:updatedItems] : nil);

			void (^BuildAddedUpdatedRemovedItemList)(void) = ^{
				if (addedUpdatedRemovedItems==nil)
				{
					addedUpdatedRemovedItems = [NSMutableArray arrayWithCapacity:(addedItemList.items.count + updatedItemList.items.count + removedItemList.items.count)];

					if (removedItemList!=nil)
					{
						[addedUpdatedRemovedItems addObjectsFromArray:removedItemList.items];
					}

					if (addedItemList!=nil)
					{
						[addedUpdatedRemovedItems addObjectsFromArray:addedItemList.items];
					}

					if (updatedItemList!=nil)
					{
						[addedUpdatedRemovedItems addObjectsFromArray:updatedItemList.items];
					}
				}
			};

			for (OCQuery *query in self->_queries)
			{
				// Protect full query results against modification (-setFullQueryResults: is protected using @synchronized(query), too)
				@synchronized(query)
				{
					// Queries targeting directories
					if (query.queryPath != nil)
					{
						// Only update queries that have already gone through their complete, initial content update
						if (query.state == OCQueryStateIdle)
						{
							__block NSMutableArray <OCItem *> *updatedFullQueryResults = nil;
							__block OCCoreItemList *updatedFullQueryResultsItemList = nil;

							void (^GetUpdatedFullResultsReady)(void) = ^{
								if (updatedFullQueryResults == nil)
								{
									NSMutableArray <OCItem *> *fullQueryResults;

									if ((fullQueryResults = query.fullQueryResults) != nil)
									{
										updatedFullQueryResults = [fullQueryResults mutableCopy];
									}
									else
									{
										updatedFullQueryResults = [NSMutableArray new];
									}
								}

								if (updatedFullQueryResultsItemList == nil)
								{
									updatedFullQueryResultsItemList = [OCCoreItemList itemListWithItems:updatedFullQueryResults];
								}
							};

							if ((addedItemList != nil) && (addedItemList.itemsByParentPaths[query.queryPath].count > 0))
							{
								// Items were added in the target path of this query
								GetUpdatedFullResultsReady();

								for (OCItem *item in addedItemList.itemsByParentPaths[query.queryPath])
								{
									if (!query.includeRootItem && [item.path isEqual:query.queryPath])
									{
										// Respect query.includeRootItem for special case "/" and don't include root items if not wanted
										continue;
									}

									[updatedFullQueryResults addObject:item];
								}
							}

							if (removedItemList != nil)
							{
								if (removedItemList.itemsByParentPaths[query.queryPath].count > 0)
								{
									// Items were removed in the target path of this query
									GetUpdatedFullResultsReady();

									for (OCItem *item in removedItemList.itemsByParentPaths[query.queryPath])
									{
										if (item.path != nil)
										{
											OCItem *removeItem;

											if ((removeItem = updatedFullQueryResultsItemList.itemsByFileID[item.fileID]) != nil)
											{
												[updatedFullQueryResults removeObjectIdenticalTo:removeItem];
											}
										}
									}
								}

								if (removedItemList.itemsByPath[query.queryPath] != nil)
								{
									if (addedItemList.itemsByPath[query.queryPath] != nil)
									{
										// Handle replacement scenario
										query.rootItem = addedItemList.itemsByPath[query.queryPath];
									}
									else
									{
										// The target of this query was removed
										updatedFullQueryResults = [NSMutableArray new];
										query.state = OCQueryStateTargetRemoved;
									}
								}
							}

							if ((updatedItemList != nil) && (query.state != OCQueryStateTargetRemoved))
							{
								OCItem *updatedRootItem = nil;

								GetUpdatedFullResultsReady();

								if ((updatedItemList.itemsByParentPaths[query.queryPath].count > 0) || // path match
								    ([updatedItemList.itemLocalIDsSet intersectsSet:updatedFullQueryResultsItemList.itemLocalIDsSet])) // Contained localID match
								{
									// Items were updated
									for (OCItem *item in updatedItemList.itemsByParentPaths[query.queryPath])
									{
										if (!query.includeRootItem && [item.path isEqual:query.queryPath])
										{
											// Respect query.includeRootItem for special case "/" and don't include root items if not wanted
											continue;
										}

										if (item.path != nil)
										{
											OCItem *reMoveItem = nil;

											if ((reMoveItem = updatedFullQueryResultsItemList.itemsByFileID[item.fileID]) == nil)
											{
												reMoveItem = updatedFullQueryResultsItemList.itemsByLocalID[item.localID];
											}

											if (reMoveItem != nil)
											{
												NSUInteger replaceAtIndex;

												// Replace if found
												if ((replaceAtIndex = [updatedFullQueryResults indexOfObjectIdenticalTo:reMoveItem]) != NSNotFound)
												{
													[updatedFullQueryResults removeObjectAtIndex:replaceAtIndex];
													[updatedFullQueryResults insertObject:item atIndex:replaceAtIndex];
												}
												else
												{
													[updatedFullQueryResults addObject:item];
												}
											}
											else
											{
												[updatedFullQueryResults addObject:item];
											}
										}
									}
								}

								if ((updatedRootItem = updatedItemList.itemsByPath[query.queryPath]) != nil)
								{
									// Root item of query was updated
									query.rootItem = updatedRootItem;

									if (query.includeRootItem)
									{
										OCItem *removeItem;

										if ((removeItem = updatedFullQueryResultsItemList.itemsByPath[query.queryPath]) != nil)
										{
											[updatedFullQueryResults removeObject:removeItem];
										}

										if ([updatedFullQueryResults indexOfObjectIdenticalTo:updatedRootItem] == NSNotFound)
										{
											[updatedFullQueryResults addObject:updatedRootItem];
										}
									}
								}
							}

							if (updatedFullQueryResults != nil)
							{
								query.fullQueryResults = updatedFullQueryResults;
							}
						}
					}

					// Queries targeting items
					if (query.queryItem != nil)
					{
						// Only update queries that have already gone through their complete, initial content update
						if ((query.state == OCQueryStateIdle) ||
						    (query.state == OCQueryStateTargetRemoved)) // An item could appear removed temporarily when it was moved on the server and the item has not yet been seen by the core in its new location
						{
							OCPath queryItemPath = query.queryItem.path;
							OCLocalID queryItemLocalID = query.queryItem.localID;
							OCItem *resultItem = nil;

							if (addedItemList!=nil)
							{
								if ((resultItem = addedItemList.itemsByPath[queryItemPath]) != nil)
								{
									query.state = OCQueryStateIdle;
									query.fullQueryResults = [NSMutableArray arrayWithObject:resultItem];
								}
								else if ((resultItem = addedItemList.itemsByLocalID[queryItemLocalID]) != nil)
								{
									query.state = OCQueryStateIdle;
									query.fullQueryResults = [NSMutableArray arrayWithObject:resultItem];
								}
							}

							if (updatedItemList!=nil)
							{
								if ((resultItem = updatedItemList.itemsByPath[queryItemPath]) != nil)
								{
									query.state = OCQueryStateIdle;
									query.fullQueryResults = [NSMutableArray arrayWithObject:resultItem];
								}
								else if ((resultItem = updatedItemList.itemsByLocalID[queryItemLocalID]) != nil)
								{
									query.state = OCQueryStateIdle;
									query.fullQueryResults = [NSMutableArray arrayWithObject:resultItem];
								}
							}

							if (removedItemList!=nil)
							{
								if ((removedItemList.itemsByPath[queryItemPath] != nil) || (removedItemList.itemsByLocalID[queryItemLocalID] != nil))
								{
									query.state = OCQueryStateTargetRemoved;
									query.fullQueryResults = [NSMutableArray new];
								}
							}
						}
					}

					// Queries targeting sync anchors
					if ((query.querySinceSyncAnchor != nil) && (newSyncAnchor!=nil))
					{
						BuildAddedUpdatedRemovedItemList();

						if (addedUpdatedRemovedItems.count > 0)
						{
							query.state = OCQueryStateWaitingForServerReply;

							[query mergeItemsToFullQueryResults:addedUpdatedRemovedItems syncAnchor:newSyncAnchor];

							query.state = OCQueryStateIdle;

							[query setNeedsRecomputation];
						}
					}

					// Custom queries
					if (query.isCustom && ((addedItemList!=nil) || (updatedItemList!=nil) || (removedItemList!=nil)))
					{
						[query updateWithAddedItems:addedItemList updatedItems:updatedItemList removedItems:removedItemList];
					}

					// Apply postprocessing on queries
					if (queryPostProcessor != nil)
					{
						queryPostProcessor(self, query, addedItemList, removedItemList, updatedItemList);
					}
				}
			}

			// Run postflight action
			if (afterQueryUpdatesAction != nil)
			{
				afterQueryUpdatesAction(^{
					[self endActivity:@"Item Updates - update queries"];
				});
			}
			else
			{
				[self endActivity:@"Item Updates - update queries"];
			}

			// Signal file provider
			if (self.postFileProviderNotifications && !skipDatabase)
			{
				BuildAddedUpdatedRemovedItemList();

				if (addedUpdatedRemovedItems.count > 0)
				{
					[self signalChangesForItems:addedUpdatedRemovedItems];
				}
			}
		}];
	}

	// - Fetch updated directory contents as needed
	if (refreshPaths.count > 0)
	{
		// Ensure the sync anchor was updated following these updates before triggering a refresh
		[self queueBlock:^{
			for (OCPath path in refreshPaths)
			{
				OCPath refreshPath = path;

				if (![refreshPath hasSuffix:@"/"])
				{
					refreshPath = [refreshPath stringByAppendingString:@"/"];
				}

				[self scheduleItemListTaskForPath:refreshPath forQuery:NO];
			}
		}];
	}

	// Initiate an IPC change notification
	if (!skipDatabase)
	{
		[self postIPCChangeNotification];
	}

	[self endActivity:@"Perform item and query updates"];
}

@end
