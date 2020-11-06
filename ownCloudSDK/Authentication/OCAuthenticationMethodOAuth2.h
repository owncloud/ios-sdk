//
//  OCAuthenticationMethodOAuth2.h
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

#import "OCAuthenticationMethod.h"
#import "OCClassSettings.h"
#import "OCAuthenticationBrowserSession.h"
#import "OCPKCE.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCAuthenticationMethodOAuth2 : OCAuthenticationMethod <OCClassSettingsSupport>

@property(strong,nullable,class,nonatomic) Class browserSessionClass;

+ (BOOL)startAuthenticationSession:(__autoreleasing id _Nonnull * _Nullable)authenticationSession forURL:(NSURL *)authorizationRequestURL scheme:(NSString *)scheme options:(nullable OCAuthenticationMethodBookmarkAuthenticationDataGenerationOptions)options completionHandler:(void(^)(NSURL *_Nullable callbackURL, NSError *_Nullable error))oauth2CompletionHandler; //!< Starts a system authentication session for the provided URL, scheme and completionHandler. Used by OCAuthenticationMethodOAuth2 as interface to ASWebAuthenticationSession.

#pragma mark - PKCE support
@property(strong,nullable) OCPKCE *pkce; //!< pre-configured PKCE object to use for Proof Key for Code Exchange

#pragma mark - Subclassing points
- (nullable NSURL *)authorizationEndpointURLForConnection:(OCConnection *)connection;
- (nullable NSURL *)tokenEndpointURLForConnection:(OCConnection *)connection;
- (NSString *)redirectURIForConnection:(OCConnection *)connection;
- (NSDictionary<NSString *, NSString *> *)tokenRefreshParametersForRefreshToken:(NSString *)refreshToken;
- (void)retrieveEndpointInformationForConnection:(OCConnection *)connection completionHandler:(void(^)(NSError *error))completionHandler;
- (nullable NSString *)scope;
- (nullable NSString *)prompt;

@end

extern OCAuthenticationMethodIdentifier OCAuthenticationMethodIdentifierOAuth2;

extern OCClassSettingsKey OCAuthenticationMethodOAuth2AuthorizationEndpoint;
extern OCClassSettingsKey OCAuthenticationMethodOAuth2TokenEndpoint;
extern OCClassSettingsKey OCAuthenticationMethodOAuth2RedirectURI;
extern OCClassSettingsKey OCAuthenticationMethodOAuth2ClientID;
extern OCClassSettingsKey OCAuthenticationMethodOAuth2ClientSecret;
extern OCClassSettingsKey OCAuthenticationMethodOAuth2ExpirationOverrideSeconds;

NS_ASSUME_NONNULL_END
