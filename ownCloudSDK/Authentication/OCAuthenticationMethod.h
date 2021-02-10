//
//  OCAuthenticationMethod.h
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

#import <Foundation/Foundation.h>
#import "OCTypes.h"
#import "OCLogTag.h"
#import "OCClassSettings.h"

@class OCConnection;
@class OCHTTPRequest;
@class OCHTTPResponse;
@class OCIssue;

typedef NSString* OCAuthenticationMethodIdentifier NS_TYPED_EXTENSIBLE_ENUM; //!< NSString identifier for an authentication method, f.ex. "owncloud.oauth2" for OAuth2
typedef NSString* OCAuthenticationMethodKey NS_TYPED_ENUM; //!< NSString key used in the options dictionary used to generate the authentication data for a bookmark.
typedef NSDictionary<OCAuthenticationMethodKey,id>* OCAuthenticationMethodBookmarkAuthenticationDataGenerationOptions; //!< Dictionary with options used to generate the authentication data for a bookmark. F.ex. passwords or the view controller to attach own UI to.
typedef NSDictionary<OCAuthenticationMethodKey,id>* OCAuthenticationMethodDetectionOptions; //!< Dictionary with options used to detect available authentication methods

NS_ASSUME_NONNULL_BEGIN

typedef void(^OCAuthenticationMethodAuthenticationCompletionHandler)(NSError * _Nullable error, OCIssue * _Nullable issue);

typedef NS_ENUM(NSUInteger, OCAuthenticationMethodType)
{
	OCAuthenticationMethodTypePassphrase,	//!< Authentication method is password based (=> UI should show username and password entry field)
	OCAuthenticationMethodTypeToken		//!< Authentication method is token based (=> UI should show no username and password entry field)
};

@interface OCAuthenticationMethod : NSObject <OCLogTagging, OCClassSettingsSupport>
{
	NSDate *_authenticationDataKnownInvalidDate;

	@private
	id _cachedAuthenticationSecret;
}

#pragma mark - Registration
+ (void)registerAuthenticationMethodClass:(Class)authenticationMethodClass; //!< Add an authentication method to the core
+ (void)unregisterAuthenticationMethodClass:(Class)authenticationMethodClass; //!< Add an authentication method to the core
+ (NSArray <Class> *)registeredAuthenticationMethodClasses; //!< Array of registered authentication method classes
+ (nullable Class)registeredAuthenticationMethodForIdentifier:(OCAuthenticationMethodIdentifier)identifier; //!< Returns the OCAuthenticationMethod class for identifier

#pragma mark - Identification
@property(readonly,assign,class,nonatomic) OCAuthenticationMethodType type;
@property(readonly,strong,class,nonatomic,nonnull) OCAuthenticationMethodIdentifier identifier;
@property(readonly,strong,class,nonatomic,nonnull) NSString *name;
@property(readonly,strong,nonatomic,nonnull) NSString *name;

#pragma mark - Authentication Data Access
@property(readonly,class,nonatomic) BOOL usesUserName; //!< This authentication method uses a user name (passphrase-based only)
+ (nullable NSString *)userNameFromAuthenticationData:(NSData *)authenticationData; //!< Returns the user name stored inside authenticationData
+ (nullable NSString *)passPhraseFromAuthenticationData:(NSData *)authenticationData; //!< Returns the passphrase stored inside authenticationData (passphrase-based only)

@property(readonly,nonatomic,nullable) NSDate *authenticationDataKnownInvalidDate; //!< The date the .authenticationData was last known to be invalid. Reset to nil when -flushCachedAuthenticationSecret is called.

#pragma mark - Authentication Method Detection
+ (nullable NSArray <OCHTTPRequest *> *)detectionRequestsForConnection:(OCConnection *)connection; //!< Provides a list of URLs whose content is needed to determine whether this authentication method is supported
+ (void)detectAuthenticationMethodSupportForConnection:(OCConnection *)connection withServerResponses:(NSDictionary<NSURL *, OCHTTPRequest *> *)serverResponses options:(OCAuthenticationMethodDetectionOptions)options completionHandler:(void(^)(OCAuthenticationMethodIdentifier identifier, BOOL supported))completionHandler; //!< Detects authentication method support using collected responses (for URL provided by -detectionRequestsForConnection:) and then returns result via the completionHandler.

#pragma mark - Authentication / Deauthentication ("Login / Logout")
- (void)authenticateConnection:(OCConnection *)connection withCompletionHandler:(OCAuthenticationMethodAuthenticationCompletionHandler)completionHandler; //!< Authenticates the connection.
- (void)deauthenticateConnection:(OCConnection *)connection withCompletionHandler:(OCAuthenticationMethodAuthenticationCompletionHandler)completionHandler; //!< Deauthenticates the connection.

- (OCHTTPRequest *)authorizeRequest:(OCHTTPRequest *)request forConnection:(OCConnection *)connection; //!< Applies all necessary modifications to a request so that it's authorized using this authentication method. This can be adding tokens, passwords, etc. to the headers. The request returned by this method is sent. The default implementation applies the headers returned by -authorizationHeadersForConnection:error:.

- (nullable NSDictionary<NSString *, NSString *> *)authorizationHeadersForConnection:(OCConnection *)connection error:(NSError **)outError; //!< For authentication methods based on HTTP headers, returns a dictionary of the authorization headers. nil and an error otherwise.

#pragma mark - Generate bookmark authentication data
- (void)generateBookmarkAuthenticationDataWithConnection:(OCConnection *)connection options:(OCAuthenticationMethodBookmarkAuthenticationDataGenerationOptions)options completionHandler:(void(^)(NSError * _Nullable error, OCAuthenticationMethodIdentifier  _Nullable authenticationMethodIdentifier, NSData * _Nullable authenticationData))completionHandler; //!< Generates the authenticationData for a connection's bookmark and returns the result via the completionHandler. It is not directly stored in the bookmark so that an app can decide on its own when to overwrite existing data - or save the result. The authentication method is obligated to return an error in the completionHandler if authentication is not possible (f.ex. rejected token request, wrong username/passphrase).

#pragma mark - Authentication Secret Caching
- (nullable id)cachedAuthenticationSecretForConnection:(OCConnection *)connection; //!< Method that allows an authentication method to cache a secret in memory. If none is present in memory, -loadCachedAuthenticationSecretForConnection: is called.
- (nullable id)loadCachedAuthenticationSecretForConnection:(OCConnection *)connection; //!< Called by -cachedAuthenticationSecretForConnection: if no authentication secret is stored in memory. Should retrieve and return the authentication secret for the connection.
- (void)flushCachedAuthenticationSecret; //!< Flushes the cached authentication secret. Called f.ex. if the device is locked or the user switches to another app.

#pragma mark - Wait for authentication
- (BOOL)canSendAuthenticatedRequestsForConnection:(OCConnection *)connection withAvailabilityHandler:(OCConnectionAuthenticationAvailabilityHandler)availabilityHandler; //!< This method is called by the -[OCConnection canSendAuthenticatedRequestsForQueue:availabilityHandler:] to determine if the authentication method is currently in the position to authenticate requests for the given connection. If it is, YES should be returned and the availabilityHandler shouldn't be used. If it is not (if, f.ex. a token has expired and needs to be renewed first), this method should return NO, attempt the necessary changes (if this involves scheduling requests, make sure these don't have OCConnectionSignalIDAuthenticationAvailable in their requiredSignals) and then call the availabilityHandler with the outcome. If an error is returned, all queued requests fail with the provided error.

#pragma mark - Handle responses before they are delivered to the request senders
- (nullable NSError *)handleRequest:(OCHTTPRequest *)request response:(OCHTTPResponse *)response forConnection:(OCConnection *)connection withError:(NSError *)error; //!< This method is called for every finished request before the response gets delivered to the sender. Gives the authentication method a chance to get knowledge of and react to error infos contained in response

@end

@protocol OCAuthenticationMethodUIAppExtension

- (BOOL)cacheSecrets; //!< Determines if -cachedAuthenticationSecretForConnection: actually caches the authentication secret. If not implemented in OCAuthenticationMethod, the default is NO.

@end

extern OCAuthenticationMethodKey OCAuthenticationMethodUsernameKey; //!< For passphrase-based authentication methods: the user name (value type: NSString*)
extern OCAuthenticationMethodKey OCAuthenticationMethodPassphraseKey; //!< For passphrase-based authentication methods: the passphrase (value type: NSString*)
extern OCAuthenticationMethodKey OCAuthenticationMethodPresentingViewControllerKey; //!< The UIViewController to use when presenting a view controller (for f.ex. token-based authentication mechanisms like OAuth2) (value type: UIViewController*)
extern OCAuthenticationMethodKey OCAuthenticationMethodAllowURLProtocolUpgradesKey; //!< Allow OCConnection to modify the OCBookmark with an upgraded URL, where an upgrade means that the hostname and base path must be identical and the protocol may only change from http to https. Any other change will be rejected and produce an OCErrorAuthorizationRedirect with userInfo[OCAuthorizationMethodAlternativeServerURLKey] for user approval (=> if the user approves, the app would update the URL in the bookmark accordingly and start authentication anew). This key is currently supported for
extern OCAuthenticationMethodKey OCAuthenticationMethodRequiredUsernameKey; //!< For token-based authentication methods: only generate bookmark data tokens if they allow logging in as the provided username / user ID. Return an OCErrorAuthorizationNotMatchingRequiredUserID error otherwise.

extern NSString *OCAuthorizationMethodAlternativeServerURLKey; //!< Key for alternative server URL in -[NSError userInfo].
extern NSString *OCAuthorizationMethodAlternativeServerURLOriginURLKey; //!< Key for the URL from where the alternative server URL was requested.

extern OCClassSettingsIdentifier OCClassSettingsIdentifierAuthentication;
extern OCClassSettingsKey OCAuthenticationMethodBrowserSessionClass;
extern OCClassSettingsKey OCAuthenticationMethodBrowserSessionPrefersEphermal;

NS_ASSUME_NONNULL_END

#define OCAuthenticationMethodAutoRegisterLoadCommand	[OCAuthenticationMethod registerAuthenticationMethodClass:self];

#define OCAuthenticationMethodAutoRegister +(void)load{ \
						OCAuthenticationMethodAutoRegisterLoadCommand \
				       	   }
