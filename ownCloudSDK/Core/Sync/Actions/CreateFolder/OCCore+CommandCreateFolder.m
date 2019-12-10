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
#import "OCSyncActionCreateFolder.h"

@implementation OCCore (CommandCreateFolder)

#pragma mark - Command
- (nullable NSProgress *)createFolder:(NSString *)folderName inside:(OCItem *)parentItem options:(nullable NSDictionary<OCCoreOption,id> *)options resultHandler:(nullable OCCoreActionResultHandler)resultHandler
{
	OCCorePlaceholderCompletionHandler placeholderCompletionHandler = options[OCCoreOptionPlaceholderCompletionHandler];
	OCCorePlaceholderCompletionHandler intermediatePlaceholderCompletionHandler = nil;
	__block OCItem *placeholderItem = nil;
	__block NSError *placeholderError = nil;

	if (folderName == nil) { return(nil); }
	if (parentItem == nil) { return(nil); }

	if (placeholderCompletionHandler != nil)
	{
		intermediatePlaceholderCompletionHandler = ^(NSError *error, OCItem *item) {
			placeholderItem = item;
			placeholderError = error;
		};
	}

	return ([self _enqueueSyncRecordWithAction:[[OCSyncActionCreateFolder alloc] initWithParentItem:parentItem folderName:folderName placeholderCompletionHandler:intermediatePlaceholderCompletionHandler] cancellable:NO preflightResultHandler:((placeholderCompletionHandler != nil) ? ^(NSError * _Nullable error) {
		placeholderCompletionHandler(placeholderError, placeholderItem);
	} : nil) resultHandler:resultHandler]);
}

@end
