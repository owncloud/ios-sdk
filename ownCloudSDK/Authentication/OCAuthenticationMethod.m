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

@synthesize cachedAuthenticationDataID = _cachedAuthenticationDataID;

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
+ (NSArray <OCHTTPRequest *> *)detectionRequestsForConnection:(OCConnection *)connection
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
		request.authenticationDataID = self.cachedAuthenticationDataID;
		[request addHeaderFields:authHeaders];
	}

	return (request);
}

- (NSDictionary<NSString *, NSString *> *)authorizationHeadersForConnection:(OCConnection *)connection error:(NSError **)outError
{
	return (nil);
}

#pragma mark - Authentication Data ID computation
+ (nullable OCAuthenticationDataID)authenticationDataIDForAuthenticationData:(nullable NSData *)authenticationData
{
	OCAuthenticationDataID identifier = nil;

	if (authenticationData != nil)
	{
		identifier = [[[authenticationData sha256Hash] sha1Hash] asHexStringWithSeparator:nil];
	}

	return (identifier);
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
		_cachedAuthenticationDataID = nil;
		[self willChangeValueForKey:@"authenticationDataKnownInvalidDate"];
		_authenticationDataKnownInvalidDate = nil;
		[self didChangeValueForKey:@"authenticationDataKnownInvalidDate"];
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
INCLUDE_IN_CLASS_SETTINGS_SNAPSHOTS(OCAuthenticationMethod)

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

+ (OCClassSettingsMetadataCollection)classSettingsMetadata
{
	return (@{
		// Authentication
		OCAuthenticationMethodBrowserSessionClass : @{
			OCClassSettingsMetadataKeyType 		: OCClassSettingsMetadataTypeString,
			OCClassSettingsMetadataKeyDescription 	: @"Alternative browser session class to use instead of `ASWebAuthenticationSession`. Please also see Compile Time Configuration if you want to use this.",
			OCClassSettingsMetadataKeyStatus	: OCClassSettingsKeyStatusSupported,
			OCClassSettingsMetadataKeyPossibleValues : @{
				@"operating-system" : @"Use ASWebAuthenticationSession for browser sessions.",
				@"UIWebView" : @"Use UIWebView for browser sessions. Requires compilation with `OC_FEATURE_AVAILABLE_UIWEBVIEW_BROWSER_SESSION=1` preprocessor flag.",
				@"CustomScheme" : @"Replace http and https with custom schemes to delegate browser sessions to a different app.",
				@"MIBrowser" : @"Replace `http` with `mibrowser` and `https` with `mibrowsers` to delegate browser sessions to the MobileIron browser.",
				@"AWBrowser" : @"Replace `http` with `awb` and `https` with `awbs` to delegate browser sessions to the AirWatch browser."
			},
			OCClassSettingsMetadataKeyCategory	: @"Authentication"
		},

		OCAuthenticationMethodBrowserSessionPrefersEphermal : @{
			OCClassSettingsMetadataKeyType 		: OCClassSettingsMetadataTypeBoolean,
			OCClassSettingsMetadataKeyDescription 	: @"Indicates whether the app should ask iOS for a private authentication (web) session for OAuth2 or OpenID Connect. Private authentication sessions do not share cookies and other browsing data with the user's normal browser. Apple only promises that [this setting](https://developer.apple.com/documentation/authenticationservices/aswebauthenticationsession/3237231-prefersephemeralwebbrowsersessio) will be honored if the user has set Safari as default browser.",
			OCClassSettingsMetadataKeyStatus	: OCClassSettingsKeyStatusSupported,
			OCClassSettingsMetadataKeyCategory	: @"Authentication"
		}
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
OCAuthenticationMethodKey OCAuthenticationMethodRequiredUsernameKey = @"requiredUsername";

NSString *OCAuthorizationMethodAlternativeServerURLKey = @"alternativeServerURL";
NSString *OCAuthorizationMethodAlternativeServerURLOriginURLKey = @"alternativeServerURLOriginURL";

OCClassSettingsIdentifier OCClassSettingsIdentifierAuthentication = @"authentication";
OCClassSettingsKey OCAuthenticationMethodBrowserSessionClass = @"browser-session-class";
OCClassSettingsKey OCAuthenticationMethodBrowserSessionPrefersEphermal = @"browser-session-prefers-ephermal";
