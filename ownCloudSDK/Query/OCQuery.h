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
#import "OCTypes.h"
#import "OCQueryFilter.h"
#import "OCItem.h"
#import "OCQueryChangeSet.h"

#pragma mark - Types
typedef NS_ENUM(NSUInteger, OCQueryState)
{
	OCQueryStateStopped,			//!< Query is not running

	OCQueryStateStarted,			//!< Query has (just) been started
	OCQueryStateContentsFromCache,		//!< Query provides contents from the cache
	OCQueryStateWaitingForServerReply,	//!< Query has sent a request to the server and awaits its reply

	OCQueryStateTargetRemoved,		//!< The resource targeted by the query is unavailable or has been removed from the server. The query has been removed.
	OCQueryStateIdle			//!< Query contents is up-to-date, no operations are ongoing
};

typedef NS_OPTIONS(NSUInteger, OCQueryChangeSetRequestFlag)
{
	OCQueryChangeSetRequestFlagDefault = 0, 		//!< Default options.
	OCQueryChangeSetRequestFlagOnlyResults = (1 << 0)  	//!< Return a changeset that only contains the queryResults array.
};

NS_ASSUME_NONNULL_BEGIN

typedef void(^OCQueryChangesAvailableNotificationHandler)(OCQuery *query);
typedef void(^OCQueryChangeSetRequestCompletionHandler)(OCQuery *query, OCQueryChangeSet * _Nullable changeset);

@protocol OCQueryDelegate <NSObject>

- (void)query:(OCQuery *)query failedWithError:(NSError *)error; //!< Notifies the delegate that the query failed with an error (f.ex. network/server unreachable) and was removed from the core.
- (void)queryHasChangesAvailable:(OCQuery *)query; //!< Notifies the delegate that changes are available and can be collected via -requestChangeSetWithFlags:completionHandler:

@end

#pragma mark - Query
@interface OCQuery : NSObject
{
	BOOL _includeRootItem;
	OCItem *_rootItem;

	NSMutableArray <OCItem *> *_fullQueryResults; 	  		// All items matching the query, before applying filters and sorting.
	NSMutableArray <OCItem *> *_processedQueryResults; 		// Like full query results, but after applying sorting and filtering.

	NSArray <OCItem *> *_lastQueryResults;				// processedQueryResults at the time a changeset was last requested.

	NSMutableArray <id<OCQueryFilter>> *_filters;
	NSMutableDictionary <OCQueryFilterIdentifier, id<OCQueryFilter>> *_filtersByIdentifier; // Filters to be applied on the query results, by identifier

	NSComparator _sortComparator;

	dispatch_queue_t _queue;

	OCSyncAnchor _lastMergeSyncAnchor; // Sync anchor at the time of the last call to -mergeItemsToFullQueryResults:

	BOOL _needsRecomputation;
}

#pragma mark - Initializers
+ (instancetype)queryForPath:(OCPath)queryPath;	//!< Query for directory
+ (instancetype)queryWithItem:(OCItem *)item;   //!< Query for single file item
+ (instancetype)queryForChangesSinceSyncAnchor:(OCSyncAnchor)syncAnchor; //!< Query for changed folders since (but not including) a particular sync anchor

#pragma mark - Location
@property(nullable, strong) OCPath queryPath;	//!< Path targeted by the query, relative to the server's root directory.
@property(nullable, strong) OCItem *queryItem;	//!< For queries targeting single items, the item being targeted by the query.
@property(nullable, strong) OCSyncAnchor querySinceSyncAnchor; //!< For queries targeting all changes occuring since a particular sync anchor.

#pragma mark - State
@property(assign) OCQueryState state;		//!< Current state of the query

#pragma mark - Sorting
@property(nullable,copy,nonatomic) NSComparator sortComparator;	//!< Comparator used to sort the query results

#pragma mark - Filtering
@property(nullable,strong) NSArray <id<OCQueryFilter>> *filters; //!< Filters to be applied on the query results

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
