//
//  OCCore+Download.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 21.06.18.
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

@implementation OCCore (Download)

- (NSProgress *)downloadItem:(OCItem *)item options:(NSDictionary *)options resultHandler:(OCCoreDownloadResultHandler)resultHandler
{
	NSURL *temporaryDirectoryURL = [[NSURL fileURLWithPath:NSTemporaryDirectory()]  URLByAppendingPathComponent:[NSUUID UUID].UUIDString];
	NSURL *temporaryFileURL = [temporaryDirectoryURL URLByAppendingPathComponent:item.name];
	OCEventTarget *eventTarget;

	[[NSFileManager defaultManager] createDirectoryAtURL:temporaryDirectoryURL withIntermediateDirectories:YES attributes:nil error:NULL];

	eventTarget = 	[OCEventTarget 	eventTargetWithEventHandlerIdentifier:self.eventHandlerIdentifier
					userInfo:@{ @"item" : item }
					ephermalUserInfo:((resultHandler!=nil) ?  @{ @"resultHandler" : [resultHandler copy] } : nil)
			];

	return ([self.connection downloadItem:item to:temporaryFileURL options:options resultTarget:eventTarget]);
}

- (void)_handleDownloadFileEvent:(OCEvent *)event sender:(id)sender
{
	OCCoreDownloadResultHandler resultHandler = event.ephermalUserInfo[@"resultHandler"];
	OCItem *item = event.userInfo[@"item"];

	if (resultHandler != nil)
	{
		resultHandler(event.error, self, item, event.file);
	}
}

@end
