//
//  OCAuthenticationBrowserSession.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 02.12.19.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2019, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import <UIKit/UIKit.h>
#import "OCAuthenticationMethod.h"
#import "OCClassSettings.h"

NS_ASSUME_NONNULL_BEGIN

typedef void(^OCAuthenticationBrowserSessionCompletionHandler)(NSURL *_Nullable callbackURL, NSError *_Nullable error);

@interface OCAuthenticationBrowserSession : NSObject <OCClassSettingsSupport>

@property(strong,readonly) NSURL *url;
@property(strong,readonly) NSString *scheme;
@property(nullable,strong,readonly) OCAuthenticationMethodBookmarkAuthenticationDataGenerationOptions options;
@property(nullable,strong,readonly,nonatomic) UIViewController *hostViewController; //!< Convenience accessor for options[OCAuthenticationMethodPresentingViewControllerKey]
@property(copy) OCAuthenticationBrowserSessionCompletionHandler completionHandler;

- (instancetype)initWithURL:(NSURL *)authorizationRequestURL callbackURLScheme:(NSString *)scheme options:(nullable OCAuthenticationMethodBookmarkAuthenticationDataGenerationOptions)options completionHandler:(OCAuthenticationBrowserSessionCompletionHandler)completionHandler;

- (BOOL)start;

- (void)completedWithCallbackURL:(nullable NSURL *)callbackURL error:(nullable NSError *)error;

@end

extern OCClassSettingsIdentifier OCClassSettingsIdentifierBrowserSession;

NS_ASSUME_NONNULL_END
