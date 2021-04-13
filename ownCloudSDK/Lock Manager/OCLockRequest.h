//
//  OCLockRequest.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 06.02.21.
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

NS_ASSUME_NONNULL_BEGIN

@class OCLockRequest;

typedef void(^OCLockAcquiredHandler)(NSError * _Nullable error, OCLock * _Nullable lock);
typedef BOOL(^OCLockNeededHandler)(OCLockRequest *request);

@interface OCLockRequest : NSObject

@property(strong) OCLockResourceIdentifier resourceIdentifier;

@property(copy,nullable) OCLockNeededHandler lockNeededHandler; //!< Called before taking the opportunity to acquire the lock, to determine if the lock is actually still required.
@property(copy,nullable) OCLockAcquiredHandler acquiredHandler; //!< Called when the lock has been acquired.

@property(strong,nullable) OCLock *lock;

@property(assign) BOOL invalidated;

- (instancetype)initWithResourceIdentifier:(OCLockResourceIdentifier)resourceIdentifier acquiredHandler:(OCLockAcquiredHandler)acquiredHandler;

- (void)invalidate;

@end

NS_ASSUME_NONNULL_END
