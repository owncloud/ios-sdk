//
//  OCRateLimiter.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 07.03.19.
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

NS_ASSUME_NONNULL_BEGIN

@interface OCRateLimiter : NSObject

@property(assign) NSTimeInterval minimumTime; //!< The minimum amount of time that should pass before invoking the action again

- (instancetype)initWithMinimumTime:(NSTimeInterval)minimumTime;

- (void)runRateLimitedBlock:(dispatch_block_t)block;

@end

NS_ASSUME_NONNULL_END
