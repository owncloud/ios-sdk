//
//  OCCore+CommandDownload.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 09.11.18.
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

#import "OCCore.h"
#import "OCCore+SyncEngine.h"
#import "OCSyncContext.h"
#import "NSError+OCError.h"
#import "OCMacros.h"
#import "NSString+OCParentPath.h"
#import "OCSyncActionUpdate.h"

@implementation OCCore (CommandUpdate)

#pragma mark - Command
- (nullable NSProgress *)updateItem:(OCItem *)item properties:(NSArray <OCItemPropertyName> *)properties options:(nullable NSDictionary *)options resultHandler:(nullable OCCoreActionResultHandler)resultHandler
{
	return (nil);
	// return ([self _enqueueSyncRecordWithAction:[[OCSyncActionDownload alloc] initWithItem:item options:options] allowsRescheduling:YES resultHandler:resultHandler]);
}

@end
