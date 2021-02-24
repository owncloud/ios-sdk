//
//  OCCoreManager+ItemResolution.m
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

#import "OCCoreManager+ItemResolution.h"
#import "NSError+OCError.h"

@implementation OCCoreManager (ItemResolution)

- (void)requestCoreForBookmarkWithItemWithLocalID:(OCLocalID)localID setup:(void(^)(OCCore * _Nullable core, NSError * _Nullable error))setupHandler completionHandler:(void(^)(NSError * _Nullable error, OCCore * _Nullable core, OCItem * _Nullable item))completionHandler
{
	// Locate the bookmark whose database contains the provided localID
	[OCBookmarkManager.sharedBookmarkManager locateBookmarkForItemWithLocalID:localID completionHandler:^(NSError * _Nullable error, OCBookmark * _Nullable bookmark, OCItem * _Nullable item) {
		if ((bookmark != nil) && (item != nil))
		{
			// Request a core for the bookamrk
			[self requestCoreForBookmark:bookmark setup:setupHandler completionHandler:^(OCCore * _Nullable core, NSError * _Nullable error) {
				if (core != nil)
				{
					// Make sure the item is "fresh"
					[core.vault.database retrieveCacheItemForLocalID:localID completionHandler:^(OCDatabase *db, NSError *error, OCSyncAnchor syncAnchor, OCItem *item) {
						if (item != nil)
						{
							// Return core and item
							completionHandler(nil, core, item);
						}
						else
						{
							completionHandler(OCError(OCErrorItemNotFound), nil, nil);
						}
					}];
				}
				else
				{
					completionHandler(error, nil, nil);
				}
			}];
		}
		else
		{
			completionHandler(error, nil, nil);
		}
	}];
}

@end
