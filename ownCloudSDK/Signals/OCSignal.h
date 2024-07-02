//
//  OCSignal.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 27.09.20.
//  Copyright © 2020 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2020, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import <Foundation/Foundation.h>
#import "OCTypes.h"

typedef NSString* OCSignalUUID;
typedef NSInteger OCSignalRevision;

#define OCSignalRevisionInitial 0
#define OCSignalRevisionNone -1

NS_ASSUME_NONNULL_BEGIN

@interface OCSignal : NSObject <NSSecureCoding>

+ (OCSignalUUID)generateUUID; //!< Generates a signal UUID 

@property(readonly,strong) OCSignalUUID uuid;
@property(readonly,nullable,strong) OCCodableDict payload;

@property(assign) OCSignalRevision revision; //!< The revision of the signal. Increments with every update of the signal.
@property(assign) BOOL terminatesConsumersAfterDelivery; //!< Indicating if this signal should "terminate" (remove) the consumers after the signal has been delivered, f.ex. for one-time calls. Defaults to YES. For status updates, this should be set to NO until the final status is reached (f.ex. progress reaching 100%).

- (instancetype)initWithUUID:(OCSignalUUID)uuid payload:(nullable OCCodableDict)payload;

@end

NS_ASSUME_NONNULL_END
