//
//  NSHTTPCookie+OCCookies.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 14.08.19.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2019, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "NSHTTPCookie+OCCookies.h"

@implementation NSHTTPCookie (OCCookies)

- (BOOL)shouldApplyForURL:(NSURL *)url expired:(BOOL * _Nullable)outCookieExpired
{
	NSHTTPCookie *cookie = self;
	NSDate *expiresDate = nil;
	BOOL forbidden = NO;

	// Check expiry date
	if ((expiresDate = cookie.expiresDate) != nil)
	{
		// Not a session cookie (those don't have expiresDates)
		if ([expiresDate timeIntervalSinceNow] <= 0)
		{
			if (outCookieExpired != NULL)
			{
				*outCookieExpired = YES;
			}
			forbidden = YES;
		}
	}

	// Check secure
	if (!forbidden && cookie.secure)
	{
		// Secure cookies should only be transmitted over secure connections
		forbidden = ![url.scheme.lowercaseString hasSuffix:@"s"];
	}

	// Check ports
	if (!forbidden)
	{
		// Cookies are only limited to certain ports if a port (list) was provided (can also be empty, therefore we're checking for .count rather than nil)
		if (cookie.portList.count > 0)
		{
			NSNumber *urlPort;

			if ((urlPort = url.port) == nil)
			{
				urlPort = [url.scheme.lowercaseString hasSuffix:@"s"] ? @(443) : @(80);
			}

			forbidden = ![cookie.portList containsObject:urlPort];
		}
	}

	// Check domain
	if (!forbidden)
	{
		NSString *cookieDomain = cookie.domain;
		NSString *urlHost = url.host;

		if ([cookieDomain hasPrefix:@"."])
		{
			// Cookie domains starting with a dot match all subdomains and the domain itself
			forbidden = !([urlHost hasSuffix:cookieDomain] || [urlHost isEqual:[cookieDomain substringFromIndex:1]]);
		}
		else
		{
			// Cookie domains not starting with a dot only match the exact domain
			forbidden = ![urlHost isEqualToString:cookieDomain];
		}
	}

	// Check path
	if (!forbidden)
	{
		// Cookie should be sent for all requests to its path and all requests whose path is prefixed with the cookie's path
		forbidden = ![url.path hasPrefix:cookie.path];
	}

	return (!forbidden);
}

@end
