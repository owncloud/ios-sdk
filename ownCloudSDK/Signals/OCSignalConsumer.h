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

NS_ASSUME_NONNULL_BEGIN

@class OCSignalConsumer;

typedef NSString* OCSignalConsumerUUID;
typedef void(^OCSignalHandler)(OCSignalConsumer *consumer, OCSignal *signal);

@interface OCSignalConsumer : NSObject

@property(readonly) OCSignalConsumerUUID uuid;

@property(strong,nullable) OCSignalUUID signalUUID;

@property(strong,nullable) OCCoreRunIdentifier runIdentifier;
@property(strong,nullable) NSBundle *bundleIdentifier;

@property(copy,nullable) OCSignalHandler signalHandler;

@end

NS_ASSUME_NONNULL_END
