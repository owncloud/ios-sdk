//
//  OCBackgroundTask.h
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

@class OCBackgroundTask;

typedef void(^OCBackgroundTaskExpirationHandler)(OCBackgroundTask *task);

@interface OCBackgroundTask : NSObject

@property(assign) UIBackgroundTaskIdentifier identifier;
@property(readonly,strong) NSString *name;

@property(assign) BOOL started;

@property(readonly,copy) OCBackgroundTaskExpirationHandler expirationHandler;

+ (instancetype)backgroundTaskWithName:(nullable NSString *)name expirationHandler:(OCBackgroundTaskExpirationHandler)expirationHandler;

- (instancetype)initWithName:(nullable NSString *)name expirationHandler:(OCBackgroundTaskExpirationHandler)expirationHandler;

- (nullable instancetype)start;

- (void)end;
- (void)endWhenDeallocating:(id)object;

- (void)clearExpirationHandler;

@end

NS_ASSUME_NONNULL_END
