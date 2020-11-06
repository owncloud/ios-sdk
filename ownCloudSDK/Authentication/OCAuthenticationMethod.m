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
#import "OCHTTPRequest.h"
#import "OCHTTPResponse+DAVError.h"
#import "NSError+OCError.h"
#import "OCIPNotificationCenter.h"
#import "OCBookmark+IPNotificationNames.h"
#import "OCLogger.h"

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
	return ((id _Nonnull) nil); // Needs to be overridden by all subclasses. If one does not, let it crash.
}

+ (NSString *)name
{
	return((id _Nonnull) nil); // Needs to be overridden by all subclasses. If one does not, let it crash.
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
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_authenticationDataChangedLocally:) name:OCBookmarkAuthenticationDataChangedNotification object:nil];

		[[OCIPNotificationCenter sharedNotificationCenter] addObserver:self forName:OCBookmark.bookmarkAuthUpdateNotificationName withHandler:^(OCIPNotificationCenter * _Nonnull notificationCenter, OCAuthenticationMethod *authMethod, OCIPCNotificationName  _Nonnull notificationName) {
			[authMethod _authenticationDataChangedRemotely:YES];
		}];
	}

	return(self);
}

- (void)dealloc
{
	[[OCIPNotificationCenter sharedNotificationCenter] removeObserver:self forName:OCBookmark.bookmarkAuthUpdateNotificationName];

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
		OCLogDebug(@"Received %@ notification: flush auth secret", notification.name);
		[self flushCachedAuthenticationSecret];
	}
}

- (void)_authenticationDataChangedLocally:(NSNotification *)notification
{
	[self _authenticationDataChangedRemotely:NO];
}

- (void)_authenticationDataChangedRemotely:(BOOL)remotely
{
	// Flush cached authentication secret so it is re-read from the bookmark. Right now we flush all cached
	// secrets for every change of every bookmark. This could be optimized in the future, but given how rare
	// such an event occurs and that performance impact should be almost imperceptible, it's probably not worth
	// to put any time and effort into this.
	OCLogDebug(@"Received %@ notification to flush auth secret", (remotely ? @"remote" : @"local"));

	[self flushCachedAuthenticationSecret];
}

#pragma mark - Authentication Method Detection
+ (NSArray <NSURL *> *)detectionURLsForConnection:(OCConnection *)connection
{
	return(nil);
}

+ (void)detectAuthenticationMethodSupportForConnection:(OCConnection *)connection withServerResponses:(NSDictionary<NSURL *, OCHTTPRequest *> *)serverResponses options:(OCAuthenticationMethodDetectionOptions)options completionHandler:(void(^)(OCAuthenticationMethodIdentifier identifier, BOOL supported))completionHandler
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

- (OCHTTPRequest *)authorizeRequest:(OCHTTPRequest *)request forConnection:(OCConnection *)connection
{
	NSError *error = nil;
	NSDictionary<NSString *, NSString *> *authHeaders;

	if ((authHeaders = [self authorizationHeadersForConnection:connection error:&error]) != nil)
	{
		[request addHeaderFields:authHeaders];
	}

	return (request);
}

- (NSDictionary<NSString *, NSString *> *)authorizationHeadersForConnection:(OCConnection *)connection error:(NSError **)outError
{
	return (nil);
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

			_cachedAuthenticationSecret = cachedAuthenticationSecret;

			if ([self respondsToSelector:@selector(cacheSecrets)])
			{
				dispatch_async(dispatch_get_main_queue(), ^{
					if (!((id<OCAuthenticationMethodUIAppExtension>)self).cacheSecrets)
					{
						@synchronized(self)
						{
							self->_cachedAuthenticationSecret = nil;
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
		_authenticationDataKnownInvalidDate = nil;
	}
}

#pragma mark - Wait for authentication
- (BOOL)canSendAuthenticatedRequestsForConnection:(OCConnection *)connection withAvailabilityHandler:(OCConnectionAuthenticationAvailabilityHandler)availabilityHandler
{
	return (YES);
}

#pragma mark - Handle responses before they are delivered to the request senders
- (NSError *)handleRequest:(OCHTTPRequest *)request response:(OCHTTPResponse *)response forConnection:(OCConnection *)connection withError:(NSError *)error
{
	// If a request returns with an UNAUTHORIZED status code, turn it into an actual error
	if (response.status.code == OCHTTPStatusCodeUNAUTHORIZED)
	{
		if (error == nil)
		{
			NSError *davError;

			if ((davError = [response bodyParsedAsDAVError]) != nil)
			{
				error = OCErrorFromError(OCErrorAuthorizationFailed, davError);
			}
			else
			{
				error = OCError(OCErrorAuthorizationFailed);
			}

			OCErrorAddDateFromResponse(error, response);
		}
	}

	return (error);
}

#pragma mark - Class settings
+ (OCClassSettingsIdentifier)classSettingsIdentifier
{
	return (OCClassSettingsIdentifierAuthentication);
}

+ (NSDictionary<NSString *,id> *)defaultSettingsForIdentifier:(OCClassSettingsIdentifier)identifier
{
	return (@{
		OCAuthenticationMethodBrowserSessionClass	  	: @"operating-system",
		OCAuthenticationMethodBrowserSessionPrefersEphermal	: @(NO)
	});
}


#pragma mark - Log tagging
+ (NSArray<OCLogTagName> *)logTags
{
	return ([NSArray arrayWithObjects:@"AUTH", [[self.identifier componentsSeparatedByString:@"."].lastObject capitalizedString], nil]);
}

- (NSArray<OCLogTagName> *)logTags
{
	return ([[self class] logTags]);
}

@end

OCAuthenticationMethodKey OCAuthenticationMethodUsernameKey = @"username";
OCAuthenticationMethodKey OCAuthenticationMethodPassphraseKey = @"passphrase";
OCAuthenticationMethodKey OCAuthenticationMethodPresentingViewControllerKey = @"presentingViewController";
OCAuthenticationMethodKey OCAuthenticationMethodAllowURLProtocolUpgradesKey = @"allowURLProtocolUpgrades";

NSString *OCAuthorizationMethodAlternativeServerURLKey = @"alternativeServerURL";

OCClassSettingsIdentifier OCClassSettingsIdentifierAuthentication = @"authentication";
OCClassSettingsKey OCAuthenticationMethodBrowserSessionClass = @"browser-session-class";
OCClassSettingsKey OCAuthenticationMethodBrowserSessionPrefersEphermal = @"browser-session-prefers-ephermal";
