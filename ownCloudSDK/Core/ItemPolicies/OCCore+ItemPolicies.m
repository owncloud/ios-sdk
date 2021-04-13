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
#import "OCItemPolicyProcessorDownloadExpiration.h"
#import "OCItemPolicyProcessorVacuum.h"
#import "OCItemPolicyProcessorVersionUpdates.h"
#import "OCCore+SyncEngine.h"
#import "OCItemPolicy.h"

@implementation OCCore (ItemPolicies)

- (void)addItemPolicy:(OCItemPolicy *)policy options:(OCCoreItemPolicyOption)options completionHandler:(OCCoreCompletionHandler)completionHandler
{
	[self beginActivity:@"Adding item policy"];

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
		[self postInternalItemPoliciesChangedNotificationForPolicy:policy];

		if (completionHandler != nil)
		{
			completionHandler(error);
		}

		if ((options & OCCoreItemPolicyOptionSkipTrigger) == 0)
		{
			[self runPolicyProcessorsForTrigger:OCItemPolicyProcessorTriggerPoliciesChanged];
		}

		[self endActivity:@"Adding item policy"];
	}];
}

- (void)updateItemPolicy:(OCItemPolicy *)policy options:(OCCoreItemPolicyOption)options completionHandler:(OCCoreCompletionHandler)completionHandler
{
	[self beginActivity:@"Updating item policy"];

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
		[self postInternalItemPoliciesChangedNotificationForPolicy:policy];

		if (completionHandler != nil)
		{
			completionHandler(error);
		}

		if ((options & OCCoreItemPolicyOptionSkipTrigger) == 0)
		{
			[self runPolicyProcessorsForTrigger:OCItemPolicyProcessorTriggerPoliciesChanged];
		}

		[self endActivity:@"Updating item policy"];
	}];
}

- (void)removeItemPolicy:(OCItemPolicy *)policy options:(OCCoreItemPolicyOption)options completionHandler:(OCCoreCompletionHandler)completionHandler
{
	[self beginActivity:@"Removing item policy"];

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
		[self postInternalItemPoliciesChangedNotificationForPolicy:policy];

		if (completionHandler != nil)
		{
			completionHandler(error);
		}

		if ((options & OCCoreItemPolicyOptionSkipTrigger) == 0)
		{
			[self runPolicyProcessorsForTrigger:OCItemPolicyProcessorTriggerPoliciesChanged];
		}

		[self endActivity:@"Removing item policy"];
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
	[self beginActivity:@"Run policy processors"];

	[self performProtectedSyncBlock:^NSError *{
		[self runPolicyProcessorsForTrigger:triggerMask];
		return (nil);
	} completionHandler:^(NSError *error) {
		[self endActivity:@"Run policy processors"];
	}];
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

				[policyProcessor performPreflightOnPoliciesWithTrigger:triggerMask withItems:nil];

				[policyProcessor willEnterTrigger:triggerMask];

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

				[policyProcessor performPreflightOnPoliciesWithTrigger:triggerMask withItems:items];

				[policyProcessor willEnterTrigger:triggerMask];

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
	[self addItemPolicyProcessor:[[OCItemPolicyProcessorDownloadExpiration alloc] initWithCore:self]];
	[self addItemPolicyProcessor:[[OCItemPolicyProcessorVacuum alloc] initWithCore:self]];
	[self addItemPolicyProcessor:[[OCItemPolicyProcessorVersionUpdates alloc] initWithCore:self]];

	// Load item policies to update processors
	[self loadItemPoliciesWithCompletionHandler:nil];

	// Listen to change notifications
	[[OCIPNotificationCenter sharedNotificationCenter] addObserver:self forName:self.itemPoliciesChangedNotificationName withHandler:^(OCIPNotificationCenter * _Nonnull notificationCenter, OCCore * _Nonnull core, OCIPCNotificationName  _Nonnull notificationName) {
		[core invalidateItemPolicies];
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

#pragma mark - Change notification
- (void)postInternalItemPoliciesChangedNotificationForPolicy:(OCItemPolicy *)policy
{
	if ([policy.kind isEqual:OCItemPolicyKindAvailableOffline])
	{
		@synchronized(_availableOfflineFolderPaths)
		{
			_availableOfflineCacheValid = NO;
		}
	}

	[NSNotificationCenter.defaultCenter postNotificationName:OCCoreItemPoliciesChangedNotification object:policy.kind];
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

NSNotificationName OCCoreItemPoliciesChangedNotification = @"OCCoreItemPoliciesChangedNotification";

NSErrorUserInfoKey OCErrorItemPoliciesKey = @"item-policies";
