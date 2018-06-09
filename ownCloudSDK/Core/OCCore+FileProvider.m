//
//  OCCore+FileProvider.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 09.06.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import "OCCore+FileProvider.h"
#import "OCCore+Internal.h"

@implementation OCCore (FileProvider)

#pragma mark - Fileprovider tools
- (void)retrieveItemFromDatabaseForFileID:(OCFileID)fileID completionHandler:(void(^)(NSError *error, OCSyncAnchor syncAnchor, OCItem *itemFromDatabase))completionHandler
{
	[self queueBlock:^{
		dispatch_group_t waitForRetrievalGroup = dispatch_group_create();

		dispatch_group_enter(waitForRetrievalGroup);

		[self.vault.database retrieveCacheItemForFileID:fileID completionHandler:^(OCDatabase *db, NSError *error, OCSyncAnchor syncAnchor, OCItem *item) {
			dispatch_group_leave(waitForRetrievalGroup);

			completionHandler(error, syncAnchor, item);
		}];

		dispatch_group_wait(waitForRetrievalGroup, DISPATCH_TIME_FOREVER);
	}];
}

- (NSURL *)localURLForItem:(OCItem *)item
{
	return ([self.vault localURLForItem:item]);
}

@end
