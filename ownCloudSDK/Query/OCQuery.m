//
//  OCQuery.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 05.02.18.
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

#import "OCQuery.h"
#import <objc/runtime.h>

@implementation OCQuery

#pragma mark - Location
@synthesize queryPath = _queryPath;
@synthesize queryRootItem = _queryRootItem;

#pragma mark - State
@synthesize state = _state;

#pragma mark - Sorting
@synthesize sortComparator = _sortComparator;

#pragma mark - Filtering
@synthesize filters = _filters;

#pragma mark - Query results
@synthesize queryResults = _queryResults;

#pragma mark - Change Sets
@synthesize hasChangesAvailable = _hasChangesAvailable;
@synthesize delegate = _delegate;
@synthesize changesAvailableNotificationHandler = _changesAvailableNotificationHandler;


#pragma mark - Initializers
+ (instancetype)queryForPath:(OCPath)queryPath
{
	OCQuery *query = [self new];
	
	query.queryPath = queryPath;
	
	return (query);
}

+ (instancetype)queryWithRootItem:(OCItem *)rootItem
{
	OCQuery *query = [self new];
	
	query.queryRootItem = rootItem;
	query.queryPath = rootItem.path;

	return (query);
}

- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
	}

	return (self);
}

#pragma mark - Sorting
- (void)setSortComparator:(NSComparator)sortComparator
{
	_sortComparator = [sortComparator copy];

	[self setNeedsRecomputation];
}

#pragma mark - Filtering
- (void)addFilter:(id<OCQueryFilter>)filter withIdentifier:(OCQueryFilterIdentifier)identifier
{
	if (filter == nil) { return; }

	@synchronized(self)
	{
		if (_filters == nil) { _filters = [NSMutableArray new]; }
		if (_filtersByIdentifier == nil) { _filtersByIdentifier = [NSMutableDictionary new]; }

		[_filters addObject:filter];

		if (identifier != nil)
		{
			[_filtersByIdentifier setObject:filter forKey:identifier];
			objc_setAssociatedObject(filter, (__bridge void *)[OCQuery class], identifier, OBJC_ASSOCIATION_RETAIN);
		}
	}

	[self setNeedsRecomputation];
}

- (id<OCQueryFilter>)filterWithIdentifier:(OCQueryFilterIdentifier)identifier
{
	if (identifier == nil) { return(nil); }

	@synchronized(self)
	{
		return ([_filtersByIdentifier objectForKey:identifier]);
	}
}

- (void)removeFilter:(id<OCQueryFilter>)filter
{
	if (filter == nil) { return; }

	@synchronized(self)
	{
		NSString *identifier;

		if ((identifier = objc_getAssociatedObject(filter, (__bridge void *)[OCQuery class])) != nil)
		{
			[_filtersByIdentifier removeObjectForKey:identifier];
		}

		[_filters removeObject:filter];
	}

	[self setNeedsRecomputation];
}

#pragma mark - Change Sets
- (void)requestChangeSetWithFlags:(OCQueryChangeSetRequestFlag)flag completionHandler:(OCQueryChangeSetRequestCompletionHandler)completionHandler
{
	// Stub implementation
}

#pragma mark - Needs recomputation
- (void)setNeedsRecomputation
{
	[[NSNotificationCenter defaultCenter] postNotificationName:OCQueryNeedsRecomputationNotification object:self];
}


@end

NSNotificationName OCQueryDidChangeStateNotification = @"OCQueryDidChangeState";
NSNotificationName OCQueryDidUpdateNotification = @"OCQueryDidUpdate";
NSNotificationName OCQueryNeedsRecomputationNotification = @"OCQueryNeedsRecomputation";
