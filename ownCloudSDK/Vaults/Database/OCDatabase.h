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

@class OCDatabase;
@class OCItem;
@class OCItemVersionIdentifier;
@class OCSyncRecord;
@class OCFile;

typedef void(^OCDatabaseCompletionHandler)(OCDatabase *db, NSError *error);
typedef void(^OCDatabaseRetrieveCompletionHandler)(OCDatabase *db, NSError *error, OCSyncAnchor syncAnchor, NSArray <OCItem *> *items);
typedef void(^OCDatabaseRetrieveItemCompletionHandler)(OCDatabase *db, NSError *error, OCSyncAnchor syncAnchor, OCItem *item);
typedef void(^OCDatabaseRetrieveThumbnailCompletionHandler)(OCDatabase *db, NSError *error, CGSize maximumSizeInPixels, NSString *mimeType, NSData *thumbnailData);
typedef void(^OCDatabaseRetrieveSyncRecordCompletionHandler)(OCDatabase *db, NSError *error, OCSyncRecord *syncRecord);
typedef void(^OCDatabaseRetrieveSyncRecordsCompletionHandler)(OCDatabase *db, NSError *error, NSArray <OCSyncRecord *> *syncRecords);
typedef void(^OCDatabaseProtectedBlockCompletionHandler)(NSError *error, NSNumber *previousCounterValue, NSNumber *newCounterValue);

typedef NSString* OCDatabaseTableName NS_TYPED_ENUM;
typedef NSString* OCDatabaseCounterIdentifier;

@interface OCDatabase : NSObject <OCLogTagging>
{
	NSURL *_databaseURL;

	NSMutableArray <OCSQLiteTableSchema *> *_tableSchemas;

	NSUInteger _removedItemRetentionLength;

	OCSQLiteDB *_sqlDB;
}

@property(strong) NSURL *databaseURL;

@property(assign) NSUInteger removedItemRetentionLength;

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

- (void)retrieveCacheItemForFileID:(OCFileID)fileID completionHandler:(OCDatabaseRetrieveItemCompletionHandler)completionHandler;

- (void)retrieveCacheItemsAtPath:(OCPath)path itemOnly:(BOOL)itemOnly completionHandler:(OCDatabaseRetrieveCompletionHandler)completionHandler;
- (NSArray <OCItem *> *)retrieveCacheItemsSyncAtPath:(OCPath)path itemOnly:(BOOL)itemOnly error:(NSError * __autoreleasing *)outError syncAnchor:(OCSyncAnchor __autoreleasing *)outSyncAnchor;

- (void)retrieveCacheItemsUpdatedSinceSyncAnchor:(OCSyncAnchor)synchAnchor foldersOnly:(BOOL)foldersOnly completionHandler:(OCDatabaseRetrieveCompletionHandler)completionHandler;

#pragma mark - Thumbnail interface
- (void)retrieveThumbnailDataForItemVersion:(OCItemVersionIdentifier *)itemVersion specID:(NSString *)specID maximumSizeInPixels:(CGSize)maximumSizeInPixels completionHandler:(OCDatabaseRetrieveThumbnailCompletionHandler)completionHandler;
- (void)storeThumbnailData:(NSData *)thumbnailData withMIMEType:(NSString *)mimeType specID:(NSString *)specID forItemVersion:(OCItemVersionIdentifier *)itemVersion maximumSizeInPixels:(CGSize)maximumSizeInPixels completionHandler:(OCDatabaseCompletionHandler)completionHandler;

#pragma mark - File interface
//- (void)addFiles:(NSArray <OCFile *> *)files completionHandler:(OCDatabaseCompletionHandler)completionHandler;
//- (void)updateFiles:(NSArray <OCFile *> *)files completionHandler:(OCDatabaseCompletionHandler)completionHandler;
//- (void)removeFiles:(NSArray <OCFile *> *)files completionHandler:(OCDatabaseCompletionHandler)completionHandler;

#pragma mark - Sync interface
- (void)addSyncRecords:(NSArray <OCSyncRecord *> *)syncRecords completionHandler:(OCDatabaseCompletionHandler)completionHandler;
- (void)updateSyncRecords:(NSArray <OCSyncRecord *> *)syncRecords completionHandler:(OCDatabaseCompletionHandler)completionHandler;
- (void)removeSyncRecords:(NSArray <OCSyncRecord *> *)syncRecords completionHandler:(OCDatabaseCompletionHandler)completionHandler;

- (void)retrieveSyncRecordForID:(OCSyncRecordID)recordID completionHandler:(OCDatabaseRetrieveSyncRecordCompletionHandler)completionHandler;
- (void)retrieveSyncRecordsForPath:(OCPath)path action:(OCSyncActionIdentifier)action inProgressSince:(NSDate *)inProgressSince completionHandler:(OCDatabaseRetrieveSyncRecordsCompletionHandler)completionHandler;

#pragma mark - Log interface

#pragma mark - Integrity / Synchronization primitives
- (void)retrieveValueForCounter:(OCDatabaseCounterIdentifier)counterIdentifier completionHandler:(void(^)(NSError *error, NSNumber *counterValue))completionHandler;
- (void)increaseValueForCounter:(OCDatabaseCounterIdentifier)counterIdentifier withProtectedBlock:(NSError *(^)(NSNumber *previousCounterValue, NSNumber *newCounterValue))protectedBlock completionHandler:(OCDatabaseProtectedBlockCompletionHandler)completionHandler;

@end

#import "OCDatabase+Schemas.h"
