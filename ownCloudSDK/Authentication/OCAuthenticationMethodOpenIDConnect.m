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
#import "OCLogger.h"
#import "OCMacros.h"
#import "NSError+OCError.h"

@implementation OCAuthenticationMethodOpenIDConnect

// Automatically register
OCAuthenticationMethodAutoRegister

#pragma mark - Class settings
+ (NSDictionary<NSString *,id> *)defaultSettingsForIdentifier:(OCClassSettingsIdentifier)identifier
{
	NSMutableDictionary<NSString *,id> *defaultSettings = [[super defaultSettingsForIdentifier:identifier] mutableCopy];

	defaultSettings[OCAuthenticationMethodOpenIDConnectRedirectURI] = @"oc://ios.owncloud.com";
	defaultSettings[OCAuthenticationMethodOpenIDConnectScope] = @"openid offline_access email profile";

	return (defaultSettings);
}

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

#pragma mark - OAuth2 extensions
- (NSURL *)authorizationEndpointURLForConnection:(OCConnection *)connection
{
	NSString *authorizationEndpointURLString;

	if ((authorizationEndpointURLString = OCTypedCast(_openIDConfig[@"authorization_endpoint"], NSString)) != nil)
	{
		return ([NSURL URLWithString:authorizationEndpointURLString]);
	}

	return (nil);
}

- (NSURL *)tokenEndpointURLForConnection:(OCConnection *)connection;
{
	NSString *tokenEndpointURLString;

	if ((tokenEndpointURLString = OCTypedCast(_openIDConfig[@"token_endpoint"], NSString)) != nil)
	{
		return ([NSURL URLWithString:tokenEndpointURLString]);
	}

	return (nil);
}

- (NSString *)redirectURIForConnection:(OCConnection *)connection
{
	return ([self classSettingForOCClassSettingsKey:OCAuthenticationMethodOpenIDConnectRedirectURI]);
}

- (NSDictionary<NSString *, NSString *> *)tokenRefreshParametersForRefreshToken:(NSString *)refreshToken
{
	NSMutableDictionary<NSString *, NSString *> *refreshParameters = [[super tokenRefreshParametersForRefreshToken:refreshToken] mutableCopy];

	refreshParameters[@"client_id"] = [self classSettingForOCClassSettingsKey:OCAuthenticationMethodOAuth2ClientID];
	refreshParameters[@"client_secret"] = [self classSettingForOCClassSettingsKey:OCAuthenticationMethodOAuth2ClientSecret];
	refreshParameters[@"scope"] = @"openid profile"; // self.scope;

	return (refreshParameters);
}

- (void)retrieveEndpointInformationForConnection:(OCConnection *)connection completionHandler:(void(^)(NSError *error))completionHandler
{
	NSURL *openidConfigURL;

	if ((openidConfigURL = [self.class _openIDConfigurationURLForConnection:connection]) != nil)
	{
		[connection sendRequest:[OCHTTPRequest requestWithURL:openidConfigURL] ephermalCompletionHandler:^(OCHTTPRequest * _Nonnull request, OCHTTPResponse * _Nullable response, NSError * _Nullable error) {
			NSError *jsonError;

			if ((self->_openIDConfig = [response bodyConvertedDictionaryFromJSONWithError:&jsonError]) != nil)
			{
				self.pkce = [OCPKCE new]; // Enable PKCE

				completionHandler(nil);
			}
			else
			{
				completionHandler(error);
			}
		}];
	}
	else
	{
		completionHandler(OCError(OCErrorInsufficientParameters));
	}
}

- (NSString *)scope
{
	return ([self classSettingForOCClassSettingsKey:OCAuthenticationMethodOpenIDConnectScope]);
}

- (NSString *)prompt
{
	return (@"consent");
}

#pragma mark - Authentication Method Detection
+ (NSURL *)_openIDConfigurationURLForConnection:(OCConnection *)connection
{
	return ([connection URLForEndpoint:OCConnectionEndpointIDWellKnown options:@{ OCConnectionEndpointURLOptionWellKnownSubPath : @"openid-configuration" }]);
}

+ (NSArray <NSURL *> *)detectionURLsForConnection:(OCConnection *)connection
{
	NSURL *openidConfigURL;
	NSArray <NSURL *> *oAuth2DetectionURLs;

	if ((oAuth2DetectionURLs = [super detectionURLsForConnection:connection]) != nil)
	{
		if ((openidConfigURL = [self _openIDConfigurationURLForConnection:connection]) != nil)
		{
			return ([oAuth2DetectionURLs arrayByAddingObject:openidConfigURL]);
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

			if ((wellKnownURL = [self _openIDConfigurationURLForConnection:connection]) != nil)
			{
				OCHTTPRequest *wellKnownRequest;

				if ((wellKnownRequest = [serverResponses objectForKey:wellKnownURL]) != nil)
				{
					OCHTTPResponse *response = wellKnownRequest.httpResponse;

					if (response.status.isSuccess)
					{
						if ([response.contentType hasSuffix:@"/json"])
						{
							NSError *error = nil;
							NSDictionary<NSString *, id> *oidcConfig;

							if ((oidcConfig = [response bodyConvertedDictionaryFromJSONWithError:&error]) != nil)
							{
								// OIDC supported
								completionHandler(OCAuthenticationMethodIdentifierOpenIDConnect, YES);
								completeWithNotSupported = NO;
							}
							else
							{
								OCLogError(@"Error decoding OIDC configuration JSON: %@", OCLogPrivate(error));
							}
						}
					}
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

#pragma mark - Generate bookmark authentication data
- (void)generateBookmarkAuthenticationDataWithConnection:(OCConnection *)connection options:(OCAuthenticationMethodBookmarkAuthenticationDataGenerationOptions)options completionHandler:(void(^)(NSError *error, OCAuthenticationMethodIdentifier authenticationMethodIdentifier, NSData *authenticationData))completionHandler
{
	[self retrieveEndpointInformationForConnection:connection completionHandler:^(NSError * _Nonnull error) {
		if (error == nil)
		{
			[super generateBookmarkAuthenticationDataWithConnection:connection options:options completionHandler:completionHandler];
		}
		else
		{
			completionHandler(error, nil, nil);
		}
	}];
}

@end

OCAuthenticationMethodIdentifier OCAuthenticationMethodIdentifierOpenIDConnect = @"com.owncloud.openid-connect";

OCClassSettingsKey OCAuthenticationMethodOpenIDConnectRedirectURI = @"oidc-redirect-uri";
OCClassSettingsKey OCAuthenticationMethodOpenIDConnectScope = @"oidc-scope";
