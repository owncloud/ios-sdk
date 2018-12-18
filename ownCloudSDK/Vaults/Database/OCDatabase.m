//
//  OCDatabase.m
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

#import "OCDatabase.h"
#import "OCSQLiteMigration.h"
#import "OCLogger.h"
#import "OCSQLiteTransaction.h"
#import "OCSQLiteQueryCondition.h"
#import "OCItem.h"
#import "OCItemVersionIdentifier.h"
#import "OCSyncRecord.h"
#import "NSString+OCParentPath.h"
#import "NSError+OCError.h"
#import "OCMacros.h"
#import "OCSyncAction.h"

@interface OCDatabase ()
{
	NSMutableDictionary <OCSyncRecordID, NSProgress *> *_progressBySyncRecordID;
	NSMutableDictionary <OCSyncRecordID, OCCoreActionResultHandler> *_resultHandlersBySyncRecordID;
	NSMutableDictionary <OCSyncRecordID, NSDictionary<OCSyncActionParameter,id> *> *_ephermalParametersBySyncRecordID;
}

@end

@implementation OCDatabase

@synthesize databaseURL = _databaseURL;

@synthesize removedItemRetentionLength = _removedItemRetentionLength;

@synthesize sqlDB = _sqlDB;

#pragma mark - Initialization
- (instancetype)initWithURL:(NSURL *)databaseURL
{
	if ((self = [self init]) != nil)
	{
		self.databaseURL = databaseURL;

		self.removedItemRetentionLength = 100;

		_progressBySyncRecordID = [NSMutableDictionary new];
		_resultHandlersBySyncRecordID = [NSMutableDictionary new];
		_ephermalParametersBySyncRecordID = [NSMutableDictionary new];

		self.sqlDB = [[OCSQLiteDB alloc] initWithURL:databaseURL];
		[self addSchemas];
	}

	return (self);
}

#pragma mark - Open / Close
- (void)openWithCompletionHandler:(OCDatabaseCompletionHandler)completionHandler
{
	[self.sqlDB openWithFlags:OCSQLiteOpenFlagsDefault completionHandler:^(OCSQLiteDB *db, NSError *error) {
		self.sqlDB.maxBusyRetryTimeInterval = 10; // Avoid busy timeout if another process performs wide changes

		if (error == nil)
		{
			NSString *thumbnailsDBPath = [[[self.sqlDB.databaseURL URLByDeletingPathExtension] URLByAppendingPathExtension:@"tdb"] path];

			[self.sqlDB executeQuery:[OCSQLiteQuery query:@"ATTACH DATABASE ? AS 'thumb'" withParameters:@[ thumbnailsDBPath ] resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) { // relatedTo:OCDatabaseTableNameThumbnails
				if (error == nil)
				{
					[self.sqlDB applyTableSchemasWithCompletionHandler:^(OCSQLiteDB *db, NSError *error) {
						if (completionHandler!=nil)
						{
							completionHandler(self, error);
						}
					}];
				}
				else
				{
					OCLogError(@"Error attaching thumbnail database: %@", error);

					if (completionHandler!=nil)
					{
						completionHandler(self, error);
					}
				}
			}]];
		}
		else
		{
			if (completionHandler!=nil)
			{
				completionHandler(self, error);
			}
		}
	}];
}

- (void)closeWithCompletionHandler:(OCDatabaseCompletionHandler)completionHandler
{
	[self.sqlDB executeQuery:[OCSQLiteQuery query:@"DETACH DATABASE thumb" resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) { // relatedTo:OCDatabaseTableNameThumbnails
		if (error != nil)
		{
			OCLogError(@"Error detaching thumbnail database: %@", error);
		}
	}]];

	[self.sqlDB closeWithCompletionHandler:^(OCSQLiteDB *db, NSError *error) {
		if (completionHandler != nil)
		{
			completionHandler(self, error);
		}
	}];
}

#pragma mark - Transactions
- (void)performBatchUpdates:(NSError *(^)(OCDatabase *database))updates completionHandler:(OCDatabaseCompletionHandler)completionHandler
{
	[self.sqlDB executeTransaction:[OCSQLiteTransaction transactionWithBlock:^NSError *(OCSQLiteDB *db, OCSQLiteTransaction *transaction) {
		if (updates != nil)
		{
			return(updates(self));
		}

		return (nil);
	} type:OCSQLiteTransactionTypeDeferred completionHandler:^(OCSQLiteDB *db, OCSQLiteTransaction *transaction, NSError *error) {
		if (completionHandler != nil)
		{
			completionHandler(self, error);
		}
	}]];
}

#pragma mark - Meta data interface
- (void)addCacheItems:(NSArray <OCItem *> *)items syncAnchor:(OCSyncAnchor)syncAnchor completionHandler:(OCDatabaseCompletionHandler)completionHandler
{
	NSMutableArray <OCSQLiteQuery *> *queries = [[NSMutableArray alloc] initWithCapacity:items.count];

	for (OCItem *item in items)
	{
		[queries addObject:[OCSQLiteQuery queryInsertingIntoTable:OCDatabaseTableNameMetaData rowValues:@{
			@"type" 		: @(item.type),
			@"syncAnchor"		: syncAnchor,
			@"removed"		: @(0),
			@"locallyModified" 	: @(item.locallyModified),
			@"localRelativePath"	: ((item.localRelativePath!=nil) ? item.localRelativePath : [NSNull null]),
			@"path" 		: item.path,
			@"parentPath" 		: [item.path parentPath],
			@"name"			: [item.path lastPathComponent],
			@"fileID"		: item.fileID,
			@"itemData"		: [item serializedData]
		} resultHandler:^(OCSQLiteDB *db, NSError *error, NSNumber *rowID) {
			item.databaseID = rowID;
		}]];
	}

	[self.sqlDB executeTransaction:[OCSQLiteTransaction transactionWithQueries:queries type:OCSQLiteTransactionTypeDeferred completionHandler:^(OCSQLiteDB *db, OCSQLiteTransaction *transaction, NSError *error) {
		completionHandler(self, error);
	}]];
}

- (void)updateCacheItems:(NSArray <OCItem *> *)items syncAnchor:(OCSyncAnchor)syncAnchor completionHandler:(OCDatabaseCompletionHandler)completionHandler
{
	NSMutableArray <OCSQLiteQuery *> *queries = [[NSMutableArray alloc] initWithCapacity:items.count];

	for (OCItem *item in items)
	{
		if (item.databaseID != nil)
		{
			[queries addObject:[OCSQLiteQuery queryUpdatingRowWithID:item.databaseID inTable:OCDatabaseTableNameMetaData withRowValues:@{
				@"type" 		: @(item.type),
				@"syncAnchor"		: syncAnchor,
				@"removed"		: @(item.removed),
				@"locallyModified" 	: @(item.locallyModified),
				@"localRelativePath"	: ((item.localRelativePath!=nil) ? item.localRelativePath : [NSNull null]),
				@"path" 		: item.path,
				@"parentPath" 		: [item.path parentPath],
				@"name"			: [item.path lastPathComponent],
				@"fileID"		: item.fileID,
				@"itemData"		: [item serializedData]
			} completionHandler:nil]];
		}
		else
		{
			OCLogError(@"Item without databaseID can't be used for updating: %@", item);
		}
	}

	[self.sqlDB executeTransaction:[OCSQLiteTransaction transactionWithQueries:queries type:OCSQLiteTransactionTypeDeferred completionHandler:^(OCSQLiteDB *db, OCSQLiteTransaction *transaction, NSError *error) {
		completionHandler(self, error);
	}]];
}

- (void)removeCacheItems:(NSArray <OCItem *> *)items syncAnchor:(OCSyncAnchor)syncAnchor completionHandler:(OCDatabaseCompletionHandler)completionHandler
{
	// TODO: Update parent directories with new sync anchor value (not sure if necessary, as a change in eTag should also trigger an update of the parent directory sync anchor)

	for (OCItem *item in items)
	{
		item.removed = YES;

		if (item.databaseID == nil)
		{
			OCLogError(@"Item without databaseID can't be used for deletion: %@", item);
		}
	}

	[self updateCacheItems:items syncAnchor:syncAnchor completionHandler:completionHandler];
}

- (void)_completeRetrievalWithResultSet:(OCSQLiteResultSet *)resultSet completionHandler:(OCDatabaseRetrieveCompletionHandler)completionHandler
{
	NSMutableArray <OCItem *> *items = [NSMutableArray new];
	NSError *returnError = nil;
	__block OCSyncAnchor syncAnchor = nil;

	[resultSet iterateUsing:^(OCSQLiteResultSet *resultSet, NSUInteger line, NSDictionary<NSString *,id<NSObject>> *resultDict, BOOL *stop) {
		NSData *itemData;
		OCSyncAnchor itemSyncAnchor = (NSNumber *)resultDict[@"syncAnchor"];

		if ((itemData = (NSData *)resultDict[@"itemData"]) != nil)
		{
			OCItem *item;

			if ((item = [OCItem itemFromSerializedData:itemData]) != nil)
			{
				[items addObject:item];
				item.databaseID = resultDict[@"mdID"];
			}
		}

		if (itemSyncAnchor != nil)
		{
			if (syncAnchor != nil)
			{
				if (syncAnchor.integerValue < itemSyncAnchor.integerValue)
				{
					syncAnchor = itemSyncAnchor;
				}
			}
			else
			{
				syncAnchor = itemSyncAnchor;
			}
		}
	} error:&returnError];

	if (returnError != nil)
	{
		completionHandler(self, returnError, nil, nil);
	}
	else
	{
		completionHandler(self, nil, syncAnchor, items);
	}
}

- (void)retrieveCacheItemForFileID:(OCFileID)fileID completionHandler:(OCDatabaseRetrieveItemCompletionHandler)completionHandler
{
	if (fileID == nil)
	{
		OCLogError(@"Retrieval of fileID==nil failed");

		completionHandler(self, OCError(OCErrorItemNotFound), nil, nil);
		return;
	}

	[self.sqlDB executeQuery:[OCSQLiteQuery query:@"SELECT mdID, syncAnchor, itemData FROM metaData WHERE fileID=? AND removed=0" withParameters:@[fileID] resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
		if (error != nil)
		{
			completionHandler(self, error, nil, nil);
		}
		else
		{
			[self _completeRetrievalWithResultSet:resultSet completionHandler:^(OCDatabase *db, NSError *error, OCSyncAnchor syncAnchor, NSArray<OCItem *> *items) {
				completionHandler(db, error, syncAnchor, items.firstObject);
			}];
		}
	}]];
}

- (void)retrieveCacheItemsAtPath:(OCPath)path itemOnly:(BOOL)itemOnly completionHandler:(OCDatabaseRetrieveCompletionHandler)completionHandler
{
	NSString *parentPath = path;
	NSString *sqlQueryString = nil;
	NSArray *parameters = nil;

	if (itemOnly)
	{
		sqlQueryString = @"SELECT mdID, syncAnchor, itemData FROM metaData WHERE path=? AND removed=0";
		parameters = @[path];
	}
	else
	{
		sqlQueryString = @"SELECT mdID, syncAnchor, itemData FROM metaData WHERE (parentPath=? OR path=? OR path=?) AND removed=0";
		parameters = @[parentPath, parentPath, path];
	}

	[self.sqlDB executeQuery:[OCSQLiteQuery query:sqlQueryString withParameters:parameters resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
		if (error != nil)
		{
			completionHandler(self, error, nil, nil);
		}
		else
		{
			[self _completeRetrievalWithResultSet:resultSet completionHandler:completionHandler];
		}
	}]];
}

- (NSArray <OCItem *> *)retrieveCacheItemsSyncAtPath:(OCPath)path itemOnly:(BOOL)itemOnly error:(NSError * __autoreleasing *)outError syncAnchor:(OCSyncAnchor __autoreleasing *)outSyncAnchor
{
	__block NSArray <OCItem *> *items = nil;

	OCSyncExec(cacheItemsRetrieval, {
		[self retrieveCacheItemsAtPath:path itemOnly:itemOnly completionHandler:^(OCDatabase *db, NSError *error, OCSyncAnchor syncAnchor, NSArray<OCItem *> *dbItems) {
			items = dbItems;

			if (outError != NULL) { *outError = error; }
			if (outSyncAnchor != NULL) { *outSyncAnchor = syncAnchor; }

			OCSyncExecDone(cacheItemsRetrieval);
		}];
	});

	return (items);
}

- (void)retrieveCacheItemsUpdatedSinceSyncAnchor:(OCSyncAnchor)synchAnchor foldersOnly:(BOOL)foldersOnly completionHandler:(OCDatabaseRetrieveCompletionHandler)completionHandler
{
	NSString *sqlQueryString = @"SELECT mdID, syncAnchor, itemData FROM metaData WHERE syncAnchor > ?";

	if (foldersOnly)
	{
		sqlQueryString = [sqlQueryString stringByAppendingFormat:@" AND type == %ld", (long)OCItemTypeCollection];
	}

	[self.sqlDB executeQuery:[OCSQLiteQuery query:sqlQueryString withParameters:@[synchAnchor] resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
		if (error != nil)
		{
			completionHandler(self, error, nil, nil);
		}
		else
		{
			[self _completeRetrievalWithResultSet:resultSet completionHandler:completionHandler];
		}
	}]];
}

#pragma mark - Thumbnail interface
- (void)storeThumbnailData:(NSData *)thumbnailData withMIMEType:(NSString *)mimeType specID:(NSString *)specID forItemVersion:(OCItemVersionIdentifier *)itemVersion maximumSizeInPixels:(CGSize)maximumSizeInPixels completionHandler:(OCDatabaseCompletionHandler)completionHandler
{
	if ((itemVersion.fileID == nil) || (itemVersion.eTag == nil))
	{
		OCLogError(@"Error storing thumbnail for itemVersion %@ because it lacks fileID or eTag.", OCLogPrivate(itemVersion));
		return;
	}

	if (specID == nil)
	{
		OCLogError(@"Error storing thumbnail for itemVersion %@ because it lacks a specID.", OCLogPrivate(itemVersion));
		return;
	}

	if (thumbnailData == nil)
	{
		OCLogError(@"Error storing thumbnail data for itemVersion %@ because it lacks data.", OCLogPrivate(itemVersion));
		return;
	}

	[self.sqlDB executeTransaction:[OCSQLiteTransaction transactionWithQueries:@[
		// Remove outdated versions and smaller thumbnail sizes
		[OCSQLiteQuery  query:@"DELETE FROM thumb.thumbnails WHERE fileID = :fileID AND ((eTag != :eTag) OR (maxWidth < :maxWidth AND maxHeight < :maxHeight) OR (specID != :specID))" // relatedTo:OCDatabaseTableNameThumbnails
			        withNamedParameters:@{
					@"fileID" : itemVersion.fileID,
					@"eTag" : itemVersion.eTag,
					@"specID" : specID,
					@"maxWidth" : @(maximumSizeInPixels.width),
					@"maxHeight" : @(maximumSizeInPixels.height),
			        } resultHandler:nil],

		// Insert new thumbnail
		[OCSQLiteQuery  queryInsertingIntoTable:OCDatabaseTableNameThumbnails
				rowValues:@{
					@"fileID" : itemVersion.fileID,
					@"eTag" : itemVersion.eTag,
					@"specID" : specID,
					@"maxWidth" : @(maximumSizeInPixels.width),
					@"maxHeight" : @(maximumSizeInPixels.height),
					@"mimeType" : mimeType,
					@"imageData" : thumbnailData
				} resultHandler:nil]
	] type:OCSQLiteTransactionTypeDeferred completionHandler:^(OCSQLiteDB *db, OCSQLiteTransaction *transaction, NSError *error) {
		if (completionHandler != nil)
		{
			completionHandler(self, error);
		}
	}]];
}

- (void)retrieveThumbnailDataForItemVersion:(OCItemVersionIdentifier *)itemVersion specID:(NSString *)specID maximumSizeInPixels:(CGSize)maximumSizeInPixels completionHandler:(OCDatabaseRetrieveThumbnailCompletionHandler)completionHandler
{
	/*
		// This is a bit more complex SQL statement. Here's how it was tested and what it is meant to achieve:

		// Table creation and test data set
		CREATE TABLE thumb.thumbnails (tnID INTEGER PRIMARY KEY, maxWidth INTEGER NOT NULL, maxHeight INTEGER NOT NULL);
		INSERT INTO thumbnails (maxWidth, maxHeight) VALUES (10,10);
		INSERT INTO thumbnails (maxWidth, maxHeight) VALUES (15,15);
		INSERT INTO thumbnails (maxWidth, maxHeight) VALUES (20,20);
		INSERT INTO thumbnails (maxWidth, maxHeight) VALUES (25,25);

		SELECT * FROM thumbnails ORDER BY (maxWidth =  8 AND maxHeight =  8) DESC, (maxWidth >=  8 AND maxHeight >=  8) DESC, (((maxWidth <  8 AND maxHeight <  8) * -1000 + 1) * ((maxWidth * maxHeight) - ( 8* 8))) ASC LIMIT 0,1;
		// Returns (10,10) (smaller than smallest => next bigger)

		SELECT * FROM thumbnails ORDER BY (maxWidth = 14 AND maxHeight = 14) DESC, (maxWidth >= 14 AND maxHeight >= 14) DESC, (((maxWidth < 14 AND maxHeight < 14) * -1000 + 1) * ((maxWidth * maxHeight) - (14*14))) ASC LIMIT 0,1;
		// Returns (15,15) (smaller than biggest, but smaller ones also there, no exact match => next bigger)

		SELECT * FROM thumbnails ORDER BY (maxWidth = 15 AND maxHeight = 15) DESC, (maxWidth >= 15 AND maxHeight >= 15) DESC, (((maxWidth < 15 AND maxHeight < 15) * -1000 + 1) * ((maxWidth * maxHeight) - (15*15))) ASC LIMIT 0,1;
		// Returns (15,15) (=> exact match)

		SELECT * FROM thumbnails ORDER BY (maxWidth = 16 AND maxHeight = 16) DESC, (maxWidth >= 16 AND maxHeight >= 16) DESC, (((maxWidth < 16 AND maxHeight < 16) * -1000 + 1) * ((maxWidth * maxHeight) - (16*16))) ASC LIMIT 0,1;
		// Returns (20,20) (smaller than biggest, but smaller ones also there, no exact match => next bigger)

		SELECT * FROM thumbnails ORDER BY (maxWidth = 30 AND maxHeight = 30) DESC, (maxWidth >= 30 AND maxHeight >= 30) DESC, (((maxWidth < 30 AND maxHeight < 30) * -1000 + 1) * ((maxWidth * maxHeight) - (30*30))) ASC LIMIT 0,1;
		// Returns (25,25) (bigger than biggest => return biggest)

		Explaining the ORDER part, where the magic takes place:

			(maxWidth = 30 AND maxHeight = 30) DESC, // prefer exact match
			(maxWidth >= 30 AND maxHeight >= 30) DESC, // if no exact match, prefer bigger ones

			(((maxWidth < 30 AND maxHeight < 30) * -1000 + 1) * // make sure those smaller than needed score the largest negative values and move to the end of the list
			((maxWidth * maxHeight) - (30*30))) ASC // the closer the size is to the one needed, the higher it should rank

		Wouldn't this filtering and sorting be easier in ObjC code going through the results?

		Yes, BUT by performing this in SQLite we save the overhead/memory of loading irrelevant data, and since the WHERE is very specific, the set that SQLite needs to sort
		this way will be tiny and shouldn't have any measurable performance impact.
	*/

	if ((itemVersion.fileID==nil) || (itemVersion.eTag==nil) || (specID == nil))
	{
		if (completionHandler!=nil)
		{
			completionHandler(self, OCError(OCErrorInsufficientParameters), CGSizeZero, nil, nil);
		}
		return;
	}

	[self.sqlDB executeQuery:[OCSQLiteQuery query:@"SELECT maxWidth, maxHeight, mimeType, imageData FROM thumbnails WHERE fileID = :fileID AND eTag = :eTag AND specID = :specID ORDER BY (maxWidth = :maxWidth AND maxHeight = :maxHeight) DESC, (maxWidth >= :maxWidth AND maxHeight >= :maxHeight) DESC, (((maxWidth < :maxWidth AND maxHeight < :maxHeight) * -1000 + 1) * ((maxWidth * maxHeight) - (:maxWidth * :maxHeight))) ASC LIMIT 0,1" withNamedParameters:@{
		@"fileID"	: itemVersion.fileID,
		@"eTag"		: itemVersion.eTag,
		@"specID"	: specID,
		@"maxWidth"  	: @(maximumSizeInPixels.width),
		@"maxHeight" 	: @(maximumSizeInPixels.height),
	} resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
		NSError *returnError = error;
		__block BOOL calledCompletionHandler = NO;

		if (returnError == nil)
		{
			[resultSet iterateUsing:^(OCSQLiteResultSet *resultSet, NSUInteger line, NSDictionary<NSString *,id> *rowDictionary, BOOL *stop) {
				NSNumber *maxWidthNumber = nil, *maxHeightNumber = nil;
				NSString *mimeType = nil;
				NSData *imageData = nil;

				if (((maxWidthNumber = rowDictionary[@"maxWidth"])!=nil) &&
				    ((maxHeightNumber = rowDictionary[@"maxHeight"])!=nil) &&
				    ((mimeType = rowDictionary[@"mimeType"])!=nil) &&
				    ((imageData = rowDictionary[@"imageData"])!=nil))
				{
					completionHandler(self, nil, CGSizeMake((CGFloat)maxWidthNumber.integerValue, (CGFloat)maxHeightNumber.integerValue), mimeType, imageData);
					calledCompletionHandler = YES;
				}
			} error:&returnError];
		}

		if (!calledCompletionHandler)
		{
			completionHandler(self, returnError, CGSizeZero, nil, nil);
		}
	}]];
}

#pragma mark - Sync interface
- (void)addSyncRecords:(NSArray <OCSyncRecord *> *)syncRecords completionHandler:(OCDatabaseCompletionHandler)completionHandler
{
	NSMutableArray <OCSQLiteQuery *> *queries = [[NSMutableArray alloc] initWithCapacity:syncRecords.count];

	for (OCSyncRecord *syncRecord in syncRecords)
	{
		NSString *path = syncRecord.action.localItem.path;

		if (path == nil) { path = @""; }

		if (path != nil)
		{
			[queries addObject:[OCSQLiteQuery queryInsertingIntoTable:OCDatabaseTableNameSyncJournal rowValues:@{
				@"timestampDate" 	: syncRecord.timestamp,
				@"inProgressSinceDate"	: ((syncRecord.inProgressSince != nil) ? syncRecord.inProgressSince : [NSNull null]),
				@"action"		: syncRecord.actionIdentifier,
				@"path"			: path,
				@"recordData"		: [syncRecord serializedData]
			} resultHandler:^(OCSQLiteDB *db, NSError *error, NSNumber *rowID) {
				syncRecord.recordID = rowID;

				@synchronized(db)
				{
					if (syncRecord.recordID != nil)
					{
						if (syncRecord.progress != nil)
						{
							self->_progressBySyncRecordID[syncRecord.recordID] = syncRecord.progress;
						}

						if (syncRecord.resultHandler != nil)
						{
							self->_resultHandlersBySyncRecordID[syncRecord.recordID] = syncRecord.resultHandler;
						}

						if (syncRecord.action.ephermalParameters != nil)
						{
							self->_ephermalParametersBySyncRecordID[syncRecord.recordID] = syncRecord.action.ephermalParameters;
						}
					}
				}
			}]];
		}
	}

	[self.sqlDB executeTransaction:[OCSQLiteTransaction transactionWithQueries:queries type:OCSQLiteTransactionTypeDeferred completionHandler:^(OCSQLiteDB *db, OCSQLiteTransaction *transaction, NSError *error) {
		if (completionHandler != nil)
		{
			completionHandler(self, error);
		}
	}]];
}

- (void)updateSyncRecords:(NSArray <OCSyncRecord *> *)syncRecords completionHandler:(OCDatabaseCompletionHandler)completionHandler
{
	NSMutableArray <OCSQLiteQuery *> *queries = [[NSMutableArray alloc] initWithCapacity:syncRecords.count];

	for (OCSyncRecord *syncRecord in syncRecords)
	{
		if (syncRecord.recordID != nil)
		{
			[queries addObject:[OCSQLiteQuery queryUpdatingRowWithID:syncRecord.recordID inTable:OCDatabaseTableNameSyncJournal withRowValues:@{
				@"inProgressSinceDate"	: ((syncRecord.inProgressSince != nil) ? syncRecord.inProgressSince : [NSNull null]),
				@"recordData"		: [syncRecord serializedData]
			} completionHandler:^(OCSQLiteDB *db, NSError *error) {
				@synchronized(db)
				{
					if (syncRecord.progress != nil)
					{
						self->_progressBySyncRecordID[syncRecord.recordID] = syncRecord.progress;
					}
					else
					{
						[self->_progressBySyncRecordID removeObjectForKey:syncRecord.recordID];
					}

					if (syncRecord.resultHandler != nil)
					{
						self->_resultHandlersBySyncRecordID[syncRecord.recordID] = syncRecord.resultHandler;
					}
					else
					{
						[self->_resultHandlersBySyncRecordID removeObjectForKey:syncRecord.recordID];
					}

					if (syncRecord.action.ephermalParameters != nil)
					{
						self->_ephermalParametersBySyncRecordID[syncRecord.recordID] = syncRecord.action.ephermalParameters;
					}
					else
					{
						[self->_ephermalParametersBySyncRecordID removeObjectForKey:syncRecord.recordID];
					}
				}
			}]];
		}
		else
		{
			OCLogError(@"Sync record without recordID can't be used for updating: %@", syncRecord);
		}
	}

	[self.sqlDB executeTransaction:[OCSQLiteTransaction transactionWithQueries:queries type:OCSQLiteTransactionTypeDeferred completionHandler:^(OCSQLiteDB *db, OCSQLiteTransaction *transaction, NSError *error) {
		if (completionHandler != nil)
		{
			completionHandler(self, error);
		}
	}]];
}

- (void)removeSyncRecords:(NSArray <OCSyncRecord *> *)syncRecords completionHandler:(OCDatabaseCompletionHandler)completionHandler
{
	NSMutableArray <OCSQLiteQuery *> *queries = [[NSMutableArray alloc] initWithCapacity:syncRecords.count];

	for (OCSyncRecord *syncRecord in syncRecords)
	{
		if (syncRecord.recordID != nil)
		{
			[queries addObject:[OCSQLiteQuery queryDeletingRowWithID:syncRecord.recordID fromTable:OCDatabaseTableNameSyncJournal completionHandler:^(OCSQLiteDB *db, NSError *error) {
				OCSyncRecordID syncRecordID;

				if ((syncRecordID = syncRecord.recordID) != nil)
				{
					syncRecord.recordID = nil;

					@synchronized(db)
					{
						[self->_progressBySyncRecordID removeObjectForKey:syncRecordID];
						[self->_resultHandlersBySyncRecordID removeObjectForKey:syncRecordID];
						[self->_ephermalParametersBySyncRecordID removeObjectForKey:syncRecordID];
					}
				}
			}]];
		}
		else
		{
			OCLogError(@"Sync record without recordID can't be used for deletion: %@", syncRecord);
		}
	}

	[self.sqlDB executeTransaction:[OCSQLiteTransaction transactionWithQueries:queries type:OCSQLiteTransactionTypeDeferred completionHandler:^(OCSQLiteDB *db, OCSQLiteTransaction *transaction, NSError *error) {
		if (completionHandler != nil)
		{
			completionHandler(self, error);
		}
	}]];
}

- (OCSyncRecord *)_syncRecordFromRowDictionary:(NSDictionary<NSString *,id<NSObject>> *)rowDictionary
{
	OCSyncRecord *syncRecord = nil;

	if ((syncRecord = [OCSyncRecord syncRecordFromSerializedData:(NSData *)rowDictionary[@"recordData"]]) != nil)
	{
		OCSyncRecordID recordID;

		if ((recordID = (OCSyncRecordID)rowDictionary[@"recordID"]) != nil)
		{
			syncRecord.recordID = recordID;

			@synchronized(self.sqlDB)
			{
				syncRecord.progress = _progressBySyncRecordID[syncRecord.recordID];
				syncRecord.resultHandler = _resultHandlersBySyncRecordID[syncRecord.recordID];
				syncRecord.action.ephermalParameters = _ephermalParametersBySyncRecordID[syncRecord.recordID];
			}
		}
	}

	return(syncRecord);
}

- (void)retrieveSyncRecordForID:(OCSyncRecordID)recordID completionHandler:(OCDatabaseRetrieveSyncRecordCompletionHandler)completionHandler
{
	if (recordID == nil)
	{
		if (completionHandler != nil)
		{
			completionHandler(self, nil, nil);
		}

		return;
	}

	[self.sqlDB executeQuery:[OCSQLiteQuery querySelectingColumns:@[ @"recordID", @"recordData" ] fromTable:OCDatabaseTableNameSyncJournal where:@{
		@"recordID" : recordID,
	} orderBy:nil resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
		__block OCSyncRecord *syncRecord = nil;
		NSError *iterationError = error;

		if (error == nil)
		{
			[resultSet iterateUsing:^(OCSQLiteResultSet *resultSet, NSUInteger line, NSDictionary<NSString *,id<NSObject>> *rowDictionary, BOOL *stop) {
				syncRecord = [self _syncRecordFromRowDictionary:rowDictionary];
				*stop = YES;
			} error:&iterationError];
		}

		if (completionHandler != nil)
		{
			completionHandler(self, iterationError, syncRecord);
		}
	}]];
}

- (void)retrieveSyncRecordsForPath:(OCPath)path action:(OCSyncActionIdentifier)action inProgressSince:(NSDate *)inProgressSince completionHandler:(OCDatabaseRetrieveSyncRecordsCompletionHandler)completionHandler
{
	[self.sqlDB executeQuery:[OCSQLiteQuery querySelectingColumns:@[ @"recordID", @"recordData" ] fromTable:OCDatabaseTableNameSyncJournal where:@{
		@"path" 		: [OCSQLiteQueryCondition queryConditionWithOperator:@"="  value:path 		 apply:(path!=nil)],
		@"action" 		: [OCSQLiteQueryCondition queryConditionWithOperator:@"="  value:action 	 apply:(action!=nil)],
		@"inProgressSinceDate" 	: [OCSQLiteQueryCondition queryConditionWithOperator:@">=" value:inProgressSince apply:(inProgressSince!=nil)]
	} orderBy:@"timestampDate ASC" resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
		NSMutableArray <OCSyncRecord *> *syncRecords = [NSMutableArray new];
		NSError *iterationError = error;

		[resultSet iterateUsing:^(OCSQLiteResultSet *resultSet, NSUInteger line, NSDictionary<NSString *,id<NSObject>> *rowDictionary, BOOL *stop) {
			OCSyncRecord *syncRecord;

			if ((syncRecord = [self _syncRecordFromRowDictionary:rowDictionary]) != nil)
			{
				[syncRecords addObject:syncRecord];
			}
		} error:&iterationError];

		if (completionHandler != nil)
		{
			completionHandler(self, iterationError, syncRecords);
		}
	}]];
}

#pragma mark - Integrity / Synchronization primitives
- (void)retrieveValueForCounter:(OCDatabaseCounterIdentifier)counterIdentifier completionHandler:(void(^)(NSError *error, NSNumber *counterValue))completionHandler
{
	[self.sqlDB executeQuery:[OCSQLiteQuery query:@"SELECT value FROM counters WHERE identifier = ?" withParameters:@[ counterIdentifier ] resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
		__block NSNumber *counterValue = nil;
		NSError *returnError = error;

		if (error == nil)
		{
			[resultSet iterateUsing:^(OCSQLiteResultSet *resultSet, NSUInteger line, NSDictionary<NSString *,id> *rowDictionary, BOOL *stop) {
				counterValue = rowDictionary[@"value"];
			} error:&returnError];

			if (counterValue == nil)
			{
				counterValue = @(0);
			}
		}

		completionHandler(returnError, counterValue);
	}]];
}

- (void)increaseValueForCounter:(OCDatabaseCounterIdentifier)counterIdentifier withProtectedBlock:(NSError *(^)(NSNumber *previousCounterValue, NSNumber *newCounterValue))protectedBlock completionHandler:(OCDatabaseProtectedBlockCompletionHandler)completionHandler
{
	[self.sqlDB executeTransaction:[OCSQLiteTransaction transactionWithBlock:^NSError *(OCSQLiteDB *db, OCSQLiteTransaction *transaction) {
		__block NSNumber *previousValue=nil, *newValue=nil;
		__block NSError *transactionError = nil;

		// Retrieve current value
		[self retrieveValueForCounter:counterIdentifier completionHandler:^(NSError *error, NSNumber *counterValue) {
			previousValue = counterValue;
			if (error != nil) { transactionError = error; }
		}];

		// Update value
		if (transactionError == nil)
		{
			if ((previousValue==nil) || (previousValue.integerValue==0))
			{
				// Create row
				[db executeQuery:[OCSQLiteQuery query:@"INSERT INTO counters (identifier, value, lastUpdated) VALUES (?, ?, ?)" withParameters:@[ counterIdentifier, @(1), @(NSDate.timeIntervalSinceReferenceDate) ] resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
					if (error != nil) { transactionError = error; }
				}]];
			}
			else
			{
				// Update row
				[db executeQuery:[OCSQLiteQuery query:@"UPDATE counters SET value = value + 1, lastUpdated = ? WHERE identifier = ?" withParameters:@[ @(NSDate.timeIntervalSinceReferenceDate), counterIdentifier ] resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
					if (error != nil) { transactionError = error; }
				}]];
			}
		}

		// Retrieve new value
		if (transactionError == nil)
		{
			[self retrieveValueForCounter:counterIdentifier completionHandler:^(NSError *error, NSNumber *counterValue) {
				newValue = counterValue;
				if (error != nil) { transactionError = error; }
			}];

			if (transactionError == nil)
			{
				NSMutableDictionary *userInfo = [NSMutableDictionary new];

				if (previousValue != nil) { userInfo[@"old"] = previousValue; }
				if (newValue != nil)	  { userInfo[@"new"] = newValue; }

				transaction.userInfo = userInfo;
			}
		}

		// Perform protected block
		if ((transactionError == nil) && (protectedBlock != nil))
		{
			transactionError = protectedBlock(previousValue, newValue);
		}

		return (transactionError);
	} type:OCSQLiteTransactionTypeExclusive completionHandler:^(OCSQLiteDB *db, OCSQLiteTransaction *transaction, NSError *error) {
		if (completionHandler != nil)
		{
			completionHandler(error, ((NSDictionary *)transaction.userInfo)[@"old"], ((NSDictionary *)transaction.userInfo)[@"new"]);
		}
	}]];
}

#pragma mark - Log tags
+ (NSArray<OCLogTagName> *)logTags
{
	return (@[@"DB"]);
}

- (NSArray<OCLogTagName> *)logTags
{
	return (@[@"DB"]);
}

@end
