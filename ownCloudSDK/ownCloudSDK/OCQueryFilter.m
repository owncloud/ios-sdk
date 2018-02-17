//
//  OCQueryFilter.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 06.02.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

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
