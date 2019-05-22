//
//  OCAuthenticationMethodOpenIDConnect.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 22.05.19.
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

#import "OCAuthenticationMethodOpenIDConnect.h"
#import "OCConnection.h"

@implementation OCAuthenticationMethodOpenIDConnect

#pragma mark - Identification
+ (OCAuthenticationMethodType)type
{
	return (OCAuthenticationMethodTypeToken);
}

+ (OCAuthenticationMethodIdentifier)identifier
{
	return (OCAuthenticationMethodIdentifierOpenIDConnect);
}

+ (NSString *)name
{
	return (@"OpenID Connect");
}

#pragma mark - Authentication Method Detection
+ (NSURL *)_wellKnownOpenIDConfigurationURLForConnection:(OCConnection *)connection
{
	return ([connection URLForEndpoint:OCConnectionEndpointIDWellKnown options:@{ OCConnectionEndpointURLOptionWellKnownSubPath : @"openid-configuration" }]);
}

+ (NSArray <NSURL *> *)detectionURLsForConnection:(OCConnection *)connection
{
	NSURL *wellKnownURL;
	NSArray <NSURL *> *oAuth2DetectionURLs;

	if ((oAuth2DetectionURLs = [super detectionURLsForConnection:connection]) != nil)
	{
		if ((wellKnownURL = [self _wellKnownOpenIDConfigurationURLForConnection:connection]) != nil)
		{
			return ([oAuth2DetectionURLs arrayByAddingObject:wellKnownURL]);
		}
	}

	return (nil);
}

+ (void)detectAuthenticationMethodSupportForConnection:(OCConnection *)connection withServerResponses:(NSDictionary<NSURL *, OCHTTPRequest *> *)serverResponses options:(OCAuthenticationMethodDetectionOptions)options completionHandler:(void(^)(OCAuthenticationMethodIdentifier identifier, BOOL supported))completionHandler
{
	[super detectAuthenticationMethodSupportForConnection:connection withServerResponses:serverResponses options:options completionHandler:^(OCAuthenticationMethodIdentifier identifier, BOOL supported) {

		if (supported)
		{
			// OAuth2 supported => continue
			NSURL *wellKnownURL;
			BOOL completeWithNotSupported = YES;

			if ((wellKnownURL = [self _wellKnownOpenIDConfigurationURLForConnection:connection]) != nil)
			{
				OCHTTPRequest *wellKnownRequest;

				if ((wellKnownRequest = [serverResponses objectForKey:wellKnownURL]) != nil)
				{

				}
			}

			// Fallback completion handler call
			if (completeWithNotSupported)
			{
				// OIDC not supported
				completionHandler(OCAuthenticationMethodIdentifierOpenIDConnect, NO);
			}

		}
		else
		{
			// OAuth2 not supported => OIDC requirement not met
			completionHandler(OCAuthenticationMethodIdentifierOpenIDConnect, NO);
		}
	}];
}


@end

OCAuthenticationMethodIdentifier OCAuthenticationMethodIdentifierOpenIDConnect = @"com.owncloud.openid-connect";
