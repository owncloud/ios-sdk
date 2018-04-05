//
//  OCQueryChangeSet.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 06.02.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2018, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCQueryChangeSet.h"

@implementation OCQueryChangeSet

#pragma mark - Init & Dealloc
- (instancetype)initWithQueryResult:(NSArray <OCItem *> *)queryResult relativeTo:(NSArray <OCItem *> *)previousQueryResult
{
	if ((self = [super init]) != nil)
	{
		// Minimum implementation
		self.queryResult = queryResult;

		self.containsChanges = YES;
		self.contentSwap = YES;
	}

	return(self);
}

#pragma mark - Change set enumeration
- (void)enumerateChangesUsingBlock:(OCQueryChangeSetEnumerator)enumerator
{
	if (_containsChanges)
	{
		if (_contentSwap)
		{
			enumerator(self, OCQueryChangeSetOperationContentSwap, self.queryResult, nil);
		}
		else
		{
			if (_updatedItems.count > 0)
			{
				enumerator(self, OCQueryChangeSetOperationUpdate, self.updatedItems, self.updatedItemsIndexSet);
			}

			if (_removedItems.count > 0)
			{
				enumerator(self, OCQueryChangeSetOperationRemove, self.removedItems, self.removedItemsIndexSet);
			}

			if (_insertedItems.count > 0)
			{
				enumerator(self, OCQueryChangeSetOperationInsert, self.insertedItems, self.insertedItemsIndexSet);
			}
		}
	}
}

@end
