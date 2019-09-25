//
//  OCDatabase+Schemas.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 02.05.18.
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

#import "OCDatabase+Schemas.h"
#import "OCItem.h"
#import "OCSQLiteTransaction.h"
#import "OCSyncLane.h"

#define INSTALL_TRANSACTION_ERROR_COLLECTION_RESULT_HANDLER \
	__block NSError *transactionError = nil;  \
	OCSQLiteDBResultHandler resultHandler = ^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {  \
		if (error != nil)  \
		{  \
			transactionError = error;  \
		}  \
	};


@implementation OCDatabase (Schemas)

#pragma mark - Schemas
- (void)addSchemas
{
	[self addOrUpdateCountersSchema];

	[self addOrUpdateMetaDataSchema];
	[self addOrUpdateThumbnailsSchema];

	[self addOrUpdateSyncLanesSchema];
	[self addOrUpdateSyncJournalSchema];
	[self addOrUpdateEvents];

	[self addOrUpdateItemPoliciesSchema];

	[self addOrUpdateUpdateScanPaths];
}

- (void)addOrUpdateMetaDataSchema
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
		openStatements:nil
		upgradeMigrator:nil]
	];

	// Version 2
	[self.sqlDB addTableSchema:[OCSQLiteTableSchema
		schemaWithTableName:OCDatabaseTableNameMetaData
		version:2
		creationQueries:@[
			/*
				mdID : INTEGER	  	- unique ID used to uniquely identify and efficiently update a row
				type : INTEGER    	- OCItemType value to indicate if this is a file or a collection/folder
				locallyModified: INTEGER- value indicating if this is a file that's been created or modified locally
				localRelativePath: TEXT	- path of the local copy of the item, relative to the rootURL of the vault that stores it
				path : TEXT	  	- full path of the item (e.g. "/example/file.txt")
				parentPath : TEXT 	- parent path of the item. (e.g. "/example" for an item at "/example/file.txt")
				name : TEXT 	  	- name of the item (e.g. "file.txt" for an item at "/example/file.txt")
				fileID : TEXT		- OCFileID identifying the item
				itemData : BLOB	  	- data of the serialized OCItem
			*/
			@"CREATE TABLE metaData (mdID INTEGER PRIMARY KEY, type INTEGER NOT NULL, locallyModified INTEGER NOT NULL, localRelativePath TEXT NULL, path TEXT NOT NULL, parentPath TEXT NOT NULL, name TEXT NOT NULL, fileID TEXT NOT NULL, itemData BLOB NOT NULL)",

			// Create indexes over path and parentPath
			@"CREATE INDEX idx_metaData_path ON metaData (path)",
			@"CREATE INDEX idx_metaData_parentPath ON metaData (parentPath)",

			// Create trigger to delete thumbnails alongside metadata entries
			@"CREATE TRIGGER delete_associated_thumbnails AFTER DELETE ON metaData BEGIN DELETE FROM thumb.thumbnails WHERE fileID = OLD.fileID; END" // relatedTo:OCDatabaseTableNameThumbnails
		]
		openStatements:nil
		upgradeMigrator:^(OCSQLiteDB *db, OCSQLiteTableSchema *schema, void (^completionHandler)(NSError *error)) {
			// Migrate to version 2
			[db executeTransaction:[OCSQLiteTransaction transactionWithBlock:^NSError *(OCSQLiteDB *db, OCSQLiteTransaction *transaction) {
				INSTALL_TRANSACTION_ERROR_COLLECTION_RESULT_HANDLER

				// Add fileID column
				[db executeQuery:[OCSQLiteQuery query:@"ALTER TABLE metaData ADD COLUMN fileID TEXT" resultHandler:resultHandler]];
				if (transactionError != nil) { return(transactionError); }

				// Populate fileID column
				[db executeQuery:[OCSQLiteQuery querySelectingColumns:@[@"mdID", @"itemData"] fromTable:OCDatabaseTableNameMetaData where:nil resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
					[resultSet iterateUsing:^(OCSQLiteResultSet *resultSet, NSUInteger line, NSDictionary<NSString *, id> *rowDictionary, BOOL *stop) {
						OCItem *item;

						if ((item = [OCItem itemFromSerializedData:rowDictionary[@"itemData"]]) != nil)
						{
							if (rowDictionary[@"mdID"] != nil)
							{
								[db executeQuery:[OCSQLiteQuery queryUpdatingRowWithID:rowDictionary[@"mdID"]
												inTable:OCDatabaseTableNameMetaData
												withRowValues:@{
															@"fileID" : item.fileID
														}
												completionHandler:^(OCSQLiteDB *db, NSError *error) {
													if (error != nil)
													{
														transactionError = error;
													}
												}
										]
								];
							}
						}
					} error:&transactionError];
				}]];
				if (transactionError != nil) { return(transactionError); }

				// Create indexes
				[db executeQuery:[OCSQLiteQuery query:@"CREATE INDEX idx_metaData_path ON metaData (path)" resultHandler:resultHandler]];
				if (transactionError != nil) { return(transactionError); }

				[db executeQuery:[OCSQLiteQuery query:@"CREATE INDEX idx_metaData_parentPath ON metaData (parentPath)" resultHandler:resultHandler]];
				if (transactionError != nil) { return(transactionError); }

				// Create deletion trigger
				[db executeQuery:[OCSQLiteQuery query:@"CREATE TRIGGER delete_associated_thumbnails AFTER DELETE ON metaData BEGIN DELETE FROM thumb.thumbnails WHERE fileID = OLD.fileID; END" resultHandler:resultHandler]]; // relatedTo:OCDatabaseTableNameThumbnails

				return (transactionError);

			} type:OCSQLiteTransactionTypeDeferred completionHandler:^(OCSQLiteDB *db, OCSQLiteTransaction *transaction, NSError *error) {
				completionHandler(error);
			}]];
		}]
	];

	// Version 3
	[self.sqlDB addTableSchema:[OCSQLiteTableSchema
		schemaWithTableName:OCDatabaseTableNameMetaData
		version:3
		creationQueries:@[
			/*
				mdID : INTEGER	  	- unique ID used to uniquely identify and efficiently update a row
				type : INTEGER    	- OCItemType value to indicate if this is a file or a collection/folder
				syncAnchor: INTEGER	- sync anchor, a number that increases its value with every change to an entry. For files, higher sync anchor values indicate the file changed (incl. creation, content or meta data changes). For collections/folders, higher sync anchor values indicate the list of items in the collection/folder changed in a way not covered by file entries (i.e. rename, deletion, but not creation of files).
				locallyModified: INTEGER- value indicating if this is a file that's been created or modified locally
				localRelativePath: TEXT	- path of the local copy of the item, relative to the rootURL of the vault that stores it
				path : TEXT	  	- full path of the item (e.g. "/example/file.txt")
				parentPath : TEXT 	- parent path of the item. (e.g. "/example" for an item at "/example/file.txt")
				name : TEXT 	  	- name of the item (e.g. "file.txt" for an item at "/example/file.txt")
				fileID : TEXT		- OCFileID identifying the item
				itemData : BLOB	  	- data of the serialized OCItem
			*/
			@"CREATE TABLE metaData (mdID INTEGER PRIMARY KEY, type INTEGER NOT NULL, syncAnchor INTEGER NOT NULL, locallyModified INTEGER NOT NULL, localRelativePath TEXT NULL, path TEXT NOT NULL, parentPath TEXT NOT NULL, name TEXT NOT NULL, fileID TEXT NOT NULL, itemData BLOB NOT NULL)",

			// Create indexes over path and parentPath
			@"CREATE INDEX idx_metaData_path ON metaData (path)",
			@"CREATE INDEX idx_metaData_parentPath ON metaData (parentPath)",
			@"CREATE INDEX idx_metaData_synchAnchor ON metaData (syncAnchor)",
		]
		openStatements:@[
			// Create trigger to delete thumbnails alongside metadata entries
			@"CREATE TEMPORARY TRIGGER temp_delete_associated_thumbnails AFTER DELETE ON metaData BEGIN DELETE FROM thumb.thumbnails WHERE fileID = OLD.fileID; END" // relatedTo:OCDatabaseTableNameThumbnails
		]
		upgradeMigrator:^(OCSQLiteDB *db, OCSQLiteTableSchema *schema, void (^completionHandler)(NSError *error)) {
			// Migrate to version 3
			[db executeTransaction:[OCSQLiteTransaction transactionWithBlock:^NSError *(OCSQLiteDB *db, OCSQLiteTransaction *transaction) {
				INSTALL_TRANSACTION_ERROR_COLLECTION_RESULT_HANDLER

				// Add syncAnchor column
				[db executeQuery:[OCSQLiteQuery query:@"ALTER TABLE metaData ADD COLUMN syncAnchor INTEGER" resultHandler:resultHandler]];
				if (transactionError != nil) { return(transactionError); }

				// Create synchAnchor index
				[db executeQuery:[OCSQLiteQuery query:@"CREATE INDEX idx_metaData_synchAnchor ON metaData (syncAnchor)" resultHandler:resultHandler]];
				if (transactionError != nil) { return(transactionError); }

				return (transactionError);

			} type:OCSQLiteTransactionTypeDeferred completionHandler:^(OCSQLiteDB *db, OCSQLiteTransaction *transaction, NSError *error) {
				completionHandler(error);
			}]];
		}]
	];

	// Version 4
	[self.sqlDB addTableSchema:[OCSQLiteTableSchema
		schemaWithTableName:OCDatabaseTableNameMetaData
		version:4
		creationQueries:@[
			/*
				mdID : INTEGER	  	- unique ID used to uniquely identify and efficiently update a row
				type : INTEGER    	- OCItemType value to indicate if this is a file or a collection/folder
				syncAnchor: INTEGER	- sync anchor, a number that increases its value with every change to an entry. For files, higher sync anchor values indicate the file changed (incl. creation, content or meta data changes). For collections/folders, higher sync anchor values indicate the list of items in the collection/folder changed in a way not covered by file entries (i.e. rename, deletion, but not creation of files).
				removed : INTEGER	- value indicating if this file or folder has been removed: 1 if it was, 0 if not (default). Removed entries are kept around until their delta to the latest syncAnchor value exceeds -[OCDatabase removedItemRetentionLength].
				locallyModified: INTEGER- value indicating if this is a file that's been created or modified locally
				localRelativePath: TEXT	- path of the local copy of the item, relative to the rootURL of the vault that stores it
				path : TEXT	  	- full path of the item (e.g. "/example/file.txt")
				parentPath : TEXT 	- parent path of the item. (e.g. "/example" for an item at "/example/file.txt")
				name : TEXT 	  	- name of the item (e.g. "file.txt" for an item at "/example/file.txt")
				fileID : TEXT		- OCFileID identifying the item
				itemData : BLOB	  	- data of the serialized OCItem
			*/
			@"CREATE TABLE metaData (mdID INTEGER PRIMARY KEY, type INTEGER NOT NULL, syncAnchor INTEGER NOT NULL, removed INTEGER NOT NULL, locallyModified INTEGER NOT NULL, localRelativePath TEXT NULL, path TEXT NOT NULL, parentPath TEXT NOT NULL, name TEXT NOT NULL, fileID TEXT NOT NULL, itemData BLOB NOT NULL)",

			// Create indexes over path and parentPath
			@"CREATE INDEX idx_metaData_path ON metaData (path)",
			@"CREATE INDEX idx_metaData_parentPath ON metaData (parentPath)",
			@"CREATE INDEX idx_metaData_synchAnchor ON metaData (syncAnchor)",
			@"CREATE INDEX idx_metaData_removed ON metaData (removed)",
		]
		openStatements:@[
			// Create trigger to delete thumbnails alongside metadata entries
			@"CREATE TEMPORARY TRIGGER temp_delete_associated_thumbnails AFTER DELETE ON metaData BEGIN DELETE FROM thumb.thumbnails WHERE fileID = OLD.fileID; END" // relatedTo:OCDatabaseTableNameThumbnails
		]
		upgradeMigrator:^(OCSQLiteDB *db, OCSQLiteTableSchema *schema, void (^completionHandler)(NSError *error)) {
			// Migrate to version 4
			[db executeTransaction:[OCSQLiteTransaction transactionWithBlock:^NSError *(OCSQLiteDB *db, OCSQLiteTransaction *transaction) {
				INSTALL_TRANSACTION_ERROR_COLLECTION_RESULT_HANDLER

				// Add "removed" column
				[db executeQuery:[OCSQLiteQuery query:@"ALTER TABLE metaData ADD COLUMN removed INTEGER" resultHandler:resultHandler]];
				if (transactionError != nil) { return(transactionError); }

				// Create "removed" index
				[db executeQuery:[OCSQLiteQuery query:@"CREATE INDEX idx_metaData_removed ON metaData (removed)" resultHandler:resultHandler]];
				if (transactionError != nil) { return(transactionError); }

				// Delete existing metaData (as it lacks parentFileID info, and versions of this schema < 4 serve only as cache)
				[db executeQuery:[OCSQLiteQuery query:@"DELETE FROM metaData" resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
					if (error != nil)
					{
						transactionError = error;
					}
				}]];

				if (transactionError != nil) { return(transactionError); }

				return (transactionError);

			} type:OCSQLiteTransactionTypeDeferred completionHandler:^(OCSQLiteDB *db, OCSQLiteTransaction *transaction, NSError *error) {
				completionHandler(error);
			}]];
		}]
	];

	// Version 5
	[self.sqlDB addTableSchema:[OCSQLiteTableSchema
		schemaWithTableName:OCDatabaseTableNameMetaData
		version:5
		creationQueries:@[
			/*
				mdID : INTEGER	  	- unique ID used to uniquely identify and efficiently update a row
				type : INTEGER    	- OCItemType value to indicate if this is a file or a collection/folder
				syncAnchor: INTEGER	- sync anchor, a number that increases its value with every change to an entry. For files, higher sync anchor values indicate the file changed (incl. creation, content or meta data changes). For collections/folders, higher sync anchor values indicate the list of items in the collection/folder changed in a way not covered by file entries (i.e. rename, deletion, but not creation of files).
				removed : INTEGER	- value indicating if this file or folder has been removed: 1 if it was, 0 if not (default). Removed entries are kept around until their delta to the latest syncAnchor value exceeds -[OCDatabase removedItemRetentionLength].
				locallyModified: INTEGER- value indicating if this is a file that's been created or modified locally
				localRelativePath: TEXT	- path of the local copy of the item, relative to the rootURL of the vault that stores it
				path : TEXT	  	- full path of the item (e.g. "/example/file.txt")
				parentPath : TEXT 	- parent path of the item. (e.g. "/example" for an item at "/example/file.txt")
				name : TEXT 	  	- name of the item (e.g. "file.txt" for an item at "/example/file.txt")
				fileID : TEXT		- OCFileID identifying the item
				localID : TEXT		- OCLocalID identifying the item
				itemData : BLOB	  	- data of the serialized OCItem
			*/
			@"CREATE TABLE metaData (mdID INTEGER PRIMARY KEY, type INTEGER NOT NULL, syncAnchor INTEGER NOT NULL, removed INTEGER NOT NULL, locallyModified INTEGER NOT NULL, localRelativePath TEXT NULL, path TEXT NOT NULL, parentPath TEXT NOT NULL, name TEXT NOT NULL, fileID TEXT NOT NULL, localID TEXT, itemData BLOB NOT NULL)",

			// Create indexes over path and parentPath
			@"CREATE INDEX idx_metaData_path ON metaData (path)",
			@"CREATE INDEX idx_metaData_parentPath ON metaData (parentPath)",
			@"CREATE INDEX idx_metaData_synchAnchor ON metaData (syncAnchor)",
			@"CREATE INDEX idx_metaData_localID ON metaData (localID)",
			@"CREATE INDEX idx_metaData_fileID ON metaData (fileID)",
			@"CREATE INDEX idx_metaData_removed ON metaData (removed)",
		]
		openStatements:@[
			// Create trigger to delete thumbnails alongside metadata entries
			@"CREATE TEMPORARY TRIGGER temp_delete_associated_thumbnails AFTER DELETE ON metaData BEGIN DELETE FROM thumb.thumbnails WHERE fileID = OLD.fileID; END" // relatedTo:OCDatabaseTableNameThumbnails
		]
		upgradeMigrator:^(OCSQLiteDB *db, OCSQLiteTableSchema *schema, void (^completionHandler)(NSError *error)) {
			// Migrate to version 5

			[db executeTransaction:[OCSQLiteTransaction transactionWithBlock:^NSError *(OCSQLiteDB *db, OCSQLiteTransaction *transaction) {
				INSTALL_TRANSACTION_ERROR_COLLECTION_RESULT_HANDLER

				// Add "removed" column
				[db executeQuery:[OCSQLiteQuery query:@"ALTER TABLE metaData ADD COLUMN localID TEXT" resultHandler:resultHandler]];
				if (transactionError != nil) { return(transactionError); }

				// Create "localID" index
				[db executeQuery:[OCSQLiteQuery query:@"CREATE INDEX idx_metaData_localID ON metaData (localID)" resultHandler:resultHandler]];
				if (transactionError != nil) { return(transactionError); }

				// Create "fileID" index
				[db executeQuery:[OCSQLiteQuery query:@"CREATE INDEX idx_metaData_fileID ON metaData (fileID)" resultHandler:resultHandler]];
				if (transactionError != nil) { return(transactionError); }

				// Migrate
				[db executeQuery:[OCSQLiteQuery querySelectingColumns:@[@"mdID", @"itemData"] fromTable:OCDatabaseTableNameMetaData where:nil resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
					// Migrate OCItems
					[resultSet iterateUsing:^(OCSQLiteResultSet *resultSet, NSUInteger line, NSDictionary<NSString *, id> *rowDictionary, BOOL *stop) {
						OCItem *item;

						if ((item = [OCItem itemFromSerializedData:rowDictionary[@"itemData"]]) != nil)
						{
							if (rowDictionary[@"mdID"] != nil)
							{
								item.localID = item.fileID;

								if (item.parentFileID != nil)
								{
									item.parentLocalID = item.parentFileID;
								}

								[db executeQuery:[OCSQLiteQuery queryUpdatingRowWithID:rowDictionary[@"mdID"]
												inTable:OCDatabaseTableNameMetaData
												withRowValues:@{
															@"localID"  : item.localID,
															@"itemData" : [item serializedData]
													       }
												completionHandler:^(OCSQLiteDB *db, NSError *error) {
													if (error != nil)
													{
														transactionError = error;
													}
												}
										]
								];
							}
						}
					} error:&transactionError];
				}]];
				if (transactionError != nil) { return(transactionError); }

				return (transactionError);

			} type:OCSQLiteTransactionTypeDeferred completionHandler:^(OCSQLiteDB *db, OCSQLiteTransaction *transaction, NSError *error) {
				completionHandler(error);
			}]];
		}]
	];

	// Version 6
	[self.sqlDB addTableSchema:[OCSQLiteTableSchema
		schemaWithTableName:OCDatabaseTableNameMetaData
		version:6
		creationQueries:@[
			/*
				mdID : INTEGER	  	- unique ID used to uniquely identify and efficiently update a row
				type : INTEGER    	- OCItemType value to indicate if this is a file or a collection/folder
				syncAnchor: INTEGER	- sync anchor, a number that increases its value with every change to an entry. For files, higher sync anchor values indicate the file changed (incl. creation, content or meta data changes). For collections/folders, higher sync anchor values indicate the list of items in the collection/folder changed in a way not covered by file entries (i.e. rename, deletion, but not creation of files).
				removed : INTEGER	- value indicating if this file or folder has been removed: 1 if it was, 0 if not (default). Removed entries are kept around until their delta to the latest syncAnchor value exceeds -[OCDatabase removedItemRetentionLength].
				locallyModified: INTEGER- value indicating if this is a file that's been created or modified locally
				localRelativePath: TEXT	- path of the local copy of the item, relative to the rootURL of the vault that stores it
				path : TEXT	  	- full path of the item (e.g. "/example/file.txt")
				parentPath : TEXT 	- parent path of the item. (e.g. "/example" for an item at "/example/file.txt")
				name : TEXT 	  	- name of the item (e.g. "file.txt" for an item at "/example/file.txt")
				fileID : TEXT		- OCFileID identifying the item
				localID : TEXT		- OCLocalID identifying the item
				itemData : BLOB	  	- data of the serialized OCItem
			*/
			@"CREATE TABLE metaData (mdID INTEGER PRIMARY KEY AUTOINCREMENT, type INTEGER NOT NULL, syncAnchor INTEGER NOT NULL, removed INTEGER NOT NULL, locallyModified INTEGER NOT NULL, localRelativePath TEXT NULL, path TEXT NOT NULL, parentPath TEXT NOT NULL, name TEXT NOT NULL, fileID TEXT NOT NULL, localID TEXT, itemData BLOB NOT NULL)",

			// Create indexes over path and parentPath
			@"CREATE INDEX idx_metaData_path ON metaData (path)",
			@"CREATE INDEX idx_metaData_parentPath ON metaData (parentPath)",
			@"CREATE INDEX idx_metaData_synchAnchor ON metaData (syncAnchor)",
			@"CREATE INDEX idx_metaData_localID ON metaData (localID)",
			@"CREATE INDEX idx_metaData_fileID ON metaData (fileID)",
			@"CREATE INDEX idx_metaData_removed ON metaData (removed)",
		]
		openStatements:@[
			// Create trigger to delete thumbnails alongside metadata entries
			@"CREATE TEMPORARY TRIGGER temp_delete_associated_thumbnails AFTER DELETE ON metaData BEGIN DELETE FROM thumb.thumbnails WHERE fileID = OLD.fileID; END" // relatedTo:OCDatabaseTableNameThumbnails
		]
		upgradeMigrator:^(OCSQLiteDB *db, OCSQLiteTableSchema *schema, void (^completionHandler)(NSError *error)) {
			// Migrate to version 6

			[db executeTransaction:[OCSQLiteTransaction transactionWithBlock:^NSError *(OCSQLiteDB *db, OCSQLiteTransaction *transaction) {
				INSTALL_TRANSACTION_ERROR_COLLECTION_RESULT_HANDLER

				// Create new table
				[db executeQuery:[OCSQLiteQuery query:@"CREATE TABLE metaData_new (mdID INTEGER PRIMARY KEY AUTOINCREMENT, type INTEGER NOT NULL, syncAnchor INTEGER NOT NULL, removed INTEGER NOT NULL, locallyModified INTEGER NOT NULL, localRelativePath TEXT NULL, path TEXT NOT NULL, parentPath TEXT NOT NULL, name TEXT NOT NULL, fileID TEXT NOT NULL, localID TEXT, itemData BLOB NOT NULL)" resultHandler:resultHandler]];
				if (transactionError != nil) { return(transactionError); }

				// Migrate data to new table
				[db executeQuery:[OCSQLiteQuery query:@"INSERT INTO metaData_new (mdID, type, syncAnchor, removed, locallyModified, localRelativePath, path, parentPath, name, fileID, localID, itemData) SELECT mdID, type, syncAnchor, removed, locallyModified, localRelativePath, path, parentPath, name, fileID, localID, itemData FROM metaData" resultHandler:resultHandler]];
				if (transactionError != nil) { return(transactionError); }

				// Drop old table
				[db executeQuery:[OCSQLiteQuery query:@"DROP TABLE metaData" resultHandler:resultHandler]];
				if (transactionError != nil) { return(transactionError); }

				// Rename new table
				[db executeQuery:[OCSQLiteQuery query:@"ALTER TABLE metaData_new RENAME TO metaData" resultHandler:resultHandler]];
				if (transactionError != nil) { return(transactionError); }

				return (transactionError);
			} type:OCSQLiteTransactionTypeDeferred completionHandler:^(OCSQLiteDB *db, OCSQLiteTransaction *transaction, NSError *error) {
				completionHandler(error);
			}]];
		}]
	];

	// Version 7
	[self.sqlDB addTableSchema:[OCSQLiteTableSchema
		schemaWithTableName:OCDatabaseTableNameMetaData
		version:7
		creationQueries:@[
			/*
				mdID : INTEGER	  		- unique ID used to uniquely identify and efficiently update a row
				type : INTEGER    		- OCItemType value to indicate if this is a file or a collection/folder
				syncAnchor: INTEGER		- sync anchor, a number that increases its value with every change to an entry. For files, higher sync anchor values indicate the file changed (incl. creation, content or meta data changes). For collections/folders, higher sync anchor values indicate the list of items in the collection/folder changed in a way not covered by file entries (i.e. rename, deletion, but not creation of files).
				removed : INTEGER		- value indicating if this file or folder has been removed: 1 if it was, 0 if not (default). Removed entries are kept around until their delta to the latest syncAnchor value exceeds -[OCDatabase removedItemRetentionLength].
				locallyModified: INTEGER	- value indicating if this is a file that's been created or modified locally
				localRelativePath: TEXT		- path of the local copy of the item, relative to the rootURL of the vault that stores it
				path : TEXT	  		- full path of the item (e.g. "/example/file.txt")
				parentPath : TEXT 		- parent path of the item. (e.g. "/example" for an item at "/example/file.txt")
				name : TEXT 	  		- name of the item (e.g. "file.txt" for an item at "/example/file.txt")
				mimeType : TEXT			- MIME type of the item
				size : INTEGER			- size of the item
				favorite : INTEGER		- BOOL indicating if the item is favorite (OCItem.isFavorite)
				cloudStatus : INTEGER 		- Cloud status of the item (OCItem.cloudStatus)
				hasLocalAttributes : INTEGER 	- BOOL indicating an item with local attributes (OCItem.hasLocalAttributes)
				lastUsedDate : REAL 		- NSDate.timeIntervalSince1970 value of OCItem.lastUsed
				fileID : TEXT			- OCFileID identifying the item
				localID : TEXT			- OCLocalID identifying the item
				itemData : BLOB	  		- data of the serialized OCItem
			*/
			@"CREATE TABLE metaData (mdID INTEGER PRIMARY KEY AUTOINCREMENT, type INTEGER NOT NULL, syncAnchor INTEGER NOT NULL, removed INTEGER NOT NULL, locallyModified INTEGER NOT NULL, localRelativePath TEXT NULL, path TEXT NOT NULL, parentPath TEXT NOT NULL, name TEXT NOT NULL, mimeType TEXT NULL, size INTEGER NOT NULL, favorite INTEGER NOT NULL, cloudStatus INTEGER NOT NULL, hasLocalAttributes INTEGER NOT NULL, lastUsedDate REAL NULL, fileID TEXT NOT NULL, localID TEXT, itemData BLOB NOT NULL)",

			// Create indexes over path and parentPath
			@"CREATE INDEX idx_metaData_path ON metaData (path)",
			@"CREATE INDEX idx_metaData_parentPath ON metaData (parentPath)",
			@"CREATE INDEX idx_metaData_synchAnchor ON metaData (syncAnchor)",
			@"CREATE INDEX idx_metaData_localID ON metaData (localID)",
			@"CREATE INDEX idx_metaData_fileID ON metaData (fileID)",
			@"CREATE INDEX idx_metaData_removed ON metaData (removed)",
		]
		openStatements:@[
			// Create trigger to delete thumbnails alongside metadata entries
			@"CREATE TEMPORARY TRIGGER temp_delete_associated_thumbnails AFTER DELETE ON metaData BEGIN DELETE FROM thumb.thumbnails WHERE fileID = OLD.fileID; END" // relatedTo:OCDatabaseTableNameThumbnails
		]
		upgradeMigrator:^(OCSQLiteDB *db, OCSQLiteTableSchema *schema, void (^completionHandler)(NSError *error)) {
			// Migrate to version 7

			[db executeTransaction:[OCSQLiteTransaction transactionWithBlock:^NSError *(OCSQLiteDB *db, OCSQLiteTransaction *transaction) {
				INSTALL_TRANSACTION_ERROR_COLLECTION_RESULT_HANDLER

				// Create new table
				[db executeQuery:[OCSQLiteQuery query:
				@"CREATE TABLE metaData_new (mdID INTEGER PRIMARY KEY AUTOINCREMENT, type INTEGER NOT NULL, syncAnchor INTEGER NOT NULL, removed INTEGER NOT NULL, locallyModified INTEGER NOT NULL, localRelativePath TEXT NULL, path TEXT NOT NULL, parentPath TEXT NOT NULL, name TEXT NOT NULL, mimeType TEXT NULL, size INTEGER NOT NULL, favorite INTEGER NOT NULL, cloudStatus INTEGER NOT NULL, hasLocalAttributes INTEGER NOT NULL, lastUsedDate REAL NULL, fileID TEXT NOT NULL, localID TEXT, itemData BLOB NOT NULL)" resultHandler:resultHandler]];
				if (transactionError != nil) { return(transactionError); }

				// Migrate data to new table, filling new columns with placeholder data
				[db executeQuery:[OCSQLiteQuery query:@"INSERT INTO metaData_new (mdID, type, syncAnchor, removed, locallyModified, localRelativePath, path, parentPath, name, mimeType, size, favorite, cloudStatus, hasLocalAttributes, lastUsedDate, fileID, localID, itemData) SELECT mdID, type, syncAnchor, removed, locallyModified, localRelativePath, path, parentPath, name, \"-\", 0, 0, 0, 0, 0, fileID, localID, itemData FROM metaData" resultHandler:resultHandler]];
				if (transactionError != nil) { return(transactionError); }

				// Drop old table
				[db executeQuery:[OCSQLiteQuery query:@"DROP TABLE metaData" resultHandler:resultHandler]];
				if (transactionError != nil) { return(transactionError); }

				// Rename new table
				[db executeQuery:[OCSQLiteQuery query:@"ALTER TABLE metaData_new RENAME TO metaData" resultHandler:resultHandler]];
				if (transactionError != nil) { return(transactionError); }

				// Fill new columns with real data
				[db executeQuery:[OCSQLiteQuery querySelectingColumns:@[@"mdID", @"itemData"] fromTable:OCDatabaseTableNameMetaData where:nil resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
					// Migrate OCItems
					[resultSet iterateUsing:^(OCSQLiteResultSet *resultSet, NSUInteger line, NSDictionary<NSString *, id> *rowDictionary, BOOL *stop) {
						OCItem *item;

						if ((item = [OCItem itemFromSerializedData:rowDictionary[@"itemData"]]) != nil)
						{
							if (rowDictionary[@"mdID"] != nil)
							{
								[db executeQuery:[OCSQLiteQuery queryUpdatingRowWithID:rowDictionary[@"mdID"]
												inTable:OCDatabaseTableNameMetaData
												withRowValues:@{
															@"mimeType" : OCSQLiteNullProtect(item.mimeType),
															@"size" : @(item.size),
															@"favorite" : OCSQLiteNullProtect(item.isFavorite),
															@"cloudStatus" : @(item.cloudStatus),
															@"hasLocalAttributes" : @(item.hasLocalAttributes),
															@"lastUsedDate" : OCSQLiteNullProtect(item.lastModified)
													       }
												completionHandler:^(OCSQLiteDB *db, NSError *error) {
													if (error != nil)
													{
														transactionError = error;
													}
												}
										]
								];
							}
						}
					} error:&transactionError];
				}]];
				if (transactionError != nil) { return(transactionError); }

				return (transactionError);
			} type:OCSQLiteTransactionTypeDeferred completionHandler:^(OCSQLiteDB *db, OCSQLiteTransaction *transaction, NSError *error) {
				completionHandler(error);
			}]];
		}]
	];

	// Version 8
	[self.sqlDB addTableSchema:[OCSQLiteTableSchema
		schemaWithTableName:OCDatabaseTableNameMetaData
		version:8
		creationQueries:@[
			/*
				mdID : INTEGER	  		- unique ID used to uniquely identify and efficiently update a row
				type : INTEGER    		- OCItemType value to indicate if this is a file or a collection/folder
				syncAnchor: INTEGER		- sync anchor, a number that increases its value with every change to an entry. For files, higher sync anchor values indicate the file changed (incl. creation, content or meta data changes). For collections/folders, higher sync anchor values indicate the list of items in the collection/folder changed in a way not covered by file entries (i.e. rename, deletion, but not creation of files).
				removed : INTEGER		- value indicating if this file or folder has been removed: 1 if it was, 0 if not (default). Removed entries are kept around until their delta to the latest syncAnchor value exceeds -[OCDatabase removedItemRetentionLength].
				locallyModified: INTEGER	- value indicating if this is a file that's been created or modified locally
				localRelativePath: TEXT		- path of the local copy of the item, relative to the rootURL of the vault that stores it
				path : TEXT	  		- full path of the item (e.g. "/example/file.txt")
				parentPath : TEXT 		- parent path of the item. (e.g. "/example" for an item at "/example/file.txt")
				name : TEXT 	  		- name of the item (e.g. "file.txt" for an item at "/example/file.txt")
				mimeType : TEXT			- MIME type of the item
				size : INTEGER			- size of the item
				favorite : INTEGER		- BOOL indicating if the item is favorite (OCItem.isFavorite)
				cloudStatus : INTEGER 		- Cloud status of the item (OCItem.cloudStatus)
				hasLocalAttributes : INTEGER 	- BOOL indicating an item with local attributes (OCItem.hasLocalAttributes)
				lastUsedDate : REAL 		- NSDate.timeIntervalSince1970 value of OCItem.lastUsed
				fileID : TEXT			- OCFileID identifying the item
				localID : TEXT			- OCLocalID identifying the item
				itemData : BLOB	  		- data of the serialized OCItem
			*/
			@"CREATE TABLE metaData (mdID INTEGER PRIMARY KEY AUTOINCREMENT, type INTEGER NOT NULL, syncAnchor INTEGER NOT NULL, removed INTEGER NOT NULL, locallyModified INTEGER NOT NULL, localRelativePath TEXT NULL, path TEXT NOT NULL, parentPath TEXT NOT NULL, name TEXT NOT NULL, mimeType TEXT NULL, size INTEGER NOT NULL, favorite INTEGER NOT NULL, cloudStatus INTEGER NOT NULL, hasLocalAttributes INTEGER NOT NULL, lastUsedDate REAL NULL, fileID TEXT, localID TEXT, itemData BLOB NOT NULL)",

			// Create indexes over path and parentPath
			@"CREATE INDEX idx_metaData_path ON metaData (path)",
			@"CREATE INDEX idx_metaData_parentPath ON metaData (parentPath)",
			@"CREATE INDEX idx_metaData_synchAnchor ON metaData (syncAnchor)",
			@"CREATE INDEX idx_metaData_localID ON metaData (localID)",
			@"CREATE INDEX idx_metaData_fileID ON metaData (fileID)",
			@"CREATE INDEX idx_metaData_removed ON metaData (removed)",
		]
		openStatements:@[
			// Create trigger to delete thumbnails alongside metadata entries
			@"CREATE TEMPORARY TRIGGER temp_delete_associated_thumbnails AFTER DELETE ON metaData BEGIN DELETE FROM thumb.thumbnails WHERE fileID = OLD.fileID; END" // relatedTo:OCDatabaseTableNameThumbnails
		]
		upgradeMigrator:^(OCSQLiteDB *db, OCSQLiteTableSchema *schema, void (^completionHandler)(NSError *error)) {
			// Migrate to version 8

			[db executeTransaction:[OCSQLiteTransaction transactionWithBlock:^NSError *(OCSQLiteDB *db, OCSQLiteTransaction *transaction) {
				INSTALL_TRANSACTION_ERROR_COLLECTION_RESULT_HANDLER

				// Create new table (without fileID NOT NULL constraint)
				[db executeQuery:[OCSQLiteQuery query:
				@"CREATE TABLE metaData_new (mdID INTEGER PRIMARY KEY AUTOINCREMENT, type INTEGER NOT NULL, syncAnchor INTEGER NOT NULL, removed INTEGER NOT NULL, locallyModified INTEGER NOT NULL, localRelativePath TEXT NULL, path TEXT NOT NULL, parentPath TEXT NOT NULL, name TEXT NOT NULL, mimeType TEXT NULL, size INTEGER NOT NULL, favorite INTEGER NOT NULL, cloudStatus INTEGER NOT NULL, hasLocalAttributes INTEGER NOT NULL, lastUsedDate REAL NULL, fileID TEXT, localID TEXT, itemData BLOB NOT NULL)" resultHandler:resultHandler]];
				if (transactionError != nil) { return(transactionError); }

				// Migrate data to new table
				[db executeQuery:[OCSQLiteQuery query:@"INSERT INTO metaData_new (mdID, type, syncAnchor, removed, locallyModified, localRelativePath, path, parentPath, name, mimeType, size, favorite, cloudStatus, hasLocalAttributes, lastUsedDate, fileID, localID, itemData) SELECT mdID, type, syncAnchor, removed, locallyModified, localRelativePath, path, parentPath, name, mimeType, size, favorite, cloudStatus, hasLocalAttributes, lastUsedDate, fileID, localID, itemData FROM metaData" resultHandler:resultHandler]];
				if (transactionError != nil) { return(transactionError); }

				// Drop old table
				[db executeQuery:[OCSQLiteQuery query:@"DROP TABLE metaData" resultHandler:resultHandler]];
				if (transactionError != nil) { return(transactionError); }

				// Rename new table
				[db executeQuery:[OCSQLiteQuery query:@"ALTER TABLE metaData_new RENAME TO metaData" resultHandler:resultHandler]];
				if (transactionError != nil) { return(transactionError); }

				return (transactionError);
			} type:OCSQLiteTransactionTypeDeferred completionHandler:^(OCSQLiteDB *db, OCSQLiteTransaction *transaction, NSError *error) {
				completionHandler(error);
			}]];
		}]
	];

	// Version 9: internal development only

	// Version 10
	[self.sqlDB addTableSchema:[OCSQLiteTableSchema
		schemaWithTableName:OCDatabaseTableNameMetaData
		version:10
		creationQueries:@[
			/*
				mdID : INTEGER	  		- unique ID used to uniquely identify and efficiently update a row
				type : INTEGER    		- OCItemType value to indicate if this is a file or a collection/folder
				syncAnchor: INTEGER		- sync anchor, a number that increases its value with every change to an entry. For files, higher sync anchor values indicate the file changed (incl. creation, content or meta data changes). For collections/folders, higher sync anchor values indicate the list of items in the collection/folder changed in a way not covered by file entries (i.e. rename, deletion, but not creation of files).
				removed : INTEGER		- value indicating if this file or folder has been removed: 1 if it was, 0 if not (default). Removed entries are kept around until their delta to the latest syncAnchor value exceeds -[OCDatabase removedItemRetentionLength].
				mdTimestamp: INTEGER		- NSDate.timeIntervalSinceReferenceDate value of creation or last update of this record
				locallyModified: INTEGER	- value indicating if this is a file that's been created or modified locally
				localRelativePath: TEXT		- path of the local copy of the item, relative to the rootURL of the vault that stores it
				path : TEXT	  		- full path of the item (e.g. "/example/file.txt")
				parentPath : TEXT 		- parent path of the item. (e.g. "/example" for an item at "/example/file.txt")
				name : TEXT 	  		- name of the item (e.g. "file.txt" for an item at "/example/file.txt")
				mimeType : TEXT			- MIME type of the item
				size : INTEGER			- size of the item
				favorite : INTEGER		- BOOL indicating if the item is favorite (OCItem.isFavorite)
				cloudStatus : INTEGER 		- Cloud status of the item (OCItem.cloudStatus)
				downloadTrigger : TEXT		- What triggered the download of the item (OCItemDownloadTriggerID)
				hasLocalAttributes : INTEGER 	- BOOL indicating an item with local attributes (OCItem.hasLocalAttributes)
				lastUsedDate : REAL 		- NSDate.timeIntervalSince1970 value of OCItem.lastUsed
				fileID : TEXT			- OCFileID identifying the item
				localID : TEXT			- OCLocalID identifying the item
				itemData : BLOB	  		- data of the serialized OCItem
			*/
			@"CREATE TABLE metaData (mdID INTEGER PRIMARY KEY AUTOINCREMENT, type INTEGER NOT NULL, syncAnchor INTEGER NOT NULL, removed INTEGER NOT NULL, mdTimestamp INTEGER NOT NULL, locallyModified INTEGER NOT NULL, localRelativePath TEXT NULL, path TEXT NOT NULL, parentPath TEXT NOT NULL, name TEXT NOT NULL, mimeType TEXT NULL, size INTEGER NOT NULL, favorite INTEGER NOT NULL, cloudStatus INTEGER NOT NULL, downloadTrigger TEXT NULL, hasLocalAttributes INTEGER NOT NULL, lastUsedDate REAL NULL, fileID TEXT, localID TEXT, itemData BLOB NOT NULL)",

			// Create indexes over path and parentPath
			@"CREATE INDEX idx_metaData_path ON metaData (path)",
			@"CREATE INDEX idx_metaData_parentPath ON metaData (parentPath)",
			@"CREATE INDEX idx_metaData_synchAnchor ON metaData (syncAnchor)",
			@"CREATE INDEX idx_metaData_localID ON metaData (localID)",
			@"CREATE INDEX idx_metaData_fileID ON metaData (fileID)",
			@"CREATE INDEX idx_metaData_removed ON metaData (removed)",
		]
		openStatements:@[
			// Create trigger to delete thumbnails alongside metadata entries
			@"CREATE TEMPORARY TRIGGER temp_delete_associated_thumbnails AFTER DELETE ON metaData BEGIN DELETE FROM thumb.thumbnails WHERE fileID = OLD.fileID; END" // relatedTo:OCDatabaseTableNameThumbnails
		]
		upgradeMigrator:^(OCSQLiteDB *db, OCSQLiteTableSchema *schema, void (^completionHandler)(NSError *error)) {
			// Migrate to version 10
			[db executeTransaction:[OCSQLiteTransaction transactionWithBlock:^NSError *(OCSQLiteDB *db, OCSQLiteTransaction *transaction) {
				INSTALL_TRANSACTION_ERROR_COLLECTION_RESULT_HANDLER

				// Create new table (with new downloadTrigger column)
				[db executeQuery:[OCSQLiteQuery query:
				@"CREATE TABLE metaData_new (mdID INTEGER PRIMARY KEY AUTOINCREMENT, type INTEGER NOT NULL, syncAnchor INTEGER NOT NULL, removed INTEGER NOT NULL, mdTimestamp INTEGER NOT NULL, locallyModified INTEGER NOT NULL, localRelativePath TEXT NULL, path TEXT NOT NULL, parentPath TEXT NOT NULL, name TEXT NOT NULL, mimeType TEXT NULL, size INTEGER NOT NULL, favorite INTEGER NOT NULL, cloudStatus INTEGER NOT NULL, downloadTrigger TEXT NULL, hasLocalAttributes INTEGER NOT NULL, lastUsedDate REAL NULL, fileID TEXT, localID TEXT, itemData BLOB NOT NULL)" resultHandler:resultHandler]];
				if (transactionError != nil) { return(transactionError); }

				// Migrate data to new table
				[db executeQuery:[OCSQLiteQuery query:@"INSERT INTO metaData_new (mdID, type, syncAnchor, removed, mdTimestamp, locallyModified, localRelativePath, path, parentPath, name, mimeType, size, favorite, cloudStatus, hasLocalAttributes, lastUsedDate, fileID, localID, itemData) SELECT mdID, type, syncAnchor, removed, 0, locallyModified, localRelativePath, path, parentPath, name, mimeType, size, favorite, cloudStatus, hasLocalAttributes, lastUsedDate, fileID, localID, itemData FROM metaData" resultHandler:resultHandler]];
				if (transactionError != nil) { return(transactionError); }

				// Add user download trigger to all existing downloaded files
				[db executeQuery:[OCSQLiteQuery query:@"UPDATE metaData_new SET downloadTrigger=? WHERE cloudStatus=?" withParameters:@[ OCItemDownloadTriggerIDUser, @(OCItemCloudStatusLocalCopy) ] resultHandler:resultHandler]];
				if (transactionError != nil) { return(transactionError); }

				// Add mdTimestamp to all existing reocrds
				[db executeQuery:[OCSQLiteQuery query:@"UPDATE metaData_new SET mdTimestamp=?" withParameters:@[ @((NSUInteger)[NSDate timeIntervalSinceReferenceDate]) ] resultHandler:resultHandler]];
				if (transactionError != nil) { return(transactionError); }

				// Drop old table
				[db executeQuery:[OCSQLiteQuery query:@"DROP TABLE metaData" resultHandler:resultHandler]];
				if (transactionError != nil) { return(transactionError); }

				// Rename new table
				[db executeQuery:[OCSQLiteQuery query:@"ALTER TABLE metaData_new RENAME TO metaData" resultHandler:resultHandler]];
				if (transactionError != nil) { return(transactionError); }

				return (transactionError);
			} type:OCSQLiteTransactionTypeDeferred completionHandler:^(OCSQLiteDB *db, OCSQLiteTransaction *transaction, NSError *error) {
				completionHandler(error);
			}]];
		}]
	];
}

- (void)addOrUpdateSyncLanesSchema
{
	// Version 1
	[self.sqlDB addTableSchema:[OCSQLiteTableSchema
		schemaWithTableName:OCDatabaseTableNameSyncLanes
		version:1
		creationQueries:@[
			/*
				laneID : INTEGER  	- unique ID used to uniquely identify and efficiently update a row
				laneData : BLOB		- archived OCSyncLane data
			*/
			@"CREATE TABLE syncLanes (laneID INTEGER PRIMARY KEY AUTOINCREMENT, laneData BLOB NOT NULL)",
		]
		openStatements:nil
		upgradeMigrator:nil]
	];
}

- (void)addOrUpdateSyncJournalSchema
{
	/*** Sync Journal ***/

	// Version 1
	[self.sqlDB addTableSchema:[OCSQLiteTableSchema
		schemaWithTableName:OCDatabaseTableNameSyncJournal
		version:1
		creationQueries:@[
			/*
				recordID : INTEGER  		- unique ID used to uniquely identify and efficiently update a row
				timestamp : REAL		- NSDate.timeIntervalSinceReferenceDate at the time the record was added to the journal
				operation : TEXT		- operation to carry out
				path : TEXT			- path of the item targeted by the operation
				recordData : BLOB		- archived OCSyncRecord data
			*/
			@"CREATE TABLE syncJournal (recordID INTEGER PRIMARY KEY, timestamp REAL NOT NULL, operation TEXT NOT NULL, path TEXT NOT NULL, recordData BLOB)",
		]
		openStatements:nil
		upgradeMigrator:nil]
	];

	// Version 2
	[self.sqlDB addTableSchema:[OCSQLiteTableSchema
		schemaWithTableName:OCDatabaseTableNameSyncJournal
		version:2
		creationQueries:@[
			/*
				recordID : INTEGER  		- unique ID used to uniquely identify and efficiently update a row
				timestampDate : REAL		- NSDate.timeIntervalSince1970 at the time the record was added to the journal
				inProgressSinceDate : REAL	- NSDate.timeIntervalSince1970 at the time the record was beginning to be processed
				action : TEXT			- action to perform
				path : TEXT			- path of the item targeted by the operation
				recordData : BLOB		- archived OCSyncRecord data
			*/
			@"CREATE TABLE syncJournal (recordID INTEGER PRIMARY KEY, timestampDate REAL NOT NULL, inProgressSinceDate REAL, action TEXT NOT NULL, path TEXT NOT NULL, recordData BLOB)",
		]
		openStatements:nil
		upgradeMigrator:^(OCSQLiteDB *db, OCSQLiteTableSchema *schema, void (^completionHandler)(NSError *error)) {
			// Migrate to version 2
			[db executeTransaction:[OCSQLiteTransaction transactionWithBlock:^NSError *(OCSQLiteDB *db, OCSQLiteTransaction *transaction) {
				INSTALL_TRANSACTION_ERROR_COLLECTION_RESULT_HANDLER

				// Drop unused V1 table
				[db executeQuery:[OCSQLiteQuery query:@"DROP TABLE syncJournal" resultHandler:resultHandler]];
				if (transactionError != nil) { return(transactionError); }

				// Create it anew
				[db executeQuery:[OCSQLiteQuery query:@"CREATE TABLE syncJournal (recordID INTEGER PRIMARY KEY, timestampDate REAL NOT NULL, inProgressSinceDate REAL, action TEXT NOT NULL, path TEXT NOT NULL, recordData BLOB)" resultHandler:resultHandler]];
				if (transactionError != nil) { return(transactionError); }

				return (transactionError);

			} type:OCSQLiteTransactionTypeDeferred completionHandler:^(OCSQLiteDB *db, OCSQLiteTransaction *transaction, NSError *error) {
				completionHandler(error);
			}]];
		}]
	];

	// Version 3
	[self.sqlDB addTableSchema:[OCSQLiteTableSchema
		schemaWithTableName:OCDatabaseTableNameSyncJournal
		version:3
		creationQueries:@[
			/*
				recordID : INTEGER  		- unique ID used to uniquely identify and efficiently update a row
				timestampDate : REAL		- NSDate.timeIntervalSince1970 at the time the record was added to the journal
				inProgressSinceDate : REAL	- NSDate.timeIntervalSince1970 at the time the record was beginning to be processed
				action : TEXT			- action to perform
				localID : TEXT			- localID of the item targeted by the operation
				path : TEXT			- path of the item targeted by the operation
				recordData : BLOB		- archived OCSyncRecord data
			*/
			@"CREATE TABLE syncJournal (recordID INTEGER PRIMARY KEY, timestampDate REAL NOT NULL, inProgressSinceDate REAL, action TEXT NOT NULL, localID TEXT NOT NULL, path TEXT NOT NULL, recordData BLOB)",
		]
		openStatements:nil
		upgradeMigrator:^(OCSQLiteDB *db, OCSQLiteTableSchema *schema, void (^completionHandler)(NSError *error)) {
			// Migrate to version 3
			[db executeTransaction:[OCSQLiteTransaction transactionWithBlock:^NSError *(OCSQLiteDB *db, OCSQLiteTransaction *transaction) {
				INSTALL_TRANSACTION_ERROR_COLLECTION_RESULT_HANDLER

				// Drop previous table
				[db executeQuery:[OCSQLiteQuery query:@"DROP TABLE syncJournal" resultHandler:resultHandler]];
				if (transactionError != nil) { return(transactionError); }

				// Create it anew
				[db executeQuery:[OCSQLiteQuery query:@"CREATE TABLE syncJournal (recordID INTEGER PRIMARY KEY, timestampDate REAL NOT NULL, inProgressSinceDate REAL, action TEXT NOT NULL, localID TEXT NOT NULL, path TEXT NOT NULL, recordData BLOB)" resultHandler:resultHandler]];
				if (transactionError != nil) { return(transactionError); }

				return (transactionError);

			} type:OCSQLiteTransactionTypeDeferred completionHandler:^(OCSQLiteDB *db, OCSQLiteTransaction *transaction, NSError *error) {
				completionHandler(error);
			}]];
		}]
	];

	// Version 4
	[self.sqlDB addTableSchema:[OCSQLiteTableSchema
		schemaWithTableName:OCDatabaseTableNameSyncJournal
		version:4
		creationQueries:@[
			/*
				recordID : INTEGER  		- unique ID used to uniquely identify and efficiently update a row
				timestampDate : REAL		- NSDate.timeIntervalSince1970 at the time the record was added to the journal
				inProgressSinceDate : REAL	- NSDate.timeIntervalSince1970 at the time the record was beginning to be processed
				action : TEXT			- action to perform
				localID : TEXT			- localID of the item targeted by the operation
				path : TEXT			- path of the item targeted by the operation
				recordData : BLOB		- archived OCSyncRecord data
			*/
			@"CREATE TABLE syncJournal (recordID INTEGER PRIMARY KEY AUTOINCREMENT, timestampDate REAL NOT NULL, inProgressSinceDate REAL, action TEXT NOT NULL, localID TEXT NOT NULL, path TEXT NOT NULL, recordData BLOB)",
		]
		openStatements:nil
		upgradeMigrator:^(OCSQLiteDB *db, OCSQLiteTableSchema *schema, void (^completionHandler)(NSError *error)) {
			// Migrate to version 4
			[db executeTransaction:[OCSQLiteTransaction transactionWithBlock:^NSError *(OCSQLiteDB *db, OCSQLiteTransaction *transaction) {
				INSTALL_TRANSACTION_ERROR_COLLECTION_RESULT_HANDLER

				// Create new table
				[db executeQuery:[OCSQLiteQuery query:@"CREATE TABLE syncJournal_new (recordID INTEGER PRIMARY KEY AUTOINCREMENT, timestampDate REAL NOT NULL, inProgressSinceDate REAL, action TEXT NOT NULL, localID TEXT NOT NULL, path TEXT NOT NULL, recordData BLOB)" resultHandler:resultHandler]];
				if (transactionError != nil) { return(transactionError); }

				// Migrate data to new table
				[db executeQuery:[OCSQLiteQuery query:@"INSERT INTO syncJournal_new (recordID, timestampDate, inProgressSinceDate, action, localID, path, recordData) SELECT recordID, timestampDate, inProgressSinceDate, action, localID, path, recordData FROM syncJournal" resultHandler:resultHandler]];
				if (transactionError != nil) { return(transactionError); }

				// Drop old table
				[db executeQuery:[OCSQLiteQuery query:@"DROP TABLE syncJournal" resultHandler:resultHandler]];
				if (transactionError != nil) { return(transactionError); }

				// Rename new table
				[db executeQuery:[OCSQLiteQuery query:@"ALTER TABLE syncJournal_new RENAME TO syncJournal" resultHandler:resultHandler]];
				if (transactionError != nil) { return(transactionError); }

				return (transactionError);

			} type:OCSQLiteTransactionTypeDeferred completionHandler:^(OCSQLiteDB *db, OCSQLiteTransaction *transaction, NSError *error) {
				completionHandler(error);
			}]];
		}]
	];

	// Version 5
	__weak OCDatabase *weakSelf = self;

	[self.sqlDB addTableSchema:[OCSQLiteTableSchema
		schemaWithTableName:OCDatabaseTableNameSyncJournal
		version:5
		creationQueries:@[
			/*
				recordID : INTEGER  		- unique ID used to uniquely identify and efficiently update a row
				laneID : INTEGER		- ID of the sync lane this record is scheduled on
				timestampDate : REAL		- NSDate.timeIntervalSince1970 at the time the record was added to the journal
				inProgressSinceDate : REAL	- NSDate.timeIntervalSince1970 at the time the record was beginning to be processed
				action : TEXT			- action to perform
				localID : TEXT			- localID of the item targeted by the operation
				path : TEXT			- path of the item targeted by the operation
				recordData : BLOB		- archived OCSyncRecord data
			*/
			@"CREATE TABLE syncJournal (recordID INTEGER PRIMARY KEY AUTOINCREMENT, laneID INTEGER, timestampDate REAL NOT NULL, inProgressSinceDate REAL, action TEXT NOT NULL, localID TEXT NOT NULL, path TEXT NOT NULL, recordData BLOB)",
		]
		openStatements:nil
		upgradeMigrator:^(OCSQLiteDB *db, OCSQLiteTableSchema *schema, void (^completionHandler)(NSError *error)) {
			// Migrate to version 5
			[db executeTransaction:[OCSQLiteTransaction transactionWithBlock:^NSError *(OCSQLiteDB *sqlDB, OCSQLiteTransaction *transaction) {
				INSTALL_TRANSACTION_ERROR_COLLECTION_RESULT_HANDLER

				// Add laneID column
				[sqlDB executeQuery:[OCSQLiteQuery query:@"ALTER TABLE syncJournal ADD COLUMN laneID INTEGER" resultHandler:resultHandler]];
				if (transactionError != nil) { return(transactionError); }

				// Create transitional lane with catch-all tag and assign all existing sync records to it
				OCSyncLane *transitionalLane = [OCSyncLane new];
				transitionalLane.tags = [[NSMutableSet alloc] initWithObjects:@"/", nil]; // Catch-all

				[weakSelf addSyncLane:transitionalLane completionHandler:^(OCDatabase *database, NSError *error) {
					if (error == nil)
					{
						if (transitionalLane.identifier != nil)
						{
							[sqlDB executeQuery:[OCSQLiteQuery queryUpdatingRowsWhere:@{} inTable:OCDatabaseTableNameSyncJournal withRowValues:@{ @"laneID" : transitionalLane.identifier } completionHandler:^(OCSQLiteDB * _Nonnull db, NSError * _Nullable error) {
								OCWTLogError(nil, @"Assigned all existing sync records to transitionalLane. error=%@", error);
							}]];
						}
					}
					else
					{
						OCWTLogError(nil, @"Error creating transitional lane: %@", error);
					}
				}];

				return (transactionError);
			} type:OCSQLiteTransactionTypeDeferred completionHandler:^(OCSQLiteDB *db, OCSQLiteTransaction *transaction, NSError *error) {
				completionHandler(error);
			}]];
		}]
	];
}

- (void)addOrUpdateUpdateScanPaths
{
	/*** Update Scan Paths ***/

	// Version 1
	[self.sqlDB addTableSchema:[OCSQLiteTableSchema
		schemaWithTableName:OCDatabaseTableNameUpdateJobs
		version:1
		creationQueries:@[
			/*
				jobID : INTEGER  		- unique ID used to uniquely identify and efficiently update a row
				path : TEXT			- path to scan as part of an update
			*/
			@"CREATE TABLE updateJobs (jobID INTEGER PRIMARY KEY AUTOINCREMENT, path TEXT NOT NULL)",
		]
		openStatements:nil
		upgradeMigrator:nil]
	];
}

- (void)addOrUpdateEvents
{
	/*** Sync Events ***/

	// Version 1
	[self.sqlDB addTableSchema:[OCSQLiteTableSchema
		schemaWithTableName:OCDatabaseTableNameEvents
		version:1
		creationQueries:@[
			/*
				eventID : INTEGER  		- unique ID used to uniquely identify and efficiently update a row
				recordID : INTEGER		- ID of sync record this event refers to
				eventData : BLOB		- archived OCEvent data
			*/
			@"CREATE TABLE events (eventID INTEGER PRIMARY KEY, recordID INTEGER NOT NULL, eventData BLOB NOT NULL)",
		]
		openStatements:nil
		upgradeMigrator:nil]
	];

	// Version 2
	[self.sqlDB addTableSchema:[OCSQLiteTableSchema
		schemaWithTableName:OCDatabaseTableNameEvents
		version:2
		creationQueries:@[
			/*
				eventID : INTEGER  		- unique ID used to uniquely identify and efficiently update a row
				recordID : INTEGER		- ID of sync record this event refers to
				processSession : BLOB		- process session the event was added from
				eventData : BLOB		- archived OCEvent data
			*/
			@"CREATE TABLE events (eventID INTEGER PRIMARY KEY, recordID INTEGER NOT NULL, processSession BLOB NOT NULL, eventData BLOB NOT NULL)",
		]
		openStatements:nil
		upgradeMigrator:^(OCSQLiteDB *db, OCSQLiteTableSchema *schema, void (^completionHandler)(NSError *error)) {
			// Migrate to version 2
			[db executeTransaction:[OCSQLiteTransaction transactionWithBlock:^NSError *(OCSQLiteDB *db, OCSQLiteTransaction *transaction) {
				INSTALL_TRANSACTION_ERROR_COLLECTION_RESULT_HANDLER

				[db executeQuery:[OCSQLiteQuery query:@"ALTER TABLE events ADD COLUMN processSession BLOB" resultHandler:resultHandler]];
				if (transactionError != nil) { return(transactionError); }

				return (transactionError);

			} type:OCSQLiteTransactionTypeDeferred completionHandler:^(OCSQLiteDB *db, OCSQLiteTransaction *transaction, NSError *error) {
				completionHandler(error);
			}]];
		}]
	];

	// Version 3
	[self.sqlDB addTableSchema:[OCSQLiteTableSchema
		schemaWithTableName:OCDatabaseTableNameEvents
		version:3
		creationQueries:@[
			/*
				eventID : INTEGER  		- unique ID used to uniquely identify and efficiently update a row
				recordID : INTEGER		- ID of sync record this event refers to
				processSession : BLOB		- process session the event was added from
				eventData : BLOB		- archived OCEvent data
			*/
			@"CREATE TABLE events (eventID INTEGER PRIMARY KEY AUTOINCREMENT, recordID INTEGER NOT NULL, processSession BLOB NOT NULL, eventData BLOB NOT NULL)",
		]
		openStatements:nil
		upgradeMigrator:^(OCSQLiteDB *db, OCSQLiteTableSchema *schema, void (^completionHandler)(NSError *error)) {
			// Migrate to version 3
			[db executeTransaction:[OCSQLiteTransaction transactionWithBlock:^NSError *(OCSQLiteDB *db, OCSQLiteTransaction *transaction) {
				INSTALL_TRANSACTION_ERROR_COLLECTION_RESULT_HANDLER

				// Create new table
				[db executeQuery:[OCSQLiteQuery query:@"CREATE TABLE events_new (eventID INTEGER PRIMARY KEY AUTOINCREMENT, recordID INTEGER NOT NULL, processSession BLOB NOT NULL, eventData BLOB NOT NULL)" resultHandler:resultHandler]];
				if (transactionError != nil) { return(transactionError); }

				// Migrate data to new table
				[db executeQuery:[OCSQLiteQuery query:@"INSERT INTO events_new (eventID, recordID, processSession, eventData) SELECT eventID, recordID, processSession, eventData FROM events" resultHandler:resultHandler]];
				if (transactionError != nil) { return(transactionError); }

				// Drop old table
				[db executeQuery:[OCSQLiteQuery query:@"DROP TABLE events" resultHandler:resultHandler]];
				if (transactionError != nil) { return(transactionError); }

				// Rename new table
				[db executeQuery:[OCSQLiteQuery query:@"ALTER TABLE events_new RENAME TO events" resultHandler:resultHandler]];
				if (transactionError != nil) { return(transactionError); }

				return (transactionError);

			} type:OCSQLiteTransactionTypeDeferred completionHandler:^(OCSQLiteDB *db, OCSQLiteTransaction *transaction, NSError *error) {
				completionHandler(error);
			}]];
		}]
	];

	// Version 4
	[self.sqlDB addTableSchema:[OCSQLiteTableSchema
		schemaWithTableName:OCDatabaseTableNameEvents
		version:4
		creationQueries:@[
			/*
				eventID : INTEGER  		- unique ID used to uniquely identify and efficiently update a row
				recordID : INTEGER		- ID of sync record this event refers to
				uuid : TEXT			- event.uuid of the event contained in this row
				processSession : BLOB		- process session the event was added from
				eventData : BLOB		- archived OCEvent data
			*/
			@"CREATE TABLE events (eventID INTEGER PRIMARY KEY AUTOINCREMENT, recordID INTEGER NOT NULL, uuid TEXT, processSession BLOB NOT NULL, eventData BLOB NOT NULL)",
		]
		openStatements:nil
		upgradeMigrator:^(OCSQLiteDB *db, OCSQLiteTableSchema *schema, void (^completionHandler)(NSError *error)) {
			// Migrate to version 4
			[db executeTransaction:[OCSQLiteTransaction transactionWithBlock:^NSError *(OCSQLiteDB *db, OCSQLiteTransaction *transaction) {
				INSTALL_TRANSACTION_ERROR_COLLECTION_RESULT_HANDLER

				[db executeQuery:[OCSQLiteQuery query:@"ALTER TABLE events ADD COLUMN uuid TEXT" resultHandler:resultHandler]];
				if (transactionError != nil) { return(transactionError); }

				return (transactionError);
			} type:OCSQLiteTransactionTypeDeferred completionHandler:^(OCSQLiteDB *db, OCSQLiteTransaction *transaction, NSError *error) {
				completionHandler(error);
			}]];
		}]
	];
}

- (void)addOrUpdateItemPoliciesSchema
{
	// Version 1
	[self.sqlDB addTableSchema:[OCSQLiteTableSchema
		schemaWithTableName:OCDatabaseTableNameItemPolicies
		version:1
		creationQueries:@[
			/*
				policyID : INTEGER  		- unique ID used to uniquely identify and efficiently update a row
				identifier : TEXT    		- OCItemPolicyIdentifier of the OCItemPolicy (where set)
				path : TEXT			- path of the OCItemPolicy (where set)
				localID : TEXT			- localID of the OCItemPolicy (where set)
				kind : TEXT			- kind of the OCItemPolicy
				policyData : BLOB  		- data of the serialized OCItemPolicy
			*/
			@"CREATE TABLE itemPolicies (policyID INTEGER PRIMARY KEY AUTOINCREMENT, identifier TEXT NULL, path TEXT NULL, localID TEXT NULL, kind TEXT NOT NULL, policyData BLOB NOT NULL)",

			// Create indexes
			@"CREATE INDEX idx_itemPolicies_path ON itemPolicies (path)",
			@"CREATE INDEX idx_itemPolicies_localID ON itemPolicies (localID)",
			@"CREATE INDEX idx_itemPolicies_kind ON itemPolicies (kind)",
			@"CREATE INDEX idx_itemPolicies_identifier ON itemPolicies (identifier)",
		]
		openStatements:nil
		upgradeMigrator:nil]
	];
}

- (void)addOrUpdateThumbnailsSchema
{
	/*** Thumbnails ***/

	// Version 1
	[self.sqlDB addTableSchema:[OCSQLiteTableSchema
		schemaWithTableName:OCDatabaseTableNameThumbnails
		version:1
		creationQueries:@[
			/*
				tnID : INTEGER	  	- unique ID used to uniquely identify and efficiently update a row
				fileID : TEXT		- OCFileID of the item to which this thumbnail belongs
				eTag : TEXT		- OCFileETag of the item to which this thumbnail belongs
				maxWidth : INTEGER	- maximum width of the item when retrieving the thumbnail from the server
				maxHeight : INTEGER	- maximum height of the item when retrieving the thumbnail from the server
				mimeType : TEXT		- MIME Type of imageData
				imageData : BLOB	- image data of the thumbnail
			*/
			@"CREATE TABLE thumb.thumbnails (tnID INTEGER PRIMARY KEY, fileID TEXT NOT NULL, eTag TEXT NOT NULL, maxWidth INTEGER NOT NULL, maxHeight INTEGER NOT NULL, mimeType TEXT NOT NULL, imageData BLOB NOT NULL)", // relatedTo:OCDatabaseTableNameThumbnails

			// Create index over fileID
			@"CREATE INDEX thumb.idx_thumbnails_fileID ON thumbnails (fileID)" // relatedTo:OCDatabaseTableNameThumbnails
		]
		openStatements:nil
		upgradeMigrator:nil]
	];

	// Version 2
	[self.sqlDB addTableSchema:[OCSQLiteTableSchema
		schemaWithTableName:OCDatabaseTableNameThumbnails
		version:2
		creationQueries:@[
			/*
				tnID : INTEGER	  	- unique ID used to uniquely identify and efficiently update a row
				fileID : TEXT		- OCFileID of the item to which this thumbnail belongs
				eTag : TEXT		- OCFileETag of the item to which this thumbnail belongs
				specID : TEXT		- a string consisting of other attributes affecting thumbnail creation, like f.ex. the MIME Type (which can change after a rename)
				maxWidth : INTEGER	- maximum width of the item when retrieving the thumbnail from the server
				maxHeight : INTEGER	- maximum height of the item when retrieving the thumbnail from the server
				mimeType : TEXT		- MIME Type of imageData
				imageData : BLOB	- image data of the thumbnail
			*/
			@"CREATE TABLE thumb.thumbnails (tnID INTEGER PRIMARY KEY AUTOINCREMENT, fileID TEXT NOT NULL, eTag TEXT NOT NULL, specID TEXT NOT NULL, maxWidth INTEGER NOT NULL, maxHeight INTEGER NOT NULL, mimeType TEXT NOT NULL, imageData BLOB NOT NULL)", // relatedTo:OCDatabaseTableNameThumbnails

			// Create index over fileID
			@"CREATE INDEX thumb.idx_thumbnails_fileID ON thumbnails (fileID)" // relatedTo:OCDatabaseTableNameThumbnails
		]
		openStatements:nil
		upgradeMigrator:^(OCSQLiteDB *db, OCSQLiteTableSchema *schema, void (^completionHandler)(NSError *error)) {
			// Migrate to version 2
			[db executeTransaction:[OCSQLiteTransaction transactionWithBlock:^NSError *(OCSQLiteDB *db, OCSQLiteTransaction *transaction) {
				INSTALL_TRANSACTION_ERROR_COLLECTION_RESULT_HANDLER

				// Add "specID" column
				[db executeQuery:[OCSQLiteQuery query:@"ALTER TABLE thumb.thumbnails ADD COLUMN specID TEXT" resultHandler:resultHandler]];
				if (transactionError != nil) { return(transactionError); }

				return (transactionError);
			} type:OCSQLiteTransactionTypeDeferred completionHandler:^(OCSQLiteDB *db, OCSQLiteTransaction *transaction, NSError *error) {
				completionHandler(error);
			}]];
		}]
	];
}

- (void)addOrUpdateCountersSchema
{
	/*** Counters ***/

	// Version 1
	[self.sqlDB addTableSchema:[OCSQLiteTableSchema
		schemaWithTableName:OCDatabaseTableNameCounters
		version:1
		creationQueries:@[
			/*
				cnID : INTEGER	  	- unique ID used to uniquely identify and efficiently update a row
				identifier : TEXT	- OCDatabaseCounterIdentifier of the counter
				value : INTEGER		- Current value of the counter
				lastUpdated : REAL	- NSDate.timeIntervalSinceReferenceDate for when the counter was last updated
			*/
			@"CREATE TABLE counters (cnID INTEGER PRIMARY KEY AUTOINCREMENT, identifier TEXT NOT NULL, value INTEGER NOT NULL, lastUpdated REAL NOT NULL)" // relatedTo:OCDatabaseTableNameCounters
		]
		openStatements:nil
		upgradeMigrator:nil]
	];
}

@end

OCDatabaseTableName OCDatabaseTableNameMetaData = @"metaData";
OCDatabaseTableName OCDatabaseTableNameSyncLanes = @"syncLanes";
OCDatabaseTableName OCDatabaseTableNameSyncJournal = @"syncJournal";
OCDatabaseTableName OCDatabaseTableNameUpdateJobs = @"updateJobs";
OCDatabaseTableName OCDatabaseTableNameThumbnails = @"thumb.thumbnails"; // Places that need to be changed as well if this is changed are annotated with relatedTo:OCDatabaseTableNameThumbnails
OCDatabaseTableName OCDatabaseTableNameEvents = @"events";
OCDatabaseTableName OCDatabaseTableNameCounters = @"counters";
OCDatabaseTableName OCDatabaseTableNameItemPolicies = @"itemPolicies";
