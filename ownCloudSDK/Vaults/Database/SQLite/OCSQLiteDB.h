//
//  OCSQLiteDB.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 14.03.18.
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

#import <Foundation/Foundation.h>

#import <sqlite3.h>

#import "OCSQLiteResultSet.h"
#import "OCRunLoopThread.h"

@class OCSQLiteDB;
@class OCSQLiteTransaction;
@class OCSQLiteQuery;
@class OCSQLiteTableSchema;

typedef NS_ENUM(NSUInteger, OCSQLiteOpenFlags)
{
	OCSQLiteOpenFlagsReadOnly = SQLITE_OPEN_READONLY,
	OCSQLiteOpenFlagsReadWrite = SQLITE_OPEN_READWRITE,
	OCSQLiteOpenFlagsCreate = SQLITE_OPEN_CREATE,

	OCSQLiteOpenFlagsDefault = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE
};

typedef NS_ENUM(NSUInteger, OCSQLiteDBError)
{
	OCSQLiteDBErrorAlreadyOpenedInInstance //!< Instance has already opened file
};

typedef void(^OCSQLiteDBCompletionHandler)(OCSQLiteDB *db, NSError *error);
typedef void(^OCSQLiteDBResultHandler)(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet);
typedef void(^OCSQLiteDBInsertionHandler)(OCSQLiteDB *db, NSError *error, NSNumber *rowID);

@interface OCSQLiteDB : NSObject
{
	NSURL *_databaseURL;
	OCRunLoopThread *_sqliteThread;

	NSTimeInterval _maxBusyRetryTimeInterval;
	NSTimeInterval _firstBusyRetryTime;

	NSInteger _transactionNestingLevel;
	NSUInteger _savepointCounter;

	NSMutableArray <OCSQLiteTableSchema *> *_tableSchemas;

	sqlite3 *_db;
}

@property(class,nonatomic) BOOL allowConcurrentFileAccess; //!< Makes every OCSQLiteDB use a different OCRunLoopThread, so concurrent file access can occur. NO by default. Use this only for implementing concurrency tests.

@property(strong) NSURL *databaseURL;	//!< URL of the SQLite database file. If nil, an in-memory database is used.

@property(assign,nonatomic) NSTimeInterval maxBusyRetryTimeInterval; //!< Amount of time SQLite retries accessing a database before it returns a SQLITE_BUSY error

@property(readonly,nonatomic) sqlite3 *sqlite3DB;

@property(readonly,nonatomic) BOOL opened;

#pragma mark - Init
- (instancetype)initWithURL:(NSURL *)sqliteDatabaseFileURL;

#pragma mark - Open & Close
- (void)openWithFlags:(OCSQLiteOpenFlags)flags completionHandler:(OCSQLiteDBCompletionHandler)completionHandler;
- (void)closeWithCompletionHandler:(OCSQLiteDBCompletionHandler)completionHandler;

#pragma mark - Table Schemas
- (void)addTableSchema:(OCSQLiteTableSchema *)schema; //!< Adds a table schema to the database. All schemas must be added prior to calling -applyTableSchemasWithCompletionHandler: the database.
- (void)applyTableSchemasWithCompletionHandler:(OCSQLiteDBCompletionHandler)completionHandler; //!< Applies the table schemas: creates tables that don't yet exist, applies all available upgrades for existing tables

#pragma mark - Execute
- (void)executeQuery:(OCSQLiteQuery *)query; //!< Executes a query. Usually async, but synchronous if called from with in a OCSQLiteTransactionBlock.
- (void)executeTransaction:(OCSQLiteTransaction *)query; //!< Executes a transaction. Usually async, but synchronous if called from with in a OCSQLiteTransactionBlock.
- (void)executeOperation:(NSError *(^)(OCSQLiteDB *db))operationBlock completionHandler:(OCSQLiteDBCompletionHandler)completionHandler; //!< Executes a block in the internal context, so all calls to -executeQuery: and -executeTransaction: inside this block will be executed synchronously. Will always be scheduled and not be executed immediately, even if called from the internal context.

#pragma mark - Error handling
- (NSError *)lastError;

#pragma mark - Insertion Row ID
- (NSNumber *)lastInsertRowID; //!< Returns the last insert row ID. May only be used within query and transaction completionHandlers. Will return nil otherwise.

#pragma mark - Miscellaneous
- (void)shrinkMemory; //!< Tells SQLite to release as much memory as it can.
+ (int64_t)setMemoryLimit:(int64_t)memoryLimit; //!< Sets a memory limit on the 

@end

extern NSErrorDomain OCSQLiteErrorDomain; //!< Native SQLite errors

extern NSErrorDomain OCSQLiteDBErrorDomain; //!< OCSQLiteDB errors

#define OCSQLiteError(errorCode) [NSError errorWithDomain:OCSQLiteErrorDomain code:errorCode userInfo:@{ NSDebugDescriptionErrorKey : [NSString stringWithFormat:@"%s [%@:%d]", __PRETTY_FUNCTION__, [[NSString stringWithUTF8String:__FILE__] lastPathComponent], __LINE__] }] //!< Macro that creates an NSError from an SQLite error code, but also adds method name, source file and line number)

#define OCSQLiteDBError(errorCode) [NSError errorWithDomain:OCSQLiteDBErrorDomain code:errorCode userInfo:@{ NSDebugDescriptionErrorKey : [NSString stringWithFormat:@"%s [%@:%d]", __PRETTY_FUNCTION__, [[NSString stringWithUTF8String:__FILE__] lastPathComponent], __LINE__] }] //!< Macro that creates an NSError from an OCSQLiteDBError error code, but also adds method name, source file and line number)

#define OCSQLiteLastDBError(db) [NSError errorWithDomain:OCSQLiteErrorDomain code:sqlite3_errcode(db) userInfo:@{ NSDebugDescriptionErrorKey : [NSString stringWithFormat:@"%s [%@:%d]: %s", __PRETTY_FUNCTION__, [[NSString stringWithUTF8String:__FILE__] lastPathComponent], __LINE__, sqlite3_errmsg(db)] }]

#import "OCSQLiteQuery.h"
