//
//  OCAuthenticationMethodOAuth2+OCMocking.h
//  ownCloudMocking
//
//  Created by Felix Schwarz on 17.12.18.
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

#import <ownCloudSDK/ownCloudSDK.h>
#import "OCMockManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCAuthenticationMethodOAuth2 (OCMocking)

// Counterparts of mockable methods
+ (BOOL)ocm_oa2_startAuthenticationSession:(__autoreleasing id _Nonnull * _Nullable)authenticationSession forURL:(NSURL *)authorizationRequestURL scheme:(NSString *)scheme options:(nullable OCAuthenticationMethodBookmarkAuthenticationDataGenerationOptions)options completionHandler:(void(^)(NSURL *_Nullable callbackURL, NSError *_Nullable error))oauth2CompletionHandler;

@end

// Block and mock location for every mockable method
typedef BOOL(^OCMockAuthenticationMethodOAuth2StartAuthenticationSessionForURLSchemeCompletionHandlerBlock)(__autoreleasing id _Nonnull * _Nullable authenticationSession, NSURL *authorizationRequestURL, NSString *scheme, OCAuthenticationMethodBookmarkAuthenticationDataGenerationOptions _Nullable options, void(^completionHandler)(NSURL *_Nullable callbackURL, NSError *_Nullable error));
extern OCMockLocation OCMockLocationAuthenticationMethodOAuth2StartAuthenticationSessionForURLSchemeCompletionHandler;

NS_ASSUME_NONNULL_END
