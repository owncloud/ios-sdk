//
//  OCHostSimulator+CookieRedirect.m
//  ownCloudMocking
//
//  Created by Felix Schwarz on 20.08.20.
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

#import "OCHostSimulator+CookieRedirect.h"

@implementation OCHostSimulator (CookieRedirect)

+ (instancetype)cookieRedirectSimulatorWithRequestWithoutCookiesHandler:(dispatch_block_t)requestWithoutCookiesHandler requestForCookiesHandler:(dispatch_block_t)requestForCookiesHandler requestWithCookiesHandler:(dispatch_block_t)requestWithCookiesHandler
{
	OCHostSimulator *hostSimulator;
	__block NSURL *originallyRequestedURL = nil;
	__block dispatch_block_t requestWithoutCookiesHandlerBlock = requestWithoutCookiesHandler;
	__block dispatch_block_t requestForCookiesHandlerBlock = requestForCookiesHandler;
	__block dispatch_block_t requestWithCookiesHandlerBlock = requestWithCookiesHandler;

	hostSimulator = [OCHostSimulator new];
	hostSimulator.requestHandler = ^BOOL(OCConnection *connection, OCHTTPRequest *request, OCHostSimulatorResponseHandler responseHandler) {
		if ([request.url.path isEqual:@"/set/cookies"])
		{
			NSString *originalURLString = originallyRequestedURL.absoluteString;

			responseHandler(nil, [OCHostSimulatorResponse responseWithURL:request.url statusCode:OCHTTPStatusCodeTEMPORARY_REDIRECT headers:@{
				@"Location" 	: originalURLString,
				@"Set-Cookie"	: @"sessionCookie=value; Max-Age=2592000; Path=/"
			} contentType:@"text/html" body:nil]);

			if (requestForCookiesHandlerBlock != nil)
			{
				requestForCookiesHandlerBlock();
				requestForCookiesHandlerBlock = nil;
			}

			return (YES);
		}

		if (request.headerFields[@"Cookie"] == nil)
		{
			originallyRequestedURL = request.url;

			responseHandler(nil, [OCHostSimulatorResponse responseWithURL:request.url statusCode:OCHTTPStatusCodeTEMPORARY_REDIRECT headers:@{
				@"Location" : @"/set/cookies"
			} contentType:@"text/html" body:nil]);

			if (requestWithoutCookiesHandlerBlock != nil)
			{
				requestWithoutCookiesHandlerBlock();
				requestWithoutCookiesHandlerBlock = nil;
			}

			return (YES);
		}
		else
		{
			if (requestWithCookiesHandlerBlock != nil)
			{
				requestWithCookiesHandlerBlock();
				requestWithCookiesHandlerBlock = nil;
			}
		}

		return (NO);
	};

	hostSimulator.unroutableRequestHandler = nil;

	return (hostSimulator);
}

@end
