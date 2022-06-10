//
//  OCDataSourceArray.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 22.03.22.
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

#import "OCDataSourceArray.h"

@implementation OCDataSourceArray

- (void)setItems:(nullable NSArray<id<OCDataItem>> *)items updated:(nullable NSSet<id<OCDataItem>> *)updatedItems
{
	NSMapTable<OCDataItemReference, id<OCDataItem>> *itemsByReference = [NSMapTable strongToStrongObjectsMapTable];
	NSMutableArray<OCDataItemReference> *itemReferences = [NSMutableArray new];
	NSMutableSet<OCDataItemReference> *updatedItemReferences = (updatedItems != nil) ? [NSMutableSet new] : nil;

	for (id<OCDataItem> item in items)
	{
		OCDataItemReference itemRef;

		if ((itemRef = item.dataItemReference) != nil)
		{
			[itemsByReference setObject:item forKey:itemRef];
			[itemReferences addObject:itemRef];
		}
	}

	if (updatedItems != nil)
	{
		for (id<OCDataItem> item in updatedItems)
		{
			OCDataItemReference itemRef;

			if ((itemRef = item.dataItemReference) != nil)
			{
				[updatedItemReferences addObject:itemRef];
			}
		}
	}

	@synchronized(_subscriptions)
	{
		_itemsByReference = itemsByReference;
		[self setItemReferences:itemReferences updated:updatedItemReferences];
	}
}

- (void)setVersionedItems:(nullable NSArray<id<OCDataItem,OCDataItemVersioning>> *)items
{
	NSMutableSet<id<OCDataItem>> *updatedItems = nil;

	@synchronized(_subscriptions)
	{
		for (id<OCDataItem,OCDataItemVersioning> item in items)
		{
			OCDataItemReference itemRef;

			if ((itemRef = item.dataItemReference) != nil)
			{
				id<OCDataItem,OCDataItemVersioning> oldItem;

				if ((oldItem = (id<OCDataItem,OCDataItemVersioning>)[_itemsByReference objectForKey:itemRef]) != nil)
				{
					OCDataItemVersion newVersion = item.dataItemVersion;
					OCDataItemVersion oldVersion = oldItem.dataItemVersion;

					if (![newVersion isEqual:oldVersion])
					{
						if (updatedItems == nil) { updatedItems = [NSMutableSet new]; }

						[updatedItems addObject:item];
					}
				}
			}
		}
	}

	[self setItems:items updated:updatedItems];
}

- (nullable OCDataItemRecord *)recordForItemRef:(OCDataItemReference)itemRef error:(NSError * _Nullable * _Nullable)error
{
	id<OCDataItem> item;

	@synchronized(_subscriptions)
	{
		item = [_itemsByReference objectForKey:itemRef];
	}

	if (item != nil)
	{
		BOOL hasChildren = NO;

		if (_dataItemHasChildrenProvider != nil)
		{
			hasChildren = _dataItemHasChildrenProvider(self, item);
		}
		else
		{
			if ([item respondsToSelector:@selector(hasChildrenUsingSource:)])
			{
				hasChildren = [item hasChildrenUsingSource:self];
			}
		}

		return ([[OCDataItemRecord alloc] initWithSource:self item:item hasChildren:hasChildren]);
	}

	return (nil);
}

- (void)retrieveItemForRef:(OCDataItemReference)itemRef reusingRecord:(OCDataItemRecord *)reuseRecord completionHandler:(OCDataSourceItemForReferenceCompletionHandler)completionHandler
{
	id<OCDataItem> item;
	OCDataItemRecord *itemRecord = reuseRecord;
	NSError *error = nil;

	@synchronized(_subscriptions)
	{
		item = [_itemsByReference objectForKey:itemRef];
	}

	if (reuseRecord != nil)
	{
		reuseRecord.item = item;
	}
	else
	{
		itemRecord = [self recordForItemRef:itemRef error:&error];
	}

	completionHandler(error, itemRecord);
}

@end
