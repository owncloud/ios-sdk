//
//  OCSignalManager.m
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

#import "OCSignalManager.h"
#import "OCSignalRecord.h"

typedef NSMutableDictionary<OCSignalUUID,OCSignalRecord*>* OCSignalManagerStorage;

@interface OCSignalManager ()
{
	NSMutableDictionary<OCSignalConsumerUUID, OCSignalHandler> *_handlersByConsumerUUID;
}
@end

@implementation OCSignalManager

- (instancetype)initWithKeyValueStore:(OCKeyValueStore *)keyValueStore
{
	if ((self = [super init]) != nil)
	{
		_handlersByConsumerUUID = [NSMutableDictionary new];

		_keyValueStore = keyValueStore;

		[_keyValueStore addObserver:^(OCKeyValueStore * _Nonnull store, id  _Nullable owner, OCKeyValueStoreKey  _Nonnull key, id  _Nullable newValue) {
			[(OCSignalManager *)owner setShouldDeliverSignals];
		} forKey:OCKeyValueStoreKeySignals withOwner:self initial:YES];
	}

	return (self);
}

- (void)_modifyStorage:(BOOL(^)(OCSignalManagerStorage storage))modifier
{
	[self.keyValueStore updateObjectForKey:OCKeyValueStoreKeySignals usingModifier:^id _Nullable(id  _Nullable existingObject, BOOL * _Nonnull outDidModify) {
		if (existingObject == nil)
		{
			existingObject = [NSMutableDictionary new];
		}

		*outDidModify = modifier((OCSignalManagerStorage)existingObject);

		return (existingObject);
	}];
}

#pragma mark - Consumer
- (void)addConsumer:(OCSignalConsumer *)consumer
{
	OCSignalUUID signalUUID = consumer.signalUUID;

	if (signalUUID == nil) { return; }

	[self _modifyStorage:^BOOL(OCSignalManagerStorage storage) {
		if (storage[signalUUID] == nil)
		{
			storage[signalUUID] = [[OCSignalRecord alloc] initWithSignalUUID:signalUUID];
		}

		[storage[signalUUID] addConsumer:consumer];

		return (YES);
	}];
}

- (void)removeConsumer:(OCSignalConsumer *)consumer
{
	OCSignalUUID signalUUID = consumer.signalUUID;

	if (signalUUID == nil) { return; }

	[self _modifyStorage:^BOOL(OCSignalManagerStorage storage) {
		if (storage[signalUUID] != nil)
		{
			OCSignalConsumer *consumerToRemove = nil;

			for (OCSignalConsumer *storedConsumer in storage[signalUUID].consumers)
			{
				if ([storedConsumer.uuid isEqual:consumer.uuid])
				{
					consumerToRemove = storedConsumer;
					break;
				}
			}

			if (consumerToRemove != nil)
			{
				[storage[signalUUID] removeConsumer:consumerToRemove];
				return (YES);
			}
		}

		return (NO);
	}];
}

- (void)_removeConsumerMatching:(BOOL(^)(OCSignalConsumer *storedConsumer))matcher onlyFirstMatch:(BOOL)onlyFirstMatch
{
	if (matcher == nil) { return; }

	[self _modifyStorage:^BOOL(OCSignalManagerStorage storage) {
		__block BOOL didChange = NO;

		[storage enumerateKeysAndObjectsUsingBlock:^(OCSignalUUID  _Nonnull signalUUID, OCSignalRecord * _Nonnull record, BOOL * _Nonnull stop) {
			if ([record removeConsumersMatching:matcher onlyFirstMatch:onlyFirstMatch])
			{
				didChange = YES;

				if (onlyFirstMatch)
				{
					*stop = YES;
				}
			}
		}];

		return (didChange);
	}];
}

- (void)removeConsumerWithUUID:(OCSignalConsumerUUID)consumerUUID
{
	if (consumerUUID == nil) { return; }

	[self _removeConsumerMatching:^BOOL(OCSignalConsumer *storedConsumer) {
		return ([storedConsumer.uuid isEqual:consumerUUID]);
	} onlyFirstMatch:YES];
}

- (void)removeConsumersWithRunIdentifier:(OCCoreRunIdentifier)runIdentifier
{
	if (runIdentifier == nil) { return; }

	[self _removeConsumerMatching:^BOOL(OCSignalConsumer *storedConsumer) {
		return ([storedConsumer.runIdentifier isEqual:runIdentifier]);
	} onlyFirstMatch:NO];
}

- (void)removeConsumersWithComponentIdentifier:(OCAppComponentIdentifier)componentIdentifier
{
	if (componentIdentifier == nil) { return; }

	[self _removeConsumerMatching:^BOOL(OCSignalConsumer *storedConsumer) {
		return ([storedConsumer.componentIdentifier isEqual:componentIdentifier]);
	} onlyFirstMatch:NO];
}

- (void)removeConsumersForSignalUUID:(OCSignalUUID)signalUUID
{
	if (signalUUID == nil) { return; }

	[self _modifyStorage:^BOOL(OCSignalManagerStorage storage) {
		if (storage[signalUUID] != nil)
		{
			storage[signalUUID] = nil;

			return (YES);
		}

		return (NO);
	}];
}

#pragma mark - Signals
- (void)postSignal:(OCSignal *)signal
{
	OCSignalUUID signalUUID = signal.uuid;
	NSMutableArray<OCSignalConsumer *> *matchingConsumers = nil;

	if (signalUUID == nil) { return; }

	[self _modifyStorage:^BOOL(OCSignalManagerStorage storage) {
		OCSignalRecord *signalRecord;
		BOOL madeChanges = NO;

		if ((signalRecord = storage[signalUUID]) != nil)
		{
			OCAppComponentIdentifier localComponentIdentifier = OCAppIdentity.sharedAppIdentity.componentIdentifier;

			signalRecord.signal = signal;

			madeChanges = [signalRecord removeConsumersMatching:^BOOL(OCSignalConsumer * _Nonnull storedConsumer) {
				if ([storedConsumer.componentIdentifier isEqual:localComponentIdentifier])
				{
					OCSignalConsumerUUID consumerUUID;

					if ((consumerUUID = storedConsumer.uuid) != nil)
					{
						OCSignalHandler signalHandler;

						if ((signalHandler = self->_handlersByConsumerUUID[consumerUUID]) != nil)
						{
							if (matchingConsumers == nil)
							{
								matchingConsumers = [NSMutableArray new];
							}

							storedConsumer.signalHandler = signalHandler;

							[matchingConsumers addObject:storedConsumer];

							self->_handlersByConsumerUUID[consumerUUID] = nil;
						}
					}

					return (YES);
				}
			} onlyFirstMatch:NO];

			if (madeChanges)
			{
				if (signalRecord.consumers.count == 0)
				{
					storage[signalUUID] = nil;
				}
			}
		}

		return (madeChanges);
	}];

	for (OCSignalConsumer *consumer in matchingConsumers)
	{
		if (consumer.signalHandler != nil)
		{
			consumer.signalHandler(consumer, 0, signal);
		}
	}
}

- (void)setShouldDeliverSignals
{
}

- (void)deliverSignals
{
}

@end

OCKeyValueStoreKey OCKeyValueStoreKeySignals = @"signals";
