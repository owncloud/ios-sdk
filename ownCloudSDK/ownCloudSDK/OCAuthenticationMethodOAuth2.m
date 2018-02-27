//
//  OCAuthenticationMethodOAuth2.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 05.02.18.
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

#import <UIKit/UIKit.h>
#import <SafariServices/SafariServices.h>

#import "OCAuthenticationMethodOAuth2.h"
#import "OCAuthenticationMethod+OCTools.h"
#import "OCConnection.h"
#import "NSError+OCError.h"
#import "NSURL+OCURLQueryParameterExtensions.h"

#pragma mark - Internal OA2 keys
typedef NSString* OA2DictKeyPath;
static OA2DictKeyPath OA2ExpirationDate	= @"expirationDate";

static OA2DictKeyPath OA2TokenResponse  = @"tokenResponse";
static OA2DictKeyPath OA2BearerString   = @"bearerString";
static OA2DictKeyPath OA2AccessToken    = @"tokenResponse.access_token";
static OA2DictKeyPath OA2RefreshToken   = @"tokenResponse.refresh_token";
static OA2DictKeyPath OA2ExpiresInSecs  = @"tokenResponse.expires_in";
static OA2DictKeyPath OA2TokenType      = @"tokenResponse.token_type";
static OA2DictKeyPath OA2MessageURL     = @"tokenResponse.message_url";
static OA2DictKeyPath OA2UserID         = @"tokenResponse.user_id";

@interface OCAuthenticationMethodOAuth2 ()
{
	SFAuthenticationSession *authenticationSession;
}
@end

@implementation OCAuthenticationMethodOAuth2

// Automatically register
OCAuthenticationMethodAutoRegister

#pragma mark - Class settings
+ (OCClassSettingsIdentifier)classSettingsIdentifier
{
	return (@"authentication-oauth2");
}

+ (NSDictionary<NSString *,id> *)defaultSettingsForIdentifier:(OCClassSettingsIdentifier)identifier
{
	return (@{
		OCAuthenticationMethodOAuth2AuthorizationEndpoint : @"index.php/apps/oauth2/authorize",
		OCAuthenticationMethodOAuth2TokenEndpoint 	  : @"index.php/apps/oauth2/api/v1/token",
		OCAuthenticationMethodOAuth2RedirectURI 	  : @"oc://ios.owncloud.com",
		OCAuthenticationMethodOAuth2ClientID 		  : @"mxd5OQDk6es5LzOzRvidJNfXLUZS2oN3oUFeXPP8LpPrhx3UroJFduGEYIBOxkY1",
		OCAuthenticationMethodOAuth2ClientSecret 	  : @"KFeFWWEZO9TkisIQzR3fo7hfiMXlOpaqP8CFuTbSHzV1TUuGECglPxpiVKJfOXIx"
	});
}

#pragma mark - Identification
+ (OCAuthenticationMethodType)type
{
	return (OCAuthenticationMethodTypeToken);
}

+ (OCAuthenticationMethodIdentifier)identifier
{
	return (OCAuthenticationMethodOAuth2Identifier);
}

#pragma mark - Authentication / Deauthentication ("Login / Logout")
- (OCConnectionRequest *)authorizeRequest:(OCConnectionRequest *)request forConnection:(OCConnection *)connection
{
	NSDictionary *authSecret;

	if ((authSecret = [self cachedAuthenticationSecretForConnection:connection]) != nil)
	{
		NSString *authorizationHeaderValue;
		
		if ((authorizationHeaderValue = [authSecret valueForKeyPath:OA2BearerString]) != nil)
		{
			[request setValue:authorizationHeaderValue forHeaderField:@"Authorization"];
		}
	}

	return(request);
}

#pragma mark - Generate bookmark authentication data
- (void)generateBookmarkAuthenticationDataWithConnection:(OCConnection *)connection options:(OCAuthenticationMethodBookmarkAuthenticationDataGenerationOptions)options completionHandler:(void(^)(NSError *error, OCAuthenticationMethodIdentifier authenticationMethodIdentifier, NSData *authenticationData))completionHandler
{
	UIViewController *viewController;
	
	if (completionHandler==nil) { return; }
	
	if (((viewController = options[OCAuthenticationMethodPresentingViewControllerKey]) != nil) && (connection!=nil))
	{
		NSURL *authorizationRequestURL;

		// Generate Authorization Request URL
		authorizationRequestURL = [[connection URLForEndpointPath:[self classSettingForOCClassSettingsKey:OCAuthenticationMethodOAuth2AuthorizationEndpoint]] urlByAppendingQueryParameters:@{
						@"response_type" : @"code",
						@"client_id" 	 : [self classSettingForOCClassSettingsKey:OCAuthenticationMethodOAuth2ClientID],
						@"redirect_uri"  : [self classSettingForOCClassSettingsKey:OCAuthenticationMethodOAuth2RedirectURI]
					  } replaceExisting:NO];
		
		dispatch_async(dispatch_get_main_queue(), ^{
			// Create and start authentication session on main thread
			authenticationSession = [[SFAuthenticationSession alloc] initWithURL:authorizationRequestURL callbackURLScheme:[[NSURL URLWithString:[self classSettingForOCClassSettingsKey:OCAuthenticationMethodOAuth2RedirectURI]] scheme] completionHandler:^(NSURL *callbackURL, NSError *error) {

				// Handle authentication session result
				if (error == nil)
				{
					NSString *authorizationCode;
					
					// Obtain Authorization Code
					if ((authorizationCode = [callbackURL queryParameters][@"code"]) != nil)
					{
						NSLog(@"Authorization Code: %@", authorizationCode);

						// Send Access Token Request
						[self 	_sendTokenRequestToConnection:connection
						       	withParameters:@{
								@"grant_type"    : @"authorization_code",
								@"code"		 : authorizationCode,
								@"redirect_uri"  : [self classSettingForOCClassSettingsKey:OCAuthenticationMethodOAuth2RedirectURI]
							}
							completionHandler:^(NSError *error, NSDictionary *jsonResponseDict, NSData *authenticationData){
								completionHandler(error, OCAuthenticationMethodOAuth2Identifier, authenticationData);
							}
						];
					}
					else
					{
						// No code was supplied in callback URL
						error = OCError(OCErrorAuthorizationFailed);
					}
				}
				
				if (error != nil)
				{
					// Return errors
					completionHandler(error, OCAuthenticationMethodOAuth2Identifier, nil);
				}
			
				NSLog(@"Callback URL: %@", callbackURL);
				NSLog(@"Error: %@", error);
				
				// Release Authentication Session
				authenticationSession = nil;
			}];

			// Start authentication session
			[authenticationSession start];
		});
	}
	else
	{
		completionHandler(OCError(OCErrorInsufficientParameters), OCAuthenticationMethodOAuth2Identifier, nil);
	}
}

#pragma mark - Authentication Secret Caching
- (id)loadCachedAuthenticationSecretForConnection:(OCConnection *)connection
{
	NSData *authenticationData;
	
	if ((authenticationData = connection.bookmark.authenticationData) != nil)
	{
		return ([NSPropertyListSerialization propertyListWithData:authenticationData options:NSPropertyListImmutable format:NULL error:NULL]);
	}
	
	return (nil);
}

#pragma mark - Wait for authentication
- (BOOL)canSendAuthenticatedRequestsForConnection:(OCConnection *)connection withAvailabilityHandler:(OCConnectionAuthenticationAvailabilityHandler)availabilityHandler
{
	NSDictionary<NSString *, id> *authSecret;
	
	if ((authSecret = [self cachedAuthenticationSecretForConnection:connection]) != nil)
	{
		NSTimeInterval timeLeftUntilExpiration = [[authSecret valueForKeyPath:OA2ExpirationDate] timeIntervalSinceNow];

		// Get a new token up to 2 minutes before the old one expires
		if (timeLeftUntilExpiration < 120)
		{
			[self _refreshTokenForConnection:connection availabilityHandler:availabilityHandler];

			return (NO);
		}
		
		// Token is still valid
		return (YES);
	}
	
	// No secret
	availabilityHandler(OCError(OCErrorAuthorizationNoMethodData), NO);

	return (NO);
}

#pragma mark - Token management
- (void)_refreshTokenForConnection:(OCConnection *)connection availabilityHandler:(OCConnectionAuthenticationAvailabilityHandler)availabilityHandler
{
	NSDictionary<NSString *, id> *authSecret;
	NSError *error=nil;
	
	if ((authSecret = [self cachedAuthenticationSecretForConnection:connection]) != nil)
	{
		NSString *refreshToken;
		
		if ((refreshToken = [authSecret valueForKeyPath:OA2RefreshToken]) != nil)
		{
			[self 	_sendTokenRequestToConnection:connection
				withParameters:@{
					@"grant_type"    : @"refresh_token",
					@"refresh_token" : refreshToken,
				}
				completionHandler:^(NSError *error, NSDictionary *jsonResponseDict, NSData *authenticationData){
					// Update authentication data of the bookmark
					if ((error==nil) && (authenticationData!=nil))
					{
						connection.bookmark.authenticationData = authenticationData;
					}
				
					availabilityHandler(error, (error==nil));
				}
			];
		}
		else
		{
			// Missing data in secret
			error = OCError(OCErrorAuthorizationMissingData);
		}
	}
	else
	{
		// No secret
		error = OCError(OCErrorAuthorizationNoMethodData);
	}

	if (error != nil)
	{
		if (availabilityHandler!=nil)
		{
			availabilityHandler(error, NO);
		}
	}
}

- (void)_sendTokenRequestToConnection:(OCConnection *)connection withParameters:(NSDictionary<NSString*,NSString*> *)parameters completionHandler:(void(^)(NSError *error, NSDictionary *jsonResponseDict, NSData *authenticationData))completionHandler
{
	OCConnectionRequest *tokenRequest;

	// Compose Token Request
	if ((tokenRequest = [OCConnectionRequest requestWithURL:[connection URLForEndpointPath:[self classSettingForOCClassSettingsKey:OCAuthenticationMethodOAuth2TokenEndpoint]]]) != nil)
	{
		tokenRequest.method = OCConnectionRequestMethodPOST; // Use POST
		
		tokenRequest.skipAuthorization = YES;
		
		[tokenRequest addParameters:parameters];

		[tokenRequest setValue:[OCAuthenticationMethod basicAuthorizationValueForUsername:[self classSettingForOCClassSettingsKey:OCAuthenticationMethodOAuth2ClientID] passphrase:[self classSettingForOCClassSettingsKey:OCAuthenticationMethodOAuth2ClientSecret]]
				    forHeaderField:@"Authorization"];
		
		// Send Token Request
		[connection sendRequest:tokenRequest toQueue:connection.commandQueue ephermalCompletionHandler:^(OCConnectionRequest *request, NSError *error) {
			NSLog(@"Token Request Result: %@, %@ %@ %@", error, request.response, request.responseBodyAsString, [request responseBodyConvertedDictionaryFromJSONWithError:NULL]);

			// Handle Token Request Result
			if (error == nil)
			{
				NSDictionary *jsonResponseDict;
				
				if ((jsonResponseDict = [request responseBodyConvertedDictionaryFromJSONWithError:NULL]) != nil)
				{
					NSString *jsonError;
				
					if ((jsonError = jsonResponseDict[@"error"]) != nil)
					{
						// Handle errors coming from JSON response
						NSDictionary *errorInfo = @{
							@"authMethod" : OCAuthenticationMethodOAuth2Identifier,
							@"jsonError" : jsonError
						};

						error = OCErrorWithInfo(OCErrorAuthorizationFailed, errorInfo);
					}
					else
					{
						// Success
						NSDate *validUntil = nil;
						NSData *authenticationData;
						NSDictionary *authenticationDataDict;

						if (jsonResponseDict[@"expires_in"] != nil)
						{
							validUntil = [NSDate dateWithTimeIntervalSinceNow:[jsonResponseDict[@"expires_in"] integerValue]];
						}
						else
						{
							validUntil = [NSDate dateWithTimeIntervalSinceNow:3600];
						}
						
						authenticationDataDict = @{
							@"expirationDate" : validUntil,
							@"bearerString"  : [NSString stringWithFormat:@"Bearer %@", jsonResponseDict[@"access_token"]],
							@"tokenResponse" : jsonResponseDict
						};
						
						if ((authenticationData = [NSPropertyListSerialization dataWithPropertyList:authenticationDataDict format:NSPropertyListBinaryFormat_v1_0 options:0 error:&error]) != nil)
						{
							completionHandler(nil, jsonResponseDict, authenticationData);
						}
						else if (error == nil)
						{
							error = OCError(OCErrorInternal);
						}
					}
				}
			}
			
			if (error != nil)
			{
				// Return error
				completionHandler(error, nil, nil);
			}
		}];
	}
	else
	{
		// Internal error
		completionHandler(OCError(OCErrorInternal), nil, nil);
	}
}

@end

OCAuthenticationMethodIdentifier OCAuthenticationMethodOAuth2Identifier = @"com.owncloud.oauth2";

OCClassSettingsKey OCAuthenticationMethodOAuth2AuthorizationEndpoint = @"oa2-authorization-endpoint";
OCClassSettingsKey OCAuthenticationMethodOAuth2TokenEndpoint = @"oa2-token-endpoint";
OCClassSettingsKey OCAuthenticationMethodOAuth2RedirectURI = @"oa2-redirect-uri";
OCClassSettingsKey OCAuthenticationMethodOAuth2ClientID = @"oa2-client-id";
OCClassSettingsKey OCAuthenticationMethodOAuth2ClientSecret = @"oa2-client-secret";
