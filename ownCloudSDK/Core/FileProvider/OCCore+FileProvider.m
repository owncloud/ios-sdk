//
//  OCCore+FileProvider.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 09.06.18.
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

#import "OCCore+FileProvider.h"
#import "OCCore+Internal.h"
#import "OCVault+Internal.h"
#import "NSString+OCPath.h"
#import "OCLogger.h"
#import "OCMacros.h"

@implementation OCCore (FileProvider)

#pragma mark - Fileprovider tools
- (void)retrieveItemFromDatabaseForLocalID:(OCLocalID)localID completionHandler:(void(^)(NSError * __nullable error, OCSyncAnchor __nullable syncAnchor, OCItem * __nullable itemFromDatabase))completionHandler
{
	[self queueBlock:^{
		OCSyncExec(cacheItemRetrieval, {
			[self.vault.database retrieveCacheItemForLocalID:localID completionHandler:^(OCDatabase *db, NSError *error, OCSyncAnchor syncAnchor, OCItem *item) {
				completionHandler(error, syncAnchor, item);

				OCSyncExecDone(cacheItemRetrieval);
			}];
		});
	}];
}

#pragma mark - Singal changes for items
- (void)signalChangesToFileProviderForItems:(NSArray <OCItem *> *)changedItems
{
	if (self.postFileProviderNotifications)
	{
		[self.vault signalChangesForItems:changedItems];
	}
}

@end
