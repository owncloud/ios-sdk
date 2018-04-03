//
//  OCSQLiteMigration.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 02.04.18.
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

#import "OCSQLiteMigration.h"
#import "OCSQLiteTableSchema.h"

@implementation OCSQLiteMigration

#pragma mark - Init & Dealloc
- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_applicableSchemas = [NSMutableArray new];
		_versionsByTableName = [NSMutableDictionary new];
	}

	return(self);
}

- (void)applySchemasToDatabase:(OCSQLiteDB *)db completionHandler:(OCSQLiteDBCompletionHandler)completionHandler
{
	if (_appliedSchemas >= _applicableSchemas.count)
	{
		if (completionHandler != nil)
		{
			completionHandler(db, nil);
		}
	}
	else
	{
		OCSQLiteTableSchema *applySchema = _applicableSchemas[_appliedSchemas];

		void (^schemaCompletionHandler)(NSError *error, BOOL isCreation) = ^(NSError *error, BOOL isCreation){
			if (error == nil)
			{
				NSString *queryString;

				if (isCreation)
				{
					queryString = @"INSERT INTO tableSchemas (version,tableName) VALUES (:newVersion,:nameOfTable)";
				}
				else
				{
					queryString = @"UPDATE tableSchemas SET version=:newVersion WHERE tableName=:nameOfTable";
				}

				[db executeQuery:[OCSQLiteQuery query:queryString
								withNamedParameters:@{
									@"newVersion" : @(applySchema.version),
									@"nameOfTable" : applySchema.tableName

								}
								resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet)
						{
							if (error == nil)
							{
								_appliedSchemas++;
								[self applySchemasToDatabase:db completionHandler:completionHandler];
							}
							else
							{
								if (completionHandler != nil)
								{
									completionHandler(db, error);
								}
							}
						}]
				];
			}
			else
			{
				if (completionHandler != nil)
				{
					completionHandler(db, error);
				}
			}
		};

		if (_versionsByTableName[applySchema.tableName] != nil)
		{
			// Migrate to new version
			if (applySchema.upgradeMigrator != nil)
			{
				// Run upgrade migration
				applySchema.upgradeMigrator(db, applySchema, ^(NSError *error) { schemaCompletionHandler(error, NO); });
			}
			else
			{
				// No migrator to execute
				_appliedSchemas++;
				[self applySchemasToDatabase:db completionHandler:completionHandler];
			}
		}
		else
		{
			// Create
			[db executeOperation:^NSError *(OCSQLiteDB *db) {
				__block NSError *returnError = nil;

				[applySchema.creationQueries enumerateObjectsUsingBlock:^(NSString *queryString, NSUInteger idx, BOOL * _Nonnull stop) {
					[db executeQuery:[OCSQLiteQuery query:queryString resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
						returnError = error;
					}]];

					if (returnError!=nil) { *stop = YES; }
				}];

				return (returnError);
			} completionHandler:^(OCSQLiteDB *db, NSError *error) {
				schemaCompletionHandler(error, YES);
			}];
		}
	}
}

@end
