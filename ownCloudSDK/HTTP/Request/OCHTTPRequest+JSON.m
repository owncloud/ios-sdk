//
//  OCHTTPRequest+JSON.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 08.01.21.
//  Copyright © 2021 ownCloud GmbH. All rights reserved.
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

#import "OCHTTPRequest+JSON.h"

@implementation OCHTTPRequest (JSON)

+ (nullable instancetype)requestWithURL:(NSURL *)url jsonObject:(id)jsonObject error:(NSError * _Nullable * _Nullable)outError
{
	OCHTTPRequest *request = [self requestWithURL:url];
	NSError *error =nil;

	request.redirectPolicy = OCHTTPRequestRedirectPolicyHandleLocally;

	request.method = OCHTTPMethodPOST;
	error = [request setBodyWithJSON:jsonObject];

	if (outError != NULL)
	{
		*outError = error;
	}

	if (error != nil)
	{
		return (nil);
	}

	return (request);
}

- (nullable NSError *)setBodyWithJSON:(id)jsonObject
{
	NSError *error = nil;

	[self setValue:@"application/json" forHeaderField:OCHTTPHeaderFieldNameContentType];
	self.bodyData = [NSJSONSerialization dataWithJSONObject:jsonObject options:0 error:&error];

	return (error);
}

@end
