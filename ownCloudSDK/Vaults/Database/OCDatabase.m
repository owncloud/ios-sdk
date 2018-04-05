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
#import "OCItem.h"

@implementation OCDatabase

@synthesize databaseURL = _databaseURL;
@synthesize sqlDB = _sqlDB;

#pragma mark - Initialization
- (instancetype)initWithURL:(NSURL *)databaseURL
{
	if ((self = [self init]) != nil)
	{
		self.databaseURL = databaseURL;

		self.sqlDB = [[OCSQLiteDB alloc] initWithURL:databaseURL];
		[self addSchemas];
	}

	return (self);
}

#pragma mark - Schemas
- (void)addSchemas
{
	/*** MetaData ***/

	// Version 1
	[self.sqlDB addTableSchema:[OCSQLiteTableSchema
		schemaWithTableName:OCDatabaseTableNameMetaData
		version:1
		creationQueries:@[
			/*
				mdID : INTEGER	  	- unique ID used to uniquely identify and efficiently update a row
				type : INTEGER    	- OCItemType value to indicate if this is a file or a collection/folder
				locallyModified: INTEGER- value indicating if this is a file that's been created or modified locally
				localRelativePath: TEXT	- path of the local copy of the item, relative to the rootURL of the vault that stores it
				path : TEXT	  	- full path of the item (e.g. "/example/file.txt")
				parentPath : TEXT 	- parent path of the item. (e.g. "/example" for an item at "/example/file.txt")
				name : TEXT 	  	- name of the item (e.g. "file.txt" for an item at "/example/file.txt")
				itemData : BLOB	  	- data of the serialized OCItem
			*/
			@"CREATE TABLE metaData (mdID INTEGER PRIMARY KEY, type INTEGER NOT NULL, locallyModified INTEGER NOT NULL, localRelativePath TEXT NULL, path TEXT NOT NULL, parentPath TEXT NOT NULL, name TEXT NOT NULL, itemData BLOB NOT NULL)"
		]
		upgradeMigrator:nil]
	];
}

#pragma mark - Open / Close
- (void)openWithCompletionHandler:(OCDatabaseCompletionHandler)completionHandler
{
	[self.sqlDB openWithFlags:OCSQLiteOpenFlagsDefault completionHandler:^(OCSQLiteDB *db, NSError *error) {
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
			if (completionHandler!=nil)
			{
				completionHandler(self, error);
			}
		}
	}];
}

- (void)closeWithCompletionHandler:(OCDatabaseCompletionHandler)completionHandler
{
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
- (void)addCacheItems:(NSArray <OCItem *> *)items completionHandler:(OCDatabaseCompletionHandler)completionHandler
{
	NSMutableArray <OCSQLiteQuery *> *queries = [[NSMutableArray alloc] initWithCapacity:items.count];

	for (OCItem *item in items)
	{
		[queries addObject:[OCSQLiteQuery queryInsertingIntoTable:OCDatabaseTableNameMetaData rowValues:@{
			@"type" 		: @(item.type),
			@"locallyModified" 	: @(item.locallyModified),
			@"localRelativePath"	: ((item.localRelativePath!=nil) ? item.localRelativePath : [NSNull null]),
			@"path" 		: item.path,
			@"parentPath" 		: [item.path stringByDeletingLastPathComponent],
			@"name"			: [item.path lastPathComponent],
			@"itemData"		: [item serializedData]
		} resultHandler:^(OCSQLiteDB *db, NSError *error, NSNumber *rowID) {
			item.databaseID = rowID;
		}]];
	}

	[self.sqlDB executeTransaction:[OCSQLiteTransaction transactionWithQueries:queries type:OCSQLiteTransactionTypeDeferred completionHandler:^(OCSQLiteDB *db, OCSQLiteTransaction *transaction, NSError *error) {
		completionHandler(self, error);
	}]];
}

- (void)updateCacheItems:(NSArray <OCItem *> *)items completionHandler:(OCDatabaseCompletionHandler)completionHandler
{
	NSMutableArray <OCSQLiteQuery *> *queries = [[NSMutableArray alloc] initWithCapacity:items.count];

	for (OCItem *item in items)
	{
		if (item.databaseID != nil)
		{
			[queries addObject:[OCSQLiteQuery queryUpdatingRowWithID:item.databaseID inTable:OCDatabaseTableNameMetaData withRowValues:@{
				@"type" 		: @(item.type),
				@"locallyModified" 	: @(item.locallyModified),
				@"localRelativePath"	: ((item.localRelativePath!=nil) ? item.localRelativePath : [NSNull null]),
				@"path" 		: item.path,
				@"parentPath" 		: [item.path stringByDeletingLastPathComponent],
				@"name"			: [item.path lastPathComponent],
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

- (void)removeCacheItems:(NSArray <OCItem *> *)items completionHandler:(OCDatabaseCompletionHandler)completionHandler
{
	NSMutableArray <OCSQLiteQuery *> *queries = [[NSMutableArray alloc] initWithCapacity:items.count];

	for (OCItem *item in items)
	{
		if (item.databaseID != nil)
		{
			[queries addObject:[OCSQLiteQuery queryDeletingRowWithID:item.databaseID fromTable:OCDatabaseTableNameMetaData completionHandler:^(OCSQLiteDB *db, NSError *error) {
				item.databaseID = nil;
			}]];
		}
		else
		{
			OCLogError(@"Item without databaseID can't be used for deletion: %@", item);
		}
	}

	[self.sqlDB executeTransaction:[OCSQLiteTransaction transactionWithQueries:queries type:OCSQLiteTransactionTypeDeferred completionHandler:^(OCSQLiteDB *db, OCSQLiteTransaction *transaction, NSError *error) {
		completionHandler(self, error);
	}]];
}

- (void)retrieveCacheItemsAtPath:(OCPath)path completionHandler:(OCDatabaseRetrieveCompletionHandler)completionHandler
{
	[self.sqlDB executeQuery:[OCSQLiteQuery querySelectingColumns:@[ @"mdID", @"itemData" ] fromTable:OCDatabaseTableNameMetaData where:@{
		@"parentPath" : path
	} resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
		if (error != nil)
		{
			completionHandler(self, error, nil);
		}
		else
		{
			NSMutableArray <NSDictionary<NSString *, id<NSObject>> *> *resultDicts = [NSMutableArray new];
			NSError *returnError = nil;

			[resultSet iterateUsing:^(OCSQLiteResultSet *resultSet, NSUInteger line, NSDictionary<NSString *,id<NSObject>> *rowDictionary, BOOL *stop) {
				[resultDicts addObject:rowDictionary];
			} error:&returnError];

			if (returnError != nil)
			{
				completionHandler(self, returnError, nil);
			}
			else
			{
				dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
					NSMutableArray <OCItem *> *items = [NSMutableArray new];

					for (NSDictionary<NSString *, id<NSObject>> *resultDict in resultDicts)
					{
						NSData *itemData;

						if ((itemData = (NSData *)resultDict[@"itemData"]) != nil)
						{
							OCItem *item;

							if ((item = [OCItem itemFromSerializedData:itemData]) != nil)
							{
								[items addObject:item];
								item.databaseID = resultDict[@"mdID"];
							}
						}
					}

					completionHandler(self, nil, items);
				});
			}
		}
	}]];
}

@end

OCDatabaseTableName OCDatabaseTableNameMetaData = @"metaData";
