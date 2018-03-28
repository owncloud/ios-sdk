//
//  OCSQLiteDB.m
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

#import "OCSQLiteDB.h"
#import "OCLogger.h"
#import "OCSQLiteStatement.h"
#import "OCSQLiteTransaction.h"

#define IsSQLiteError(error) [error.domain isEqualToString:OCSQLiteErrorDomain]
#define IsSQLiteErrorCode(error,errorCode) ((error.code == errorCode) && IsSQLiteError(error))

@implementation OCSQLiteDB

@synthesize databaseURL = _databaseURL;
@synthesize maxBusyRetryTimeInterval = _maxBusyRetryTimeInterval;

- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_maxBusyRetryTimeInterval = 2.0;
	}

	return (self);
}

- (instancetype)initWithURL:(NSURL *)sqliteFileURL
{
	if ((self = [self init]) != nil)
	{
		_databaseURL = sqliteFileURL;
	}

	return (self);
}

- (void)dealloc
{
	if (self.opened)
	{
		OCLogWarning(@"OCSQLiteDB still open on deallocation for %@ - force closing", _databaseURL);
		[self _close]; // Force-close on deallocation
	}

	[_sqliteThread terminate];
}

#pragma mark - Queuing and execution
- (OCRunLoopThread *)runLoopThread
{
	OCRunLoopThread *runLoopThread = nil;

	@synchronized(self)
	{
		if ((runLoopThread = _sqliteThread) == nil)
		{
			NSString *threadName;

			if (_databaseURL.path != nil)
			{
				threadName = [@"OCSQLiteDB-" stringByAppendingString:_databaseURL.path];
			}
			else
			{
				threadName = [@"OCSQLiteDB-" stringByAppendingString:NSUUID.UUID.UUIDString];
			}

			runLoopThread  = _sqliteThread = [OCRunLoopThread runLoopThreadNamed:threadName];
		}
	}

	return (runLoopThread);
}

- (void)queueBlock:(dispatch_block_t)block
{
	[self.runLoopThread dispatchBlockToRunLoopAsync:block];
}

- (BOOL)isOnSQLiteThread
{
	return ([OCRunLoopThread currentRunLoopThread] == self.runLoopThread);
}

#pragma mark - Accessors
static int OCSQLiteDBBusyHandler(void *refCon, int count)
{
	OCSQLiteDB *dbObj = (__bridge OCSQLiteDB *)refCon;

	if (count == 0)
	{
		// Record start time
		dbObj->_firstBusyRetryTime = [NSDate timeIntervalSinceReferenceDate];

		return (1); // Retry
	}
	else
	{
		NSTimeInterval elapsedTime = ([NSDate timeIntervalSinceReferenceDate] - dbObj->_firstBusyRetryTime);

		if (elapsedTime < dbObj->_maxBusyRetryTimeInterval)
		{
			// We're still below the timeout threshold, so sleep a random time between 50 and 100 microseconds
			sqlite3_sleep(50 + arc4random_uniform(50));

			return (1); // Retry
		}
	}

	return (0); // Give up and return busy error
}

- (void)setMaxBusyRetryTimeInterval:(NSTimeInterval)maxBusyRetryTimeInterval
{
	_maxBusyRetryTimeInterval = maxBusyRetryTimeInterval;

	if (_maxBusyRetryTimeInterval == 0)
	{
		sqlite3_busy_handler(_db, NULL, NULL);
	}
	else
	{
		sqlite3_busy_handler(_db, &OCSQLiteDBBusyHandler, (__bridge void *)self);
	}
}

- (sqlite3 *)sqlite3DB
{
	return (_db);
}

#pragma mark - Open & Close
- (void)openWithFlags:(OCSQLiteOpenFlags)flags completionHandler:(OCSQLiteDBCompletionHandler)completionHandler
{
	[self queueBlock:^{
		NSError *error = nil;

		if (!self.opened)
		{
			const char *filename = [[_databaseURL path] UTF8String];
			int sqErr;

			if (filename == NULL)
			{
				filename = ":memory:";
				OCLogDebug(@"OCSQLiteDB using in-memory database");
			}

			if ((sqErr = sqlite3_open_v2(filename, &_db, flags, NULL)) == SQLITE_OK)
			{
				// Success
				self.maxBusyRetryTimeInterval = _maxBusyRetryTimeInterval;
			}
			else
			{
				// Error
				error = OCSQLiteError(sqErr);
			}
		}
		else
		{
			// Instance already open
			error = OCSQLiteDBError(OCSQLiteDBErrorAlreadyOpenedInInstance);
			OCLogDebug(@"Attempt to open OCSQLiteDB %@ more than once", _databaseURL);
		}

		if (completionHandler != nil)
		{
			completionHandler(self,error);
		}
	}];
}

- (void)closeWithCompletionHandler:(OCSQLiteDBCompletionHandler)completionHandler
{
	[self queueBlock:^{
		NSError *error = [self _close];

		if (completionHandler != nil)
		{
			completionHandler(self, error);
		}
	}];
}

- (NSError *)_close
{
	int sqErr;

	do
	{
		sqErr = sqlite3_close(_db);
	}while((sqErr == SQLITE_BUSY) || (sqErr == SQLITE_LOCKED));

	if (sqErr != SQLITE_OK)
	{
		return (OCSQLiteError(sqErr));
	}

	return (nil);
}

#pragma mark - Queries (public)
- (void)executeQuery:(OCSQLiteQuery *)query
{
	[self queueBlock:^{
		[self _executeQuery:query inTransaction:nil];
	}];
}

- (void)executeTransaction:(OCSQLiteTransaction *)transaction
{
	[self queueBlock:^{
		[self _executeTransaction:transaction];
	}];
}

#pragma mark - Queries (internal)
- (NSError *)_executeSimpleSQLQuery:(NSString *)sqlQuery
{
	OCSQLiteStatement *statement;
	NSError *error = nil;

	if ((statement = [self _statementForSQLQuery:sqlQuery error:&error]) != nil)
	{
		if (error == nil)
		{
			int sqErr;

			sqErr = sqlite3_step(statement.sqlStatement);

			if ((sqErr != SQLITE_OK) && (sqErr != SQLITE_DONE))
			{
				error = OCSQLiteLastDBError(_db);
			}
		}
	}

	return (error);
}

- (NSError *)_executeQuery:(OCSQLiteQuery *)query inTransaction:(OCSQLiteTransaction *)transaction
{
	OCSQLiteStatement *statement;
	NSError *error = nil;
	BOOL hasRows = NO;

	if ((statement = [self _statementForSQLQuery:query.sqlQuery error:&error]) != nil)
	{
		if (query.namedParameters != nil)
		{
			[statement bindParametersFromDictionary:query.namedParameters];
		}
		else if (query.parameters != nil)
		{
			[statement bindParameters:query.parameters];
		}

		if (error == nil)
		{
			int sqErr = sqlite3_step(statement.sqlStatement);

			switch (sqErr)
			{
				case SQLITE_OK:
				case SQLITE_DONE:
				break;

				case SQLITE_ROW:
					hasRows = YES;
				break;

				default:
					error = OCSQLiteLastDBError(_db);
				break;
			}
		}

		if (query.resultHandler != nil)
		{
			query.resultHandler(self, error, transaction, ((error==nil) ? (hasRows ? [[OCSQLiteResultSet alloc] initWithStatement:statement] : nil) : nil));
		}
	}

	return (error);
}

- (OCSQLiteStatement *)_statementForSQLQuery:(NSString *)sqlQuery error:(NSError **)outError
{
	// This is a hook for caching statements in the future
	return ([OCSQLiteStatement statementFromQuery:sqlQuery database:self error:outError]);
}

- (void)_executeTransaction:(OCSQLiteTransaction *)transaction
{
	NSError *error = nil;

	// Begin transaction
	switch (transaction.type)
	{
		case OCSQLiteTransactionTypeDeferred:
			error = [self _executeSimpleSQLQuery:@"BEGIN DEFERRED TRANSACTION"];
		break;

		case OCSQLiteTransactionTypeExclusive:
			error = [self _executeSimpleSQLQuery:@"BEGIN EXCLUSIVE TRANSACTION"];
		break;

		case OCSQLiteTransactionTypeImmediate:
			error = [self _executeSimpleSQLQuery:@"BEGIN IMMEDIATE TRANSACTION"];
		break;
	}

	if (error == nil)
	{
		// Perform transaction
		if (transaction.queries != nil)
		{
			for (OCSQLiteQuery *query in transaction.queries)
			{
				error = [self _executeQuery:query inTransaction:transaction];

				if (error != nil)
				{
					error = [NSError errorWithDomain:error.domain code:error.code userInfo:@{
							NSUnderlyingErrorKey 		    : error,
							OCSQLiteTransactionFailedRequestKey : query
						}];
					break;
				}
			}
		}
		else if (transaction.transactionBlock != nil)
		{
			error = transaction.transactionBlock(self, transaction);
		}
	}

	// Force rollback in case of an SQLite error
	if (error != nil)
	{
		if (IsSQLiteError(error))
		{
			if ((error.code != SQLITE_DONE) && (error.code != SQLITE_OK) && (error.code != SQLITE_ROW))
			{
				transaction.commit = NO;
			}
		}
	}

	// Rollback or commit
	if (transaction.commit)
	{
		BOOL retry;

		do
		{
			NSError *commitError;

			retry = NO;

			commitError = [self _executeSimpleSQLQuery:@"COMMIT TRANSACTION"];

			if (IsSQLiteErrorCode(commitError, SQLITE_BUSY))
			{
				// Another thread or process has a shared lock on the db. Let's retry the COMMIT, once the reader has hopefully had a chance to clear the lock. (https://www.sqlite.org/lang_transaction.html)
				retry = YES;
			}

			if (error == nil)
			{
				error = commitError;
			}
		}while(retry);
	}
	else
	{
		NSError *rollbackError;

		rollbackError = [self _executeSimpleSQLQuery:@"ROLLBACK TRANSACTION"];

		if (error == nil)
		{
			error = rollbackError;
		}
	}

	if (transaction.completionHandler != nil)
	{
		if (IsSQLiteErrorCode(error, SQLITE_DONE))
		{
			error = nil;
		}

		transaction.completionHandler(self, transaction, error);
	}
}

#pragma mark - Error handling
- (NSError *)lastError
{
	return (OCSQLiteLastDBError(_db));
}

@end

NSErrorDomain OCSQLiteErrorDomain = @"SQLite";
NSErrorDomain OCSQLiteDBErrorDomain = @"OCSQLiteDB";
