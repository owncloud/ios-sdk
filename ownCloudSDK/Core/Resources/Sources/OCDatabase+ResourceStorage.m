//
//  OCDatabase+ResourceStorage.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 10.01.22.
//  Copyright © 2022 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2022, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCDatabase+ResourceStorage.h"
#import "OCSQLiteDB.h"
#import "OCLogger.h"
#import "OCResourceImage.h"
#import "OCMacros.h"
#import "OCSQLiteTransaction.h"
#import "NSError+OCError.h"

@implementation OCDatabase (ResourceStorage)

- (void)storeResource:(nonnull OCResource *)resource completionHandler:(nonnull OCResourceStoreCompletionHandler)completionHandler
{
	if ((resource.type == nil) || (resource.identifier == nil) || (resource.version == nil))
	{
		OCTLogError(@[@"ResMan"], @"Error storing resource %@ because it lacks type, identifier or version.", OCLogPrivate(resource));
		return;
	}

	NSError *error = nil;
	NSData *resourceData = [NSKeyedArchiver archivedDataWithRootObject:resource requiringSecureCoding:YES error:&error];

	if (resourceData == nil)
	{
		OCTLogError(@[@"ResMan"], @"Error storing resource %@ because it can't be serialized (error=%@).", OCLogPrivate(resource), error);
		return;
	}

	OCResourceImage *imageResource = OCTypedCast(resource, OCResourceImage);

	[self.sqlDB executeTransaction:[OCSQLiteTransaction transactionWithQueries:@[
		// Remove outdated versions and smaller resource sizes
		[OCSQLiteQuery  query:@"DELETE FROM thumb.resources WHERE identifier = :identifier AND type = :type AND ((version != :version) OR (maxWidth <= :maxWidth AND maxHeight <= :maxHeight) OR (structDesc != :structDesc))" // relatedTo:OCDatabaseTableNameResources
			        withNamedParameters:@{
					@"type" : resource.type,

					@"identifier" : resource.identifier,
					@"version" : OCSQLiteNullProtect(resource.version),
					@"structDesc" : OCSQLiteNullProtect(resource.structureDescription),

					@"maxWidth" : @((imageResource != nil) ? imageResource.maxPixelSize.width : 0),
					@"maxHeight" : @((imageResource != nil) ? imageResource.maxPixelSize.height : 0),
			        } resultHandler:nil],

		// Insert new resource
		[OCSQLiteQuery  queryInsertingIntoTable:OCDatabaseTableNameResources
				rowValues:@{
					@"type" : resource.type,

					@"identifier" : resource.identifier,
					@"version" : OCSQLiteNullProtect(resource.version),
					@"structDesc" : OCSQLiteNullProtect(resource.structureDescription),

					@"maxWidth" : ((imageResource != nil) ? @(imageResource.maxPixelSize.width) : NSNull.null),
					@"maxHeight" : ((imageResource != nil) ? @(imageResource.maxPixelSize.height) : NSNull.null),

					@"metaData" : ((resource.metaData != nil) ? resource.metaData : NSNull.null),
					@"data" : resourceData
				} resultHandler:nil]
	] type:OCSQLiteTransactionTypeDeferred completionHandler:^(OCSQLiteDB *db, OCSQLiteTransaction *transaction, NSError *error) {
		if (completionHandler != nil)
		{
			completionHandler(error);
		}
	}]];
}

- (void)retrieveResourceForRequest:(nonnull OCResourceRequest *)request completionHandler:(nonnull OCResourceRetrieveCompletionHandler)completionHandler
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

	if ((request.type==nil) || (request.identifier==nil))
	{
		if (completionHandler!=nil)
		{
			completionHandler(OCError(OCErrorInsufficientParameters), nil);
		}
		return;
	}

	[self.sqlDB executeQuery:[OCSQLiteQuery query:[NSString stringWithFormat:@"SELECT maxWidth, maxHeight, data FROM thumb.resources WHERE identifier = :identifier %@ %@ ORDER BY (maxWidth = :maxWidth AND maxHeight = :maxHeight) DESC, (maxWidth >= :maxWidth AND maxHeight >= :maxHeight) DESC, (((maxWidth < :maxWidth AND maxHeight < :maxHeight) * -1000 + 1) * ((maxWidth * maxHeight) - (:maxWidth * :maxHeight))) ASC LIMIT 0,1",
		((request.version != nil) ? @"AND version = :version" : @""),
		((request.structureDescription != nil) ? @"AND structDesc = :structDesc" : @"")] withNamedParameters:@{
		@"identifier"	: request.identifier,
		@"version"	: OCSQLiteNullProtect(request.version),
		@"structDesc"	: OCSQLiteNullProtect(request.structureDescription),
		@"maxWidth"  	: @(request.maxPixelSize.width),
		@"maxHeight" 	: @(request.maxPixelSize.height),
	} resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
		NSError *returnError = error;
		__block BOOL calledCompletionHandler = NO;

		if (returnError == nil)
		{
			[resultSet iterateUsing:^(OCSQLiteResultSet *resultSet, NSUInteger line, NSDictionary<NSString *,id> *rowDictionary, BOOL *stop) {
				NSNumber *maxWidthNumber = nil, *maxHeightNumber = nil;
				NSData *data = nil;

				if (((maxWidthNumber = rowDictionary[@"maxWidth"])!=nil) &&
				    ((maxHeightNumber = rowDictionary[@"maxHeight"])!=nil) &&
				    ((data = rowDictionary[@"data"])!=nil))
				{
					NSError *error;
					OCResource *resource;

					if ((resource = [NSKeyedUnarchiver unarchivedObjectOfClass:OCResource.class fromData:data error:&error]) != nil)
					{
						completionHandler(nil, resource);

						calledCompletionHandler = YES;
						*stop = YES;
					}
				}
			} error:&returnError];
		}

		if (!calledCompletionHandler)
		{
			completionHandler(returnError, nil);
		}
	}]];
}

@end
