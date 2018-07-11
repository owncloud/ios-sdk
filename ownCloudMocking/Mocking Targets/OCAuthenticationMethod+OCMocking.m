//
//  OCAuthenticationMethod+OCMocking.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 11.07.18.
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

#import "OCAuthenticationMethod+OCMocking.h"
#import "NSObject+OCSwizzle.h"

@implementation OCAuthenticationMethod (OCMocking)

+ (void)load
{
	[self addMockLocation:OCMockLocationAuthenticationMethodDetectAuthenticationMethodSupportForConnection
	      forClassSelector:@selector(detectAuthenticationMethodSupportForConnection:withServerResponses:options:completionHandler:)
	      with:@selector(ocm_detectAuthenticationMethodSupportForConnection:withServerResponses:options:completionHandler:)];

	[self addMockLocation:OCMockLocationAuthenticationMethodGenerateBookmarkAuthenticiationDataWithConnection
	      forSelector:@selector(generateBookmarkAuthenticationDataWithConnection:options:completionHandler:)
	      with:@selector(ocm_generateBookmarkAuthenticationDataWithConnection:options:completionHandler:)];

	[self addMockLocation:OCMockLocationAuthenticationMethodAuthenticateConnection
	      forSelector:@selector(authenticateConnection:withCompletionHandler:)
	      with:@selector(ocm_authenticateConnection:withCompletionHandler:)];

	[self addMockLocation:OCMockLocationAuthenticationMethodDeauthenticateConnection
	      forSelector:@selector(deauthenticateConnection:withCompletionHandler:)
	      with:@selector(ocm_deauthenticateConnection:withCompletionHandler:)];
}

+ (void)ocm_detectAuthenticationMethodSupportForConnection:(OCConnection *)connection withServerResponses:(NSDictionary<NSURL *, OCConnectionRequest *> *)serverResponses options:(OCAuthenticationMethodDetectionOptions)options completionHandler:(void(^)(OCAuthenticationMethodIdentifier identifier, BOOL supported))completionHandler
{
	OCMockAuthenticationMethodDetectAuthenticationMethodSupportForConnectionBlock mockBlock;

	if ((mockBlock = [[OCMockManager sharedMockManager] mockingBlockForLocation:OCMockLocationAuthenticationMethodDetectAuthenticationMethodSupportForConnection]) != nil)
	{
		mockBlock(connection, serverResponses, options, completionHandler);
	}
	else
	{
		[self ocm_detectAuthenticationMethodSupportForConnection:connection withServerResponses:serverResponses options:options completionHandler:completionHandler];
	}
}

- (void)ocm_generateBookmarkAuthenticationDataWithConnection:(OCConnection *)connection options:(OCAuthenticationMethodBookmarkAuthenticationDataGenerationOptions)options completionHandler:(void(^)(NSError *error, OCAuthenticationMethodIdentifier authenticationMethodIdentifier, NSData *authenticationData))completionHandler
{
	OCMockAuthenticationMethodGenerateBookmarkAuthenticiationDataWithConnectionBlock mockBlock;

	if ((mockBlock = [[OCMockManager sharedMockManager] mockingBlockForLocation:OCMockLocationAuthenticationMethodGenerateBookmarkAuthenticiationDataWithConnection]) != nil)
	{
		mockBlock(connection, options, completionHandler);
	}
	else
	{
		[self ocm_generateBookmarkAuthenticationDataWithConnection:connection options:options completionHandler:completionHandler];
	}
}

- (void)ocm_authenticateConnection:(OCConnection *)connection withCompletionHandler:(OCAuthenticationMethodAuthenticationCompletionHandler)completionHandler;
{
	OCMockAuthenticationMethodAuthenticateConnectionBlock mockBlock;

	if ((mockBlock = [[OCMockManager sharedMockManager] mockingBlockForLocation:OCMockLocationAuthenticationMethodAuthenticateConnection]) != nil)
	{
		mockBlock(connection, completionHandler);
	}
	else
	{
		[self ocm_authenticateConnection:connection withCompletionHandler:completionHandler];
	}
}

- (void)ocm_deauthenticateConnection:(OCConnection *)connection withCompletionHandler:(OCAuthenticationMethodAuthenticationCompletionHandler)completionHandler;
{
	OCMockAuthenticationMethodDeauthenticateConnectionBlock mockBlock;

	if ((mockBlock = [[OCMockManager sharedMockManager] mockingBlockForLocation:OCMockLocationAuthenticationMethodDeauthenticateConnection]) != nil)
	{
		mockBlock(connection, completionHandler);
	}
	else
	{
		[self ocm_deauthenticateConnection:connection withCompletionHandler:completionHandler];
	}
}

@end

OCMockLocation OCMockLocationAuthenticationMethodDetectAuthenticationMethodSupportForConnection = @"OCAuthenticationMethod.detectAuthenticationMethodSupportForConnection";
OCMockLocation OCMockLocationAuthenticationMethodGenerateBookmarkAuthenticiationDataWithConnection = @"OCAuthenticationMethod.generateBookmarkAuthenticationDataWithConnection";
OCMockLocation OCMockLocationAuthenticationMethodAuthenticateConnection = @"OCAuthenticationMethod.authenticateConnection";
OCMockLocation OCMockLocationAuthenticationMethodDeauthenticateConnection = @"OCAuthenticationMethod.deauthenticateConnection";
