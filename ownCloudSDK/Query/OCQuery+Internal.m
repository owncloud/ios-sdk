//
//  OCQuery+Internal.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 02.04.18.
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

#import "OCQuery+Internal.h"

@implementation OCQuery (Internal)

#pragma mark - Update full results
- (void)updateWithFullResults:(NSMutableArray <OCItem *> *)fullQueryResults
{
	@synchronized(self)
	{
		_fullQueryResults = fullQueryResults;

		[self setNeedsRecomputation];
	}
}

#pragma mark - Update processed results
- (void)updateProcessedResultsIfNeeded:(BOOL)ifNeeded
{
	@synchronized(self)
	{
		if (!ifNeeded || (_needsRecomputation && ifNeeded))
		{
			NSMutableIndexSet *removeIndexes = nil;
			NSMutableArray *newProcessedResults = [[NSMutableArray alloc] initWithArray:_fullQueryResults];

			// Apply filter(s)
			if (_filters.count > 0)
			{
				for (id<OCQueryFilter> filter in _filters)
				{
					[_fullQueryResults enumerateObjectsUsingBlock:^(OCItem *item, NSUInteger idx, BOOL *stop) {
						if (![filter query:self shouldIncludeItem:item])
						{
							[removeIndexes addIndex:idx];
						}
					}];
				}

				[newProcessedResults removeObjectsAtIndexes:removeIndexes];
			}

			// Apply comparator
			if (_sortComparator != nil)
			{
				[newProcessedResults sortUsingComparator:_sortComparator];
			}

			// We just recomputed
			_processedQueryResults = newProcessedResults;
			_needsRecomputation = NO;
		}
	}
}

#pragma mark - Needs recomputation
- (void)setNeedsRecomputation
{
	@synchronized(self)
	{
		_needsRecomputation = YES;
		self.hasChangesAvailable = YES;
	}
}

#pragma mark - Queue
- (void)queueBlock:(dispatch_block_t)block
{
	dispatch_async(_queue, block);
}

@end
