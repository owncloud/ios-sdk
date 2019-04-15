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

@interface OCBackgroundTask : NSObject

@property(readonly) UIBackgroundTaskIdentifier identifier;
@property(readonly,strong) NSString *name;

@property(assign) BOOL started;

@property(readonly,copy) dispatch_block_t expirationHandler;

- (instancetype)initWithName:(nullable NSString *)name expirationHandler:(dispatch_block_t)expirationHandler;

- (instancetype)start;

- (void)end;
- (void)endWhenDeallocating:(id)object;

@end

NS_ASSUME_NONNULL_END
