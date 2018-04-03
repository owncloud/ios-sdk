//
//  OCQuery+OCCore.m
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

#import "OCQuery+OCCore.h"

@implementation OCQuery (OCCore)

- (void)updateWithFullResults:(NSMutableArray <OCItem *> *)fullQueryResults
{
	@synchronized(self)
	{
		_fullQueryResults = fullQueryResults;

		[self updateProcessedResults];
	}
}

- (void)updateProcessedResults
{
	@synchronized(self)
	{
		NSMutableIndexSet *removeIndexes = nil;

		[_processedQueryResults setArray:_fullQueryResults];

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

			[_processedQueryResults removeObjectsAtIndexes:removeIndexes];
		}

		// Apply comparator
		if (_sortComparator != nil)
		{
			[_processedQueryResults sortUsingComparator:_sortComparator];
		}
	}
}

@end
