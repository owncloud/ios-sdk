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
#import "NSString+OCPath.h"
#import "NSError+OCError.h"
#import "OCMacros.h"
#import "OCSyncAction.h"
#import "OCSyncLane.h"
#import "OCProcessManager.h"
#import "OCQueryCondition+SQLBuilder.h"
#import "OCAsyncSequentialQueue.h"
#import "NSString+OCSQLTools.h"
#import "OCItemPolicy.h"

@interface OCDatabase ()
{
	NSMutableDictionary <OCSyncRecordID, NSProgress *> *_progressBySyncRecordID;
	NSMutableDictionary <OCSyncRecordID, OCCoreActionResultHandler> *_resultHandlersBySyncRecordID;
	NSMutableDictionary <OCSyncRecordID, NSDictionary<OCSyncActionParameter,id> *> *_ephermalParametersBySyncRecordID;

	OCAsyncSequentialQueue *_openQueue;
	NSInteger _openCount;
}

@end

@implementation OCDatabase

@synthesize databaseURL = _databaseURL;

@synthesize removedItemRetentionLength = _removedItemRetentionLength;

@synthesize itemFilter = _itemFilter;

@synthesize sqlDB = _sqlDB;

#pragma mark - Initialization
- (instancetype)initWithURL:(NSURL *)databaseURL
{
	if ((self = [self init]) != nil)
	{
		self.databaseURL = databaseURL;

		self.removedItemRetentionLength = 100;

		_selectItemRowsSQLQueryPrefix = @"SELECT mdID, mdTimestamp, syncAnchor, itemData";

		_progressBySyncRecordID = [NSMutableDictionary new];
		_resultHandlersBySyncRecordID = [NSMutableDictionary new];
		_ephermalParametersBySyncRecordID = [NSMutableDictionary new];
		_eventsByDatabaseID = [NSMutableDictionary new];

		_openQueue = [OCAsyncSequentialQueue new];
		_openQueue.executor = ^(OCAsyncSequentialQueueJob  _Nonnull job, dispatch_block_t  _Nonnull completionHandler) {
			dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
				job(completionHandler);
			});
		};

		self.sqlDB = [[OCSQLiteDB alloc] initWithURL:databaseURL];
		self.sqlDB.journalMode = OCSQLiteJournalModeWAL;
		[self addSchemas];
	}

	return (self);
}

#pragma mark - Open / Close
- (void)openWithCompletionHandler:(OCDatabaseCompletionHandler)completionHandler
{
	[_openQueue async:^(dispatch_block_t  _Nonnull openQueueCompletionHandler) {
		if (self->_openCount > 0)
		{
			self->_openCount++;

			if (completionHandler != nil)
			{
				completionHandler(self, nil);
			}

			openQueueCompletionHandler();
			return;
		}

		[self.sqlDB openWithFlags:OCSQLiteOpenFlagsDefault completionHandler:^(OCSQLiteDB *db, NSError *error) {
			db.maxBusyRetryTimeInterval = 10; // Avoid busy timeout if another process performs large changes
			[db executeQueryString:@"PRAGMA synchronous=FULL"]; // Force checkpoint / synchronization after every transaction

			if (error == nil)
			{
				NSString *thumbnailsDBPath = [[[self.sqlDB.databaseURL URLByDeletingPathExtension] URLByAppendingPathExtension:@"tdb"] path];

				self->_openCount++;

				[self.sqlDB executeQuery:[OCSQLiteQuery query:@"ATTACH DATABASE ? AS 'thumb'" withParameters:@[ thumbnailsDBPath ] resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) { // relatedTo:OCDatabaseTableNameThumbnails
					if (error == nil)
					{
						[self.sqlDB applyTableSchemasWithCompletionHandler:^(OCSQLiteDB *db, NSError *error) {
							[self.sqlDB executeQueryString:@"PRAGMA journal_mode"];

							if (completionHandler!=nil)
							{
								completionHandler(self, error);
							}

							openQueueCompletionHandler();
						}];
					}
					else
					{
						OCLogError(@"Error attaching thumbnail database: %@", error);

						if (completionHandler!=nil)
						{
							completionHandler(self, error);
						}

						openQueueCompletionHandler();
					}
				}]];
			}
			else
			{
				if (completionHandler!=nil)
				{
					completionHandler(self, error);
				}

				self->_openCount--;
				openQueueCompletionHandler();
			}
		}];
	}];
}

- (void)closeWithCompletionHandler:(OCDatabaseCompletionHandler)completionHandler
{
	[_openQueue async:^(dispatch_block_t  _Nonnull openQueueCompletionHandler) {
		self->_openCount--;

		if (self->_openCount > 0)
		{
			if (completionHandler!=nil)
			{
				completionHandler(self, nil);
			}

			openQueueCompletionHandler();
			return;
		}

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

			openQueueCompletionHandler();
		}];
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
- (OCDatabaseTimestamp)_timestampForSyncAnchor:(OCSyncAnchor)syncAnchor
{
	// Ensure a consistent timestamp for every sync anchor, so that matching for mdTimestamp will also match on the entirety of all included sync anchors, not just parts of it (worst case)
	@synchronized(self)
	{
		if (syncAnchor != nil)
		{
			if ((_lastSyncAnchor==nil) || ((_lastSyncAnchor!=nil) && ![_lastSyncAnchor isEqual:syncAnchor]))
			{
				_lastSyncAnchor = syncAnchor;
				_lastSyncAnchorTimestamp = @((NSUInteger)NSDate.timeIntervalSinceReferenceDate);
			}

			return (_lastSyncAnchorTimestamp);
		}
	}

	return @((NSUInteger)NSDate.timeIntervalSinceReferenceDate);
}

- (void)addCacheItems:(NSArray <OCItem *> *)items syncAnchor:(OCSyncAnchor)syncAnchor completionHandler:(OCDatabaseCompletionHandler)completionHandler
{
	NSMutableArray <OCSQLiteQuery *> *queries = [[NSMutableArray alloc] initWithCapacity:items.count];
	OCDatabaseTimestamp mdTimestamp = [self _timestampForSyncAnchor:syncAnchor];

	if (_itemFilter != nil)
	{
		items = _itemFilter(items);
	}

	for (OCItem *item in items)
	{
		if (item.localID == nil)
		{
			OCLogDebug(@"Item added without localID: %@", item);
		}

		if ((item.parentLocalID == nil) && (![item.path isEqualToString:@"/"]))
		{
			OCLogDebug(@"Item added without parentLocalID: %@", item);
		}

		[queries addObject:[OCSQLiteQuery queryInsertingIntoTable:OCDatabaseTableNameMetaData rowValues:@{
			@"type" 		: @(item.type),
			@"syncAnchor"		: syncAnchor,
			@"removed"		: @(0),
			@"mdTimestamp"		: mdTimestamp,
			@"locallyModified" 	: @(item.locallyModified),
			@"localRelativePath"	: OCSQLiteNullProtect(item.localRelativePath),
			@"downloadTrigger"	: OCSQLiteNullProtect(item.downloadTriggerIdentifier),
			@"path" 		: item.path,
			@"parentPath" 		: [item.path parentPath],
			@"name"			: [item.path lastPathComponent],
			@"mimeType" 		: OCSQLiteNullProtect(item.mimeType),
			@"size" 		: @(item.size),
			@"favorite" 		: @(item.isFavorite.boolValue),
			@"cloudStatus" 		: @(item.cloudStatus),
			@"hasLocalAttributes" 	: @(item.hasLocalAttributes),
			@"lastUsedDate" 	: OCSQLiteNullProtect(item.lastUsed),
			@"fileID"		: OCSQLiteNullProtect(item.fileID),
			@"localID"		: OCSQLiteNullProtect(item.localID),
			@"itemData"		: [item serializedData]
		} resultHandler:^(OCSQLiteDB *db, NSError *error, NSNumber *rowID) {
			item.databaseID = rowID;
			item.databaseTimestamp = mdTimestamp;
		}]];
	}

	[self.sqlDB executeTransaction:[OCSQLiteTransaction transactionWithQueries:queries type:OCSQLiteTransactionTypeDeferred completionHandler:^(OCSQLiteDB *db, OCSQLiteTransaction *transaction, NSError *error) {
		completionHandler(self, error);
	}]];
}

- (void)updateCacheItems:(NSArray <OCItem *> *)items syncAnchor:(OCSyncAnchor)syncAnchor completionHandler:(OCDatabaseCompletionHandler)completionHandler
{
	NSMutableArray <OCSQLiteQuery *> *queries = [[NSMutableArray alloc] initWithCapacity:items.count];
	OCDatabaseTimestamp mdTimestamp = [self _timestampForSyncAnchor:syncAnchor];

	if (_itemFilter != nil)
	{
		items = _itemFilter(items);
	}

	for (OCItem *item in items)
	{
		if ((item.localID == nil) && (!item.removed))
		{
			OCLogDebug(@"Item updated without localID: %@", item);
		}

		if ((item.parentLocalID == nil) && (![item.path isEqualToString:@"/"]))
		{
			OCLogDebug(@"Item updated without parentLocalID: %@", item);
		}

		if (item.databaseID != nil)
		{
			[queries addObject:[OCSQLiteQuery queryUpdatingRowWithID:item.databaseID inTable:OCDatabaseTableNameMetaData withRowValues:@{
				@"type" 		: @(item.type),
				@"syncAnchor"		: syncAnchor,
				@"removed"		: @(item.removed),
				@"mdTimestamp"		: mdTimestamp,
				@"locallyModified" 	: @(item.locallyModified),
				@"localRelativePath"	: OCSQLiteNullProtect(item.localRelativePath),
				@"downloadTrigger"	: OCSQLiteNullProtect(item.downloadTriggerIdentifier),
				@"path" 		: item.path,
				@"parentPath" 		: [item.path parentPath],
				@"name"			: [item.path lastPathComponent],
				@"mimeType" 		: OCSQLiteNullProtect(item.mimeType),
				@"size" 		: @(item.size),
				@"favorite" 		: @(item.isFavorite.boolValue),
				@"cloudStatus" 		: @(item.cloudStatus),
				@"hasLocalAttributes" 	: @(item.hasLocalAttributes),
				@"lastUsedDate" 	: OCSQLiteNullProtect(item.lastUsed),
				@"fileID"		: OCSQLiteNullProtect(item.fileID),
				@"localID"		: OCSQLiteNullProtect(item.localID),
				@"itemData"		: [item serializedData]
			} completionHandler:nil]];

			item.databaseTimestamp = mdTimestamp;
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

	if (_itemFilter != nil)
	{
		items = _itemFilter(items);
	}

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

- (void)purgeCacheItemsWithDatabaseIDs:(NSArray <OCDatabaseID> *)databaseIDs completionHandler:(OCDatabaseCompletionHandler)completionHandler
{
	if (databaseIDs.count == 0)
	{
		if (completionHandler != nil)
		{
			completionHandler(self, nil);
		}
	}
	else
	{
		NSMutableArray <OCSQLiteQuery *> *queries = [[NSMutableArray alloc] initWithCapacity:databaseIDs.count];

		for (OCDatabaseID databaseID in databaseIDs)
		{
			[queries addObject:[OCSQLiteQuery queryDeletingRowWithID:databaseID fromTable:OCDatabaseTableNameMetaData completionHandler:nil]];
		}

		[self.sqlDB executeTransaction:[OCSQLiteTransaction transactionWithQueries:queries type:OCSQLiteTransactionTypeDeferred completionHandler:^(OCSQLiteDB *db, OCSQLiteTransaction *transaction, NSError *error) {
			if (completionHandler != nil)
			{
				completionHandler(self, error);
			}
		}]];
	}
}

- (OCItem *)_itemFromResultDict:(NSDictionary<NSString *,id<NSObject>> *)resultDict
{
	NSData *itemData;
	OCItem *item = nil;

	if ((itemData = (NSData *)resultDict[@"itemData"]) != nil)
	{
		if ((item = [OCItem itemFromSerializedData:itemData]) != nil)
		{
			NSNumber *removed, *mdTimestamp;
			NSString *downloadTrigger;

			if ((removed = (NSNumber *)resultDict[@"removed"]) != nil)
			{
				item.removed = removed.boolValue;
			}

			if ((mdTimestamp = (NSNumber *)resultDict[@"mdTimestamp"]) != nil)
			{
				item.databaseTimestamp = mdTimestamp;
			}

			if ((downloadTrigger = (NSString *)resultDict[@"downloadTrigger"]) != nil)
			{
				item.downloadTriggerIdentifier = downloadTrigger;
			}

			item.databaseID = resultDict[@"mdID"];
		}
	}

	return (item);
}

- (void)_completeRetrievalWithResultSet:(OCSQLiteResultSet *)resultSet completionHandler:(OCDatabaseRetrieveCompletionHandler)completionHandler
{
	NSMutableArray <OCItem *> *items = [NSMutableArray new];
	NSError *returnError = nil;
	__block OCSyncAnchor syncAnchor = nil;

	[resultSet iterateUsing:^(OCSQLiteResultSet *resultSet, NSUInteger line, NSDictionary<NSString *,id<NSObject>> *resultDict, BOOL *stop) {
		OCSyncAnchor itemSyncAnchor;
		OCItem *item;

		if ((item = [self _itemFromResultDict:resultDict]) != nil)
		{
			[items addObject:item];
		}

		if ((itemSyncAnchor = (NSNumber *)resultDict[@"syncAnchor"]) != nil)
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

- (void)_retrieveCacheItemForSQLQuery:(NSString *)sqlQuery parameters:(nullable NSArray<id> *)parameters completionHandler:(OCDatabaseRetrieveItemCompletionHandler)completionHandler
{
	[self.sqlDB executeQuery:[OCSQLiteQuery query:sqlQuery withParameters:parameters resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
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

- (void)_retrieveCacheItemsForSQLQuery:(NSString *)sqlQuery parameters:(nullable NSArray<id> *)parameters completionHandler:(OCDatabaseRetrieveCompletionHandler)completionHandler
{
	[self.sqlDB executeQuery:[OCSQLiteQuery query:sqlQuery withParameters:parameters resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
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


- (void)retrieveCacheItemForLocalID:(OCLocalID)localID completionHandler:(OCDatabaseRetrieveItemCompletionHandler)completionHandler
{
	if (localID == nil)
	{
		OCLogError(@"Retrieval of localID==nil failed");

		completionHandler(self, OCError(OCErrorItemNotFound), nil, nil);
		return;
	}

	[self _retrieveCacheItemForSQLQuery:[_selectItemRowsSQLQueryPrefix stringByAppendingString:@" FROM metaData WHERE localID=? AND removed=0"]
				 parameters:@[localID]
			  completionHandler:completionHandler];
}

- (void)retrieveCacheItemForFileID:(OCFileID)fileID completionHandler:(OCDatabaseRetrieveItemCompletionHandler)completionHandler
{
	[self retrieveCacheItemForFileID:fileID includingRemoved:NO completionHandler:completionHandler];
}

- (void)retrieveCacheItemForFileID:(OCFileID)fileID includingRemoved:(BOOL)includingRemoved completionHandler:(OCDatabaseRetrieveItemCompletionHandler)completionHandler
{
	if (fileID == nil)
	{
		OCLogError(@"Retrieval of fileID==nil failed");

		completionHandler(self, OCError(OCErrorItemNotFound), nil, nil);
		return;
	}

	[self _retrieveCacheItemForSQLQuery:(includingRemoved ? [_selectItemRowsSQLQueryPrefix stringByAppendingString:@", removed FROM metaData WHERE fileID=?"] : [_selectItemRowsSQLQueryPrefix stringByAppendingString:@", removed FROM metaData WHERE fileID=? AND removed=0"])
				 parameters:@[fileID]
			  completionHandler:completionHandler];
}

- (void)retrieveCacheItemsRecursivelyBelowPath:(OCPath)path includingPathItself:(BOOL)includingPathItself includingRemoved:(BOOL)includingRemoved completionHandler:(OCDatabaseRetrieveCompletionHandler)completionHandler
{
	NSMutableArray *parameters = [NSMutableArray new];

	if (path.length == 0)
	{
		OCLogError(@"Retrieval below zero-length/nil path failed");

		completionHandler(self, OCError(OCErrorInsufficientParameters), nil, nil);
		return;
	}

	[parameters addObject:[[path stringBySQLLikeEscaping] stringByAppendingString:@"%"]];

	NSString *sqlStatement = [_selectItemRowsSQLQueryPrefix stringByAppendingString:@", removed FROM metaData WHERE path LIKE ?"];

	if (includingRemoved)
	{
		sqlStatement = [sqlStatement stringByAppendingString:@" AND removed=0"];
	}

	if (!includingPathItself)
	{
		sqlStatement = [sqlStatement stringByAppendingString:@" AND path!=?"];
		[parameters addObject:path];
	}

	[self _retrieveCacheItemsForSQLQuery:sqlStatement parameters:parameters completionHandler:completionHandler];
}

- (void)retrieveCacheItemsAtPath:(OCPath)path itemOnly:(BOOL)itemOnly completionHandler:(OCDatabaseRetrieveCompletionHandler)completionHandler
{
	NSString *sqlQueryString = nil;
	NSArray *parameters = nil;

	if (path == nil)
	{
		completionHandler(self, OCError(OCErrorInsufficientParameters), nil, nil);
		return;
	}

	if (itemOnly)
	{
		sqlQueryString = [_selectItemRowsSQLQueryPrefix stringByAppendingString:@" FROM metaData WHERE path=? AND removed=0"];
		parameters = @[path];
	}
	else
	{
		sqlQueryString = [_selectItemRowsSQLQueryPrefix stringByAppendingString:@" FROM metaData WHERE (parentPath=? OR path=?) AND removed=0"];
		parameters = @[path, path];
	}

	[self _retrieveCacheItemsForSQLQuery:sqlQueryString parameters:parameters completionHandler:completionHandler];
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
	NSString *sqlQueryString = [_selectItemRowsSQLQueryPrefix stringByAppendingString:@", removed FROM metaData WHERE syncAnchor > ?"];

	if (foldersOnly)
	{
		sqlQueryString = [sqlQueryString stringByAppendingFormat:@" AND type == %ld", (long)OCItemTypeCollection];
	}

	[self _retrieveCacheItemsForSQLQuery:sqlQueryString parameters:@[synchAnchor] completionHandler:completionHandler];
}

+ (NSDictionary<OCItemPropertyName, NSString *> *)columnNameByPropertyName
{
	static dispatch_once_t onceToken;
	static NSDictionary<OCItemPropertyName, NSString *> *columnNameByPropertyName;

	dispatch_once(&onceToken, ^{
		columnNameByPropertyName = @{
			OCItemPropertyNameType : @"type",

			OCItemPropertyNameLocalID : @"localID",
			OCItemPropertyNameFileID : @"fileID",

			OCItemPropertyNameName : @"name",
			OCItemPropertyNamePath : @"path",

			OCItemPropertyNameLocalRelativePath 	: @"localRelativePath",
			OCItemPropertyNameLocallyModified 	: @"locallyModified",

			OCItemPropertyNameMIMEType 		: @"mimeType",
			OCItemPropertyNameSize 			: @"size",
			OCItemPropertyNameIsFavorite 		: @"favorite",
			OCItemPropertyNameCloudStatus 		: @"cloudStatus",
			OCItemPropertyNameHasLocalAttributes 	: @"hasLocalAttributes",
			OCItemPropertyNameLastUsed 		: @"lastUsedDate",

			OCItemPropertyNameDownloadTrigger	: @"downloadTrigger",

			OCItemPropertyNameRemoved		: @"removed",
			OCItemPropertyNameDatabaseTimestamp	: @"mdTimestamp"
		};
	});

	return (columnNameByPropertyName);
}

- (void)retrieveCacheItemsForQueryCondition:(OCQueryCondition *)queryCondition completionHandler:(OCDatabaseRetrieveCompletionHandler)completionHandler
{
	NSString *sqlQueryString = [_selectItemRowsSQLQueryPrefix stringByAppendingString:@", removed FROM metaData WHERE removed=0 AND "];
	NSString *sqlWhereString = nil;
	NSArray *parameters = nil;
	NSError *error = nil;

	if ((sqlWhereString = [queryCondition buildSQLQueryWithPropertyColumnNameMap:[[self class] columnNameByPropertyName] parameters:&parameters error:&error]) != nil)
	{
		sqlQueryString = [sqlQueryString stringByAppendingString:sqlWhereString];

		[self _retrieveCacheItemsForSQLQuery:sqlQueryString parameters:parameters completionHandler:completionHandler];
	}
	else
	{
		completionHandler(self, error, nil, nil);
	}
}

- (void)iterateCacheItemsWithIterator:(void(^)(NSError *error, OCSyncAnchor syncAnchor, OCItem *item, BOOL *stop))iterator
{
	NSString *sqlQueryString = [_selectItemRowsSQLQueryPrefix stringByAppendingString:@", removed FROM metaData ORDER BY mdID ASC"];

	[self.sqlDB executeQuery:[OCSQLiteQuery query:sqlQueryString withParameters:nil resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
		NSError *returnError = nil;

		[resultSet iterateUsing:^(OCSQLiteResultSet *resultSet, NSUInteger line, NSDictionary<NSString *,id<NSObject>> *resultDict, BOOL *stop) {
			OCItem *item;

			if ((item = [self _itemFromResultDict:resultDict]) != nil)
			{
				iterator(nil, (NSNumber *)resultDict[@"syncAnchor"], item, stop);
			}
		} error:&returnError];

		iterator(returnError, nil, nil, NULL);
	}]];
}

- (void)iterateCacheItemsForQueryCondition:(nullable OCQueryCondition *)queryCondition excludeRemoved:(BOOL)excludeRemoved withIterator:(OCDatabaseItemIterator)iterator
{
	NSString *sqlQueryString = nil;
	NSString *sqlWhereString = nil;
	NSArray *parameters = nil;
	NSError *error = nil;

	if (queryCondition != nil)
	{
		if ((sqlWhereString = [queryCondition buildSQLQueryWithPropertyColumnNameMap:[[self class] columnNameByPropertyName] parameters:&parameters error:&error]) != nil)
		{
			sqlQueryString = [_selectItemRowsSQLQueryPrefix stringByAppendingFormat:@", removed FROM metaData WHERE %@%@", (excludeRemoved ? @"removed=0 AND " : @""), sqlWhereString];
		}
	}
	else
	{
		sqlQueryString = [_selectItemRowsSQLQueryPrefix stringByAppendingString:@", removed FROM metaData ORDER BY mdID ASC"];
	}

	if (sqlQueryString == nil)
	{
		iterator(OCError(OCErrorInsufficientParameters), nil, nil, NULL);
		return;
	}

	// OCLogDebug(@"Iterating result for %@ with parameters %@", sqlQueryString, parameters);

	[self.sqlDB executeQuery:[OCSQLiteQuery query:sqlQueryString withParameters:parameters resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
		NSError *returnError = nil;

		[resultSet iterateUsing:^(OCSQLiteResultSet *resultSet, NSUInteger line, NSDictionary<NSString *,id<NSObject>> *resultDict, BOOL *stop) {
			OCItem *item;

			if ((item = [self _itemFromResultDict:resultDict]) != nil)
			{
				iterator(nil, (NSNumber *)resultDict[@"syncAnchor"], item, stop);
			}
		} error:&returnError];

		iterator(returnError, nil, nil, NULL);
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

#pragma mark - Directory Update Job interface
- (void)addDirectoryUpdateJob:(OCCoreDirectoryUpdateJob *)updateJob completionHandler:(OCDatabaseDirectoryUpdateJobCompletionHandler)completionHandler
{
	if ((updateJob != nil) && (updateJob.path != nil))
	{
		[self.sqlDB executeQuery:[OCSQLiteQuery queryInsertingIntoTable:OCDatabaseTableNameUpdateJobs rowValues:@{
			@"path" 		: updateJob.path
		} resultHandler:^(OCSQLiteDB *db, NSError *error, NSNumber *rowID) {
			updateJob.identifier = rowID;

			if (completionHandler != nil)
			{
				completionHandler(self, error, updateJob);
			}
		}]];
	}
	else
	{
		OCLogError(@"updateScanPath=%@, updateScanPath.path=%@ => could not be stored in database", updateJob, updateJob.path);
		completionHandler(self, OCError(OCErrorInsufficientParameters), nil);
	}
}

- (void)retrieveDirectoryUpdateJobsAfter:(OCCoreDirectoryUpdateJobID)jobID forPath:(OCPath)path maximumJobs:(NSUInteger)maximumJobs completionHandler:(OCDatabaseRetrieveDirectoryUpdateJobsCompletionHandler)completionHandler
{
	[self.sqlDB executeQuery:[OCSQLiteQuery querySelectingColumns:nil fromTable:OCDatabaseTableNameUpdateJobs where:@{
		@"jobID" 	: [OCSQLiteQueryCondition queryConditionWithOperator:@">=" value:jobID apply:(jobID!=nil)],
		@"path" 	: [OCSQLiteQueryCondition queryConditionWithOperator:@"="  value:path apply:(path!=nil)]
	} orderBy:@"jobID ASC" limit:((maximumJobs == 0) ? nil : [NSString stringWithFormat:@"0,%ld",maximumJobs]) resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
		__block NSMutableArray <OCCoreDirectoryUpdateJob *> *updateJobs = nil;
		NSError *iterationError = error;

		if (error == nil)
		{
			[resultSet iterateUsing:^(OCSQLiteResultSet *resultSet, NSUInteger line, NSDictionary<NSString *,id<NSObject>> *rowDictionary, BOOL *stop) {
				if ((rowDictionary[@"jobID"] != nil) && (rowDictionary[@"path"] != nil))
				{
					OCCoreDirectoryUpdateJob *updateJob;

					if ((updateJob = [OCCoreDirectoryUpdateJob new]) != nil)
					{
						updateJob.identifier = (OCCoreDirectoryUpdateJobID)rowDictionary[@"jobID"];
						updateJob.path = (OCPath)rowDictionary[@"path"];

						if (updateJobs == nil) { updateJobs = [NSMutableArray new]; }

						[updateJobs addObject:updateJob];
					}

				}
			} error:&iterationError];
		}

		if (completionHandler != nil)
		{
			completionHandler(self, iterationError, updateJobs);
		}
	}]];
}

- (void)removeDirectoryUpdateJobWithID:(OCCoreDirectoryUpdateJobID)jobID completionHandler:(OCDatabaseCompletionHandler)completionHandler
{
	if (jobID != nil)
	{
		[self.sqlDB executeQuery:[OCSQLiteQuery queryDeletingRowWithID:jobID fromTable:OCDatabaseTableNameUpdateJobs completionHandler:^(OCSQLiteDB * _Nonnull db, NSError * _Nullable error) {
			completionHandler(self, error);
		}]];
	}
	else
	{
		OCLogError(@"Could not remove updateJob: jobID is nil");
		completionHandler(self, OCError(OCErrorInsufficientParameters));
	}
}

#pragma mark - Sync Lane interface
- (void)addSyncLane:(OCSyncLane *)lane completionHandler:(OCDatabaseCompletionHandler)completionHandler
{
	NSData *laneData = [NSKeyedArchiver archivedDataWithRootObject:lane];

	if (laneData != nil)
	{
		[self.sqlDB executeQuery:[OCSQLiteQuery queryInsertingIntoTable:OCDatabaseTableNameSyncLanes rowValues:@{
			@"laneData" 		: laneData
		} resultHandler:^(OCSQLiteDB *db, NSError *error, NSNumber *rowID) {
			lane.identifier = rowID;

			completionHandler(self, error);
		}]];
	}
	else
	{
		OCLogError(@"Could not serialize lane=%@ to laneData=%@", lane, laneData);
		completionHandler(self, OCError(OCErrorInsufficientParameters));
	}
}

- (void)updateSyncLane:(OCSyncLane *)lane completionHandler:(OCDatabaseCompletionHandler)completionHandler
{
	NSData *laneData = [NSKeyedArchiver archivedDataWithRootObject:lane];

	if ((lane.identifier != nil) && (laneData != nil))
	{
		[self.sqlDB executeQuery:[OCSQLiteQuery queryUpdatingRowWithID:lane.identifier inTable:OCDatabaseTableNameSyncLanes withRowValues:@{
			@"laneData"	: laneData
		} completionHandler:^(OCSQLiteDB *db, NSError *error) {
			completionHandler(self, error);
		}]];
	}
	else
	{
		OCLogError(@"Could not update lane: serialize lane=%@ to laneData=%@ failed - or lane.identifier=%@ is nil", lane, laneData, lane.identifier);
		completionHandler(self, OCError(OCErrorInsufficientParameters));
	}
}

- (void)removeSyncLane:(OCSyncLane *)lane completionHandler:(OCDatabaseCompletionHandler)completionHandler
{
	if (lane.identifier != nil)
	{
		[self.sqlDB executeQuery:[OCSQLiteQuery queryDeletingRowWithID:lane.identifier fromTable:OCDatabaseTableNameSyncLanes completionHandler:^(OCSQLiteDB * _Nonnull db, NSError * _Nullable error) {
			completionHandler(self, error);
		}]];
	}
	else
	{
		OCLogError(@"Could not remove lane: lane.identifier is nil");
		completionHandler(self, OCError(OCErrorInsufficientParameters));
	}
}

- (void)retrieveSyncLaneForID:(OCSyncLaneID)laneID completionHandler:(OCDatabaseRetrieveSyncLaneCompletionHandler)completionHandler
{
	if (laneID != nil)
	{
		[self.sqlDB executeQuery:[OCSQLiteQuery querySelectingColumns:@[ @"laneData" ] fromTable:OCDatabaseTableNameSyncLanes where:@{
			@"laneID" : laneID,
		} orderBy:nil resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
			__block OCSyncLane *syncLane = nil;
			NSError *iterationError = error;

			if (error == nil)
			{
				[resultSet iterateUsing:^(OCSQLiteResultSet *resultSet, NSUInteger line, NSDictionary<NSString *,id<NSObject>> *rowDictionary, BOOL *stop) {
					if (rowDictionary[@"laneData"] != nil)
					{
						syncLane = [NSKeyedUnarchiver unarchiveObjectWithData:((NSData *)rowDictionary[@"laneData"])];
						syncLane.identifier = laneID;
						*stop = YES;
					}
				} error:&iterationError];
			}

			if (completionHandler != nil)
			{
				completionHandler(self, iterationError, syncLane);
			}
		}]];
	}
}

- (void)retrieveSyncLanesWithCompletionHandler:(OCDatabaseRetrieveSyncLanesCompletionHandler)completionHandler;
{
	[self.sqlDB executeQuery:[OCSQLiteQuery querySelectingColumns:@[ @"laneID", @"laneData" ] fromTable:OCDatabaseTableNameSyncLanes where:@{} orderBy:@"laneID" resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
		__block NSMutableArray <OCSyncLane *> *syncLanes = nil;
		NSError *iterationError = error;

		if (error == nil)
		{
			[resultSet iterateUsing:^(OCSQLiteResultSet *resultSet, NSUInteger line, NSDictionary<NSString *,id<NSObject>> *rowDictionary, BOOL *stop) {
				if (rowDictionary[@"laneData"] != nil)
				{
					if (syncLanes == nil) { syncLanes = [NSMutableArray new]; }

					OCSyncLane *syncLane;

					if ((syncLane = [NSKeyedUnarchiver unarchiveObjectWithData:((NSData *)rowDictionary[@"laneData"])]) != nil)
					{
						syncLane.identifier = (NSNumber *)rowDictionary[@"laneID"];

						[syncLanes addObject:syncLane];
					}
				}
			} error:&iterationError];
		}

		if (completionHandler != nil)
		{
			completionHandler(self, iterationError, syncLanes);
		}
	}]];
}

- (OCSyncLane *)laneForTags:(NSSet <OCSyncLaneTag> *)tags updatedLanes:(BOOL *)outUpdatedLanes readOnly:(BOOL)readOnly
{
	__block OCSyncLane *returnLane = nil;
	__block BOOL updatedLanes = NO;

	if (tags.count == 0)
	{
		return (nil);
	}

	OCSyncExec(waitForDatabase, {
		[self _laneForTags:tags updatedLanes:&updatedLanes readOnly:readOnly completionHandler:^(OCSyncLane *lane, BOOL updatedTheLanes) {
			returnLane = lane;
			updatedLanes = updatedTheLanes;

			OCSyncExecDone(waitForDatabase);
		}];
	});

	if (outUpdatedLanes != NULL)
	{
		*outUpdatedLanes = updatedLanes;
	}

	return (returnLane);
}

- (void)_laneForTags:(NSSet <OCSyncLaneTag> *)tags updatedLanes:(BOOL *)outUpdatedLanes readOnly:(BOOL)readOnly completionHandler:(void(^)(OCSyncLane *lane, BOOL updatedLanes))completionHandler
{
	if (tags.count == 0)
	{
		completionHandler(nil, NO);
	}

	[self retrieveSyncLanesWithCompletionHandler:^(OCDatabase *db, NSError *error, NSArray<OCSyncLane *> *syncLanes) {
		NSMutableSet <OCSyncLaneID> *afterLaneIDs = nil;
		__block OCSyncLane *returnLane = nil;
		__block BOOL updatedLanes = NO;

		for (OCSyncLane *lane in syncLanes)
		{
			NSUInteger prefixMatches=0, identicalTags=0;

			if ([lane coversTags:tags prefixMatches:&prefixMatches identicalTags:&identicalTags])
			{
				if (identicalTags == tags.count)
				{
					// Tags are identical => use existing lane
					returnLane = lane;
				}
				else
				{
					// Tags overlap with lane => create new, dependant lane => add afterLaneIDs
					if (!readOnly)
					{
						if (afterLaneIDs == nil) { afterLaneIDs = [NSMutableSet new]; }

						[afterLaneIDs addObject:lane.identifier];
					}
				}
			}
		}

		// Create new lane if no matching one was found
		if ((returnLane == nil) && (!readOnly))
		{
			OCSyncLane *lane;

			if ((lane = [OCSyncLane new]) != nil)
			{
				[lane extendWithTags:tags];
				lane.afterLanes = afterLaneIDs;

				[db addSyncLane:lane completionHandler:^(OCDatabase *db, NSError *error) {
					if (error != nil)
					{
						OCLogError(@"Error adding lane=%@: %@", lane, error);
					}
					else
					{
						returnLane = lane;
						updatedLanes = YES;
					}
				}];
			}
		}

		completionHandler(returnLane, updatedLanes);
	}];
}

#pragma mark - Sync Journal interface
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
				@"laneID"		: OCSQLiteNullProtect(syncRecord.laneID),
				@"timestampDate" 	: syncRecord.timestamp,
				@"inProgressSinceDate"	: OCSQLiteNullProtect(syncRecord.inProgressSince),
				@"action"		: syncRecord.actionIdentifier,
				@"path"			: path,
				@"localID"		: syncRecord.localID,
				@"recordData"		: [syncRecord serializedData]
			} resultHandler:^(OCSQLiteDB *db, NSError *error, NSNumber *rowID) {
				syncRecord.recordID = rowID;

				@synchronized(db)
				{
					if (syncRecord.recordID != nil)
					{
						if (syncRecord.progress != nil)
						{
							self->_progressBySyncRecordID[syncRecord.recordID] = syncRecord.progress.progress;
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
				@"laneID"		: OCSQLiteNullProtect(syncRecord.laneID),
				@"inProgressSinceDate"	: OCSQLiteNullProtect(syncRecord.inProgressSince),
				@"recordData"		: [syncRecord serializedData],
				@"localID"		: syncRecord.localID
			} completionHandler:^(OCSQLiteDB *db, NSError *error) {
				@synchronized(db)
				{
					if (syncRecord.progress.progress != nil)
					{
						self->_progressBySyncRecordID[syncRecord.recordID] = syncRecord.progress.progress;
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

- (void)numberOfSyncRecordsOnSyncLaneID:(OCSyncLaneID)laneID completionHandler:(OCDatabaseRetrieveSyncRecordCountCompletionHandler)completionHandler
{
	[self.sqlDB executeQuery:[OCSQLiteQuery query:@"SELECT COUNT(*) AS cnt FROM syncJournal WHERE laneID=:laneID" withNamedParameters:@{ @"laneID" : laneID } resultHandler:^(OCSQLiteDB * _Nonnull db, NSError * _Nullable error, OCSQLiteTransaction * _Nullable transaction, OCSQLiteResultSet * _Nullable resultSet) {
		[resultSet iterateUsing:^(OCSQLiteResultSet * _Nonnull resultSet, NSUInteger line, OCSQLiteRowDictionary  _Nonnull rowDictionary, BOOL * _Nonnull stop) {
			NSError *retrieveError = nil;
			NSNumber *numberOfSyncRecordsOnLane = nil;

			numberOfSyncRecordsOnLane = (NSNumber *)[resultSet nextRowDictionaryWithError:&retrieveError][@"cnt"];

			completionHandler(self, error, numberOfSyncRecordsOnLane);
		} error:nil];
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
				syncRecord.progress.progress = _progressBySyncRecordID[syncRecord.recordID];
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

- (void)retrieveSyncRecordAfterID:(OCSyncRecordID)recordID onLaneID:(OCSyncLaneID)laneID completionHandler:(OCDatabaseRetrieveSyncRecordCompletionHandler)completionHandler
{
	[self.sqlDB executeQuery:[OCSQLiteQuery querySelectingColumns:@[ @"recordID", @"recordData" ] fromTable:OCDatabaseTableNameSyncJournal where:@{
		@"recordID" 	: [OCSQLiteQueryCondition queryConditionWithOperator:@">" value:recordID apply:(recordID!=nil)],
		@"laneID"	: [OCSQLiteQueryCondition queryConditionWithOperator:@"=" value:laneID apply:(laneID!=nil)]
	} orderBy:@"recordID ASC" limit:@"0,1" resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
		__block OCSyncRecord *syncRecord = nil;
		NSError *iterationError = error;

		[resultSet iterateUsing:^(OCSQLiteResultSet *resultSet, NSUInteger line, NSDictionary<NSString *,id<NSObject>> *rowDictionary, BOOL *stop) {
			syncRecord = [self _syncRecordFromRowDictionary:rowDictionary];
			*stop = YES;
		} error:&iterationError];

		if (completionHandler != nil)
		{
			completionHandler(self, iterationError, syncRecord);
		}
	}]];
}

#pragma mark - Event interface
- (void)queueEvent:(OCEvent *)event forSyncRecordID:(OCSyncRecordID)syncRecordID processSession:(OCProcessSession *)processSession completionHandler:(OCDatabaseCompletionHandler)completionHandler
{
	NSData *eventData = [event serializedData];

	if ((eventData != nil) && (syncRecordID!=nil))
	{
		if (processSession == nil) { processSession = OCProcessManager.sharedProcessManager.processSession; }
		NSData *processSessionData = processSession.serializedData;

		[self.sqlDB executeQuery:[OCSQLiteQuery queryInsertingIntoTable:OCDatabaseTableNameEvents rowValues:@{
			@"recordID" 		: syncRecordID,
			@"processSession"	: (processSessionData!=nil) ? processSessionData : [NSData new],
			@"uuid"			: OCSQLiteNullProtect(event.uuid),
			@"eventData"		: eventData
		} resultHandler:^(OCSQLiteDB *db, NSError *error, NSNumber *rowID) {
			event.databaseID = rowID;

			self->_eventsByDatabaseID[rowID] = event;

			completionHandler(self, error);
		}]];
	}
	else
	{
		OCLogError(@"Could not serialize event=%@ to eventData=%@ or missing recordID=%@", event, eventData, syncRecordID);
		completionHandler(self, OCError(OCErrorInsufficientParameters));
	}
}

- (BOOL)queueContainsEvent:(OCEvent *)event
{
	if (!self.sqlDB.isOnSQLiteThread)
	{
		OCLogError(@"%@ may only be called on the SQLite thread. Returning nil.", @(__PRETTY_FUNCTION__));
		return (NO);
	}

	if (event.uuid == nil)
	{
		return (NO);
	}

	__block BOOL eventExistsInDatabase = NO;

	[self.sqlDB executeQuery:[OCSQLiteQuery querySelectingColumns:@[ @"eventID" ] fromTable:OCDatabaseTableNameEvents where:@{
		@"uuid"	: event.uuid
	} orderBy:@"eventID ASC" limit:@"0,1" resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
		NSError *iterationError = error;

		[resultSet iterateUsing:^(OCSQLiteResultSet *resultSet, NSUInteger line, NSDictionary<NSString *,id<NSObject>> *rowDictionary, BOOL *stop) {
			eventExistsInDatabase = YES;
			*stop = YES;
		} error:&iterationError];
	}]];

	return (eventExistsInDatabase);
}

- (OCEvent *)nextEventForSyncRecordID:(OCSyncRecordID)recordID afterEventID:(OCDatabaseID)afterEventID
{
	__block OCEvent *event = nil;
	__block OCProcessSession *processSession = nil;

	if (!self.sqlDB.isOnSQLiteThread)
	{
		OCLogError(@"%@ may only be called on the SQLite thread. Returning nil.", @(__PRETTY_FUNCTION__));
		return (nil);
	}

	// Requests the oldest available event for the OCSyncRecordID.
	[self.sqlDB executeQuery:[OCSQLiteQuery querySelectingColumns:@[ @"eventID", @"eventData" ] fromTable:OCDatabaseTableNameEvents where:@{
		@"recordID" 	: recordID,
		@"eventID"	: [OCSQLiteQueryCondition queryConditionWithOperator:@">" value:afterEventID apply:(afterEventID!=nil)]
	} orderBy:@"eventID ASC" limit:@"0,1" resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
		NSError *iterationError = error;

		[resultSet iterateUsing:^(OCSQLiteResultSet *resultSet, NSUInteger line, NSDictionary<NSString *,id<NSObject>> *rowDictionary, BOOL *stop) {
			NSNumber *databaseID;
			NSData *processSessionData = OCTypedCast(rowDictionary[@"processSession"], NSData);

			if ((processSessionData != nil) && (processSessionData.length > 0))
			{
				processSession = [OCProcessSession processSessionFromSerializedData:processSessionData];
			}

			if ((databaseID = OCTypedCast(rowDictionary[@"eventID"], NSNumber) ) != nil)
			{
				if ((event = [self->_eventsByDatabaseID objectForKey:databaseID]) == nil)
				{
					event = [OCEvent eventFromSerializedData:(NSData *)rowDictionary[@"eventData"]];
				}

				event.databaseID = rowDictionary[@"eventID"];
			}

			*stop = YES;
		} error:&iterationError];
	}]];

	if ((processSession != nil) && (event != nil))
	{
		BOOL doProcess = YES;

		// Only perform processSession validity check if bundleIDs differ
		if (![OCProcessManager.sharedProcessManager isSessionWithCurrentProcessBundleIdentifier:processSession])
		{
			// Don't process events originating from other processes that are running
			doProcess = ![OCProcessManager.sharedProcessManager isAnyInstanceOfSessionProcessRunning:processSession];
		}

		if (!doProcess)
		{
			// Skip this event
			// return ([self nextEventForSyncRecordID:recordID afterEventID:event.databaseID]);

			// Do not skip and look for the next event… because this is about the events for a single sync record - and out of order execution should not happen (?)
			return (nil);
		}
	}

	return (event);
}

- (NSError *)removeEvent:(OCEvent *)event
{
	__block NSError *error = nil;

	if (!self.sqlDB.isOnSQLiteThread)
	{
		OCLogError(@"%@ may only be called on the SQLite thread.", @(__PRETTY_FUNCTION__));
		return (OCError(OCErrorInternal));
	}

	// Deletes the row for the OCEvent from the database.
	if (event.databaseID != nil)
	{
		[self.sqlDB executeQuery:[OCSQLiteQuery queryDeletingRowWithID:event.databaseID fromTable:OCDatabaseTableNameEvents completionHandler:^(OCSQLiteDB *db, NSError *dbError) {
			NSNumber *databaseID;

			if ((databaseID = event.databaseID) != nil)
			{
				[self->_eventsByDatabaseID removeObjectForKey:databaseID];

				event.databaseID = nil;
			}

			error = dbError;
		}]];
	}
	else
	{
		OCLogError(@"Event %@ passed to %@ without databaseID. Attempt of multi-removal?", event, @(__PRETTY_FUNCTION__));
		error = OCError(OCErrorInsufficientParameters);
	}

	return (error);
}

#pragma mark - Item policy interface
- (void)addItemPolicy:(OCItemPolicy *)itemPolicy completionHandler:(OCDatabaseCompletionHandler)completionHandler
{
	NSData *itemPolicyData = [NSKeyedArchiver archivedDataWithRootObject:itemPolicy];

	if (itemPolicyData != nil)
	{
		[self.sqlDB executeQuery:[OCSQLiteQuery queryInsertingIntoTable:OCDatabaseTableNameItemPolicies rowValues:@{
			@"identifier"	: OCSQLiteNullProtect(itemPolicy.identifier),
			@"path"		: OCSQLiteNullProtect(itemPolicy.path),
			@"localID"	: OCSQLiteNullProtect(itemPolicy.localID),
			@"kind"		: itemPolicy.kind,
			@"policyData"	: itemPolicyData,
		} resultHandler:^(OCSQLiteDB *db, NSError *error, NSNumber *rowID) {
			itemPolicy.databaseID = rowID;

			completionHandler(self, error);
		}]];
	}
	else
	{
		OCLogError(@"Could not serialize itemPolicy=%@ to itemPolicyData=%@", itemPolicy, itemPolicyData);
		completionHandler(self, OCError(OCErrorInsufficientParameters));
	}
}

- (void)updateItemPolicy:(OCItemPolicy *)itemPolicy completionHandler:(OCDatabaseCompletionHandler)completionHandler
{
	NSData *itemPolicyData = [NSKeyedArchiver archivedDataWithRootObject:itemPolicy];

	if ((itemPolicy.databaseID != nil) && (itemPolicyData != nil))
	{
		[self.sqlDB executeQuery:[OCSQLiteQuery queryUpdatingRowWithID:itemPolicy.databaseID inTable:OCDatabaseTableNameItemPolicies withRowValues:@{
			@"identifier"	: OCSQLiteNullProtect(itemPolicy.identifier),
			@"path"		: OCSQLiteNullProtect(itemPolicy.path),
			@"localID"	: OCSQLiteNullProtect(itemPolicy.localID),
			@"kind"		: itemPolicy.kind,
			@"policyData"	: itemPolicyData,
		} completionHandler:^(OCSQLiteDB *db, NSError *error) {
			completionHandler(self, error);
		}]];
	}
	else
	{
		OCLogError(@"Could not update item policy: serialize itemPolicy=%@ to itemPolicyData=%@ failed - or itemPolicy.databaseID=%@ is nil", itemPolicy, itemPolicyData, itemPolicy.databaseID);
		completionHandler(self, OCError(OCErrorInsufficientParameters));
	}
}

- (void)removeItemPolicy:(OCItemPolicy *)itemPolicy completionHandler:(OCDatabaseCompletionHandler)completionHandler
{
	if (itemPolicy.databaseID != nil)
	{
		[self.sqlDB executeQuery:[OCSQLiteQuery queryDeletingRowWithID:itemPolicy.databaseID fromTable:OCDatabaseTableNameItemPolicies completionHandler:^(OCSQLiteDB * _Nonnull db, NSError * _Nullable error) {
			completionHandler(self, error);
		}]];
	}
	else
	{
		OCLogError(@"Could not remove item policy: itemPolicy.databaseID is nil");
		completionHandler(self, OCError(OCErrorInsufficientParameters));
	}
}

- (void)retrieveItemPoliciesForKind:(OCItemPolicyKind)kind path:(OCPath)path localID:(OCLocalID)localID identifier:(OCItemPolicyIdentifier)identifier completionHandler:(OCDatabaseRetrieveItemPoliciesCompletionHandler)completionHandler
{
	[self.sqlDB executeQuery:[OCSQLiteQuery querySelectingColumns:@[ @"policyID", @"policyData" ] fromTable:OCDatabaseTableNameItemPolicies where:@{
		@"identifier"	: [OCSQLiteQueryCondition queryConditionWithOperator:@"=" value:identifier 	apply:(identifier!=nil)],
		@"path"		: [OCSQLiteQueryCondition queryConditionWithOperator:@"=" value:path		apply:(path!=nil)],
		@"localID"	: [OCSQLiteQueryCondition queryConditionWithOperator:@"=" value:localID 	apply:(localID!=nil)],
		@"kind"		: [OCSQLiteQueryCondition queryConditionWithOperator:@"=" value:kind		apply:(kind!=nil)]
	} resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
		NSMutableArray<OCItemPolicy *> *itemPolicies = [NSMutableArray new];
		NSError *iterationError = error;

		[resultSet iterateUsing:^(OCSQLiteResultSet *resultSet, NSUInteger line, NSDictionary<NSString *,id<NSObject>> *rowDictionary, BOOL *stop) {
			NSData *policyData;

			if ((policyData = (id)rowDictionary[@"policyData"]) != nil)
			{
				OCItemPolicy *itemPolicy = nil;

				if ((itemPolicy = [NSKeyedUnarchiver unarchiveObjectWithData:policyData]) != nil)
				{
					itemPolicy.databaseID = rowDictionary[@"policyID"];
					[itemPolicies addObject:itemPolicy];
				}
			}
		} error:&iterationError];

		if (completionHandler != nil)
		{
			completionHandler(self, iterationError, itemPolicies);
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
