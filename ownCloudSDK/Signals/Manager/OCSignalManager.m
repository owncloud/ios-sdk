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
#import "OCEvent.h"

typedef NSMutableDictionary<OCSignalUUID,OCSignalRecord*>* OCSignalManagerStorage;

@interface OCSignalManager ()
{
	NSMutableDictionary<OCSignalConsumerUUID, OCSignalHandler> *_handlersByConsumerUUID;
	BOOL _needsSignalDelivery;
}
@end

@implementation OCSignalManager

- (instancetype)initWithKeyValueStore:(OCKeyValueStore *)keyValueStore deliveryQueue:(nullable dispatch_queue_t)deliveryQueue
{
	if ((self = [super init]) != nil)
	{
		_keyValueStore = keyValueStore;
		_deliveryQueue = (deliveryQueue != nil) ? deliveryQueue : dispatch_get_main_queue();

		_handlersByConsumerUUID = [NSMutableDictionary new];

		[_keyValueStore registerClasses:OCEvent.safeClasses forKey:OCKeyValueStoreKeySignals];
		[_keyValueStore addObserver:^(OCKeyValueStore * _Nonnull store, id  _Nullable owner, OCKeyValueStoreKey  _Nonnull key, id  _Nullable newValue) {
			[(OCSignalManager *)owner setNeedsSignalDelivery];
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
	__block BOOL signalForUUIDAlreadyExists = NO;

	if (signalUUID == nil) { return; }

	[self _addConsumerToCache:consumer];

	[self _modifyStorage:^BOOL(OCSignalManagerStorage storage) {
		if (storage[signalUUID] == nil)
		{
			storage[signalUUID] = [[OCSignalRecord alloc] initWithSignalUUID:signalUUID];
		}
		else
		{
			if (storage[signalUUID].signal != nil)
			{
				// There's already a signal for this UUID, so attempt a delivery
				// right after adding our consumer
				signalForUUIDAlreadyExists = YES;
			}
		}

		[storage[signalUUID] addConsumer:consumer];

		return (YES);
	}];

	if (signalForUUIDAlreadyExists)
	{
		// Run delivery for signal
		dispatch_async(_deliveryQueue, ^{
			[self _processRecordForSignal:signalUUID recordModifier:nil];
		});
	}
}

- (void)_addConsumerToCache:(OCSignalConsumer *)consumer
{
	OCSignalConsumerUUID consumerUUID = consumer.uuid;

	if (consumerUUID != nil)
	{
		@synchronized(_handlersByConsumerUUID)
		{
			_handlersByConsumerUUID[consumerUUID] = consumer.signalHandler;
		}
	}
}

- (void)removeConsumer:(OCSignalConsumer *)consumer
{
	OCSignalUUID signalUUID = consumer.signalUUID;

	if (signalUUID == nil) { return; }

	[self _removeConsumerFromCache:consumer];

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

				if (storage[signalUUID].consumers.count == 0)
				{
					storage[signalUUID] = nil;
				}

				return (YES);
			}
		}

		return (NO);
	}];
}

- (void)_removeConsumerFromCache:(OCSignalConsumer *)consumer
{
	OCSignalConsumerUUID consumerUUID = consumer.uuid;

	if (consumerUUID != nil)
	{
		@synchronized(_handlersByConsumerUUID)
		{
			_handlersByConsumerUUID[consumerUUID] = nil;
		}
	}
}

- (void)_removeConsumerMatching:(BOOL(^)(OCSignalConsumer *storedConsumer))matcher onlyFirstMatch:(BOOL)onlyFirstMatch
{
	if (matcher == nil) { return; }

	[self _modifyStorage:^BOOL(OCSignalManagerStorage storage) {
		__block BOOL didChange = NO;
		__block NSMutableArray<OCSignalUUID> *emptySignalUUIDs = nil;

		[storage enumerateKeysAndObjectsUsingBlock:^(OCSignalUUID  _Nonnull signalUUID, OCSignalRecord * _Nonnull record, BOOL * _Nonnull stop) {
			if ([record removeConsumersMatching:^BOOL(OCSignalConsumer * _Nonnull storedConsumer) {
				BOOL remove = matcher(storedConsumer);

				if (remove)
				{
					[self _removeConsumerFromCache:storedConsumer];
				}

				return (remove);
			} onlyFirstMatch:onlyFirstMatch]) {
				didChange = YES;

				if (record.consumers.count == 0)
				{
					if (emptySignalUUIDs == nil) { emptySignalUUIDs = [NSMutableArray new]; }

					[emptySignalUUIDs addObject:record.signalUUID];
				}

				if (onlyFirstMatch)
				{
					*stop = YES;
				}
			}
		}];

		if (emptySignalUUIDs != nil)
		{
			[storage removeObjectsForKeys:emptySignalUUIDs];
		}

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

- (void)removeConsumersWithRunIdentifier:(OCCoreRunIdentifier)runIdentifier otherThan:(BOOL)otherThan
{
	if (runIdentifier == nil) { return; }

	[self _removeConsumerMatching:^BOOL(OCSignalConsumer *storedConsumer) {
		BOOL hasRunIdentifier = [storedConsumer.runIdentifier isEqual:runIdentifier];

		if (otherThan)
		{
			hasRunIdentifier = !hasRunIdentifier;
		}

		return (hasRunIdentifier);
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
		for (OCSignalConsumer *consumer in storage[signalUUID].consumers)
		{
			[self _removeConsumerFromCache:consumer];
		}

		if (storage[signalUUID] != nil)
		{
			storage[signalUUID] = nil;

			return (YES);
		}

		return (NO);
	}];
}

#pragma mark - Signals
- (void)_processRecordForSignal:(OCSignalUUID)signalUUID recordModifier:(BOOL(^)(OCSignalRecord *record))modifier
{
	OCAppComponentIdentifier localComponentIdentifier = OCAppIdentity.sharedAppIdentity.componentIdentifier;
	__block NSMutableArray<OCSignalConsumer *> *consumersToSignal = nil;
	__block NSMutableArray<OCSignalConsumerUUID> *consumersToClear = nil;
	__block NSMutableDictionary<OCSignalUUID, OCSignal *> *signalsByUUIDs = [NSMutableDictionary new];

	[self _modifyStorage:^BOOL(OCSignalManagerStorage storage) {
		__block BOOL madeChanges = NO;

		void (^processRecord)(OCSignalRecord *signalRecord) = ^(OCSignalRecord *signalRecord) {
			BOOL modifierMadeChanges = NO;

			// Modify record (f.ex. add a completed signal)
			if (modifier != nil)
			{
				modifierMadeChanges = modifier(signalRecord);
			}

			// Prepare signal delivery where possible
			OCSignal *signalRecordSignal = signalRecord.signal;
			if (signalRecordSignal != nil)
			{
				BOOL didRemoveConsumers = NO;

				signalsByUUIDs[signalRecord.signalUUID] = signalRecordSignal;

				didRemoveConsumers = [signalRecord removeConsumersMatching:^BOOL(OCSignalConsumer * _Nonnull storedConsumer) {
					// Check if consumer is located in the running component
					if ([storedConsumer.componentIdentifier isEqual:localComponentIdentifier])
					{
						BOOL shouldDeliver =
							// Deliver if last delivered revision != signal revision
							(storedConsumer.lastDeliveredSignalRevision != signalRecordSignal.revision);
						BOOL shouldRemove =
							// Remove if
							// - delivery behaviour is "once"
							(storedConsumer.deliveryBehaviour == OCSignalDeliveryBehaviourOnce) ||
							// - delivery behaviour is "until terminated" and the signal signals termination
							((storedConsumer.deliveryBehaviour == OCSignalDeliveryBehaviourUntilTerminated) && signalRecordSignal.terminatesConsumersAfterDelivery) ||
							// - signal signals termination
							signalRecordSignal.terminatesConsumersAfterDelivery
						;
						OCSignalConsumerUUID consumerUUID;

						if (shouldDeliver || shouldRemove)
						{
							if ((consumerUUID = storedConsumer.uuid) != nil)
							{
								OCSignalHandler signalHandler;

								@synchronized(self->_handlersByConsumerUUID)
								{
									// Move consumer's signal handler from internal bookkeeping to storedConsumer
									// IF the signal is a terminating one
									if ((signalHandler = self->_handlersByConsumerUUID[consumerUUID]) != nil)
									{
										if (shouldDeliver)
										{
											// Add internally tracked signalHandler for consumerUUID to consumer
											storedConsumer.signalHandler = signalHandler;

											if (shouldRemove)
											{
												// The consumer is also removed, so make sure to clear its signal
												// handler from the consumer itself after signal delivery
												if (consumersToClear == nil) { consumersToClear = [NSMutableArray new]; }
												[consumersToClear addObject:storedConsumer.uuid];
											}

											// Add consumer to consumersToSignal whose
											// signalHandler will subsequently be called
											if (consumersToSignal == nil) { consumersToSignal = [NSMutableArray new]; }
											[consumersToSignal addObject:storedConsumer];

											// Update last delivered signal revision
											storedConsumer.lastDeliveredSignalRevision = signalRecordSignal.revision;
											madeChanges = YES; // Make sure the lastDeliveredSignalRevision change is saved
										}

										// Remove internally tracked signalHandler for consumerUUID
										if (shouldRemove)
										{
											[self _removeConsumerFromCache:storedConsumer];
										}
									}
								}
							}
						}

						return (shouldRemove); // Remove consumer
					}

					return (NO); // Keep consumer
				} onlyFirstMatch:NO];

				if (didRemoveConsumers) {
					madeChanges = YES;
				}
			}

			if (modifierMadeChanges)
			{
				madeChanges = YES;
			}

			// Remove empty records
			if (signalRecord.consumers.count == 0)
			{
				storage[signalUUID] = nil;
				madeChanges = YES;
			}
		};

		if (signalUUID != nil)
		{
			// Process single signal's record
			OCSignalRecord *signalRecord;

			if ((signalRecord = storage[signalUUID]) != nil)
			{
				processRecord(signalRecord);
			}
		}
		else
		{
			// Process as many signals as possible
			for (OCSignalUUID signalUUID in storage)
			{
				processRecord(storage[signalUUID]);
			}
		}

		return (madeChanges);
	}];

	// Signal consumers
	for (OCSignalConsumer *consumer in consumersToSignal)
	{
		if (consumer.signalHandler != nil)
		{
			consumer.signalHandler(consumer, signalsByUUIDs[consumer.signalUUID]);

			// Check if consumer has been marked for clearing its signalHandler
			if ([consumersToClear containsObject:consumer.uuid])
			{
				// Clear internally tracked signalHandler from consumer (typically on removal)
				consumer.signalHandler = nil;
			}
		}
	}
}

- (void)postSignal:(OCSignal *)signal
{
	if (signal.uuid == nil) { return; }

	[self _processRecordForSignal:signal.uuid recordModifier:^BOOL(OCSignalRecord *record) {
		if (record.signal != nil)
		{
			// Increment revision for signals replacing existing signals
			signal.revision = record.signal.revision + 1;
		}

		record.signal = signal;
		return (YES);
	}];
}

- (void)setNeedsSignalDelivery
{
	_needsSignalDelivery = YES;

	dispatch_async(_deliveryQueue, ^{
		if (self->_needsSignalDelivery)
		{
			self->_needsSignalDelivery = NO;
			[self deliverSignals];
		}
	});
}

- (void)deliverSignals
{
	[self _processRecordForSignal:nil recordModifier:nil];
}

@end

OCKeyValueStoreKey OCKeyValueStoreKeySignals = @"signals";
