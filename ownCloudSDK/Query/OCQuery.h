//
//  OCQuery.h
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

#import <Foundation/Foundation.h>
#import "OCCoreQuery.h"
#import "OCTypes.h"
#import "OCQueryFilter.h"
#import "OCItem.h"
#import "OCQueryChangeSet.h"
#import "OCCoreItemList.h"
#import "OCQueryCondition.h"
#import "OCCancelAction.h"

#pragma mark - Types
typedef NS_ENUM(NSUInteger, OCQueryState)
{
	OCQueryStateStopped,			//!< 0: Query is not running

	OCQueryStateStarted,			//!< 1: Query has (just) been started
	OCQueryStateContentsFromCache,		//!< 2: Query provides contents from the cache
	OCQueryStateWaitingForServerReply,	//!< 3: Query has sent a request to the server and awaits its reply

	OCQueryStateTargetRemoved,		//!< 4: The resource targeted by the query is unavailable or has been removed from the server. The query has been removed.
	OCQueryStateIdle			//!< 5: Query contents is up-to-date, no operations are ongoing
};

typedef NS_OPTIONS(NSUInteger, OCQueryChangeSetRequestFlag)
{
	OCQueryChangeSetRequestFlagDefault = 0, 		//!< Default options.
	OCQueryChangeSetRequestFlagOnlyResults = (1 << 0)  	//!< Return a changeset that only contains the queryResults array.
};

NS_ASSUME_NONNULL_BEGIN

typedef void(^OCQueryChangesAvailableNotificationHandler)(OCQuery *query);
typedef void(^OCQueryChangeSetRequestCompletionHandler)(OCQuery *query, OCQueryChangeSet * _Nullable changeset);

typedef void(^OCQueryCustomResultHandler)(NSError * _Nullable error, NSArray <OCItem *> * _Nullable initialItems);
typedef void(^OCQueryCustomSource)(OCCore *core, OCQuery *query, OCQueryCustomResultHandler resultHandler);

@protocol OCQueryDelegate <NSObject>

- (void)query:(OCQuery *)query failedWithError:(NSError *)error; //!< Notifies the delegate that the query failed with an error (f.ex. network/server unreachable) and was removed from the core.
- (void)queryHasChangesAvailable:(OCQuery *)query; //!< Notifies the delegate that changes are available and can be collected via -requestChangeSetWithFlags:completionHandler:

@end

#pragma mark - Query
@interface OCQuery : OCCoreQuery
{
	BOOL _includeRootItem;
	OCItem *_rootItem;

	NSMutableArray <OCItem *> *_fullQueryResults; 	  		// All items matching the query, before applying filters and sorting.
	NSMutableArray <OCItem *> *_processedQueryResults; 		// Like full query results, but after applying sorting and filtering.

	OCCoreItemList *_fullQueryResultsItemList;			// Cached item list of _fullQueryResults used in the default

	NSArray <OCItem *> *_lastQueryResults;				// processedQueryResults at the time a changeset was last requested.

	NSMutableArray <id<OCQueryFilter>> *_filters;
	NSMutableDictionary <OCQueryFilterIdentifier, id<OCQueryFilter>> *_filtersByIdentifier; // Filters to be applied on the query results, by identifier

	NSComparator _sortComparator;

	dispatch_queue_t _queue;

	OCSyncAnchor _lastMergeSyncAnchor; // Sync anchor at the time of the last call to -mergeItemsToFullQueryResults:

	BOOL _needsRecomputation;
}

#pragma mark - Initializers
// Native queries
+ (instancetype)queryForPath:(OCPath)queryPath;	//!< Query for directory
+ (instancetype)queryWithItem:(OCItem *)item;   //!< Query for single file item
+ (instancetype)queryForChangesSinceSyncAnchor:(OCSyncAnchor)syncAnchor; //!< Query for changed folders since (but not including) a particular sync anchor

// Custom queries
/**
 Creates a custom query.

 A custom query starts out empty and - when started - is initially filled with the items asynchronously returned by the provided customSource.

 The query results are subsequently kept up to date with just the changes (additions, updates, deletions) using the provided inputFilter to determine relevance.

 If a query is reloaded, the customSource is invoked again and the query results replaced with the items it provides.

 @param customSource Called on start and reload of the query.
 @param inputFilter Filter to determine relevance to the query results.
 @return An OCQuery instance.
 */
+ (instancetype)queryWithCustomSource:(OCQueryCustomSource)customSource inputFilter:(id<OCQueryFilter>)inputFilter;
+ (instancetype)queryWithCondition:(OCQueryCondition *)condition inputFilter:(nullable id<OCQueryFilter>)inputFilter; //!< Custom query for items matching the condition. An inputFilter is automatically generated from the condition. However, for best performance, an inputFilter should be supplied where possible.

#pragma mark - Location
@property(nullable, strong) OCPath queryPath;	//!< Path targeted by the query, relative to the server's root directory.
@property(nullable, strong) OCItem *queryItem;	//!< For queries targeting single items, the item being targeted by the query.
@property(nullable, strong) OCSyncAnchor querySinceSyncAnchor; //!< For queries targeting all changes occuring since a particular sync anchor.

#pragma mark - Custom queries
@property(assign) BOOL isCustom; //!< YES if this is a custom query and handles updates itself via the -updateWithAddedItems:updatedItems:removedItems:.. method
@property(nullable, copy) OCQueryCustomSource customSource; //!< Convenience block used by -provideFullQueryResultsForCore: (=> see its description for more info).
@property(nullable, strong) id<OCQueryFilter> inputFilter; //!< (Input) filter to apply to items to determine if they should be included in the full query result set using the default -updateWithAddedItems:updatedItems:removedItems: implementation.
- (void)provideFullQueryResultsForCore:(OCCore *)core resultHandler:(OCQueryCustomResultHandler)resultHandler; //!< Method used to request full query results for the query upon start and reload of a custom query. The default implementation calls .customSource if it is set.
- (void)modifyFullQueryResults:(BOOL(^)(NSMutableArray <OCItem *> *fullQueryResults, OCCoreItemList *(^coreItemListProvider)(void)))modificator; //!< Intended for use by -updateWithAddedItems:updatedItems:removedItems: to modify the internally stored array of result items for the query (provided as fullQueryResults). The coreItemListProvider block is provided as a convenience to retrieve a cached (!) OCCoreItemList of the supplied fullQueryResults. The block should return YES if it made changes, NO otherwise.
- (void)updateWithAddedItems:(nullable OCCoreItemList *)addedItems updatedItems:(nullable OCCoreItemList *)updatedItems removedItems:(nullable OCCoreItemList *)removedItems; //!< OCQuery subclasses can provide their own custom updating logic for custom queries (.isCustom = YES) here. The default implementation uses .inputFilter in combination with -modifyFullQueryResults: to keep the internal full query results up-to-date.

#pragma mark - State
@property(assign) OCQueryState state;		//!< Current state of the query
@property(strong,nullable) OCCancelAction *stopAction; //!< Cancel action thats invoked when the query

#pragma mark - Sorting
@property(nullable,copy,nonatomic) NSComparator sortComparator;	//!< Comparator used to sort the query results

#pragma mark - Filtering
@property(nullable,strong) NSArray <id<OCQueryFilter>> *filters; //!< (Output) filters to be applied on the query results.

- (void)addFilter:(id<OCQueryFilter>)filter withIdentifier:(OCQueryFilterIdentifier)identifier;  //!< Adds a filter to the query.
- (nullable id<OCQueryFilter>)filterWithIdentifier:(OCQueryFilterIdentifier)identifier; //!< Retrieve a filter by its identifier.
- (void)updateFilter:(id<OCQueryFilter>)filter applyChanges:(void(^)(id<OCQueryFilter> filter))applyChangesBlock; //!< Apply changes to a filter
- (void)removeFilter:(id<OCQueryFilter>)filter; //!< Remove a filter

#pragma mark - Query results
@property(nullable, strong,nonatomic) NSArray <OCItem *> *queryResults; //!< Returns an array of OCItems representing the latest results after sorting and filtering. The contents is identical to that of _processedQueryResults at the time of calling. It does not affect the contents of _lastQueryResults.
@property(nullable, strong) OCItem *rootItem; //!< The rootItem is the item at the root of the query - representing the item at .queryPath/.queryItem.path.
@property(assign,nonatomic) BOOL includeRootItem; //!< If YES, the rootItem is included in the queryResults and change sets. If NO, it's only exposed via .rootItem.

#pragma mark - Change Sets
@property(assign,nonatomic) BOOL hasChangesAvailable;	//!< Indicates that query result changes are available for retrieval
@property(nullable, weak) id <OCQueryDelegate> delegate;	//!< Query Delegate that's informed about the availability of changes (optional)
@property(nullable, copy) OCQueryChangesAvailableNotificationHandler changesAvailableNotificationHandler; //!< Block that's called whenever changes are available (optional)

- (void)requestChangeSetWithFlags:(OCQueryChangeSetRequestFlag)flags completionHandler:(OCQueryChangeSetRequestCompletionHandler)completionHandler; //!< Requests a changeset containing all changes since the last request. Pass in OCQueryChangeSetRequestFlagOnlyResults as flag of you're only interested in the queryResults array and don't need a detailed record of changes.

@end

extern NSNotificationName OCQueryDidChangeStateNotification; //!< Notification sent when a query's state has changed
extern NSNotificationName OCQueryHasChangesAvailableNotification; //!< Notification sent when a query has changes available

NS_ASSUME_NONNULL_END
