//
//  OCSQLiteResultSet.m
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

#import "OCSQLiteResultSet.h"
#import "OCSQLiteStatement.h"
#import "OCSQLiteDB.h"
#import "OCLogger.h"

@implementation OCSQLiteResultSet

@synthesize statement = _statement;

#pragma mark - Init & Dealloc
- (instancetype)initWithStatement:(OCSQLiteStatement *)statement
{
	if ((self = [super init]) != nil)
	{
		_statement = statement;
		[_statement claim]; // Indicate this statement is in use

		_sqlStatement = _statement.sqlStatement;
	}

	return(self);
}

- (void)dealloc
{
	[_statement dropClaim]; // Indicate this statement is no longer in use
}

#pragma mark - Iterating
- (BOOL)nextRow:(NSError **)outError
{
	int sqErr;
	NSError *error = nil;

	sqErr = sqlite3_step(_statement.sqlStatement);

	if ((sqErr != SQLITE_DONE) && (sqErr != SQLITE_ROW))
	{
		error = OCSQLiteError(sqErr);
 	}

	if (outError != NULL)
	{
		*outError = error;
	}

	if (sqErr != SQLITE_ROW)
	{
		_endOfResultSetReached = YES;
	}

	return (sqErr == SQLITE_ROW); // There'll be another row after that
}

- (NSUInteger)iterateUsing:(OCSQLiteResultSetIterator)iterator error:(NSError **)outError
{
	NSUInteger lineNumber=0;
	NSError *error = nil;

	if (iterator != nil)
	{
		BOOL stop = NO;

		do
		{
			@autoreleasepool
			{
				if (error == nil)
				{
					iterator(self, lineNumber, [self rowDictionary], &stop);
					lineNumber++;
				}
				else
				{
					stop = YES;
				}
			}
		}while(!stop && [self nextRow:&error]);
	}

	if (outError != NULL)
	{
		*outError = error;
	}

	return (lineNumber);
}

- (nullable OCSQLiteRowDictionary)nextRowDictionaryWithError:(NSError **)outError
{
	NSDictionary<NSString *,id<NSObject>> *nextRowDictionary = nil;

	if (!_endOfResultSetReached)
	{
		nextRowDictionary = [self rowDictionary];
		[self nextRow:outError];
	}

	return (nextRowDictionary);
}

#pragma mark - Access result
- (id)valueForColumn:(int)columnIdx
{
	id object = nil;

	switch (sqlite3_column_type(_sqlStatement, columnIdx))
	{
		case SQLITE_INTEGER:
			object = @(sqlite3_column_int64(_sqlStatement, columnIdx));
		break;

		case SQLITE_FLOAT:
			object = @(sqlite3_column_double(_sqlStatement, columnIdx));
		break;

		case SQLITE_TEXT: {
			const unsigned char *utf8String;
			int byteCount;

			if (((utf8String = sqlite3_column_text(_sqlStatement, columnIdx)) != NULL) &&
			     (byteCount = sqlite3_column_bytes(_sqlStatement, columnIdx)))
			{
				object = [[NSString alloc] initWithBytes:(const void *)utf8String length:(NSUInteger)byteCount encoding:NSUTF8StringEncoding];
			}
		}
		break;

		case SQLITE_BLOB: {
			const void *blobData;

			if ((blobData = sqlite3_column_blob(_sqlStatement, columnIdx)) == NULL)
			{
				object = [NSData data];
			}
			else
			{
				int byteCount = sqlite3_column_bytes(_sqlStatement, columnIdx);

				object = [[NSData alloc] initWithBytes:blobData length:byteCount];
			}
		}
		break;

		case SQLITE_NULL:
			object = [NSNull null];
		break;
	}

	return (object);
}

- (NSArray<NSString *> *)columnNames
{
	if (_columnNames == nil)
	{
		NSMutableArray *columnNames = [NSMutableArray new];

		int columnCount;

		if ((columnCount = sqlite3_data_count(_sqlStatement)) > 0)
		{
			for (int columnIdx=0; columnIdx<columnCount; columnIdx++)
			{
				const char *columnName;
				NSString *columnNameString = nil;

				if ((columnName = sqlite3_column_name(_sqlStatement, columnIdx)) != NULL)
				{
					if ((columnNameString = [NSString stringWithUTF8String:columnName]) != nil)
					{
						// If a field's name ends in "Date": automatically convert Float to NSDate
						if (([columnNameString hasSuffix:@"Date"]) && (sqlite3_column_type(_sqlStatement, columnIdx) == SQLITE_FLOAT))
						{
							if (filtersByColumnIndex==nil) { filtersByColumnIndex = [NSMutableDictionary new]; }

							filtersByColumnIndex[@(columnIdx)] = [^(id object) {
								if ([object isKindOfClass:[NSNumber class]])
								{
									return ((id)[NSDate dateWithTimeIntervalSince1970:((NSNumber *)object).doubleValue]);
								}

								return (object);
							} copy];
						}

						[columnNames addObject:columnNameString];
					}
				}
			}
		}

		_columnNames = columnNames;
	}

	return (_columnNames);
}

- (NSString *)nameOfColumn:(int)columnIdx
{
	NSArray *columnNames = [self columnNames];

	if ((columnIdx>=0) && (columnIdx < columnNames.count))
	{
		return ([columnNames objectAtIndex:columnIdx]);
	}

	OCLogError(@"Column index out of bounds: index %d not in 0..%ld range", columnIdx, columnNames.count);

	return (nil);
}

- (OCSQLiteRowDictionary)rowDictionary
{
	sqlite3_stmt *sqlStatement;
	NSMutableDictionary<NSString *, id<NSObject>> *rowDict = nil;

	if ((sqlStatement = _statement.sqlStatement) != NULL)
	{
		int columnCount;

		if ((columnCount = sqlite3_data_count(sqlStatement)) > 0)
		{
			for (int columnIdx=0; columnIdx<columnCount; columnIdx++)
			{
				NSString *key;
				id value;

				if (((key = [self nameOfColumn:columnIdx])!=nil) &&
				    ((value = [self valueForColumn:columnIdx])!=nil))
				{
					// Perform column filters
					if (filtersByColumnIndex != nil)
					{
						OCSQLiteResultSetColumnFilter columnFilter;

						if ((columnFilter = filtersByColumnIndex[@(columnIdx)]) != nil)
						{
							value = columnFilter(value);
						}
					}

					if (rowDict == nil) { rowDict = [NSMutableDictionary new]; }
					[rowDict setObject:value forKey:key];
				}
			}
		}
	}

	return (rowDict);
}

@end
