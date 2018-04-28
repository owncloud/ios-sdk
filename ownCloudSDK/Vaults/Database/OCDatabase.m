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
#import "OCItemVersionIdentifier.h"

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
			@"CREATE TRIGGER delete_associated_thumbnails AFTER DELETE ON metaData BEGIN DELETE FROM thumbnails WHERE fileID = OLD.fileID; END" // relatedTo:OCDatabaseTableNameThumbnails
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
				[db executeQuery:[OCSQLiteQuery query:@"CREATE TRIGGER delete_associated_thumbnails AFTER DELETE ON metaData BEGIN DELETE FROM thumbnails WHERE fileID = OLD.fileID; END" resultHandler:resultHandler]]; // relatedTo:OCDatabaseTableNameThumbnails

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
}

#pragma mark - Open / Close
- (void)openWithCompletionHandler:(OCDatabaseCompletionHandler)completionHandler
{
	[self.sqlDB openWithFlags:OCSQLiteOpenFlagsDefault completionHandler:^(OCSQLiteDB *db, NSError *error) {
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
	NSString *parentPath = path;

	if ([parentPath hasSuffix:@"/"] && ![parentPath isEqual:@"/"])
	{
		parentPath = [parentPath substringWithRange:NSMakeRange(0, parentPath.length-1)];
	}

	[self.sqlDB executeQuery:[OCSQLiteQuery query:@"SELECT mdID, itemData FROM metaData WHERE parentPath=? OR path=?" withParameters:@[parentPath,path] resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
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

#pragma mark - Thumbnail interface
- (void)storeThumbnailData:(NSData *)thumbnailData withMIMEType:(NSString *)mimeType forItemVersion:(OCItemVersionIdentifier *)itemVersion maximumSizeInPixels:(CGSize)maximumSizeInPixels completionHandler:(OCDatabaseCompletionHandler)completionHandler
{
	if ((itemVersion.fileID == nil) || (itemVersion.eTag == nil))
	{
		OCLogError(@"Error storing thumbnail for itemVersion %@ because it lacks fileID or eTag.", OCLogPrivate(itemVersion));
		return;
	}

	if (thumbnailData == nil)
	{
		OCLogError(@"Error storing thumbnail data for itemVersion %@ because it lacks data.", OCLogPrivate(itemVersion));
		return;
	}

	[self.sqlDB executeTransaction:[OCSQLiteTransaction transactionWithQueries:@[
		// Remove outdated versions and smaller thumbnail sizes
		[OCSQLiteQuery  query:@"DELETE FROM thumb.thumbnails WHERE fileID = :fileID AND ((eTag != :eTag) OR (maxWidth < :maxWidth AND maxHeight < :maxHeight))" // relatedTo:OCDatabaseTableNameThumbnails
			        withNamedParameters:@{
					@"fileID" : itemVersion.fileID,
					@"eTag" : itemVersion.eTag,
					@"maxWidth" : @(maximumSizeInPixels.width),
					@"maxHeight" : @(maximumSizeInPixels.height),
			        } resultHandler:nil],

		// Insert new thumbnail
		[OCSQLiteQuery  queryInsertingIntoTable:OCDatabaseTableNameThumbnails
				rowValues:@{
					@"fileID" : itemVersion.fileID,
					@"eTag" : itemVersion.eTag,
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

- (void)retrieveThumbnailDataForItemVersion:(OCItemVersionIdentifier *)itemVersion maximumSizeInPixels:(CGSize)maximumSizeInPixels completionHandler:(OCDatabaseRetrieveThumbnailCompletionHandler)completionHandler
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

	[self.sqlDB executeQuery:[OCSQLiteQuery query:@"SELECT maxWidth, maxHeight, mimeType, imageData FROM thumbnails WHERE fileID = :fileID AND eTag = :eTag ORDER BY (maxWidth = :maxWidth AND maxHeight = :maxHeight) DESC, (maxWidth >= :maxWidth AND maxHeight >= :maxHeight) DESC, (((maxWidth < :maxWidth AND maxHeight < :maxHeight) * -1000 + 1) * ((maxWidth * maxHeight) - (:maxWidth * :maxHeight))) ASC LIMIT 0,1" withNamedParameters:@{
		@"fileID"	: itemVersion.fileID,
		@"eTag"		: itemVersion.eTag,
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

@end

OCDatabaseTableName OCDatabaseTableNameMetaData = @"metaData";
OCDatabaseTableName OCDatabaseTableNameThumbnails = @"thumb.thumbnails"; // Places that need to be changed as well if this is changed are annotated with relatedTo:OCDatabaseTableNameThumbnails
