//
//  OCCore+CommandCreateFolder.m
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
#import "OCCoreSyncActionCreateFolder.h"

@implementation OCCore (CommandCreateFolder)

#pragma mark - Command
- (NSProgress *)createFolder:(NSString *)folderName inside:(OCItem *)parentItem options:(NSDictionary *)options resultHandler:(OCCoreActionResultHandler)resultHandler
{
	OCItem *placeholderItem;

	if (folderName == nil) { return(nil); }
	if (parentItem == nil) { return(nil); }

	placeholderItem = [OCItem placeholderItemOfType:OCItemTypeCollection];

	placeholderItem.parentFileID = parentItem.fileID;
	placeholderItem.path = [parentItem.path stringByAppendingPathComponent:folderName];
	placeholderItem.fileID = [OCFileIDPlaceholderPrefix stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
	placeholderItem.eTag = OCFileETagPlaceholder;
	placeholderItem.lastModified = [NSDate date];

	return ([self _enqueueSyncRecordWithAction:OCSyncActionCreateFolder forItem:nil allowNilItem:YES parameters:@{
			OCSyncActionParameterParentItem : parentItem,
			OCSyncActionParameterTargetName : folderName,
			OCSyncActionParameterPlaceholderItem : placeholderItem
		} resultHandler:resultHandler]);
}

@end
