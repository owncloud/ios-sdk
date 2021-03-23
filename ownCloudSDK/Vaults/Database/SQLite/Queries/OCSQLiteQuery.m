//
//  OCSQLiteQuery.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 27.03.18.
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

#import "OCSQLiteQuery.h"
#import "OCSQLiteQueryCondition.h"
#import "OCSQLiteStatement.h"

@interface OCSQLiteQuery ()
{
	__weak OCSQLiteStatement *_statement;
}
@end

@implementation OCSQLiteQuery

#pragma mark - Queries
+ (instancetype)query:(OCSQLiteQueryString)sqlQuery withParameters:(NSArray <id<NSObject>> *)parameters resultHandler:(OCSQLiteDBResultHandler)resultHandler
{
	OCSQLiteQuery *query = [self new];

	query.sqlQuery = sqlQuery;
	query.parameters = parameters;
	query.resultHandler = resultHandler;

	return (query);
}

+ (instancetype)query:(OCSQLiteQueryString)sqlQuery withNamedParameters:(NSDictionary <NSString *, id<NSObject>> *)parameters resultHandler:(OCSQLiteDBResultHandler)resultHandler
{
	OCSQLiteQuery *query = [self new];

	query.sqlQuery = sqlQuery;
	query.namedParameters = parameters;
	query.resultHandler = resultHandler;

	return (query);
}

+ (instancetype)query:(OCSQLiteQueryString)sqlQuery resultHandler:(OCSQLiteDBResultHandler)resultHandler;
{
	OCSQLiteQuery *query = [self new];

	query.sqlQuery = sqlQuery;
	query.resultHandler = resultHandler;

	return (query);
}

#pragma mark - SELECT query builder
+ (instancetype)querySelectingColumns:(NSArray<NSString *> *)columnNames fromTable:(NSString *)tableName where:(NSDictionary <NSString *, id<NSObject>> *)matchValues orderBy:(NSString *)orderBy limit:(NSString *)limit resultHandler:(OCSQLiteDBResultHandler)resultHandler
{
	OCSQLiteQuery *query = nil;
	NSMutableArray *parameters=nil;
	OCSQLiteQueryString sqlQuery = nil;
	NSString *whereString = nil;

	// Build WHERE-string
	whereString = [self _buildWhereStringForMatchPairs:matchValues parameters:&parameters];

	sqlQuery = [NSString stringWithFormat:@"SELECT %@ FROM %@%@%@%@", ((columnNames!=nil)?[columnNames componentsJoinedByString:@","]:@"*"), tableName, whereString, ((orderBy!=nil) ? [@" ORDER BY " stringByAppendingString:orderBy] : @""), ((limit!=nil) ? [@" LIMIT " stringByAppendingString:limit] : @"")];

	query = [self new];
	query.sqlQuery = sqlQuery;
	query.parameters = parameters;
	query.resultHandler = resultHandler;

	return (query);
}

+ (instancetype)querySelectingColumns:(NSArray<NSString *> *)columnNames fromTable:(NSString *)tableName where:(NSDictionary <NSString *, id<NSObject>> *)matchValues orderBy:(NSString *)orderBy resultHandler:(OCSQLiteDBResultHandler)resultHandler
{
	return ([self querySelectingColumns:columnNames fromTable:tableName where:matchValues orderBy:orderBy limit:nil resultHandler:resultHandler]);
}

+ (instancetype)querySelectingColumns:(NSArray<NSString *> *)columnNames fromTable:(NSString *)tableName where:(NSDictionary <NSString *, id<NSObject>> *)matchValues resultHandler:(OCSQLiteDBResultHandler)resultHandler
{
	return ([self querySelectingColumns:columnNames fromTable:tableName where:matchValues orderBy:nil limit:nil resultHandler:resultHandler]);
}

#pragma mark - INSERT query builder
+ (instancetype)queryInsertingIntoTable:(NSString *)tableName rowValues:(NSDictionary <NSString *, id<NSObject>> *)rowValues resultHandler:(OCSQLiteDBInsertionHandler)resultHandler
{
	OCSQLiteQuery *query = nil;
	NSUInteger rowValuesCount;

	rowValuesCount = rowValues.count;

	if (rowValuesCount > 0)
	{
		NSMutableArray <NSString *> *columnNames;
		NSMutableArray *values;
		OCSQLiteQueryString sqlQuery = nil;
		__block NSUInteger i=0;
		NSMutableString *placeholdersString;

		placeholdersString = [[NSMutableString alloc] initWithCapacity:2*rowValuesCount];
		columnNames = [[NSMutableArray alloc] initWithCapacity:rowValuesCount];
		values = [[NSMutableArray alloc] initWithCapacity:rowValuesCount];

		[rowValues enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, id<NSObject>  _Nonnull obj, BOOL * _Nonnull stop) {
			[columnNames addObject:key];
			[values addObject:obj];

			if (i == (rowValuesCount-1))
			{
				[placeholdersString appendString:@"?"];
			}
			else
			{
				[placeholdersString appendString:@"?,"];
			}

			i++;
		}];

		sqlQuery = [NSString stringWithFormat:@"INSERT INTO %@ (%@) VALUES (%@)", tableName, [columnNames componentsJoinedByString:@","], placeholdersString];

		query = [self new];
		query.sqlQuery = sqlQuery;
		query.parameters = values;
		query.resultHandler = (resultHandler!=nil) ? ^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
			resultHandler(db, error, ((error == nil) ? [db lastInsertRowID] : nil));
		} : nil;
	}

	return (query);
}

#pragma mark - UPDATE query builder
+ (instancetype)queryUpdatingRowsWhere:(NSDictionary <NSString *, id<NSObject>> *)matchValues inTable:(NSString *)tableName withRowValues:(NSDictionary <NSString *, id<NSObject>> *)rowValues completionHandler:(OCSQLiteDBCompletionHandler)completionHandler
{
	OCSQLiteQuery *query = nil;
	NSUInteger rowValuesCount, matchValuesCount;

	rowValuesCount = rowValues.count;
	matchValuesCount = matchValues.count;

	if (rowValuesCount > 0)
	{
		NSMutableArray *parameters;
		OCSQLiteQueryString sqlQuery = nil;
		__block NSUInteger i=0;
		NSMutableString *setString;
		NSString *whereString;

		setString = [[NSMutableString alloc] initWithCapacity:20*rowValuesCount];
		parameters = [[NSMutableArray alloc] initWithCapacity:rowValuesCount+matchValuesCount];

		// Build SET-string
		[rowValues enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull columnName, id<NSObject>  _Nonnull obj, BOOL * _Nonnull stop) {
			[parameters addObject:obj];

			if (i == (rowValuesCount-1))
			{
				[setString appendFormat:@"%@=?", columnName];
			}
			else
			{
				[setString appendFormat:@"%@=?,", columnName];
			}

			i++;
		}];

		// Build WHERE-string
		whereString = [self _buildWhereStringForMatchPairs:matchValues parameters:&parameters];

		sqlQuery = [NSString stringWithFormat:@"UPDATE %@ SET %@%@", tableName, setString, whereString];

		query = [self new];
		query.sqlQuery = sqlQuery;
		query.parameters = parameters;
		query.resultHandler = (completionHandler!=nil) ? ^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
			completionHandler(db, error);
		} : nil;
	}

	return (query);
}

+ (instancetype)queryUpdatingRowWithID:(NSNumber *)rowID inTable:(NSString *)tableName withRowValues:(NSDictionary <NSString *, id<NSObject>> *)rowValues completionHandler:(OCSQLiteDBCompletionHandler)completionHandler
{
	return ([self queryUpdatingRowsWhere:((rowID!=nil) ? @{ @"ROWID" : rowID } : nil) inTable:tableName withRowValues:rowValues completionHandler:completionHandler]);
}

#pragma mark - DELETE query builder
+ (instancetype)queryDeletingRowsWhere:(NSDictionary <NSString *, id<NSObject>> *)matchValues fromTable:(NSString *)tableName completionHandler:(OCSQLiteDBCompletionHandler)completionHandler
{
	OCSQLiteQuery *query = nil;
	NSMutableArray *parameters = nil;
	OCSQLiteQueryString sqlQuery = nil;

	sqlQuery = [NSString stringWithFormat:@"DELETE FROM %@%@", tableName, [self _buildWhereStringForMatchPairs:matchValues parameters:&parameters]];

	query = [self new];
	query.sqlQuery = sqlQuery;
	query.parameters = parameters;
	query.resultHandler = (completionHandler!=nil) ? ^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
		completionHandler(db, error);
	} : nil;

	return (query);
}

+ (instancetype)queryDeletingRowWithID:(NSNumber *)rowID fromTable:(NSString *)tableName completionHandler:(OCSQLiteDBCompletionHandler)completionHandler
{
	return ([self queryDeletingRowsWhere:((rowID!=nil) ? @{ @"ROWID" : rowID } : nil) fromTable:tableName completionHandler:completionHandler]);
}

#pragma mark - Tools
+ (NSString *)_buildWhereStringForMatchPairs:(NSDictionary <NSString *, id<NSObject>> *)matchValues parameters:(NSMutableArray **)inOutParameters
{
	NSMutableString *whereString = nil;
	NSUInteger matchValuesCount = matchValues.count;
	NSMutableArray *parameters = nil;

	if (matchValuesCount > 0)
	{
		__block NSUInteger addedConditions = 0;

		if (inOutParameters != NULL)
		{
			parameters = *inOutParameters;
		}

		if (parameters == nil)
		{
			parameters = [NSMutableArray new];
		}

		whereString = [[NSMutableString alloc] initWithCapacity:20*matchValuesCount];

		[matchValues enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull columnName, id<NSObject>  _Nonnull obj, BOOL * _Nonnull stop) {
			NSString *sqlOperator = @"=";

			if ([obj isKindOfClass:[OCSQLiteQueryCondition class]])
			{
				OCSQLiteQueryCondition *condition = (OCSQLiteQueryCondition *)obj;

				if (!condition.apply)
				{
					return;
				}

				sqlOperator = condition.sqlOperator;
				obj = condition.value;
			}

			[parameters addObject:obj];

			if (addedConditions > 0)
			{
				[whereString appendFormat:@" AND %@%@?", columnName, sqlOperator];
			}
			else
			{
				[whereString appendFormat:@" WHERE %@%@?", columnName, sqlOperator];
			}

			addedConditions++;
		}];

		if (whereString.length == 0)
		{
			whereString = nil;
		}
	}

	if (inOutParameters != NULL)
	{
		*inOutParameters = parameters;
	}

	return ((whereString!=nil) ? whereString : @"");
}

#pragma mark - Statement tracking
- (OCSQLiteStatement *)statement
{
	return (_statement);
}

- (void)setStatement:(OCSQLiteStatement *)statement
{
	_statement = statement;
}

#pragma mark - Cancelation
- (BOOL)cancel
{
	if (!_cancelled)
	{
		_cancelled = YES;

		return ([_statement cancel]);
	}

	return (NO);
}

@end
