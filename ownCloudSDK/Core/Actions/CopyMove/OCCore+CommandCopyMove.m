//
//  OCCore+CommandCopyMove.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 19.06.18.
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
#import "OCSyncActionCopyMove.h"
#import "NSError+OCError.h"
#import "OCMacros.h"

@implementation OCCore (CommandCopyMove)

#pragma mark - Commands
- (NSProgress *)copyItem:(OCItem *)item to:(OCItem *)parentItem withName:(NSString *)name options:(NSDictionary *)options resultHandler:(OCCoreActionResultHandler)resultHandler
{
	if ((item == nil) || (name == nil) || (parentItem == nil)) { return(nil); }

	return ([self _enqueueSyncRecordWithAction:[[OCSyncActionCopyMove alloc] initWithItem:item action:OCSyncActionIdentifierCopy targetName:name targetParentItem:parentItem isRename:NO] allowsRescheduling:NO resultHandler:resultHandler]);
}

- (NSProgress *)moveItem:(OCItem *)item to:(OCItem *)parentItem withName:(NSString *)name options:(NSDictionary *)options resultHandler:(OCCoreActionResultHandler)resultHandler
{
	if ((item == nil) || (name == nil) || (parentItem == nil)) { return(nil); }

	return ([self _enqueueSyncRecordWithAction:[[OCSyncActionCopyMove alloc] initWithItem:item action:OCSyncActionIdentifierMove targetName:name targetParentItem:parentItem isRename:NO] allowsRescheduling:NO resultHandler:resultHandler]);
}

- (NSProgress *)renameItem:(OCItem *)item to:(NSString *)newFileName options:(NSDictionary *)options resultHandler:(OCCoreActionResultHandler)resultHandler
{
	__block OCItem *parentItem = nil;

	OCSyncExec(cacheItemRetrieval, {
		[self.vault.database retrieveCacheItemForFileID:item.parentFileID completionHandler:^(OCDatabase *db, NSError *error, OCSyncAnchor syncAnchor, OCItem *item) {
			if (item != nil)
			{
				parentItem = item;
			}

			OCSyncExecDone(cacheItemRetrieval);
		}];
	});

	if ((item == nil) || (newFileName == nil) || (parentItem == nil)) { return(nil); }

	return ([self _enqueueSyncRecordWithAction:[[OCSyncActionCopyMove alloc] initWithItem:item action:OCSyncActionIdentifierMove targetName:newFileName targetParentItem:parentItem isRename:YES] allowsRescheduling:NO resultHandler:resultHandler]);
}

@end
