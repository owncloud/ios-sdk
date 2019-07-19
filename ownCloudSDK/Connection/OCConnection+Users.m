//
//  OCConnection+Users.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 10.03.18.
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

#import "OCConnection.h"
#import "OCUser.h"
#import "NSError+OCError.h"

@implementation OCConnection (Users)

#pragma mark - User info
- (NSProgress *)retrieveLoggedInUserWithCompletionHandler:(void(^)(NSError *error, OCUser *loggedInUser))completionHandler
{
	OCHTTPRequest *request;
	NSProgress *progress = nil;

	request = [OCHTTPRequest requestWithURL:[self URLForEndpoint:OCConnectionEndpointIDUser options:nil]];
	request.requiredSignals = [NSSet setWithObject:OCConnectionSignalIDAuthenticationAvailable];

	[request setValue:@"json" forParameter:@"format"];

	progress = [self sendRequest:request ephermalCompletionHandler:^(OCHTTPRequest *request, OCHTTPResponse *response, NSError *error) {
		if (error != nil)
		{
			completionHandler(error, nil);
		}
		else
		{
			NSError *jsonError = nil;
			NSDictionary *userInfoReturnDict;
			NSDictionary *userInfoDict = nil;

			if ((userInfoReturnDict = [response bodyConvertedDictionaryFromJSONWithError:&jsonError]) != nil)
			{
				if ([userInfoReturnDict isKindOfClass:[NSDictionary class]])
				{
					userInfoDict = userInfoReturnDict[@"ocs"][@"data"];
				}
			}

			if (userInfoDict != nil)
			{
				#define IgnoreNull(obj) ([obj isKindOfClass:[NSNull class]] ? nil : obj)

				OCUser *user;

				user = [OCUser userWithUserName:IgnoreNull(userInfoDict[@"id"])
						    displayName:IgnoreNull(userInfoDict[@"display-name"])
						       isRemote:NO];
				user.emailAddress = IgnoreNull(userInfoDict[@"email"]);

				completionHandler(nil, user);
			}
			else
			{
				completionHandler((jsonError!=nil) ? jsonError : OCError(OCErrorResponseUnknownFormat), nil);
			}
		}
	}];

	return (progress);
}

@end
