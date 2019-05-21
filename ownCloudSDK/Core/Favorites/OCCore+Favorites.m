//
//  OCCore+Favorites.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 16.05.19.
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

#import "OCCore.h"
#import "OCCore+Internal.h"
#import "OCLogger.h"
#import "OCCore+SyncEngine.h"
#import "OCCore+ItemUpdates.h"
#import "OCXMLNode.h"
#import "OCMacros.h"

@implementation OCCore (Favorites)

- (nullable NSProgress *)refreshFavoritesWithCompletionHandler:(OCCoreFavoritesResultHandler)completionHandler
{
	OCProgress *progress = nil;
	OCEventTarget *eventTarget = [self _eventTargetWithCoreSelector:@selector(_handleFavoritesSearchEvent:sender:) userInfo:nil ephermalUserInfo:@{
		@"completionHandler" : [completionHandler copy]
	}];

	progress = [self.connection filterFilesWithRules:@{
		OCItemPropertyNameIsFavorite : @1
	} properties:@[
		[OCXMLNode elementWithName:@"D:getetag"],
		[OCXMLNode elementWithName:@"oc:id"]
	] resultTarget:eventTarget];

	return (progress.progress);
}

- (void)_handleFavoritesSearchEvent:(OCEvent *)event sender:(id)sender
{
	NSError *error = event.error;
	NSArray <OCItem *> *rawItems = OCTypedCast(event.result, NSArray);
	OCCoreFavoritesResultHandler completionHandler = event.ephermalUserInfo[@"completionHandler"];

	if (error != nil)
	{
		if (completionHandler != nil)
		{
			completionHandler(error, nil);
		}

		OCLogError(@"Favorites search completed with error=%@", error);

		return;
	}
	else
	{
		// Merge
		__block NSMutableArray<OCItem *> *newFavoritedItems = [NSMutableArray new];

		[self performProtectedSyncBlock:^NSError *{
			__block OCCoreItemList *currentlyFavoritedItemList = nil;
			NSMutableArray<OCItem *> *updateItems = [NSMutableArray new];
			OCCoreItemList *newFavoritedItemsList = nil;

			[self.database retrieveCacheItemsForQueryCondition:[OCQueryCondition where:OCItemPropertyNameIsFavorite isEqualTo:@(YES)] completionHandler:^(OCDatabase *db, NSError *error, OCSyncAnchor syncAnchor, NSArray<OCItem *> *items) {
				if (items.count > 0)
				{
					OCLogDebug(@"Existing favorites: %@", items);

					currentlyFavoritedItemList = [OCCoreItemList itemListWithItems:items];
				}
			}];

			for (OCItem *rawItem in rawItems)
			{
				if (rawItem.fileID != nil)
				{
					__block OCItem *localItem;

					// Try finding the localItem among the already retrieved favorite items
					if ((localItem = currentlyFavoritedItemList.itemsByFileID[rawItem.fileID]) == nil)
					{
						// If not found, retrieve from database (=> if found, already known as a favorite!)
						[self.database retrieveCacheItemForFileID:rawItem.fileID completionHandler:^(OCDatabase *db, NSError *error, OCSyncAnchor syncAnchor, OCItem *item) {
							localItem = item;

							// Update status
							localItem.isFavorite = @(YES);
							[updateItems addObject:localItem];
						}];
					}

					if (localItem != nil)
					{
						// Include found items. Note: if an item is not found, that's not an issue as the PROPFIND fetching it will also fetch its favorite status.
						[newFavoritedItems addObject:localItem];
					}
				}
			}

			OCLogDebug(@"New favorites (local): %@", newFavoritedItems);

			// Build item list from new favorited items
			newFavoritedItemsList = [OCCoreItemList itemListWithItems:newFavoritedItems];

			if (currentlyFavoritedItemList.itemFileIDsSet.count > 0)
			{
				NSMutableSet<OCFileID> *favoriteRemovedFileIDs = [[NSMutableSet alloc] initWithSet:currentlyFavoritedItemList.itemFileIDsSet];

				[favoriteRemovedFileIDs minusSet:newFavoritedItemsList.itemFileIDsSet];

				for (OCFileID favoriteRemovedFileID in favoriteRemovedFileIDs)
				{
					OCItem *favoriteRemovedItem;

					if ((favoriteRemovedItem = currentlyFavoritedItemList.itemsByFileID[favoriteRemovedFileID]) != nil)
					{
						favoriteRemovedItem.isFavorite = nil;
						[updateItems addObject:favoriteRemovedItem];
					}
				}
			}

			OCLogDebug(@"Update items (local): %@", updateItems);

			// Update items
			if (updateItems.count > 0)
			{
				[self performUpdatesForAddedItems:nil removedItems:nil updatedItems:updateItems refreshPaths:nil newSyncAnchor:nil beforeQueryUpdates:nil afterQueryUpdates:nil queryPostProcessor:nil skipDatabase:NO];
			}

			return (nil);
		} completionHandler:^(NSError *error) {
			// Call completion handler
			if (completionHandler != nil)
			{
				completionHandler(error, newFavoritedItems);
			}
		}];
	}

	OCLogDebug(@"Favorites: %@, Error: %@", event.result, event.error);
}

@end
