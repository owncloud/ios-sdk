//
//  OCAuthenticationMethod.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 05.02.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import "OCAuthenticationMethod.h"

@implementation OCAuthenticationMethod

#pragma mark - Registration
+ (NSMutableSet <Class> *)_registeredAuthenticationMethodClasses
{
	static dispatch_once_t onceToken;
	static NSMutableSet <Class> *registeredAuthenticationMethodClasses;
	
	dispatch_once(&onceToken, ^{
		registeredAuthenticationMethodClasses = [NSMutableSet new];
	});
	
	return (registeredAuthenticationMethodClasses);
}

+ (void)registerAuthenticationMethodClass:(Class)authenticationMethodClass
{
	if (authenticationMethodClass != Nil)
	{
		[[self _registeredAuthenticationMethodClasses] addObject:authenticationMethodClass];
	}
}

+ (void)unregisterAuthenticationMethodClass:(Class)authenticationMethodClass
{
	if (authenticationMethodClass != Nil)
	{
		[[self _registeredAuthenticationMethodClasses] removeObject:authenticationMethodClass];
	}
}

+ (NSArray <Class> *)registeredAuthenticationMethodClasses
{
	return ([[self _registeredAuthenticationMethodClasses] allObjects]);
}

#pragma mark - Identification
+ (OCAuthenticationMethodType)type
{
	return (OCAuthenticationMethodTypePassphrase);
}

+ (OCAuthenticationMethodIdentifier)identifier
{
	return (nil);
}

#pragma mark - Authentication / Deauthentication ("Login / Logout")
- (void)authenticateConnection:(OCConnection *)connection withCompletionHandler:(OCAuthenticationMethodAuthenticationCompletionHandler)completionHandler
{
	// Implemented by subclasses
	if (completionHandler != nil)
	{
		completionHandler(nil);
	}
}

- (void)deauthenticateConnection:(OCConnection *)connection withCompletionHandler:(OCAuthenticationMethodAuthenticationCompletionHandler)completionHandler
{
	// Implemented by subclasses
	if (completionHandler != nil)
	{
		completionHandler(nil);
	}
}

- (OCConnectionRequest *)authorizeRequest:(OCConnectionRequest *)request forConnection:(OCConnection *)connection
{
	return (request);
}

#pragma mark - Generate bookmark authentication data
- (void)generateBookmarkAuthenticationDataWithConnection:(OCConnection *)connection options:(OCAuthenticationMethodBookmarkAuthenticationDataGenerationOptions)options completionHandler:(void(^)(NSError *error, OCAuthenticationMethodIdentifier authenticationMethodIdentifier, NSData *authenticationData))completionHandler
{
	// Implemented by subclasses
	if (completionHandler != nil)
	{
		completionHandler(nil, [[self class] identifier], nil);
	}
}

@end

OCAuthenticationMethodKey OCAuthenticationMethodPassphraseKey = @"passphrase";
OCAuthenticationMethodKey OCAuthenticationMethodPresentingViewControllerKey = @"presentingViewController";


