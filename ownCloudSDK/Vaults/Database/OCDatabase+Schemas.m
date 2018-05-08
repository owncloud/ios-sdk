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

@implementation OCDatabase (Schemas)

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
		upgradeMigrator:^(OCSQLiteDB *db, OCSQLiteTableSchema *schema, void (^completionHandler)(NSError *error)) {
			// Migrate to version 2
			[db executeTransaction:[OCSQLiteTransaction transactionWithBlock:^NSError *(OCSQLiteDB *db, OCSQLiteTransaction *transaction) {
				__block NSError *transactionError = nil;
				OCSQLiteDBResultHandler resultHandler = ^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
					if (error != nil)
					{
						transactionError = error;
					}
				};

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
		upgradeMigrator:nil]
	];

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
			@"CREATE TABLE counters (cnID INTEGER PRIMARY KEY, identifier TEXT NOT NULL, value INTEGER NOT NULL, lastUpdated REAL NOT NULL)" // relatedTo:OCDatabaseTableNameCounters
		]
		upgradeMigrator:nil]
	];
}

@end

OCDatabaseTableName OCDatabaseTableNameMetaData = @"metaData";
OCDatabaseTableName OCDatabaseTableNameCounters = @"counters";
OCDatabaseTableName OCDatabaseTableNameThumbnails = @"thumb.thumbnails"; // Places that need to be changed as well if this is changed are annotated with relatedTo:OCDatabaseTableNameThumbnails
