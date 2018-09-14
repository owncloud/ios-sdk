//
//  OCCore+CommandDelete.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 16.06.18.
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
#import "OCCoreSyncContext.h"
#import "NSError+OCError.h"
#import "OCMacros.h"
#import "OCCoreSyncActionDelete.h"

@implementation OCCore (CommandDelete)

#pragma mark - Command
- (NSProgress *)deleteItem:(OCItem *)item requireMatch:(BOOL)requireMatch resultHandler:(OCCoreActionResultHandler)resultHandler
{
	return ([self _enqueueSyncRecordWithAction:OCSyncActionDeleteLocal forItem:item allowNilItem:NO allowsRescheduling:NO parameters:@{
			OCSyncActionParameterItem : item,
			OCSyncActionParameterPath : item.path,
			OCSyncActionParameterRequireMatch : @(requireMatch),
		} resultHandler:resultHandler]);
}

@end
