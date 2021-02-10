//
//  OCLock.h
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

typedef NSString* OCLockResourceIdentifier;
typedef NSString* OCLockIdentifier;

@class OCLockManager;

NS_ASSUME_NONNULL_BEGIN

@interface OCLock : NSObject <NSSecureCoding>

@property(weak,nullable) OCLockManager *manager;

@property(readonly,strong,nonatomic) OCLockIdentifier identifier;
@property(readonly,strong,nonatomic) OCLockResourceIdentifier resourceIdentifier;

@property(strong,nullable) NSDate *expirationDate;
@property(copy,nullable) dispatch_block_t expirationHandler;

@property(readonly,nonatomic) BOOL isValid;

- (instancetype)initWithIdentifier:(OCLockResourceIdentifier)resourceIdentifier;
- (void)releaseLock;

#pragma mark - Internal API
- (BOOL)keepAlive:(BOOL)force; //!< Private API, has no effect outside OCLockManager

@end

extern const NSTimeInterval OCLockExpirationInterval;

NS_ASSUME_NONNULL_END
