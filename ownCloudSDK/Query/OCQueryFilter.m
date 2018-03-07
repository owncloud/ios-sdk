//
//  OCQueryFilter.m
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

#import "OCQueryFilter.h"

@implementation OCQueryFilter

@synthesize filterHandler = _filterHandler;

+ (instancetype)filterWithHandler:(OCQueryFilterHandler)filterHandler
{
	OCQueryFilter *filter = [OCQueryFilter new];

	filter.filterHandler = filterHandler;
	
	return (filter);
}

- (BOOL)query:(OCQuery *)query shouldIncludeItem:(OCItem *)item //!< Returns YES if the item should be part of the query result, NO if it should not be.
{
	return (_filterHandler(query, self, item));
}

- (NSArray <OCItem *> *)query:(OCQuery *)query filterItems:(NSArray <OCItem *> *)items
{
	NSMutableArray *filteredItems = [NSMutableArray arrayWithCapacity:items.count];
	
	for (OCItem *item in items)
	{
		if (_filterHandler(query, self, item))
		{
			[filteredItems addObject:item];
		}
	}
	
	return (filteredItems);
}

@end
