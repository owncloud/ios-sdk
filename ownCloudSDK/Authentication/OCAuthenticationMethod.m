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
#import "OCBookmark.h"
#import "OCConnectionRequest.h"
#import "NSError+OCError.h"

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

+ (NSString *)name
{
	return(nil);
}

- (NSString *)name
{
	return ([[self class] name]);
}

#pragma mark - Authentication Data Access
+ (BOOL)usesUserName
{
	return ([self type] == OCAuthenticationMethodTypePassphrase);
}

+ (NSString *)userNameFromAuthenticationData:(NSData *)authenticationData
{
	// Implemented by subclasses
	return (nil);
}

+ (NSString *)passPhraseFromAuthenticationData:(NSData *)authenticationData
{
	// Implemented by subclasses
	return (nil);
}

#pragma mark - Init & Dealloc
- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_hostStatusChanged:) name:UIApplicationWillResignActiveNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_hostStatusChanged:) name:NSExtensionHostWillResignActiveNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_bookmarkChanged:)   name:OCBookmarkAuthenticationDataChangedNotification object:nil];
	}
	
	return(self);
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:OCBookmarkAuthenticationDataChangedNotification object:nil];
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

- (void)_bookmarkChanged:(NSNotification *)notification
{
	// Flush cached authentication secret so it is re-read from the bookmark. Right now we flush all cached
	// secrets for every change of every bookmark. This could be optimized in the future, but given how rare
	// such an event occurs and that performance impact should be almost imperceptible, it's probably not worth
	// to put any time and effort into this.
	[self flushCachedAuthenticationSecret];
}

#pragma mark - Authentication Method Detection
+ (NSArray <NSURL *> *)detectionURLsForConnection:(OCConnection *)connection
{
	return(nil);
}

+ (void)detectAuthenticationMethodSupportForConnection:(OCConnection *)connection withServerResponses:(NSDictionary<NSURL *, OCConnectionRequest *> *)serverResponses options:(OCAuthenticationMethodDetectionOptions)options completionHandler:(void(^)(OCAuthenticationMethodIdentifier identifier, BOOL supported))completionHandler
{
	if (completionHandler!=nil)
	{
		completionHandler([self identifier], NO);
	}
}

#pragma mark - Authentication / Deauthentication ("Login / Logout")
- (void)authenticateConnection:(OCConnection *)connection withCompletionHandler:(OCAuthenticationMethodAuthenticationCompletionHandler)completionHandler
{
	// Implemented by subclasses
	if (completionHandler != nil)
	{
		completionHandler(nil,nil);
	}
}

- (void)deauthenticateConnection:(OCConnection *)connection withCompletionHandler:(OCAuthenticationMethodAuthenticationCompletionHandler)completionHandler
{
	// Implemented by subclasses
	if (completionHandler != nil)
	{
		completionHandler(nil,nil);
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
			
			if ([self respondsToSelector:@selector(cacheSecrets)])
			{
				dispatch_async(dispatch_get_main_queue(), ^{
					if (((id<OCAuthenticationMethodUIAppExtension>)self).cacheSecrets)
					{
						@synchronized(self)
						{
							if (self->_cachedAuthenticationSecret == nil)
							{
								self->_cachedAuthenticationSecret = cachedAuthenticationSecret;
							}
						}
					}
				});
			}
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

#pragma mark - Wait for authentication
- (BOOL)canSendAuthenticatedRequestsForConnection:(OCConnection *)connection withAvailabilityHandler:(OCConnectionAuthenticationAvailabilityHandler)availabilityHandler
{
	return (YES);
}

#pragma mark - Handle responses before they are delivered to the request senders
- (NSError *)handleResponse:(OCConnectionRequest *)request forConnection:(OCConnection *)connection withError:(NSError *)error
{
	// If a request returns with an UNAUTHORIZED status code, turn it into an actual error
	if (request.responseHTTPStatus.code == OCHTTPStatusCodeUNAUTHORIZED)
	{
		if (error == nil)
		{
			error = OCError(OCErrorAuthorizationFailed);
		}
	}

	return (error);
}

@end

OCAuthenticationMethodKey OCAuthenticationMethodUsernameKey = @"username";
OCAuthenticationMethodKey OCAuthenticationMethodPassphraseKey = @"passphrase";
OCAuthenticationMethodKey OCAuthenticationMethodPresentingViewControllerKey = @"presentingViewController";
OCAuthenticationMethodKey OCAuthenticationMethodAllowURLProtocolUpgradesKey = @"allowURLProtocolUpgrades";

NSString *OCAuthorizationMethodAlternativeServerURLKey = @"alternativeServerURL";
