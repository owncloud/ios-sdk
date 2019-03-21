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

#import "OCCore.h"
#import "OCQuery.h"
#import "OCQuery+Internal.h"
#import "OCLogger.h"
#import "OCQueryCondition+Item.h"
#import "NSError+OCError.h"

#import <objc/runtime.h>

@implementation OCQuery

#pragma mark - Location
@synthesize queryPath = _queryPath;
@synthesize queryItem = _queryItem;

#pragma mark - State
@synthesize state = _state;

#pragma mark - Sorting
@synthesize sortComparator = _sortComparator;

#pragma mark - Filtering
@synthesize filters = _filters;

#pragma mark - Query results
@synthesize queryResults = _queryResults;
@synthesize rootItem = _rootItem;
@synthesize includeRootItem = _includeRootItem;

#pragma mark - Change Sets
@synthesize hasChangesAvailable = _hasChangesAvailable;
@synthesize delegate = _delegate;
@synthesize changesAvailableNotificationHandler = _changesAvailableNotificationHandler;

#pragma mark - Initializers
+ (instancetype)queryForPath:(OCPath)queryPath
{
	OCQuery *query = [self new];
	
	query.queryPath = queryPath;
	query.includeRootItem = NO;
	
	return (query);
}

+ (instancetype)queryWithItem:(OCItem *)rootItem
{
	OCQuery *query = [self new];
	
	query.queryItem = rootItem;
	query.includeRootItem = YES;

	return (query);
}

+ (instancetype)queryForChangesSinceSyncAnchor:(OCSyncAnchor)syncAnchor
{
	OCQuery *query = [self new];

	query.querySinceSyncAnchor = syncAnchor;

	return (query);
}

+ (instancetype)queryWithCustomSource:(OCQueryCustomSource)customSource inputFilter:(id<OCQueryFilter>)inputFilter
{
	OCQuery *query = [self new];

	query.isCustom = YES;

	query.customSource = customSource;
	query.inputFilter = inputFilter;

	return (query);
}

+ (instancetype)queryWithCondition:(OCQueryCondition *)condition inputFilter:(nullable id<OCQueryFilter>)inputFilter
{
	OCQueryCustomSource customSource = ^(OCCore *core, OCQuery *query, OCQueryCustomResultHandler resultHandler) {
		[core.vault.database retrieveCacheItemsForQueryCondition:condition completionHandler:^(OCDatabase *db, NSError *error, OCSyncAnchor syncAnchor, NSArray<OCItem *> *items) {
			resultHandler(error, items);
		}];
	};
	OCQuery *query;

	if (inputFilter == nil)
	{
		inputFilter = [OCQueryFilter filterWithHandler:^BOOL(OCQuery *query, OCQueryFilter *filter, OCItem *item) {
			return ([condition fulfilledByItem:item]);
		}];
	}

	if ((query = [self queryWithCustomSource:customSource inputFilter:inputFilter]) != nil)
	{
		query.sortComparator = condition.itemComparator;
	}

	return (query);
}

- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_queue = dispatch_queue_create(NULL, DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL);
	}

	return (self);
}

#pragma mark - Custom queries
- (void)provideFullQueryResultsForCore:(OCCore *)core resultHandler:(OCQueryCustomResultHandler)resultHandler
{
	if (_customSource != nil)
	{
		_customSource(core, self, resultHandler);
	}
	else
	{
		OCLogWarning(@"full query results requested for %@, but .customSource==nil - returning insufficient parameters error", self);
		resultHandler(OCError(OCErrorInsufficientParameters), nil);
	}
}

- (void)modifyFullQueryResults:(BOOL(^)(NSMutableArray <OCItem *> *fullQueryResults, OCCoreItemList *(^CoreItemListProvider)(void)))modificator
{
	if (modificator != nil)
	{
		@synchronized(self)
		{
			if (modificator(_fullQueryResults, ^{ return ([self fullQueryResultsItemList]); }))
			{
				// Release cached item list
				_fullQueryResultsItemList = nil;

				// Signal recomputation is needed
				[self setNeedsRecomputation];
			}
		}
	}
}

- (void)updateWithAddedItems:(nullable OCCoreItemList *)addedItems updatedItems:(nullable OCCoreItemList *)updatedItems removedItems:(nullable OCCoreItemList *)removedItems
{
	if (self.inputFilter != nil)
	{
		[self modifyFullQueryResults:^BOOL(NSMutableArray<OCItem *> * _Nonnull fullQueryResults, OCCoreItemList * _Nonnull (^ _Nonnull coreItemListProvider)(void)) {
			BOOL madeChanges = NO;

			if (addedItems != nil)
			{
				for (OCItem *addedItem in addedItems.items)
				{
					if ([self.inputFilter query:self shouldIncludeItem:addedItem])
					{
						// Add new items that match the filter
						[fullQueryResults addObject:addedItem];
						madeChanges = YES;
					}
				}
			}

			if (updatedItems != nil)
			{
				OCCoreItemList *fullQueryResultsItemList = coreItemListProvider();

				for (OCItem *updatedItem in updatedItems.items)
				{
					OCLocalID updatedItemLocalID = updatedItem.localID;
					OCItem *existingItem = (updatedItemLocalID != nil) ? fullQueryResultsItemList.itemsByLocalID[updatedItemLocalID] : nil;

					if ([self.inputFilter query:self shouldIncludeItem:updatedItem])
					{
						if (existingItem != nil)
						{
							// Update existing items that match the filter
							NSUInteger indexOfExistingItem;

							if ((indexOfExistingItem = [fullQueryResults indexOfObjectIdenticalTo:existingItem]) != NSNotFound)
							{
								[fullQueryResults replaceObjectAtIndex:indexOfExistingItem withObject:updatedItem];
							}
						}
						else
						{
							// Add items that match the filter after having been updated
							[fullQueryResults addObject:updatedItem];
						}

						madeChanges = YES;
					}
					else
					{
						if (existingItem != nil)
						{
							// Remove items that no longer match the filter after having been updated
							[fullQueryResults removeObject:existingItem];
							madeChanges = YES;
						}
					}
				}
			}

			if (removedItems != nil)
			{
				OCCoreItemList *fullQueryResultsItemList = coreItemListProvider();

				// Remove removed items in the query result set
				for (OCItem *removedItem in removedItems.items)
				{
					OCItem *removeItem;

					if ((removeItem = fullQueryResultsItemList.itemsByLocalID[removedItem.localID]) != nil)
					{
						[fullQueryResults removeObject:removeItem];
						madeChanges = YES;
					}
				}
			}

			return (madeChanges);
		}];
	}
	else
	{
		OCLogWarning(@"-[OCQuery updateWithAddedItems:updatedItems:removedItems:] not performing any action on custom query %@ because no inputFilter is set", self);
	}
}

#pragma mark - Sorting
- (void)setSortComparator:(NSComparator)sortComparator
{
	@synchronized(self)
	{
		_sortComparator = [sortComparator copy];
	}

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

- (void)updateFilter:(id<OCQueryFilter>)filter applyChanges:(void(^)(id<OCQueryFilter> filter))applyChangesBlock
{
	if (filter == nil) { return; }
	if (applyChangesBlock == nil) { return; }

	@synchronized(self)
	{
		applyChangesBlock(filter);
	}

	[self setNeedsRecomputation];
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

#pragma mark - Query results
- (NSArray<OCItem *> *)queryResults
{
	NSArray<OCItem *> *queryResults = nil;

	@synchronized(self)
	{
		[self updateProcessedResultsIfNeeded:YES];

		queryResults = _processedQueryResults;
	}

	return (queryResults);
}

#pragma mark - Change Sets
- (void)setHasChangesAvailable:(BOOL)hasChangesAvailable
{
	@synchronized(self)
	{
		_hasChangesAvailable = YES;
	}

	if (_hasChangesAvailable)
	{
		if ((_delegate != nil) && ([_delegate respondsToSelector:@selector(queryHasChangesAvailable:)]))
		{
			[_delegate queryHasChangesAvailable:self];
		}

		if (_changesAvailableNotificationHandler != nil)
		{
			_changesAvailableNotificationHandler(self);
		}
	}
}

- (void)requestChangeSetWithFlags:(OCQueryChangeSetRequestFlag)flags completionHandler:(OCQueryChangeSetRequestCompletionHandler)completionHandler
{
	NSArray <OCItem *> *processedResults=nil, *lastResults=nil;
	OCSyncAnchor syncAnchor = nil;
	BOOL changesAvailable = NO;

	@synchronized(self)
	{
		[self updateProcessedResultsIfNeeded:YES];

		processedResults = _processedQueryResults;
		lastResults = _lastQueryResults;

		changesAvailable = _hasChangesAvailable;

		_lastQueryResults = _processedQueryResults;

		if (_hasChangesAvailable)
		{
			[self willChangeValueForKey:@"hasChangesAvailable"];
			_hasChangesAvailable = NO;
			[self didChangeValueForKey:@"hasChangesAvailable"];
		}

		// Special handling for queries targeting a sync anchor: drop all entries when a change set is requested
		if (self.querySinceSyncAnchor != nil)
		{
			_fullQueryResults = [NSMutableArray new];
			_processedQueryResults = [NSMutableArray new];
			_lastQueryResults = [NSMutableArray new];

			syncAnchor = _lastMergeSyncAnchor;
		}

		// Process on serial queue in the background to ensure completionHandlers are called/change sets are returned in order of requests and to return from this method immediately
		[self queueBlock:^{
			OCQueryChangeSet *changeSet=nil;

			if (changesAvailable)
			{
				changeSet = [[OCQueryChangeSet alloc] initWithQueryResult:processedResults relativeTo:(((flags & OCQueryChangeSetRequestFlagOnlyResults)!=0)?lastResults:nil)];
			}
			else
			{
				changeSet = [[OCQueryChangeSet alloc] initWithQueryResult:processedResults relativeTo:nil];
				changeSet.containsChanges = NO;
			}

			changeSet.syncAnchor = syncAnchor;

			if (completionHandler != nil)
			{
				completionHandler(self, changeSet);
			}
		}];
	}
}

@end

NSNotificationName OCQueryDidChangeStateNotification = @"OCQueryDidChangeState";
NSNotificationName OCQueryHasChangesAvailableNotification = @"OCQueryHasChangesAvailable";
