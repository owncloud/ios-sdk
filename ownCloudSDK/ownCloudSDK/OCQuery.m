//
//  OCQuery.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 05.02.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import "OCQuery.h"

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
	
	return (query);
}

#pragma mark - Filtering
- (void)addFilter:(id<OCQueryFilter>)filter withIdentifier:(OCQueryFilterIdentifier)identifier
{
	// Stub implementation
}

- (id<OCQueryFilter>)filterWithIdentifier:(OCQueryFilterIdentifier)identifier
{
	// Stub implementation
	return (nil);
}

- (void)removeFilter:(id<OCQueryFilter>)filter
{
	// Stub implementation
}

#pragma mark - Change Sets
- (void)requestChangeSetWithFlags:(OCQueryChangeSetRequestFlag)flag completionHandler:(OCQueryChangeSetRequestCompletionHandler)completionHandler
{
	// Stub implementation
}

@end
