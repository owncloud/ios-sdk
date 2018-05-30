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

@class OCDatabase;
@class OCItem;
@class OCItemVersionIdentifier;

typedef void(^OCDatabaseCompletionHandler)(OCDatabase *db, NSError *error);
typedef void(^OCDatabaseRetrieveCompletionHandler)(OCDatabase *db, NSError *error, NSArray <OCItem *> *items);
typedef void(^OCDatabaseRetrieveThumbnailCompletionHandler)(OCDatabase *db, NSError *error, CGSize maximumSizeInPixels, NSString *mimeType, NSData *thumbnailData);
typedef void(^OCDatabaseProtectedBlockCompletionHandler)(NSError *error, NSNumber *previousCounterValue, NSNumber *newCounterValue);

typedef NSString* OCDatabaseTableName NS_TYPED_ENUM;
typedef NSString* OCDatabaseCounterIdentifier;

@interface OCDatabase : NSObject
{
	NSURL *_databaseURL;

	NSMutableArray <OCSQLiteTableSchema *> *_tableSchemas;

	OCSQLiteDB *_sqlDB;
}

@property(strong) NSURL *databaseURL;

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

- (void)retrieveCacheItemsAtPath:(OCPath)path completionHandler:(OCDatabaseRetrieveCompletionHandler)completionHandler;
- (void)retrieveCacheItemsUpdatedSinceSyncAnchor:(OCSyncAnchor)synchAnchor completionHandler:(OCDatabaseRetrieveCompletionHandler)completionHandler;

#pragma mark - Thumbnail interface
- (void)storeThumbnailData:(NSData *)thumbnailData withMIMEType:(NSString *)mimeType forItemVersion:(OCItemVersionIdentifier *)item maximumSizeInPixels:(CGSize)maxSize completionHandler:(OCDatabaseCompletionHandler)completionHandler;
- (void)retrieveThumbnailDataForItemVersion:(OCItemVersionIdentifier *)item maximumSizeInPixels:(CGSize)maxSize completionHandler:(OCDatabaseRetrieveThumbnailCompletionHandler)completionHandler;

#pragma mark - Sync interface

#pragma mark - Log interface

#pragma mark - Integrity / Synchronization primitives
- (void)retrieveValueForCounter:(OCDatabaseCounterIdentifier)counterIdentifier completionHandler:(void(^)(NSError *error, NSNumber *counterValue))completionHandler;
- (void)increaseValueForCounter:(OCDatabaseCounterIdentifier)counterIdentifier withProtectedBlock:(NSError *(^)(NSNumber *previousCounterValue, NSNumber *newCounterValue))protectedBlock completionHandler:(OCDatabaseProtectedBlockCompletionHandler)completionHandler;

@end

#import "OCDatabase+Schemas.h"
