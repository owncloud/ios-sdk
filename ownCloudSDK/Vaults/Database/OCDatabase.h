//
//  OCDatabase.h
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
#import <CoreGraphics/CoreGraphics.h>

#import "OCSQLiteDB.h"
#import "OCTypes.h"
#import "OCSQLiteTableSchema.h"
#import "OCLogTag.h"
#import "OCQueryCondition.h"
#import "OCCoreDirectoryUpdateJob.h"
#import "OCItemPolicy.h"

@class OCDatabase;
@class OCItem;
@class OCItemVersionIdentifier;
@class OCSyncRecord;
@class OCSyncLane;
@class OCFile;
@class OCEvent;
@class OCCoreDirectoryUpdateJob;
@class OCItemPolicy;

typedef void(^OCDatabaseCompletionHandler)(OCDatabase *db, NSError *error);
typedef void(^OCDatabaseRetrieveCompletionHandler)(OCDatabase *db, NSError *error, OCSyncAnchor syncAnchor, NSArray <OCItem *> *items);
typedef void(^OCDatabaseRetrieveItemCompletionHandler)(OCDatabase *db, NSError *error, OCSyncAnchor syncAnchor, OCItem *item);
typedef void(^OCDatabaseRetrieveThumbnailCompletionHandler)(OCDatabase *db, NSError *error, CGSize maximumSizeInPixels, NSString *mimeType, NSData *thumbnailData);
typedef void(^OCDatabaseRetrieveSyncRecordCompletionHandler)(OCDatabase *db, NSError *error, OCSyncRecord *syncRecord);
typedef void(^OCDatabaseRetrieveSyncRecordsCompletionHandler)(OCDatabase *db, NSError *error, NSArray <OCSyncRecord *> *syncRecords);
typedef void(^OCDatabaseRetrieveSyncRecordCountCompletionHandler)(OCDatabase *db, NSError *error, NSNumber *count);
typedef void(^OCDatabaseRetrieveSyncLaneCompletionHandler)(OCDatabase *db, NSError *error, OCSyncLane *syncRecord);
typedef void(^OCDatabaseRetrieveSyncLanesCompletionHandler)(OCDatabase *db, NSError *error, NSArray <OCSyncLane *> *syncLanes);
typedef void(^OCDatabaseDirectoryUpdateJobCompletionHandler)(OCDatabase *db, NSError *error, OCCoreDirectoryUpdateJob *updateJob);
typedef void(^OCDatabaseRetrieveDirectoryUpdateJobsCompletionHandler)(OCDatabase *db, NSError *error, NSArray<OCCoreDirectoryUpdateJob *> *updateJobs);
typedef void(^OCDatabaseProtectedBlockCompletionHandler)(NSError *error, NSNumber *previousCounterValue, NSNumber *newCounterValue);
typedef void(^OCDatabaseRetrieveItemPoliciesCompletionHandler)(OCDatabase *db, NSError *error, NSArray<OCItemPolicy *> *itemPolicies);
typedef void(^OCDatabaseItemIterator)(NSError *error, OCSyncAnchor syncAnchor, OCItem *item, BOOL *stop);

typedef NSArray<OCItem *> *(^OCDatabaseItemFilter)(NSArray <OCItem *> *items);

typedef NSString* OCDatabaseTableName NS_TYPED_ENUM;
typedef NSString* OCDatabaseCounterIdentifier;

@interface OCDatabase : NSObject <OCLogTagging>
{
	NSURL *_databaseURL;

	NSMutableArray <OCSQLiteTableSchema *> *_tableSchemas;

	NSMutableDictionary <OCDatabaseID, OCEvent *> *_eventsByDatabaseID;

	NSString *_selectItemRowsSQLQueryPrefix;

	NSUInteger _removedItemRetentionLength;

	OCDatabaseItemFilter _itemFilter;

	OCSyncAnchor _lastSyncAnchor;
	OCDatabaseTimestamp _lastSyncAnchorTimestamp;

	OCSQLiteDB *_sqlDB;
}

@property(strong) NSURL *databaseURL;

@property(assign) NSUInteger removedItemRetentionLength;

@property(copy) OCDatabaseItemFilter itemFilter;

@property(strong) OCSQLiteDB *sqlDB;

#pragma mark - Initialization
- (instancetype)initWithURL:(NSURL *)databaseURL;

#pragma mark - Open / Close
- (void)openWithCompletionHandler:(OCDatabaseCompletionHandler)completionHandler;
- (void)closeWithCompletionHandler:(OCDatabaseCompletionHandler)completionHandler;

#pragma mark - Transactions
- (void)performBatchUpdates:(NSError *(^)(OCDatabase *database))updates completionHandler:(OCDatabaseCompletionHandler)completionHandler; //!< Perform several operations in batch. All operations are wrapped in a transaction, so that all operations requested inside the updates block are executed synchronously. If the block returns an error, the entire transaction is rolled back.

#pragma mark - Meta data interface
- (void)addCacheItems:(NSArray <OCItem *> *)items syncAnchor:(OCSyncAnchor)syncAnchor completionHandler:(OCDatabaseCompletionHandler)completionHandler;
- (void)updateCacheItems:(NSArray <OCItem *> *)items syncAnchor:(OCSyncAnchor)syncAnchor completionHandler:(OCDatabaseCompletionHandler)completionHandler;
- (void)removeCacheItems:(NSArray <OCItem *> *)items syncAnchor:(OCSyncAnchor)syncAnchor completionHandler:(OCDatabaseCompletionHandler)completionHandler;
- (void)purgeCacheItemsWithDatabaseIDs:(NSArray <OCDatabaseID> *)databaseIDs completionHandler:(OCDatabaseCompletionHandler)completionHandler;

- (void)retrieveCacheItemForLocalID:(OCLocalID)localID completionHandler:(OCDatabaseRetrieveItemCompletionHandler)completionHandler;

- (void)retrieveCacheItemForFileID:(OCFileID)fileID completionHandler:(OCDatabaseRetrieveItemCompletionHandler)completionHandler;
- (void)retrieveCacheItemForFileID:(OCFileID)fileID includingRemoved:(BOOL)includingRemoved completionHandler:(OCDatabaseRetrieveItemCompletionHandler)completionHandler;

- (void)retrieveCacheItemsAtPath:(OCPath)path itemOnly:(BOOL)itemOnly completionHandler:(OCDatabaseRetrieveCompletionHandler)completionHandler;
- (NSArray <OCItem *> *)retrieveCacheItemsSyncAtPath:(OCPath)path itemOnly:(BOOL)itemOnly error:(NSError * __autoreleasing *)outError syncAnchor:(OCSyncAnchor __autoreleasing *)outSyncAnchor;

- (void)retrieveCacheItemsRecursivelyBelowPath:(OCPath)path includingPathItself:(BOOL)includingPathItself includingRemoved:(BOOL)includingRemoved completionHandler:(OCDatabaseRetrieveCompletionHandler)completionHandler;

- (void)retrieveCacheItemsUpdatedSinceSyncAnchor:(OCSyncAnchor)synchAnchor foldersOnly:(BOOL)foldersOnly completionHandler:(OCDatabaseRetrieveCompletionHandler)completionHandler;

- (void)retrieveCacheItemsForQueryCondition:(OCQueryCondition *)queryCondition completionHandler:(OCDatabaseRetrieveCompletionHandler)completionHandler;

- (void)iterateCacheItemsWithIterator:(OCDatabaseItemIterator)iterator; //!< Iterates through all cache items using the passed iterator block. The last invocation of the iterator will be with nil values for syncAnchor, item; NULL for stop.
- (void)iterateCacheItemsForQueryCondition:(OCQueryCondition *)queryCondition excludeRemoved:(BOOL)excludeRemoved withIterator:(OCDatabaseItemIterator)iterator; //!< Iterates through matching cache items using the passed iterator block. The last invocation of the iterator will be with nil values for syncAnchor, item; NULL for stop.

#pragma mark - Thumbnail interface
- (void)retrieveThumbnailDataForItemVersion:(OCItemVersionIdentifier *)itemVersion specID:(NSString *)specID maximumSizeInPixels:(CGSize)maximumSizeInPixels completionHandler:(OCDatabaseRetrieveThumbnailCompletionHandler)completionHandler;
- (void)storeThumbnailData:(NSData *)thumbnailData withMIMEType:(NSString *)mimeType specID:(NSString *)specID forItemVersion:(OCItemVersionIdentifier *)itemVersion maximumSizeInPixels:(CGSize)maximumSizeInPixels completionHandler:(OCDatabaseCompletionHandler)completionHandler;

#pragma mark - File interface
//- (void)addFiles:(NSArray <OCFile *> *)files completionHandler:(OCDatabaseCompletionHandler)completionHandler;
//- (void)updateFiles:(NSArray <OCFile *> *)files completionHandler:(OCDatabaseCompletionHandler)completionHandler;
//- (void)removeFiles:(NSArray <OCFile *> *)files completionHandler:(OCDatabaseCompletionHandler)completionHandler;

#pragma mark - Update Scan interface
- (void)addDirectoryUpdateJob:(OCCoreDirectoryUpdateJob *)updateScanPath completionHandler:(OCDatabaseDirectoryUpdateJobCompletionHandler)completionHandler;
- (void)retrieveDirectoryUpdateJobsAfter:(OCCoreDirectoryUpdateJobID)jobID forPath:(OCPath)path maximumJobs:(NSUInteger)maximumJobs completionHandler:(OCDatabaseRetrieveDirectoryUpdateJobsCompletionHandler)completionHandler;
- (void)removeDirectoryUpdateJobWithID:(OCCoreDirectoryUpdateJobID)jobID completionHandler:(OCDatabaseCompletionHandler)completionHandler;

#pragma mark - Sync Lane interface
- (void)addSyncLane:(OCSyncLane *)lane completionHandler:(OCDatabaseCompletionHandler)completionHandler;
- (void)updateSyncLane:(OCSyncLane *)lane completionHandler:(OCDatabaseCompletionHandler)completionHandler;
- (void)removeSyncLane:(OCSyncLane *)lane completionHandler:(OCDatabaseCompletionHandler)completionHandler;
- (void)retrieveSyncLaneForID:(OCSyncLaneID)laneID completionHandler:(OCDatabaseRetrieveSyncLaneCompletionHandler)completionHandler;
- (void)retrieveSyncLanesWithCompletionHandler:(OCDatabaseRetrieveSyncLanesCompletionHandler)completionHandler;
- (OCSyncLane *)laneForTags:(NSSet <OCSyncLaneTag> *)tags updatedLanes:(BOOL *)outUpdatedLanes readOnly:(BOOL)readOnly;

#pragma mark - Sync Journal interface
- (void)addSyncRecords:(NSArray <OCSyncRecord *> *)syncRecords completionHandler:(OCDatabaseCompletionHandler)completionHandler;
- (void)updateSyncRecords:(NSArray <OCSyncRecord *> *)syncRecords completionHandler:(OCDatabaseCompletionHandler)completionHandler;
- (void)removeSyncRecords:(NSArray <OCSyncRecord *> *)syncRecords completionHandler:(OCDatabaseCompletionHandler)completionHandler;
- (void)numberOfSyncRecordsOnSyncLaneID:(OCSyncLaneID)laneID completionHandler:(OCDatabaseRetrieveSyncRecordCountCompletionHandler)completionHandler;

- (void)retrieveSyncRecordForID:(OCSyncRecordID)recordID completionHandler:(OCDatabaseRetrieveSyncRecordCompletionHandler)completionHandler;
- (void)retrieveSyncRecordAfterID:(OCSyncRecordID)recordID onLaneID:(OCSyncLaneID)laneID completionHandler:(OCDatabaseRetrieveSyncRecordCompletionHandler)completionHandler;
- (void)retrieveSyncRecordsForPath:(OCPath)path action:(OCSyncActionIdentifier)action inProgressSince:(NSDate *)inProgressSince completionHandler:(OCDatabaseRetrieveSyncRecordsCompletionHandler)completionHandler;

#pragma mark - Event interface
- (void)queueEvent:(OCEvent *)event forSyncRecordID:(OCSyncRecordID)syncRecordID processSession:(OCProcessSession *)processSession completionHandler:(OCDatabaseCompletionHandler)completionHandler; //!< Queues an event for a OCSyncRecordID. Under the hood, adds this to the events table while keeping it cached in memory (to preserve ephermal data).
- (BOOL)queueContainsEvent:(OCEvent *)event; //!< Checks if an event with the same UUID already exists in the database
- (OCEvent *)nextEventForSyncRecordID:(OCSyncRecordID)syncRecordID afterEventID:(OCDatabaseID)eventID; //!< Requests the oldest available event for the OCSyncRecordID.
- (NSError *)removeEvent:(OCEvent *)event; //!< Deletes the row for the OCEvent from the database.

#pragma mark - Item policy interface
- (void)addItemPolicy:(OCItemPolicy *)itemPolicy completionHandler:(OCDatabaseCompletionHandler)completionHandler;
- (void)updateItemPolicy:(OCItemPolicy *)itemPolicy completionHandler:(OCDatabaseCompletionHandler)completionHandler;
- (void)removeItemPolicy:(OCItemPolicy *)itemPolicy completionHandler:(OCDatabaseCompletionHandler)completionHandler;

- (void)retrieveItemPoliciesForKind:(OCItemPolicyKind)kind path:(OCPath)path localID:(OCLocalID)localID identifier:(OCItemPolicyIdentifier)identifier completionHandler:(OCDatabaseRetrieveItemPoliciesCompletionHandler)completionHandler;

#pragma mark - Integrity / Synchronization primitives
- (void)retrieveValueForCounter:(OCDatabaseCounterIdentifier)counterIdentifier completionHandler:(void(^)(NSError *error, NSNumber *counterValue))completionHandler;
- (void)increaseValueForCounter:(OCDatabaseCounterIdentifier)counterIdentifier withProtectedBlock:(NSError *(^)(NSNumber *previousCounterValue, NSNumber *newCounterValue))protectedBlock completionHandler:(OCDatabaseProtectedBlockCompletionHandler)completionHandler;

@end

#import "OCDatabase+Schemas.h"
