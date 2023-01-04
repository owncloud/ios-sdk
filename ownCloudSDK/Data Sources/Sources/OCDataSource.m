//
//  OCDataSource.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 08.03.22.
//  Copyright © 2022 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2022, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCDataSource.h"
#import "OCDataSourceSubscription.h"
#import "OCDataSourceSubscription+Internal.h"
#import "NSError+OCError.h"

@interface OCDataSource ()
{
	OCCache<OCDataItemReference, id<OCDataItem>> *_cachedItems;

	BOOL _hasSubscriptions;

	NSMapTable<id<NSObject>, OCDataSourceSubscriptionObserver> *_subscriptionObserversByOwner;
}
@end

@implementation OCDataSource

- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_itemReferences = [NSMutableArray new];
		_subscriptions = [NSMutableArray new];
		_subscriptionObserversByOwner = [NSMapTable weakToStrongObjectsMapTable];
		_uuid = NSUUID.UUID.UUIDString;

		_state = OCDataSourceStateIdle;
	}

	return (self);
}

- (void)dealloc
{
	NSArray<OCDataSourceSubscription *> *subscriptions;

	@synchronized (_subscriptions)
	{
		subscriptions = [_subscriptions copy];
	}

	for (OCDataSourceSubscription *subscription in subscriptions)
	{
		[self terminateSubscription:subscription];
	}
}

#pragma mark - Item retrieval
- (OCDataItemRecord *)recordForItemRef:(OCDataItemReference)itemRef error:(NSError * _Nullable __autoreleasing *)error
{
	if (_itemRecordForReferenceProvider != nil)
	{
		return (_itemRecordForReferenceProvider(self, itemRef, error));
	}

	if (error != NULL)
	{
		*error = OCError(OCErrorFeatureNotImplemented);
	}

	return (nil);
}

- (void)retrieveItemForRef:(OCDataItemReference)itemRef reusingRecord:(nullable OCDataItemRecord *)reuseRecord completionHandler:(void(^)(NSError * _Nullable error, OCDataItemRecord * _Nullable record))completionHandler
{
	if (_itemForReferenceProvider != nil)
	{
		_itemForReferenceProvider(self, itemRef, reuseRecord, completionHandler);
		return;
	}

	completionHandler(OCError(OCErrorFeatureNotImplemented), nil);
}

#pragma mark - Children
- (nullable OCDataSource *)dataSourceForChildrenOfItemReference:(OCDataItemReference)itemRef
{
	if (_childDataSourceProvider != nil)
	{
		return (_childDataSourceProvider(self, itemRef));
	}

	return (nil);
}

#pragma mark - Caching
- (void)cacheItem:(id<OCDataItem>)item forItemRef:(OCDataItemReference)reference
{
	if (_cachedItems == nil)
	{
		_cachedItems = [[OCCache alloc] init];
		_cachedItems.countLimit = 30;
	}

	[_cachedItems setObject:item forKey:reference];
}

- (nullable id<OCDataItem>)cachedItemForItemRef:(OCDataItemReference)reference
{
	return ([_cachedItems objectForKey:reference]);
}

- (void)invalidateCacheForItemRef:(OCDataItemReference)reference
{
	[_cachedItems removeObjectForKey:reference];
}

- (void)invalidateCache
{
	[_cachedItems clearCache];
}

#pragma mark - Managing subscriptions
- (OCDataSourceSubscription *)subscribeWithUpdateHandler:(OCDataSourceSubscriptionUpdateHandler)updateHandler onQueue:(dispatch_queue_t)updateQueue trackDifferences:(BOOL)trackDifferences performIntialUpdate:(BOOL)performIntialUpdate
{
	return ([self _subscribeWithUpdateHandler:updateHandler onQueue:updateQueue trackDifferences:trackDifferences performIntialUpdate:trackDifferences isInternal:NO]);
}

- (OCDataSourceSubscription *)associateWithUpdateHandler:(OCDataSourceSubscriptionUpdateHandler)updateHandler onQueue:(dispatch_queue_t)updateQueue trackDifferences:(BOOL)trackDifferences performIntialUpdate:(BOOL)performIntialUpdate
{
	return ([self _subscribeWithUpdateHandler:updateHandler onQueue:updateQueue trackDifferences:trackDifferences performIntialUpdate:trackDifferences isInternal:YES]);
}

- (OCDataSourceSubscription *)_subscribeWithUpdateHandler:(OCDataSourceSubscriptionUpdateHandler)updateHandler onQueue:(dispatch_queue_t)updateQueue trackDifferences:(BOOL)trackDifferences performIntialUpdate:(BOOL)performIntialUpdate isInternal:(BOOL)isInternal
{
	OCDataSourceSubscription *subscription;

	@synchronized (_subscriptions)
	{
		subscription = [[OCDataSourceSubscription alloc] initWithSource:self trackDifferences:trackDifferences itemReferences:_itemReferences updateHandler:updateHandler onQueue:updateQueue];
		subscription.isInterDataSourceSubscription = isInternal;
		[_subscriptions addObject:subscription];

		[self setHasSubscriptions:(_subscriptions.count > 0)];
	}

	if (performIntialUpdate)
	{
		[subscription setNeedsUpdateHandling];
	}

	return (subscription);
}

- (void)terminateSubscription:(OCDataSourceSubscription *)subscription
{
	subscription.terminated = YES;
	subscription.source = nil;

	@synchronized (_subscriptions)
	{
		[_subscriptions removeObject:subscription];

		[self setHasSubscriptions:(_subscriptions.count > 0)];
	}
}

#pragma mark - Observing subscriptions
- (void)setHasSubscriptions:(BOOL)hasSubscriptions
{
	@synchronized(_subscriptionObserversByOwner)
	{
		if (_hasSubscriptions != hasSubscriptions)
		{
			_hasSubscriptions = hasSubscriptions;

			for (id owner in _subscriptionObserversByOwner)
			{
				OCDataSourceSubscriptionObserver observer = [_subscriptionObserversByOwner objectForKey:owner];
				observer(self, owner, hasSubscriptions);
			}
		}
	}
}

- (void)addSubscriptionObserver:(OCDataSourceSubscriptionObserver)subscriptionObserver withOwner:(id)owner performInitial:(BOOL)performInitial
{
	subscriptionObserver = [subscriptionObserver copy];

	@synchronized(_subscriptionObserversByOwner)
	{
		[_subscriptionObserversByOwner setObject:subscriptionObserver forKey:owner];

		if (performInitial)
		{
			subscriptionObserver(self, owner, _hasSubscriptions);
		}
	}
}

- (void)removeSubscriptionObserverForOwner:(id<NSObject>)owner
{
	@synchronized(_subscriptionObserversByOwner)
	{
		[_subscriptionObserversByOwner setObject:nil forKey:owner];
	}
}

#pragma mark - Managing content
- (void)setItemReferences:(nullable NSArray<OCDataItemReference> *)itemRefs updated:(nullable NSSet<OCDataItemReference> *)updatedItemRefs
{
	@synchronized (_subscriptions)
	{
		if (_synchronizationGroup != nil)
		{
			dispatch_group_enter(_synchronizationGroup);
		}

		[_itemReferences setArray:itemRefs];

		for (OCDataSourceSubscription *subscription in _subscriptions)
		{
			[subscription _updateWithItemReferences:itemRefs updated:updatedItemRefs];
		}

		if (_synchronizationGroup != nil)
		{
			dispatch_group_leave(_synchronizationGroup);
		}
	}
}

- (void)signalUpdatesForItemReferences:(nullable NSSet<OCDataItemReference> *)updatedItemRefs
{
	@synchronized (_subscriptions)
	{
		for (OCDataSourceSubscription *subscription in _subscriptions)
		{
			[subscription _updateWithItemReferences:_itemReferences updated:updatedItemRefs];
		}
	}
}

@end

OCDataSourceSpecialItem OCDataSourceSpecialItemHeader = @"header";
OCDataSourceSpecialItem OCDataSourceSpecialItemFooter = @"footer";

OCDataSourceSpecialItem OCDataSourceSpecialItemRootItem = @"rootItem";
OCDataSourceSpecialItem OCDataSourceSpecialItemFolderStatistics = @"folderStatistics";
