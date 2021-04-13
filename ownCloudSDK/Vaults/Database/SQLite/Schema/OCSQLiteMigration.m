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
#import "OCLogger.h"

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
		// Schemas are up-to-date
		if (completionHandler != nil)
		{
			completionHandler(db, nil);
		}
	}
	else
	{
		// One or more schemas need to be updated
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
								self->_appliedSchemas++;
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
			OCLog(@"Migrating '%@' to version %lu", applySchema.tableName, (unsigned long)applySchema.version);

			if (applySchema.upgradeMigrator != nil)
			{
				// Run upgrade migration
				applySchema.migrationProgress = self.progress;
				applySchema.upgradeMigrator(db, applySchema, ^(NSError *error) {
					OCLog(@"Migrated '%@' to version %lu with error=%@", applySchema.tableName, (unsigned long)applySchema.version, error);
					schemaCompletionHandler(error, NO);
				});
			}
			else
			{
				// No migrator to execute
				OCLog(@"Migrated '%@' to version %lu (none needed)", applySchema.tableName, (unsigned long)applySchema.version);

				_appliedSchemas++;
				[self applySchemasToDatabase:db completionHandler:completionHandler];
			}
		}
		else
		{
			// Create
			OCLog(@"Creating new table '%@' (version %lu)", applySchema.tableName, (unsigned long)applySchema.version);

			[db executeOperation:^NSError *(OCSQLiteDB *db) {
				__block NSError *returnError = nil;

				[applySchema.creationQueries enumerateObjectsUsingBlock:^(NSString *queryString, NSUInteger idx, BOOL * _Nonnull stop) {
					[db executeQuery:[OCSQLiteQuery query:queryString resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
						returnError = error;
					}]];

					if (returnError!=nil) { *stop = YES; }
				}];

				OCLog(@"Created new table '%@' (version %lu)", applySchema.tableName, (unsigned long)applySchema.version);

				return (returnError);
			} completionHandler:^(OCSQLiteDB *db, NSError *error) {
				schemaCompletionHandler(error, YES);
			}];
		}
	}
}

+ (nonnull NSArray<OCLogTagName> *)logTags {
	return (@[ @"SQL", @"Migration" ]);
}

- (nonnull NSArray<OCLogTagName> *)logTags {
	return (@[ @"SQL", @"Migration" ]);
}

@end
