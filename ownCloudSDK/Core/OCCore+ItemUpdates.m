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
		     preflightAction:(nullable void(^)(dispatch_block_t completionHandler))preflightAction
		    postflightAction:(nullable void(^)(dispatch_block_t completionHandler))postflightAction
		  queryPostProcessor:(nullable OCCoreItemUpdateQueryPostProcessor)queryPostProcessor
{
	// Discard empty updates
	if ((addedItems.count==0) && (removedItems.count == 0) && (updatedItems.count == 0) && (refreshPaths.count == 0) &&
	     (preflightAction == nil) && (postflightAction == nil) && (queryPostProcessor == nil))
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
			[self performUpdatesForAddedItems:addedItems removedItems:removedItems updatedItems:updatedItems refreshPaths:refreshPaths newSyncAnchor:newSyncAnchor preflightAction:preflightAction postflightAction:postflightAction queryPostProcessor:queryPostProcessor];

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
	if ((addedItems.count > 0) || (removedItems.count > 0) || (updatedItems.count > 0) || (preflightAction!=nil))
	{
		__block NSError *databaseError = nil;

		OCWaitInit(cacheUpdatesGroup);

		// Update metaData table with changes from the parameter set
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
			if (preflightAction != nil)
			{
				OCWaitWillStartTask(cacheUpdatesGroup);

				preflightAction(^{
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

	// Update queries
	if ((addedItems.count > 0) || (removedItems.count > 0) || (updatedItems.count > 0) || (postflightAction!=nil) || (queryPostProcessor!=nil))
	{
		[self beginActivity:@"Item Updates - update queries"];

		[self queueBlock:^{
			OCCoreItemList *addedItemList   = ((addedItems.count>0)   ? [OCCoreItemList itemListWithItems:addedItems]   : nil);
			OCCoreItemList *removedItemList = ((removedItems.count>0) ? [OCCoreItemList itemListWithItems:removedItems] : nil);
			OCCoreItemList *updatedItemList = ((updatedItems.count>0) ? [OCCoreItemList itemListWithItems:updatedItems] : nil);
			__block NSMutableArray <OCItem *> *addedUpdatedRemovedItems = nil;

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

								if (updatedItemList.itemsByParentPaths[query.queryPath].count > 0)
								{
									// Items were updated
									GetUpdatedFullResultsReady();

									for (OCItem *item in updatedItemList.itemsByParentPaths[query.queryPath])
									{
										if (!query.includeRootItem && [item.path isEqual:query.queryPath])
										{
											// Respect query.includeRootItem for special case "/" and don't include root items if not wanted
											continue;
										}

										if (item.path != nil)
										{
											OCItem *removeItem;

											if ((removeItem = updatedFullQueryResultsItemList.itemsByFileID[item.fileID]) != nil)
											{
												NSUInteger replaceAtIndex;

												// Replace if found
												if ((replaceAtIndex = [updatedFullQueryResults indexOfObjectIdenticalTo:removeItem]) != NSNotFound)
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
						if (query.state == OCQueryStateIdle)
						{
							OCPath queryItemPath = query.queryItem.path;
							OCItem *newQueryItem = nil;

							if (addedItemList!=nil)
							{
								if ((newQueryItem = addedItemList.itemsByPath[queryItemPath]) != nil)
								{
									query.fullQueryResults = [NSMutableArray arrayWithObject:newQueryItem];
								}
							}

							if (updatedItemList!=nil)
							{
								if ((newQueryItem = updatedItemList.itemsByPath[queryItemPath]) != nil)
								{
									query.fullQueryResults = [NSMutableArray arrayWithObject:newQueryItem];
								}
							}

							if (removedItemList!=nil)
							{
								if ((newQueryItem = updatedItemList.itemsByPath[queryItemPath]) != nil)
								{
									query.fullQueryResults = [NSMutableArray new];
									query.state = OCQueryStateTargetRemoved;
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

					// Apply postprocessing on queries
					if (queryPostProcessor != nil)
					{
						queryPostProcessor(self, query, addedItemList, removedItemList, updatedItemList);
					}
				}
			}

			// Run postflight action
			if (postflightAction != nil)
			{
				postflightAction(^{
					[self endActivity:@"Item Updates - update queries"];
				});
			}
			else
			{
				[self endActivity:@"Item Updates - update queries"];
			}

			// Signal file provider
			if (self.postFileProviderNotifications)
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
		for (OCPath path in refreshPaths)
		{
			OCPath refreshPath = path;

			if (![refreshPath hasSuffix:@"/"])
			{
				refreshPath = [refreshPath stringByAppendingString:@"/"];
			}

			[self scheduleItemListTaskForPath:refreshPath];
		}
	}

	[self endActivity:@"Perform item and query updates"];
}

@end
