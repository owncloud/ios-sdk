//
//  OCSignalManager.h
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
#import "OCSignalConsumer.h"
#import "OCKeyValueStore.h"
#import "OCTypes.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCSignalManager : NSObject

@property(strong, nullable) OCKeyValueStore *keyValueStore;

- (instancetype)initWithKeyValueStore:(OCKeyValueStore *)keyValueStore;

#pragma mark - Consumer
- (void)addConsumer:(OCSignalConsumer *)consumer;

- (void)removeConsumer:(OCSignalConsumer *)consumer;
- (void)removeConsumerWithUUID:(OCSignalConsumerUUID)consumerUUID;
- (void)removeConsumersWithRunIdentifier:(OCCoreRunIdentifier)runIdentifier;
- (void)removeConsumersWithComponentIdentifier:(OCAppComponentIdentifier)componentIdentifier;
- (void)removeConsumersForSignalUUID:(OCSignalUUID)signalUUID;

#pragma mark - Signals
- (void)postSignal:(OCSignal *)signal;

- (void)setShouldDeliverSignals;
- (void)deliverSignals;

@end

extern OCKeyValueStoreKey OCKeyValueStoreKeySignals;

NS_ASSUME_NONNULL_END
