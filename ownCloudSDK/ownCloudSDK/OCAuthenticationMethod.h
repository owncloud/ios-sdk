//
//  OCAuthenticationMethod.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 05.02.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

@class OCConnection;
@class OCConnectionRequest;

typedef NSString* OCAuthenticationMethodIdentifier; //!< NSString identifier for an authentication method, f.ex. "owncloud.oauth2" for OAuth2
typedef NSString* OCAuthenticationMethodKey NS_TYPED_ENUM; //!< NSString key used in the options dictionary used to generate the authentication data for a bookmark.
typedef NSDictionary<OCAuthenticationMethodKey,id>* OCAuthenticationMethodBookmarkAuthenticationDataGenerationOptions; //!< Dictionary with options used to generate the authentication data for a bookmark. F.ex. passwords or the view controller to

typedef void(^OCAuthenticationMethodAuthenticationCompletionHandler)(NSError *error);

typedef NS_ENUM(NSUInteger, OCAuthenticationMethodType)
{
	OCAuthenticationMethodTypePassphrase,	//!< Authentication method is password based (=> UI should show password entry field)
	OCAuthenticationMethodTypeToken		//!< Authentication method is token based (=> UI should show no password entry field)
};

@interface OCAuthenticationMethod : NSObject

#pragma mark - Registration
+ (void)registerAuthenticationMethodClass:(Class)authenticationMethodClass; //!< Add an authentication method to the core
+ (void)unregisterAuthenticationMethodClass:(Class)authenticationMethodClass; //!< Add an authentication method to the core
+ (NSArray <Class> *)registeredAuthenticationMethodClasses; //!< Array of registered authentication method classes

#pragma mark - Identification
+ (OCAuthenticationMethodIdentifier)identifier;

#pragma mark - Authentication / Deauthentication ("Login / Logout")
- (void)authenticateConnection:(OCConnection *)connection withCompletionHandler:(OCAuthenticationMethodAuthenticationCompletionHandler)completionHandler; //!< Authenticates the connection.
- (void)deauthenticateConnection:(OCConnection *)connection withCompletionHandler:(OCAuthenticationMethodAuthenticationCompletionHandler)completionHandler; //!< Deauthenticates the connection.

- (OCConnectionRequest *)authorizeRequest:(OCConnectionRequest *)request forConnection:(OCConnection *)connection; //!< Applies all necessary modifications to a request so that it authorized against using this authentication method. This can be adding tokens, passwords, etc. to the headers. The request returned by this method is sent.

#pragma mark - Generate bookmark authentication data
- (void)generateBookmarkAuthenticationDataWithConnection:(OCConnection *)connection options:(OCAuthenticationMethodBookmarkAuthenticationDataGenerationOptions)options completionHandler:(void(^)(NSError *error, OCAuthenticationMethodIdentifier authenticationMethodIdentifier, NSData *authenticationData))completionHandler; //!< Generates the authenticationData for a connection's bookmark and returns the result via the completionHandler. It is not directly stored in the bookmark so that an app can decide on its own when to overwrite existing data - or save the result.

@end

extern OCAuthenticationMethodKey OCAuthenticationMethodPassphraseKey; //!< For passphrase-based authentication methods: the passphrase (value type: NSString*)
extern OCAuthenticationMethodKey OCAuthenticationMethodPresentingViewControllerKey; //!< The UIViewController to use when presenting a view controller (for f.ex. token-based authentication mechanisms like OAuth2) (value type: UIViewController*)

#import "OCConnection.h"
#import "OCConnectionRequest.h"
