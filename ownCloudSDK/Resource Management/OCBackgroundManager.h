//
//  OCBackgroundManager.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 15.04.19.
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

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol OCBackgroundManagerDelegate <NSObject>

- (UIApplicationState)applicationState;

- (UIBackgroundTaskIdentifier)beginBackgroundTaskWithName:(nullable NSString *)taskName expirationHandler:(void(^ __nullable)(void))expirationHandler;
- (void)endBackgroundTask:(UIBackgroundTaskIdentifier)identifier;

@end

@class OCBackgroundTask;

@interface OCBackgroundManager : NSObject

@property(weak,nonatomic) id <OCBackgroundManagerDelegate> delegate; //!< Typically UIApplication.sharedApplication (not available in extensions)

#pragma mark - Shared instance
@property(class,readonly,nonatomic,strong) OCBackgroundManager *sharedBackgroundManager;

#pragma mark - State-based execution
@property(readonly) BOOL isBackgrounded;

- (void)scheduleBlock:(dispatch_block_t)block inBackground:(BOOL)inBackground; //!< Schedule a block for background or foreground execution. If the app is currently in that state, the block gets executed immediately. If the app is in a different state, the block is queued until the app returns to the desired state.

#pragma mark - Start and end background tasks
- (void)startTask:(OCBackgroundTask *)task;
- (void)endTask:(OCBackgroundTask *)task;

@end

NS_ASSUME_NONNULL_END
