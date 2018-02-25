//
//  OCAuthenticationMethod.m
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

+ (Class)registeredAuthenticationMethodForIdentifier:(OCAuthenticationMethodIdentifier)identifier
{
	NSArray <Class> *classes = [self registeredAuthenticationMethodClasses];
	
	for (Class authenticationMethodClass in classes)
	{
		if ([[authenticationMethodClass identifier] isEqual:identifier])
		{
			return (authenticationMethodClass);
		}
	}
	
	return (Nil);
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

#pragma mark - Passphrase-based Authentication Only
+ (BOOL)usesUserName
{
	return ([self type] == OCAuthenticationMethodTypePassphrase);
}

+ (NSString *)userNameFromAuthenticationData:(NSData *)authenticationData
{
	// Implemented by subclasses
	return (nil);
}

- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_hostStatusChanged:) name:UIApplicationWillResignActiveNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_hostStatusChanged:) name:NSExtensionHostWillResignActiveNotification object:nil];
	}
	
	return(self);
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillResignActiveNotification object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSExtensionHostWillResignActiveNotification object:nil];
}

- (void)_hostStatusChanged:(NSNotification *)notification
{
	if ([notification.name isEqual:UIApplicationWillResignActiveNotification] ||
	    [notification.name isEqual:NSExtensionHostWillResignActiveNotification])
	{
		// Flush cached authentication secret when device is locked or the user switches to another app
		[self flushCachedAuthenticationSecret];
	}
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

#pragma mark - Authentication Secret Caching
- (id)cachedAuthenticationSecretForConnection:(OCConnection *)connection
{
	id cachedAuthenticationSecret = nil;
	
	@synchronized(self)
	{
		if (_cachedAuthenticationSecret == nil)
		{
			cachedAuthenticationSecret = [self loadCachedAuthenticationSecretForConnection:connection];
			
			// Only cache secret if the app is running in the foreground and receiving events
			dispatch_async(dispatch_get_main_queue(), ^{
				if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive)
				{
					@synchronized(self)
					{
						if (_cachedAuthenticationSecret == nil)
						{
							_cachedAuthenticationSecret = cachedAuthenticationSecret;
						}
					}
				}
			});
		}
		else
		{
			cachedAuthenticationSecret = _cachedAuthenticationSecret;
		}
	}
	
	return (cachedAuthenticationSecret);
}

- (id)loadCachedAuthenticationSecretForConnection:(OCConnection *)connection
{
	return (nil);
}

- (void)flushCachedAuthenticationSecret
{
	@synchronized(self)
	{
		_cachedAuthenticationSecret = nil;
	}
}

@end

OCAuthenticationMethodKey OCAuthenticationMethodUsernameKey = @"username";
OCAuthenticationMethodKey OCAuthenticationMethodPassphraseKey = @"passphrase";
OCAuthenticationMethodKey OCAuthenticationMethodPresentingViewControllerKey = @"presentingViewController";


