//
//  OCLockManager.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 04.02.21.
//  Copyright © 2021 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2021, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import <Foundation/Foundation.h>
#import "OCLock.h"
#import "OCKeyValueStore.h"

NS_ASSUME_NONNULL_BEGIN

@class OCLockRequest;

@interface OCLockManager : NSObject

@property(class,nonatomic,readonly,strong) OCLockManager *sharedLockManager;

#pragma mark - Individual instances
- (instancetype)initWithKeyValueStore:(OCKeyValueStore *)keyValueStore;

#pragma mark - Locking
- (void)requestLock:(OCLockRequest *)lockRequest; //!< Requests a lock, allowing to coordinate changes across processes.
- (void)releaseLock:(OCLock *)lock; //!< Releases an acquired lock

@end

extern OCKeyValueStoreKey OCKeyValueStoreKeyManagedLocks;

NS_ASSUME_NONNULL_END
