//
//  OCCore+MessageResponseHandler.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 25.03.20.
//  Copyright © 2020 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2020, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCCore+MessageResponseHandler.h"
#import "OCCore+SyncEngine.h"
#import "OCMessage.h"

@implementation OCCore (MessageResponseHandler)

- (BOOL)handleResponseToMessage:(nonnull OCMessage *)message
{
	if ([message.bookmarkUUID isEqual:self.bookmark.uuid]) // Handle only message related to this core
	{
		if ((message.syncIssue != nil) && (message.pickedChoice != nil)) // Handle only sync issues where a choice was made
		{
			[self resolveSyncIssue:message.syncIssue withChoice:(OCSyncIssueChoice *)message.pickedChoice userInfo:message.syncIssue.routingInfo completionHandler:nil]; // Resolve issue with choice

			return (YES); // Message was handled, can now be removed
		}
	}

	return (NO); // Message was not handled
}

@end
