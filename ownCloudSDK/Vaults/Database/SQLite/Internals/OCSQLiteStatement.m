//
//  OCSQLiteStatement.m
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

#import "OCSQLiteStatement.h"
#import "OCSQLiteDB.h"
#import "OCLogger.h"
#import "OCSQLiteDB+Internal.h"

@implementation OCSQLiteStatement

@synthesize sqlStatement = _sqlStatement;
@synthesize database = _database;

+ (nullable instancetype)statementFromQuery:(NSString *)query database:(OCSQLiteDB *)database error:(NSError **)outError
{
	OCSQLiteStatement *statement = nil;
	sqlite3_stmt *sqlStatement = NULL;
	NSError *error = nil;
	/* int sqErr; */

	if (sqlite3_prepare_v2(database.sqlite3DB, (const char *)query.UTF8String, -1, &sqlStatement, NULL) != SQLITE_OK)
	{
		// Error
		error = OCSQLiteLastDBError(database.sqlite3DB);
		OCLogError(@"Error executing '%@': %@", query, OCLogPrivate(error));

		sqlite3_finalize(sqlStatement);
	}

	if (error == nil)
	{
		// Success
		statement = [[self alloc] initWithSQLStatement:sqlStatement database:database];
		statement.query = query;
	}

	if (outError != NULL) { *outError = error; }

	return (statement);
}

- (instancetype)initWithSQLStatement:(sqlite3_stmt *)sqlStatement database:(OCSQLiteDB *)database;
{
	if ((self = [super init]) != nil)
	{
		_sqlStatement = sqlStatement;
		_database = database;
		_lastUsed = NSDate.timeIntervalSinceReferenceDate;

		[_database startTrackingStatement:self];
	}

	return(self);
}

#pragma mark - Release
- (void)releaseSQLObjects
{
	if (_sqlStatement != NULL)
	{
		if (_database.isOnSQLiteThread)
		{
			sqlite3_finalize(_sqlStatement);
			_sqlStatement = NULL;
		}
		else
		{
			sqlite3_stmt *sqlStatement = _sqlStatement;
			_sqlStatement = NULL;

			[_database executeOperation:^NSError *(OCSQLiteDB *db) {
				sqlite3_finalize(sqlStatement);
				return (nil);
			} completionHandler:nil];
		}
	}
}

- (void)dealloc
{
	[_database stopTrackingStatement:self];

	[self releaseSQLObjects];
}

- (NSArray <NSString *> *)parameterNamesByIndex
{
	// Get parameter names in order
	if ((_parameterNamesByIndex == nil) && (_sqlStatement != NULL))
	{
		int paramCnt, paramIdx;

		if ((paramCnt = sqlite3_bind_parameter_count(_sqlStatement)) > 0)
		{
			_parameterNamesByIndex = [[NSMutableArray alloc] initWithCapacity:paramCnt];

			for (paramIdx=1; paramIdx<=paramCnt; paramIdx++)
			{
				const char *parameterName;

				if ((parameterName = sqlite3_bind_parameter_name(_sqlStatement, paramIdx)) != NULL)
				{
					NSString *parameterNameString;

					if ((parameterNameString = [[NSString alloc] initWithUTF8String:(parameterName+1)]) != nil) // the initial ":" or "$" or "@" or "?" is included as part of the name => offset by 1 to remove it
					{
						[_parameterNamesByIndex addObject:parameterNameString];
					}
				}
			}
		}
	}

	return (_parameterNamesByIndex);
}

#pragma mark - Binding values
- (void)bindParameterValue:(id)value atIndex:(int)paramIdx
{
	if (_sqlStatement != NULL)
	{
		if (value != nil)
		{
			if ([value isKindOfClass:[NSNumber class]])
			{
				// Numbers
				NSNumber *number = value;
				const char *objCType = number.objCType;

				// Double
				if 	(strcmp(objCType, @encode(double))==0)			{ sqlite3_bind_double(_sqlStatement, paramIdx, number.doubleValue); }
				else if (strcmp(objCType, @encode(float))==0)			{ sqlite3_bind_double(_sqlStatement, paramIdx, (double)number.floatValue); }

				// 64-Bit integer
				else if (strcmp(objCType, @encode(unsigned int))==0)		{ sqlite3_bind_int64(_sqlStatement, paramIdx, (long long)number.unsignedIntValue); } // No unsigned int binding available => bind as 64 bit value to avoid overflow
				else if (strcmp(objCType, @encode(long))==0)			{ sqlite3_bind_int64(_sqlStatement, paramIdx, (long long)number.longValue); }
				else if (strcmp(objCType, @encode(unsigned long))==0)		{ sqlite3_bind_int64(_sqlStatement, paramIdx, (long long)number.unsignedLongValue); }
				else if (strcmp(objCType, @encode(long long))==0)		{ sqlite3_bind_int64(_sqlStatement, paramIdx, number.longLongValue); }
				else if (strcmp(objCType, @encode(unsigned long long))==0) 	{ sqlite3_bind_int64(_sqlStatement, paramIdx, (long long)number.unsignedLongLongValue); }

				// 32-Bit integer
				else if (strcmp(objCType, @encode(BOOL))==0) 			{ sqlite3_bind_int(_sqlStatement, paramIdx, (int)number.boolValue); }
				else if (strcmp(objCType, @encode(char))==0) 			{ sqlite3_bind_int(_sqlStatement, paramIdx, (int)number.charValue); }
				else if (strcmp(objCType, @encode(unsigned char))==0)		{ sqlite3_bind_int(_sqlStatement, paramIdx, (int)number.unsignedCharValue); }
				else if (strcmp(objCType, @encode(short))==0) 			{ sqlite3_bind_int(_sqlStatement, paramIdx, (int)number.shortValue); }
				else if (strcmp(objCType, @encode(unsigned short))==0)		{ sqlite3_bind_int(_sqlStatement, paramIdx, (int)number.unsignedShortValue); }
				else if (strcmp(objCType, @encode(int))==0) 			{ sqlite3_bind_int(_sqlStatement, paramIdx, number.intValue); }

				// Anything else?!
				else { sqlite3_bind_text(_sqlStatement, paramIdx, number.description.UTF8String, -1, SQLITE_STATIC); }
			}
			else if ([value isKindOfClass:[NSString class]])
			{
				// Strings
				sqlite3_bind_text(_sqlStatement, paramIdx, ((NSString *)value).UTF8String, -1, SQLITE_STATIC);
			}
			else if ([value isKindOfClass:[NSDate class]])
			{
				// Dates
				sqlite3_bind_double(_sqlStatement, paramIdx, ((NSDate *)value).timeIntervalSince1970);
			}
			else if ([value isKindOfClass:[NSData class]])
			{
				// Data
				NSData *data = (NSData *)value;
				const void *p_bytes = data.bytes;

				sqlite3_bind_blob64(_sqlStatement, paramIdx, ((data.length>0) ? p_bytes : (const void *)&p_bytes), data.length, SQLITE_STATIC);
			}
			else if ([value isKindOfClass:[NSNull class]])
			{
				// Null
				sqlite3_bind_null(_sqlStatement, paramIdx);
			}
			else
			{
				// Anything else?!
				sqlite3_bind_text(_sqlStatement, paramIdx, ((NSObject *)value).description.UTF8String, -1, SQLITE_STATIC);
			}
		}
		else
		{
			// No value => NULL
			sqlite3_bind_null(_sqlStatement, paramIdx);
		}
	}
}

- (void)bindParametersFromDictionary:(NSDictionary *)parameters
{
	NSArray <NSString *> *parameterNamesByIndex = [self parameterNamesByIndex];

	// Bind parameter values
	if (parameterNamesByIndex != nil)
	{
		int paramIdx = 1; // The first host parameter has an index of 1, not 0.

		for (NSString *parameterName in parameterNamesByIndex)
		{
			[self bindParameterValue:parameters[parameterName] atIndex:paramIdx];
			paramIdx++;
		}

		if (parameterNamesByIndex.count < parameters.count)
		{
			OCLogWarning(@"SQL query contains less parameters than were provided: query: %@ - parameters: %@", self.query, OCLogPrivate(parameters));
		}
	}
}

- (void)bindParameters:(NSArray <id<NSObject>> *)values
{
	if (sqlite3_bind_parameter_count(_sqlStatement) != values.count)
	{
		OCLogWarning(@"SQL query contains other number of parameters than were specified in query: %@ - parameters: %@", self.query, OCLogPrivate(values));
	}
	else
	{
		int paramIdx = 1; // The first host parameter has an index of 1, not 0.

		for (id<NSObject> value in values)
		{
			[self bindParameterValue:value atIndex:paramIdx];

			paramIdx++;
		}
	}
}

#pragma mark - Resetting
- (void)claim
{
	@synchronized(OCSQLiteStatement.class)
	{
		_isClaimed = YES;
		_lastUsed = NSDate.timeIntervalSinceReferenceDate;
		_claimedCounter++;
	}
}

- (void)dropClaim
{
	@synchronized(OCSQLiteStatement.class)
	{
		if (_isClaimed)
		{
			// Release resources / file lock asap
			[self reset];
		}

		_isClaimed = NO;
	}
}

- (void)reset
{
	OCLogDebug(@"Resetting %@", self);

	if (_sqlStatement != NULL)
	{
	 	int sqErr;

	 	if ((sqErr = sqlite3_reset(_sqlStatement)) != SQLITE_OK)
	 	{
			OCLogWarning(@"Reset of statement %p with query `%@` failed with error=%d", self, _query, sqErr);
		}

		if ((sqErr = sqlite3_clear_bindings(_sqlStatement)) != SQLITE_OK)
		{
			OCLogWarning(@"Clearing bindings of statement %p with query `%@` failed with error=%d", self, _query, sqErr);
		}
	}
}

#pragma mark - Description
- (NSString *)description
{
	return ([NSString stringWithFormat:@"<%@: %p, query: %@, native: %p, claimed: %d (total: %lu)>", NSStringFromClass(self.class), self, _query, _sqlStatement, _isClaimed, (unsigned long)_claimedCounter]);
}

@end
