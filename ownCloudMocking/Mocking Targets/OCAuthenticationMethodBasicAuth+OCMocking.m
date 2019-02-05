//
//  OCAuthenticationMethodBasicAuth+OCMocking.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 12.07.18.
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

#import "OCAuthenticationMethodBasicAuth+OCMocking.h"
#import "NSObject+OCSwizzle.h"

@implementation OCAuthenticationMethodBasicAuth (OCMocking)

+ (void)load
{
	[self addMockLocation:OCMockLocationAuthenticationMethodBasicAuthDetectAuthenticationMethodSupportForConnection
	      forClassSelector:@selector(detectAuthenticationMethodSupportForConnection:withServerResponses:options:completionHandler:)
	      with:@selector(ocm_ba_detectAuthenticationMethodSupportForConnection:withServerResponses:options:completionHandler:)];

	[self addMockLocation:OCMockLocationAuthenticationMethodBasicAuthGenerateBookmarkAuthenticiationDataWithConnection
	      forSelector:@selector(generateBookmarkAuthenticationDataWithConnection:options:completionHandler:)
	      with:@selector(ocm_ba_generateBookmarkAuthenticationDataWithConnection:options:completionHandler:)];

	[self addMockLocation:OCMockLocationAuthenticationMethodBasicAuthAuthenticateConnection
	      forSelector:@selector(authenticateConnection:withCompletionHandler:)
	      with:@selector(ocm_ba_authenticateConnection:withCompletionHandler:)];

	[self addMockLocation:OCMockLocationAuthenticationMethodBasicAuthDeauthenticateConnection
	      forSelector:@selector(deauthenticateConnection:withCompletionHandler:)
	      with:@selector(ocm_ba_deauthenticateConnection:withCompletionHandler:)];
}

+ (void)ocm_ba_detectAuthenticationMethodSupportForConnection:(OCConnection *)connection withServerResponses:(NSDictionary<NSURL *, OCHTTPRequest *> *)serverResponses options:(OCAuthenticationMethodDetectionOptions)options completionHandler:(void(^)(OCAuthenticationMethodIdentifier identifier, BOOL supported))completionHandler
{
	OCMockAuthenticationMethodBasicAuthDetectAuthenticationMethodSupportForConnectionBlock mockBlock;

	if ((mockBlock = [[OCMockManager sharedMockManager] mockingBlockForLocation:OCMockLocationAuthenticationMethodBasicAuthDetectAuthenticationMethodSupportForConnection]) != nil)
	{
		mockBlock(connection, serverResponses, options, completionHandler);
	}
	else
	{
		[self ocm_ba_detectAuthenticationMethodSupportForConnection:connection withServerResponses:serverResponses options:options completionHandler:completionHandler];
	}
}

- (void)ocm_ba_generateBookmarkAuthenticationDataWithConnection:(OCConnection *)connection options:(OCAuthenticationMethodBookmarkAuthenticationDataGenerationOptions)options completionHandler:(void(^)(NSError *error, OCAuthenticationMethodIdentifier authenticationMethodIdentifier, NSData *authenticationData))completionHandler
{
	OCMockAuthenticationMethodBasicAuthGenerateBookmarkAuthenticiationDataWithConnectionBlock mockBlock;

	if ((mockBlock = [[OCMockManager sharedMockManager] mockingBlockForLocation:OCMockLocationAuthenticationMethodBasicAuthGenerateBookmarkAuthenticiationDataWithConnection]) != nil)
	{
		mockBlock(connection, options, completionHandler);
	}
	else
	{
		[self ocm_ba_generateBookmarkAuthenticationDataWithConnection:connection options:options completionHandler:completionHandler];
	}
}

- (void)ocm_ba_authenticateConnection:(OCConnection *)connection withCompletionHandler:(OCAuthenticationMethodAuthenticationCompletionHandler)completionHandler;
{
	OCMockAuthenticationMethodBasicAuthAuthenticateConnectionBlock mockBlock;

	if ((mockBlock = [[OCMockManager sharedMockManager] mockingBlockForLocation:OCMockLocationAuthenticationMethodBasicAuthAuthenticateConnection]) != nil)
	{
		mockBlock(connection, completionHandler);
	}
	else
	{
		[self ocm_ba_authenticateConnection:connection withCompletionHandler:completionHandler];
	}
}

- (void)ocm_ba_deauthenticateConnection:(OCConnection *)connection withCompletionHandler:(OCAuthenticationMethodAuthenticationCompletionHandler)completionHandler;
{
	OCMockAuthenticationMethodBasicAuthDeauthenticateConnectionBlock mockBlock;

	if ((mockBlock = [[OCMockManager sharedMockManager] mockingBlockForLocation:OCMockLocationAuthenticationMethodBasicAuthDeauthenticateConnection]) != nil)
	{
		mockBlock(connection, completionHandler);
	}
	else
	{
		[self ocm_ba_deauthenticateConnection:connection withCompletionHandler:completionHandler];
	}
}

@end

OCMockLocation OCMockLocationAuthenticationMethodBasicAuthDetectAuthenticationMethodSupportForConnection = @"OCAuthenticationMethodBasicAuth.detectAuthenticationMethodSupportForConnection";
OCMockLocation OCMockLocationAuthenticationMethodBasicAuthGenerateBookmarkAuthenticiationDataWithConnection = @"OCAuthenticationMethodBasicAuth.generateBookmarkAuthenticationDataWithConnection";
OCMockLocation OCMockLocationAuthenticationMethodBasicAuthAuthenticateConnection = @"OCAuthenticationMethodBasicAuth.authenticateConnection";
OCMockLocation OCMockLocationAuthenticationMethodBasicAuthDeauthenticateConnection = @"OCAuthenticationMethodBasicAuth.deauthenticateConnection";
