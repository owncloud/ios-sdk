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

@interface OCAuthenticationMethodOAuth2 : OCAuthenticationMethod <OCClassSettingsSupport>

+ (BOOL)startAuthenticationSession:(__autoreleasing id *)authenticationSession forURL:(NSURL *)authorizationRequestURL scheme:(NSString *)scheme completionHandler:(void(^)(NSURL *_Nullable callbackURL, NSError *_Nullable error))oauth2CompletionHandler; //!< Starts a system authentication session for the provided URL, scheme and completionHandler. Used by OCAuthenticationMethodOAuth2 as interface to SFAuthenticationSession and ASWebAuthenticationSession.

@end

extern OCAuthenticationMethodIdentifier OCAuthenticationMethodIdentifierOAuth2;

extern OCClassSettingsKey OCAuthenticationMethodOAuth2AuthorizationEndpoint;
extern OCClassSettingsKey OCAuthenticationMethodOAuth2TokenEndpoint;
extern OCClassSettingsKey OCAuthenticationMethodOAuth2RedirectURI;
extern OCClassSettingsKey OCAuthenticationMethodOAuth2ClientID;
extern OCClassSettingsKey OCAuthenticationMethodOAuth2ClientSecret;
