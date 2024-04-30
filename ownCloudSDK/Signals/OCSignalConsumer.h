//
//  OCSignalConsumer.h
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
#import "OCSignal.h"
#import "OCTypes.h"
#import "OCAppIdentity.h"

NS_ASSUME_NONNULL_BEGIN

@class OCSignalConsumer;

typedef NSString* OCSignalConsumerUUID;
typedef void(^OCSignalHandler)(OCSignalConsumer *consumer, OCSignal *signal);

typedef NS_ENUM(NSUInteger, OCSignalDeliveryBehaviour) {
	OCSignalDeliveryBehaviourOnce, //!< Deliver the signal only once, then remove the consumer
	OCSignalDeliveryBehaviourUntilTerminated //!< Deliver the signal as often as it changes - until it indicates the consumers should be removed ("terminated")
};

@interface OCSignalConsumer : NSObject <NSSecureCoding>

@property(readonly) OCSignalConsumerUUID uuid;

@property(strong,nullable) OCSignalUUID signalUUID;

@property(assign) OCSignalDeliveryBehaviour deliveryBehaviour;
@property(assign) OCSignalRevision lastDeliveredSignalRevision;

@property(strong,nullable) OCCoreRunIdentifier runIdentifier;
@property(strong,nullable) OCAppComponentIdentifier componentIdentifier;;

@property(copy,nullable) OCSignalHandler signalHandler;

- (instancetype)initWithSignalUUID:(OCSignalUUID)signalUUID runIdentifier:(nullable OCCoreRunIdentifier)runIdentifier deliveryBehaviour:(OCSignalDeliveryBehaviour)deliveryBehaviour handler:(OCSignalHandler)handler;

@end

NS_ASSUME_NONNULL_END
