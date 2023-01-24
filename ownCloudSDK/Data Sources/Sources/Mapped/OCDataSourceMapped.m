//
//  OCDataSourceMapped.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 15.11.22.
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

#import "OCDataSourceMapped.h"

@implementation OCDataSourceMapped
{
	NSMutableArray<id<OCDataItem>> *_mappedItems;
	NSMapTable<OCDataItemReference, id<OCDataItem>> *_mappedItemBySourceItemReference;

	OCDataSourceSubscription *_subscription;

	OCDataSourceMappedItemCreator _itemCreator;
	OCDataSourceMappedItemUpdater _itemUpdater;
	OCDataSourceMappedItemDestroyer _itemDestroyer;

	dispatch_queue_t _queue;
}

- (instancetype)initWithSource:(OCDataSource *)source creator:(OCDataSourceMappedItemCreator)itemCreator updater:(nullable OCDataSourceMappedItemUpdater)itemUpdater destroyer:(nullable OCDataSourceMappedItemDestroyer)itemDestroyer queue:(nullable dispatch_queue_t)queue
{
	if ((self = [super initWithItems:nil]) != nil)
	{
		_itemCreator = itemCreator;
		_itemUpdater = itemUpdater;
		_itemDestroyer = itemDestroyer;

		_mappedItems = NSMutableArray.new;
		_mappedItemBySourceItemReference = NSMapTable.strongToWeakObjectsMapTable;

		_queue = queue;

		self.source = source;
	}

	return (self);
}

- (void)dealloc
{
	self.source = nil;
}

- (void)setSource:(OCDataSource *)source
{
	if ((_source != nil) && (source != _source))
	{
		[_subscription terminate];
		_subscription = nil;

		if (_itemDestroyer != nil)
		{
			NSDictionary<OCDataItemReference, id<OCDataItem>> *mappedItemBySourceItemReference = _mappedItemBySourceItemReference.dictionaryRepresentation;

			[mappedItemBySourceItemReference enumerateKeysAndObjectsUsingBlock:^(OCDataItemReference  _Nonnull sourceItemRef, id<OCDataItem>  _Nonnull mappedItem, BOOL * _Nonnull stop) {
				_itemDestroyer(self, sourceItemRef, mappedItem);
			}];

			[_mappedItems removeAllObjects];
			[_mappedItemBySourceItemReference removeAllObjects];
		}
	}

	_source = source;

	if (source != nil)
	{
		__weak OCDataSourceMapped *weakSelf = self;
		_subscription = [_source associateWithUpdateHandler:^(OCDataSourceSubscription * _Nonnull subscription) {
			OCDataSourceSnapshot *snapshot;

			if ((snapshot = [subscription snapshotResettingChangeTracking:YES]) != nil)
			{
				[weakSelf _handleSourceSnapshot:snapshot];
			}
		} onQueue:_queue trackDifferences:YES performInitialUpdate:YES];
	}
}

- (void)_handleSourceSnapshot:(OCDataSourceSnapshot *)snapshot
{
	// Remove items
	for (OCDataItemReference removedItemReference in snapshot.removedItems)
	{
		id<OCDataItem> mappedItem = [_mappedItemBySourceItemReference objectForKey:removedItemReference];

		if (_itemDestroyer != nil)
		{
			_itemDestroyer(self, removedItemReference, mappedItem);
		}

		[_mappedItems removeObject:mappedItem];
	}

	// Added items
	NSArray<OCDataItemReference> *addedItems;

	if ((_mappedItems.count == 0) && (snapshot.numberOfItems > 0))
	{
		addedItems = snapshot.items;
	}
	else
	{
		addedItems = snapshot.addedItems.allObjects;
	}

	for (OCDataItemReference addedItemReference in addedItems)
	{
		NSError *error = nil;
		OCDataItemRecord *addedItemRecord = [_source recordForItemRef:addedItemReference error:&error];

		if (addedItemRecord != nil)
		{
			id<OCDataItem> mappedItem;

			if ((mappedItem = _itemCreator(self, addedItemRecord.item)) != nil)
			{
				[_mappedItems addObject:mappedItem];
				[_mappedItemBySourceItemReference setObject:mappedItem forKey:addedItemReference];
			}
		}
	}

	// Update items
	NSMutableSet<id<OCDataItem>> *updatedItems = [NSMutableSet new];

	for (OCDataItemReference updatedItemReference in snapshot.updatedItems)
	{
		NSError *error = nil;
		OCDataItemRecord *updatedItemRecord = [_source recordForItemRef:updatedItemReference error:&error];
		id<OCDataItem> existingMappedItem = [_mappedItemBySourceItemReference objectForKey:updatedItemReference];

		if ((updatedItemRecord != nil) && (existingMappedItem != nil))
		{
			id<OCDataItem> updatedMappedItem;

			if (_itemUpdater != nil)
			{
				updatedMappedItem = _itemUpdater(self, updatedItemRecord.item, existingMappedItem);
			}
			else
			{
				updatedMappedItem = existingMappedItem;
			}

			if (updatedMappedItem != existingMappedItem)
			{
				[_mappedItems removeObject:existingMappedItem];
				[_mappedItems addObject:updatedMappedItem];
				[_mappedItemBySourceItemReference setObject:updatedMappedItem forKey:updatedItemReference];
			}

			[updatedItems addObject:updatedMappedItem];
		}
	}

	// Compose items array (establish same order and corresponding contents as source)
	NSMutableArray<id<OCDataItem>> *items = [NSMutableArray new];

	for (OCDataItemReference sourceItemReference in snapshot.items)
	{
		id<OCDataItem> mappedItem;

		if ((mappedItem = [_mappedItemBySourceItemReference objectForKey:sourceItemReference]) != nil)
		{
			[items addObject:mappedItem];
		}
	}

	[self setItems:items updated:updatedItems];
}

@end
