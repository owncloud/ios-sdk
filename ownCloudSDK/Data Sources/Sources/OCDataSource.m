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
}
@end

@implementation OCDataSource

- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_itemReferences = [NSMutableArray new];
		_subscriptions = [NSMutableArray new];
	}

	return (self);
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
- (OCDataSourceSubscription *)subscribeWithUpdateHandler:(OCDataSourceSubscriptionUpdateHandler)updateHandler trackDifferences:(BOOL)trackDifferences
{
	OCDataSourceSubscription *subscription;

	@synchronized (_subscriptions)
	{
		subscription = [[OCDataSourceSubscription alloc] initWithSource:self trackDifferences:trackDifferences itemReferences:_itemReferences updateHandler:updateHandler];
		[_subscriptions addObject:subscription];
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
	}
}

#pragma mark - Managing content
- (void)setItemReferences:(nullable NSArray<OCDataItemReference> *)itemRefs updated:(nullable NSSet<OCDataItemReference> *)updatedItemRefs
{
	@synchronized (_subscriptions)
	{
		[_itemReferences setArray:itemRefs];

		for (OCDataSourceSubscription *subscription in _subscriptions)
		{
			[subscription _updateWithItemReferences:itemRefs updated:updatedItemRefs];
		}
	}
}

#pragma mark - Synchronization queue
- (void)queue:(dispatch_block_t)block
{
	block();
}

@end
