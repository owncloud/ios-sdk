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

#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
#endif /* TARGET_OS_IOS */

#import "OCAuthenticationMethod.h"

NS_ASSUME_NONNULL_BEGIN

typedef void(^OCAuthenticationBrowserSessionCompletionHandler)(NSURL *_Nullable callbackURL, NSError *_Nullable error);

@interface OCAuthenticationBrowserSession : NSObject

@property(strong,readonly) NSURL *url;
@property(strong,readonly) NSString *scheme;
@property(nullable,strong,readonly) OCAuthenticationMethodBookmarkAuthenticationDataGenerationOptions options;

#if TARGET_OS_IOS
@property(nullable,strong,readonly,nonatomic) UIViewController *hostViewController; //!< Convenience accessor for options[OCAuthenticationMethodPresentingViewControllerKey]
#endif

@property(copy) OCAuthenticationBrowserSessionCompletionHandler completionHandler;

- (instancetype)initWithURL:(NSURL *)authorizationRequestURL callbackURLScheme:(NSString *)scheme options:(nullable OCAuthenticationMethodBookmarkAuthenticationDataGenerationOptions)options completionHandler:(OCAuthenticationBrowserSessionCompletionHandler)completionHandler;

- (BOOL)start;

- (void)completedWithCallbackURL:(nullable NSURL *)callbackURL error:(nullable NSError *)error;

@end

NS_ASSUME_NONNULL_END
