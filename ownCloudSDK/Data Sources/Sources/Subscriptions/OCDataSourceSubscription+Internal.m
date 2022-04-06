//
//  OCDataSourceSubscription+Internal.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 16.03.22.
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

#import "OCDataSourceSubscription+Internal.h"
#import "OCLogger.h"

@implementation OCDataSourceSubscription (Internal)

- (void)setNeedsUpdateHandling
{
	__weak OCDataSourceSubscription *weakSelf = self;
	dispatch_queue_t updateQueue = self.updateQueue;
	dispatch_block_t updateHandlingBlock = ^{
		OCDataSourceSubscription *strongSelf;
		OCDataSourceSubscriptionUpdateHandler updateHandler;

		if (((strongSelf = weakSelf) != nil) && ((updateHandler = strongSelf.updateHandler) != nil))
		{
			@synchronized(self) {
				if (strongSelf->_needsUpdateHandling)
				{
					strongSelf->_needsUpdateHandling = NO;
				}
			};

			updateHandler(strongSelf);
		}
	};

	@synchronized(self) {
		_needsUpdateHandling = YES;
	};

	if (updateQueue != nil)
	{
		dispatch_async(updateQueue, updateHandlingBlock);
	}
	else
	{
		updateHandlingBlock();
	}
}

- (void)_updateWithItemReferences:(nullable NSArray<OCDataItemReference> *)newItemRefs updated:(nullable NSSet<OCDataItemReference> *)updatedItemRefs
{
	BOOL wasUpdated = NO;

	if ((_updatedItemRefs==nil) && (newItemRefs != nil) && (newItemRefs.count == _itemRefs.count) && [newItemRefs isEqual:_itemRefs])
	{
		// No changes
		return;
	}

	@synchronized (_itemRefs)
	{
		if (!self.trackDifferences)
		{
			// Do not track differences
			[_itemRefs setArray:newItemRefs];

			wasUpdated = YES;
		}
		else
		{
			// Track differences
			NSMutableSet<OCDataItemReference> *newlyAddedItemRefs = nil;
			NSMutableSet<OCDataItemReference> *newlyUpdatedItemRefs = nil;
			NSMutableSet<OCDataItemReference> *newlyRemovedItemRefs = nil;
			NSMutableSet<OCDataItemReference> *previouslyRemovedAndNowReaddedItemRefs = nil;
			NSMutableSet<OCDataItemReference> *previouslyAddedAndNowRemovedItemRefs = nil;
			NSMutableSet<OCDataItemReference> *danglingUpdatedItemRefs = nil;
			NSSet<OCDataItemReference> *existingItemRefs = nil;

			if (_itemRefs != nil)
			{
				existingItemRefs = [[NSSet alloc] initWithArray:_itemRefs];
				newlyRemovedItemRefs = [existingItemRefs mutableCopy];
			}

			if (updatedItemRefs != nil)
			{
				newlyUpdatedItemRefs = [updatedItemRefs mutableCopy];
			}
			else
			{
				newlyUpdatedItemRefs = [NSMutableSet new];
			}

			if (newItemRefs != nil)
			{
				newlyAddedItemRefs = [[NSMutableSet alloc] initWithArray:newItemRefs];

				// Find items that are supposed to be updated, but not contained in newItemRefs
				if (updatedItemRefs != nil)
				{
					danglingUpdatedItemRefs = [newlyUpdatedItemRefs mutableCopy];
					[danglingUpdatedItemRefs minusSet:newlyAddedItemRefs];
				}

				// Find added and removed items
				if (existingItemRefs != nil)
				{
					// Removed Items = (Old Items - New Items)
					[newlyRemovedItemRefs minusSet:newlyAddedItemRefs];

					// Added Items = (New Items - Old Items)
					[newlyAddedItemRefs minusSet:existingItemRefs];
				}

				// Find items that were added and then removed
				previouslyAddedAndNowRemovedItemRefs = [newlyRemovedItemRefs mutableCopy];
				[previouslyAddedAndNowRemovedItemRefs intersectSet:_addedItemRefs];

				// Find items that were removed and then added
				previouslyRemovedAndNowReaddedItemRefs = [newlyAddedItemRefs mutableCopy];
				[previouslyRemovedAndNowReaddedItemRefs intersectSet:_removedItemRefs];

				// Find items that are supposed to be updated, but not contained in newItemRefs
				if (danglingUpdatedItemRefs.count > 0)
				{
					OCLogWarning(@"Data Source Subscription told itemRef(s) %@ updated, but not in itemRefs, so can't be updated", danglingUpdatedItemRefs);
					[newlyUpdatedItemRefs minusSet:danglingUpdatedItemRefs];
				}

				// Addition + subsequent removal -> drop any reference to item
				[_addedItemRefs minusSet:previouslyAddedAndNowRemovedItemRefs];
				[_updatedItemRefs minusSet:previouslyAddedAndNowRemovedItemRefs];
				[newlyRemovedItemRefs minusSet:previouslyAddedAndNowRemovedItemRefs];

				// Removal + subsequent addition -> drop reference from removal + addition, add to updates
				[_removedItemRefs minusSet:previouslyRemovedAndNowReaddedItemRefs];
				[newlyAddedItemRefs minusSet:previouslyRemovedAndNowReaddedItemRefs];

				[newlyUpdatedItemRefs unionSet:previouslyRemovedAndNowReaddedItemRefs];

				// Add new additions
				[_addedItemRefs unionSet:newlyAddedItemRefs];

				// Add new updates, remove removed
				[_updatedItemRefs unionSet:newlyUpdatedItemRefs];
				[_updatedItemRefs minusSet:newlyRemovedItemRefs];

				// Add new removals
				[_removedItemRefs unionSet:newlyRemovedItemRefs];

				// Replace itemRefs content with newItemRefs
				[_itemRefs setArray:newItemRefs];

				if ((((_addedItemRefs.count > 0) || (_removedItemRefs.count > 0) || (_updatedItemRefs.count > 0)) && !_needsUpdateHandling) ||
   				     ((newlyAddedItemRefs.count > 0) || (newlyRemovedItemRefs.count > 0) || (newlyUpdatedItemRefs.count > 0)) )
				{
					wasUpdated = YES;
				}
			}
		}
	}

	if (wasUpdated)
	{
		// Notify of changes
		[self setNeedsUpdateHandling];
	}
}

@end
