//
//  OCBookmarkManager+ItemResolution.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 24.02.21.
//  Copyright © 2021 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2021, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCBookmarkManager+ItemResolution.h"
#import "OCVault.h"
#import "OCMacros.h"
#import "OCDatabase.h"
#import "OCAsyncSequentialQueue.h"
#import "NSError+OCError.h"

@implementation OCBookmarkManager (ItemResolution)

- (void)locateBookmarkForItemWithLocalID:(OCLocalID)localID completionHandler:(void(^)(NSError * _Nullable error, OCBookmark * _Nullable bookmark, OCItem * _Nullable item))lookupCompletionHandler
{
	NSArray<OCBookmark *> *bookmarks = [self.bookmarks copy];
	OCAsyncSequentialQueue *queue = [OCAsyncSequentialQueue new];

	__block BOOL lookupDone = NO;

	for (OCBookmark *bookmark in bookmarks)
	{
		// Queue resolution jobs sequentially to limit resource usage by SQLite - parallel resolution should be possible, but could cause a spike in memory consumption
		[queue async:^(dispatch_block_t  _Nonnull completionHandler) {
			OCVault *vault;

			if (lookupDone && (queue != nil)) // "queue" reference here only there to keep the OCAsyncSequentialQueue around
			{
				completionHandler();
				return;
			}

			// Create a vault for the bookmark
			if ((vault = [[OCVault alloc] initWithBookmark:bookmark]) != nil)
			{
				// Open the vault
				[vault openWithCompletionHandler:^(id sender, NSError *error) {
					if (error != nil)
					{
						completionHandler();
						return;
					}

					OCDatabase *database;

					// If "sender" is a OCDatabase, opening the OCDatabase succeeded …
					if ((database = OCTypedCast(sender, OCDatabase)) != nil)
					{
						// Try to locate an item with the provided OCLocalID
						[database retrieveCacheItemForLocalID:localID completionHandler:^(OCDatabase *db, NSError *error, OCSyncAnchor syncAnchor, OCItem *item) {
							// Close the OCVault and return any found item
							[vault closeWithCompletionHandler:^(id sender, NSError *error) {
								if (item != nil)
								{
									lookupDone = YES;
									lookupCompletionHandler(nil, bookmark, item);
								}

								completionHandler();
							}];
						}];
					}
					else
					{
						// … otherwise, opening the OCDatabase failed, so close the vault right away.
						[vault closeWithCompletionHandler:^(id sender, NSError *error) {
							completionHandler();
						}];
					}
				}];
			}
			else
			{
				completionHandler();
			}
		}];
	}

	[queue async:^(dispatch_block_t  _Nonnull completionHandler) {
		if (!lookupDone && (queue != nil)) // "queue" reference here only there to keep the OCAsyncSequentialQueue around
		{
			// Last job in the queue sends an item not found error
			lookupCompletionHandler(OCError(OCErrorItemNotFound), nil, nil);
		}

		completionHandler();
	}];
}

@end
