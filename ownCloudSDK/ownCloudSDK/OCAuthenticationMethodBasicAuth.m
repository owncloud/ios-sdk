//
//  OCAuthenticationMethodBasicAuth.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 24.02.18.
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

#import "OCAuthenticationMethodBasicAuth.h"
#import "OCAuthenticationMethod+OCTools.h"
#import "NSError+OCError.h"
#import "OCConnectionRequest.h"

static NSString *OCAuthenticationMethodBasicAuthAuthenticationHeaderValueKey = @"BasicAuthString";

@implementation OCAuthenticationMethodBasicAuth

// Automatically register
OCAuthenticationMethodAutoRegister

#pragma mark - Identification
+ (OCAuthenticationMethodType)type
{
	return (OCAuthenticationMethodTypePassphrase);
}

+ (OCAuthenticationMethodIdentifier)identifier
{
	return (OCAuthenticationMethodBasicAuthIdentifier);
}

#pragma mark - Authentication Data Tools
+ (NSDictionary *)_decodedAuthenticationData:(NSData *)authenticationData
{
	return ([NSPropertyListSerialization propertyListWithData:authenticationData options:NSPropertyListImmutable format:NULL error:NULL]);
}

#pragma mark - Passphrase-based Authentication Only
+ (NSString *)userNameFromAuthenticationData:(NSData *)authenticationData
{
	NSString *userName = nil;

	if (authenticationData != nil)
	{
		NSDictionary *authDataDict;
		
		if ((authDataDict = [OCAuthenticationMethodBasicAuth _decodedAuthenticationData:authenticationData]) != nil)
		{
			return (authDataDict[OCAuthenticationMethodUsernameKey]);
		}
	}
	
	return (userName);
}

#pragma mark - Authentication / Deauthentication ("Login / Logout")
- (OCConnectionRequest *)authorizeRequest:(OCConnectionRequest *)request forConnection:(OCConnection *)connection
{
	NSString *authenticationHeaderValue;

	if ((authenticationHeaderValue = [self cachedAuthenticationSecretForConnection:connection]) != nil)
	{
		[request setValue:authenticationHeaderValue forHeaderField:@"Authorization"];
	}

	return(request);
}

#pragma mark - Authentication Secret Caching
- (id)loadCachedAuthenticationSecretForConnection:(OCConnection *)connection
{
	NSDictionary *authDataDict = [OCAuthenticationMethodBasicAuth _decodedAuthenticationData:connection.bookmark.authenticationData];

	return (authDataDict[OCAuthenticationMethodBasicAuthAuthenticationHeaderValueKey]);
}

#pragma mark - Generate bookmark authentication data
- (void)generateBookmarkAuthenticationDataWithConnection:(OCConnection *)connection options:(OCAuthenticationMethodBookmarkAuthenticationDataGenerationOptions)options completionHandler:(void(^)(NSError *error, OCAuthenticationMethodIdentifier authenticationMethodIdentifier, NSData *authenticationData))completionHandler
{
	NSString *userName, *passPhrase;
	
	if (completionHandler==nil) { return; }
	
	if (((userName = options[OCAuthenticationMethodUsernameKey]) != nil) && ((passPhrase = options[OCAuthenticationMethodPassphraseKey]) != nil) && (connection!=nil))
	{
		NSError *error = nil;
		NSString *authenticationHeaderValue;
		NSDictionary *authenticationDict;
		NSData *authenticationData;
		
		// Generate value for "Authentication" HTTP header
		if ((authenticationHeaderValue = [OCAuthenticationMethod basicAuthorizationValueForUsername:userName passphrase:passPhrase]) != nil)
		{
			authenticationDict = @{
				OCAuthenticationMethodUsernameKey   : userName,
				OCAuthenticationMethodPassphraseKey : passPhrase,

				// Store
				OCAuthenticationMethodBasicAuthAuthenticationHeaderValueKey : authenticationHeaderValue
			};
			
			// Generate authentication data (== bplist representation of authenticationDict)
			if ((authenticationData = [NSPropertyListSerialization dataWithPropertyList:authenticationDict format:NSPropertyListBinaryFormat_v1_0 options:0 error:&error]) != nil)
			{
				// Test credentials using connection before calling completionHandler; relay result of check
				OCConnectionRequest *request;
				
				request = [OCConnectionRequest requestWithURL:[connection URLForEndpoint:OCConnectionEndpointIDCapabilities options:nil]];
				[request setValue:@"json" forParameter:@"format"];

				[request setValue:authenticationHeaderValue forHeaderField:@"Authorization"];

				request.skipAuthorization = YES;

				[connection sendRequest:request toQueue:connection.commandQueue ephermalCompletionHandler:^(OCConnectionRequest *request, NSError *error) {
					if (error != nil)
					{
						completionHandler(error, OCAuthenticationMethodBasicAuthIdentifier, nil);
					}
					else
					{
						BOOL authorizationFailed = YES;
					
						if (request.response.statusCode == 200)
						{
							NSError *error = nil;
							NSDictionary *capabilitiesDict;
							
							if ((capabilitiesDict = [request responseBodyConvertedDictionaryFromJSONWithError:&error]) != nil)
							{
								if ([capabilitiesDict valueForKeyPath:@"ocs.data"] != nil)
								{
									authorizationFailed = NO;
								}
							}
						}
						
						if (authorizationFailed)
						{
							completionHandler(OCError(OCErrorAuthorizationFailed), OCAuthenticationMethodBasicAuthIdentifier, nil);
						}
						else
						{
							completionHandler(nil, OCAuthenticationMethodBasicAuthIdentifier, authenticationData);
						}
					}
				}];
			}
			else
			{
				completionHandler(error, OCAuthenticationMethodBasicAuthIdentifier, nil);
			}
		}
		else
		{
			completionHandler(OCError(OCErrorInternal), OCAuthenticationMethodBasicAuthIdentifier, nil);
		}
	}
	else
	{
		completionHandler(OCError(OCErrorInsufficientParameters), OCAuthenticationMethodBasicAuthIdentifier, nil);
	}
}

@end

OCAuthenticationMethodIdentifier OCAuthenticationMethodBasicAuthIdentifier = @"com.owncloud.basicauth";
