//
//  OCDataSourceSubscription.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 15.03.22.
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

#import "OCDataSourceSubscription.h"
#import "OCDataSource.h"

@implementation OCDataSourceSubscription

+ (dispatch_queue_t)defaultUpdateQueue
{
	return (dispatch_get_main_queue());
}

- (instancetype)initWithSource:(OCDataSource *)source trackDifferences:(BOOL)trackDifferences itemReferences:(NSArray<OCDataItemReference> *)itemRefs updateHandler:(OCDataSourceSubscriptionUpdateHandler)updateHandler onQueue:(dispatch_queue_t)updateQueue
{
	if ((self = [super init]) != nil)
	{
		_source = source;
		_trackDifferences = trackDifferences;

		self.updateHandler = updateHandler;

		_itemRefs = (itemRefs.count > 0) ? [itemRefs mutableCopy] : [NSMutableArray new];
		_addedItemRefs = [NSMutableSet new];
		_updatedItemRefs = [NSMutableSet new];
		_removedItemRefs = [NSMutableSet new];

		_updateQueue = updateQueue;
	}

	return (self);
}

- (void)terminate
{
	[_source terminateSubscription:self];
	_terminated = YES;

	@synchronized (_itemRefs)
	{
		[_itemRefs removeAllObjects];
		[_addedItemRefs removeAllObjects];
		[_updatedItemRefs removeAllObjects];
		[_removedItemRefs removeAllObjects];

		self.updateHandler = nil;
	}
}

- (BOOL)hasChangesSinceLastTrackingReset
{
	if (_trackDifferences && !_terminated)
	{
		@synchronized (_itemRefs)
		{
			return (_addedItemRefs.count > 0) || (_updatedItemRefs.count > 0) || (_removedItemRefs.count > 0);
		}
	}

	return (NO);
}

- (OCDataSourceSnapshot *)snapshotResettingChangeTracking:(BOOL)resetChangeTracking
{
	OCDataSourceSnapshot *snapshot = [OCDataSourceSnapshot new];

	@synchronized (_itemRefs)
	{
		snapshot.items = [_itemRefs copy];
		snapshot.numberOfItems = _itemRefs.count;

		if (resetChangeTracking)
		{
			snapshot.addedItems = _addedItemRefs;
			snapshot.updatedItems = _updatedItemRefs;
			snapshot.removedItems = _removedItemRefs;

			_addedItemRefs = [NSMutableSet new];
			_updatedItemRefs = [NSMutableSet new];
			_removedItemRefs = [NSMutableSet new];
		}
		else
		{
			snapshot.addedItems = [_addedItemRefs copy];
			snapshot.updatedItems = [_updatedItemRefs copy];
			snapshot.removedItems = [_removedItemRefs copy];
		}

		snapshot.specialItems = [_source.specialItems copy];
	}

	return (snapshot);
}

@end
