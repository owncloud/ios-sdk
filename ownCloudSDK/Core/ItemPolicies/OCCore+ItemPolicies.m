//
//  OCCore+ItemPolicies.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 10.07.19.
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

#import "OCCore+ItemPolicies.h"
#import "OCCore+Internal.h"
#import "OCQueryCondition+Item.h"
#import "OCQueryCondition+SQLBuilder.h"
#import "OCItemPolicyProcessor.h"
#import "OCItemPolicyProcessorAvailableOffline.h"
#import "OCCore+SyncEngine.h"
#import "OCItemPolicy.h"

@implementation OCCore (ItemPolicies)

- (void)addItemPolicy:(OCItemPolicy *)policy completionHandler:(OCCoreCompletionHandler)completionHandler
{
	[self.database addItemPolicy:policy completionHandler:^(OCDatabase *db, NSError *error) {
		@synchronized (self->_itemPolicies)
		{
			if (self->_itemPoliciesValid)
			{
				[self->_itemPolicies addObject:policy];
				[self _updatePolicyProcessors];
			}
		}

		[self postItemPoliciesChangedNotification];

		if (completionHandler != nil)
		{
			completionHandler(error);
		}

		[self runPolicyProcessorsForTrigger:OCItemPolicyProcessorTriggerPoliciesChanged];
	}];
}

- (void)updateItemPolicy:(OCItemPolicy *)policy completionHandler:(OCCoreCompletionHandler)completionHandler
{
	[self.database updateItemPolicy:policy completionHandler:^(OCDatabase *db, NSError *error) {
		@synchronized (self->_itemPolicies)
		{
			if (self->_itemPoliciesValid)
			{
				NSUInteger index;

				if ((index = [self->_itemPolicies indexOfObjectPassingTest:^BOOL(OCItemPolicy * _Nonnull otherPolicy, NSUInteger idx, BOOL * _Nonnull stop) { return ([otherPolicy.databaseID isEqual:policy.databaseID]); }]) != NSNotFound)
				{
					[self->_itemPolicies removeObjectAtIndex:index];
				}
				[self->_itemPolicies addObject:policy];

				[self _updatePolicyProcessors];
			}
		}

		[self postItemPoliciesChangedNotification];

		if (completionHandler != nil)
		{
			completionHandler(error);
		}

		[self runPolicyProcessorsForTrigger:OCItemPolicyProcessorTriggerPoliciesChanged];
	}];
}

- (void)removeItemPolicy:(OCItemPolicy *)policy completionHandler:(OCCoreCompletionHandler)completionHandler
{
	[self.database removeItemPolicy:policy completionHandler:^(OCDatabase *db, NSError *error) {
		@synchronized (self->_itemPolicies)
		{
			if (self->_itemPoliciesValid)
			{
				NSUInteger index;

				if ((index = [self->_itemPolicies indexOfObjectPassingTest:^BOOL(OCItemPolicy * _Nonnull otherPolicy, NSUInteger idx, BOOL * _Nonnull stop) { return ([otherPolicy.databaseID isEqual:policy.databaseID]); }]) != NSNotFound)
				{
					[self->_itemPolicies removeObjectAtIndex:index];
				}

				[self _updatePolicyProcessors];
			}
		}

		[self postItemPoliciesChangedNotification];

		if (completionHandler != nil)
		{
			completionHandler(error);
		}

		[self runPolicyProcessorsForTrigger:OCItemPolicyProcessorTriggerPoliciesChanged];
	}];
}

- (void)retrievePoliciesOfKind:(nullable OCItemPolicyKind)kind affectingItem:(nullable OCItem *)item includeInternal:(BOOL)includeInternal completionHandler:(nonnull void (^)(NSError * _Nullable, NSArray<OCItemPolicy *> * _Nullable))completionHandler
{
	[self loadItemPoliciesWithCompletionHandler:^{
		NSMutableArray<OCItemPolicy *> *affectedByPolicies = nil;

		@synchronized (self->_itemPolicies)
		{
			for (OCItemPolicy *policy in self->_itemPolicies)
			{
				if ( ((kind==nil) || ((kind != nil) && [kind isEqualToString:policy.kind])) &&
				     (includeInternal || (!includeInternal && ![policy.identifier hasPrefix:OCItemPolicyIdentifierInternalPrefix]))
				   )
				{
					if ((item == nil) || ((item != nil) && [policy.condition fulfilledByItem:item]))
					{
						if (affectedByPolicies == nil) { affectedByPolicies = [NSMutableArray new]; }

						[affectedByPolicies addObject:policy];
					}
				}
			}
		}

		completionHandler(nil, affectedByPolicies);
	}];
}

- (void)addItemPolicyProcessor:(OCItemPolicyProcessor *)processor
{
	@synchronized(_itemPolicies)
	{
		processor.core = self;
		[_itemPolicyProcessors addObject:processor];

		[processor updateWithPolicies:_itemPolicies];
	}
}

- (void)removeItemPolicyProcessor:(OCItemPolicyProcessor *)processor
{
	@synchronized(_itemPolicies)
	{
		processor.core = nil;
		[_itemPolicyProcessors removeObject:processor];
	}
}

- (nullable OCItemPolicyProcessor *)itemPolicyProcessorForKind:(OCItemPolicyKind)kind
{
	@synchronized(_itemPolicies)
	{
		for (OCItemPolicyProcessor *processor in _itemPolicyProcessors)
		{
			if ([processor.kind isEqual:kind])
			{
				return (processor);
			}
		}
	}

	return (nil);
}

#pragma mark - Policy processors
- (void)runProtectedPolicyProcessorsForTrigger:(OCItemPolicyProcessorTrigger)triggerMask
{
	[self performProtectedSyncBlock:^NSError *{
		[self runPolicyProcessorsForTrigger:triggerMask];
		return (nil);
	} completionHandler:nil];
}

- (void)runPolicyProcessorsForTrigger:(OCItemPolicyProcessorTrigger)triggerMask
{
	@synchronized(_itemPolicies)
	{
		for (OCItemPolicyProcessor *policyProcessor in _itemPolicyProcessors)
		{
			if ((policyProcessor.triggerMask & triggerMask) != 0)
			{
				OCQueryCondition *matchCondition;
				OCQueryCondition *cleanupCondition;

				if ((matchCondition = policyProcessor.matchCondition) != nil)
				{
					__block BOOL foundMatch = NO;

					[self.database iterateCacheItemsForQueryCondition:matchCondition excludeRemoved:NO withIterator:^(NSError *error, OCSyncAnchor syncAnchor, OCItem *item, BOOL *stop) {
						if (item != nil)
						{
							if (!foundMatch)
							{
								foundMatch = YES;
								[policyProcessor beginMatchingWithTrigger:triggerMask];
							}

							[policyProcessor performActionOn:item withTrigger:triggerMask];
						}
					}];

					if (foundMatch)
					{
						[policyProcessor endMatchingWithTrigger:triggerMask];
					}
				}

				if ((cleanupCondition = policyProcessor.cleanupCondition) != nil)
				{
					__block BOOL foundMatch = NO;

					[self.database iterateCacheItemsForQueryCondition:cleanupCondition excludeRemoved:NO withIterator:^(NSError *error, OCSyncAnchor syncAnchor, OCItem *item, BOOL *stop) {
						if (item != nil)
						{
							if (!foundMatch)
							{
								foundMatch = YES;
								[policyProcessor beginCleanupWithTrigger:triggerMask];
							}

							[policyProcessor performCleanupOn:item withTrigger:triggerMask];
						}
					}];

					if (foundMatch)
					{
						[policyProcessor endCleanupWithTrigger:triggerMask];
					}
				}

				[policyProcessor didPassTrigger:triggerMask];
			}
		}
	}
}

- (void)runPolicyProcessorsOnNewUpdatedAndDeletedItems:(NSArray <OCItem *> *)items forTrigger:(OCItemPolicyProcessorTrigger)triggerMask
{
	@synchronized(_itemPolicies)
	{
		for (OCItemPolicyProcessor *policyProcessor in _itemPolicyProcessors)
		{
			if ((policyProcessor.triggerMask & triggerMask) != 0)
			{
				OCQueryCondition *matchCondition;
				OCQueryCondition *cleanupCondition;

				if ((matchCondition = policyProcessor.matchCondition) != nil)
				{
					__block BOOL foundMatch = NO;

					for (OCItem *item in items)
					{
						if ([matchCondition fulfilledByItem:item])
						{
							if (!foundMatch)
							{
								foundMatch = YES;
								[policyProcessor beginMatchingWithTrigger:triggerMask];
							}

							[policyProcessor performActionOn:item withTrigger:triggerMask];
						}
					}

					if (foundMatch)
					{
						[policyProcessor endMatchingWithTrigger:triggerMask];
					}
				}

				if ((cleanupCondition = policyProcessor.cleanupCondition) != nil)
				{
					__block BOOL foundMatch = NO;

					for (OCItem *item in items)
					{
						if ([cleanupCondition fulfilledByItem:item])
						{
							if (!foundMatch)
							{
								foundMatch = YES;
								[policyProcessor beginCleanupWithTrigger:triggerMask];
							}

							[policyProcessor performCleanupOn:item withTrigger:triggerMask];
						}
					}

					if (foundMatch)
					{
						[policyProcessor endCleanupWithTrigger:triggerMask];
					}
				}

				[policyProcessor didPassTrigger:triggerMask];
			}
		}
	}
}

- (void)_updatePolicyProcessors
{
	@synchronized(_itemPolicies)
	{
		for (OCItemPolicyProcessor *policyProcessor in _itemPolicyProcessors)
		{
			[policyProcessor updateWithPolicies:_itemPolicies];
		}
	}
}

#pragma mark - IPC
- (OCIPCNotificationName)itemPoliciesChangedNotificationName
{
	return ([OCIPCNotificationNameItemPoliciesChangedPrefix stringByAppendingFormat:@".%@", self.bookmark.uuid.UUIDString]);
}

- (void)setupItemPolicies
{
	// Add item policy processors
	[self addItemPolicyProcessor:[[OCItemPolicyProcessorAvailableOffline alloc] initWithCore:self]];

	// Load item policies to update processors
	[self loadItemPoliciesWithCompletionHandler:^{
//		@synchronized(self->_itemPolicies)
//		{
//			if ([self->_itemPolicies indexOfObjectPassingTest:^BOOL(OCItemPolicy * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
//				return ([obj.identifier isEqual:@"PhotosOffline"]);
//			}] == NSNotFound)
//			{
//				OCItemPolicy *itemPolicy;
//
//				itemPolicy = [[OCItemPolicy alloc] initWithKind:OCItemPolicyKindAvailableOffline condition:[OCQueryCondition where:OCItemPropertyNamePath startsWith:@"/Photos/"]];
//				itemPolicy.identifier = @"PhotosOffline";
//
//				[self addItemPolicy:itemPolicy completionHandler:nil];
//			}
//		}
	}];

	// Listen to change notifications
	[[OCIPNotificationCenter sharedNotificationCenter] addObserver:self forName:self.itemPoliciesChangedNotificationName withHandler:^(OCIPNotificationCenter * _Nonnull notificationCenter, id  _Nonnull observer, OCIPCNotificationName  _Nonnull notificationName) {
		[self invalidateItemPolicies];
	}];
}

- (void)postItemPoliciesChangedNotification
{
	[[OCIPNotificationCenter sharedNotificationCenter] postNotificationForName:self.itemPoliciesChangedNotificationName ignoreSelf:YES];
}

- (void)teardownItemPolicies
{
	[[OCIPNotificationCenter sharedNotificationCenter] removeObserver:self forName:self.itemPoliciesChangedNotificationName];
}

#pragma mark - Invalidation and lazy loading
- (void)invalidateItemPolicies
{
	@synchronized(self->_itemPolicies)
	{
		_itemPoliciesValid = NO;
		[_itemPolicies removeAllObjects];

		[self loadItemPoliciesWithCompletionHandler:nil];
	}
}

- (void)loadItemPoliciesWithCompletionHandler:(nullable dispatch_block_t)completionHandler
{
	BOOL isValid;

	@synchronized(self->_itemPolicies)
	{
		isValid = _itemPoliciesValid;
	}

	if (isValid)
	{
		if (completionHandler != nil)
		{
			completionHandler();
		}
	}
	else
	{
		[self.database retrieveItemPoliciesForKind:nil path:nil localID:nil identifier:nil completionHandler:^(OCDatabase *db, NSError *error, NSArray<OCItemPolicy *> *itemPolicies) {
			@synchronized(self->_itemPolicies)
			{
				self->_itemPoliciesValid = YES;
				[self->_itemPolicies setArray:itemPolicies];

				[self _updatePolicyProcessors];
			}

			if (completionHandler != nil)
			{
				completionHandler();
			}
		}];
	}
}

@end

OCIPCNotificationName OCIPCNotificationNameItemPoliciesChangedPrefix = @"org.owncloud.itempolicies.changed";

NSErrorUserInfoKey OCErrorItemPoliciesKey = @"item-policies";
