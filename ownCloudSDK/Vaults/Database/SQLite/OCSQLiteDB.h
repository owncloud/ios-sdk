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

@interface OCSQLiteDB : NSObject
{
	NSURL *_databaseURL;
	OCRunLoopThread *_sqliteThread;

	NSTimeInterval _maxBusyRetryTimeInterval;
	NSTimeInterval _firstBusyRetryTime;

	sqlite3 *_db;
}

@property(strong) NSURL *databaseURL;	//!< URL of the SQLite database file. If nil, an in-memory database is used.

@property(assign,nonatomic) NSTimeInterval maxBusyRetryTimeInterval; //!< Amount of time SQLite retries accessing a database before it returns a SQLITE_BUSY error

@property(readonly,nonatomic) sqlite3 *sqlite3DB;

@property(readonly,nonatomic) BOOL opened;

#pragma mark - Init
- (instancetype)initWithURL:(NSURL *)sqliteDatabaseFileURL;

#pragma mark - Open & Close
- (void)openWithFlags:(OCSQLiteOpenFlags)flags completionHandler:(OCSQLiteDBCompletionHandler)completionHandler;
- (void)closeWithCompletionHandler:(OCSQLiteDBCompletionHandler)completionHandler;

#pragma mark - Execute
- (void)executeQuery:(OCSQLiteQuery *)query;
- (void)executeTransaction:(OCSQLiteTransaction *)query;

#pragma mark - Error handling
- (NSError *)lastError;

@end

extern NSErrorDomain OCSQLiteErrorDomain; //!< Native SQLite errors

extern NSErrorDomain OCSQLiteDBErrorDomain; //!< OCSQLiteDB errors

#define OCSQLiteError(errorCode) [NSError errorWithDomain:OCSQLiteErrorDomain code:errorCode userInfo:@{ NSDebugDescriptionErrorKey : [NSString stringWithFormat:@"%s [%@:%d]", __PRETTY_FUNCTION__, [[NSString stringWithUTF8String:__FILE__] lastPathComponent], __LINE__] }] //!< Macro that creates an NSError from an SQLite error code, but also adds method name, source file and line number)

#define OCSQLiteDBError(errorCode) [NSError errorWithDomain:OCSQLiteDBErrorDomain code:errorCode userInfo:@{ NSDebugDescriptionErrorKey : [NSString stringWithFormat:@"%s [%@:%d]", __PRETTY_FUNCTION__, [[NSString stringWithUTF8String:__FILE__] lastPathComponent], __LINE__] }] //!< Macro that creates an NSError from an OCSQLiteDBError error code, but also adds method name, source file and line number)

#define OCSQLiteLastDBError(db) [NSError errorWithDomain:OCSQLiteErrorDomain code:sqlite3_errcode(db) userInfo:@{ NSDebugDescriptionErrorKey : [NSString stringWithFormat:@"%s [%@:%d]: %s", __PRETTY_FUNCTION__, [[NSString stringWithUTF8String:__FILE__] lastPathComponent], __LINE__, sqlite3_errmsg(db)] }]

#import "OCSQLiteQuery.h"
