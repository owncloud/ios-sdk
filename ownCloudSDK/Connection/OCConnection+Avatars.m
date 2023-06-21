//
//  OCConnection+Avatars.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 29.09.20.
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

#import "OCConnection.h"
#import "OCAvatar.h"
#import "NSError+OCError.h"
#import "OCHTTPResponse+DAVError.h"

@implementation OCConnection (Avatars)

/*
	Endpoint notes:
	- the response has either of the following codes:
		- 200 OK: success (+ content and Content-Type)
		- 304 NOT MODIFIED: the avatar hasn't changed (ETag is the same as provided via If-None-Match header) (+ content and Content-Type)
		- 404 NOT FOUND: no avatar available
	- the response comes with an ETag that only changes when the avatar is changed
*/

- (nullable NSProgress *)retrieveAvatarForUser:(OCUser *)user existingETag:(nullable OCFileETag)eTag withSize:(CGSize)size completionHandler:(void(^)(NSError * _Nullable error, BOOL unchanged, OCAvatar * _Nullable avatar))completionHandler
{
	OCHTTPRequest *request;
	NSProgress *progress = nil;
	NSURL *avatarURL = [[[self URLForEndpoint:OCConnectionEndpointIDAvatars options:nil] URLByAppendingPathComponent:user.userName] URLByAppendingPathComponent:[@((NSInteger)size.width).stringValue stringByAppendingString:@".png"] isDirectory:NO];

	request = [OCHTTPRequest requestWithURL:avatarURL];
	request.requiredSignals = [NSSet setWithObject:OCConnectionSignalIDAuthenticationAvailable];

	if (eTag != nil)
	{
		[request addHeaderFields:@{
			@"If-None-Match" : eTag
		}];
	}

	progress = [self sendRequest:request ephermalCompletionHandler:^(OCHTTPRequest *request, OCHTTPResponse *response, NSError *error) {
		if (error != nil)
		{
			completionHandler(error, NO, nil);
			return;
		}

		switch (response.status.code)
		{
			case OCHTTPStatusCodeNOT_MODIFIED:
			case OCHTTPStatusCodeOK: {
				OCAvatar *avatar = [[OCAvatar alloc] init];

				avatar.userIdentifier = user.userIdentifier;
				avatar.eTag = response.headerFields[OCHTTPHeaderFieldNameETag];
				avatar.mimeType = response.contentType;
				avatar.data = response.bodyData;
				avatar.timestamp = [NSDate new];

				completionHandler(nil, (response.status.code == OCHTTPStatusCodeNOT_MODIFIED), avatar);
			}
			break;

			case OCHTTPStatusCodeNOT_FOUND:
				completionHandler(OCError(OCErrorResourceDoesNotExist), NO, nil);
			break;

			default: {
				NSError *responseError;

				if ((responseError = response.bodyParsedAsDAVError) == nil)
				{
					responseError = response.status.error;
				}

				completionHandler(responseError, NO, nil);
			}
			break;
		}
	}];

	return (progress);
}

@end
