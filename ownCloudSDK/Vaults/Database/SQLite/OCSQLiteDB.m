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
#import "OCSQLiteDB+Internal.h"
#import "OCLogger.h"
#import "OCSQLiteStatement.h"
#import "OCSQLiteTransaction.h"
#import "OCSQLiteMigration.h"
#import "OCSQLiteTableSchema.h"
#import "OCMacros.h"

#import "OCExtension+License.h"

#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
#endif /* TARGET_OS_IOS */

#define IsSQLiteError(error) [error.domain isEqualToString:OCSQLiteErrorDomain]
#define IsSQLiteErrorCode(error,errorCode) ((error.code == errorCode) && IsSQLiteError(error))

static BOOL sOCSQLiteDBAllowConcurrentFileAccess = NO;
static NSMutableDictionary<NSString *, NSNumber *> *sOCSQliteDBSharedRunLoopThreadUsageCountByName;

@implementation OCSQLiteDB

@synthesize databaseURL = _databaseURL;
@synthesize maxBusyRetryTimeInterval = _maxBusyRetryTimeInterval;

+ (void)load
{
	[[OCExtensionManager sharedExtensionManager] addExtension:[OCExtension licenseExtensionWithIdentifier:@"license.ISRunLoopThread" bundleOfClass:[OCRunLoopThread class] title:@"ISRunLoopThread" resourceName:@"ISRunLoopThread" fileExtension:@"LICENSE"]];
}

+ (BOOL)allowConcurrentFileAccess
{
	return (sOCSQLiteDBAllowConcurrentFileAccess);
}

+ (void)setAllowConcurrentFileAccess:(BOOL)allowConcurrentFileAccess
{
	sOCSQLiteDBAllowConcurrentFileAccess = allowConcurrentFileAccess;
}

- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_maxBusyRetryTimeInterval = 2.0;

		_liveStatements = [NSHashTable weakObjectsHashTable];

		_journalMode = OCSQLiteJournalModeDelete; // (SQLite default)

		#if TARGET_OS_IOS
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(shrinkMemory) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
		#endif /* TARGET_OS_IOS */
	}

	return(self);
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
	#if TARGET_OS_IOS
	[[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
	#endif /* TARGET_OS_IOS */

	if (self.opened)
	{
		OCLogWarning(@"OCSQLiteDB still open on deallocation for %@ - force closing", _databaseURL);

		[self _close]; // Force-close on deallocation
	}

	if ((_runLoopThreadName != nil) && (_sqliteThread != nil))
	{
		NSInteger usageCount;

		usageCount = sOCSQliteDBSharedRunLoopThreadUsageCountByName[_runLoopThreadName].integerValue - 1;
		sOCSQliteDBSharedRunLoopThreadUsageCountByName[_runLoopThreadName] = @(usageCount);

		if (usageCount == 0)
		{
			[_sqliteThread terminate];
		}
		else
		{
			if (usageCount < 0)
			{
				OCLogError(@"Negative usage count for %@", _runLoopThreadName);
			}
		}
	}
	else
	{
		[_sqliteThread terminate];
	}
}

#pragma mark - Queuing and execution
- (OCRunLoopThread *)runLoopThread
{
	OCRunLoopThread *runLoopThread = nil;

	@synchronized(self)
	{
		if ((runLoopThread = _sqliteThread) == nil)
		{
			NSString *threadName = _runLoopThreadName;

			if (threadName == nil)
			{
				if ((_databaseURL.path != nil) && !OCSQLiteDB.allowConcurrentFileAccess)
				{
					threadName = [@"OCSQLiteDB-" stringByAppendingString:_databaseURL.path];
				}
				else
				{
					threadName = [@"OCSQLiteDB-" stringByAppendingString:NSUUID.UUID.UUIDString];
				}
			}

			if (threadName != nil)
			{
				if (_runLoopThreadName != nil)
				{
					@synchronized([OCSQLiteDB class])
					{
						if (sOCSQliteDBSharedRunLoopThreadUsageCountByName==nil)
						{
							sOCSQliteDBSharedRunLoopThreadUsageCountByName = [NSMutableDictionary new];
						}

						sOCSQliteDBSharedRunLoopThreadUsageCountByName[_runLoopThreadName] = @(sOCSQliteDBSharedRunLoopThreadUsageCountByName[_runLoopThreadName].integerValue + 1);
					}
				}

				_sqliteThread = [OCRunLoopThread runLoopThreadNamed:threadName];
			 	runLoopThread = _sqliteThread;
			}
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
	NSTimeInterval elapsedTime = ([NSDate timeIntervalSinceReferenceDate] - dbObj->_firstBusyRetryTime);

	if (count == 0)
	{
		// Record start time
		dbObj->_firstBusyRetryTime = [NSDate timeIntervalSinceReferenceDate];

		return (1); // Retry
	}
	else
	{
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
			const char *filename = [[self->_databaseURL path] UTF8String];
			int sqErr;

			if (filename == NULL)
			{
				filename = ":memory:";
				OCLogDebug(@"OCSQLiteDB using in-memory database");
			}

			if ((sqErr = sqlite3_open_v2(filename, &self->_db, flags, NULL)) == SQLITE_OK)
			{
				// Set max busy retry time interval
				self.maxBusyRetryTimeInterval = self->_maxBusyRetryTimeInterval;

				// Journal mode
				if (self->_journalMode != nil)
				{
					if ((error = [self _executeSimpleSQLQuery:[@"PRAGMA journal_mode=" stringByAppendingString:self->_journalMode]]) != nil)
					{
						if ((error.code == SQLITE_ROW) || (error.code != SQLITE_OK))
						{
							error = nil;
						}

						if (error != nil)
						{
							OCLogDebug(@"Attempt to switch journal_mode to %@ resulted in error=%@", self->_journalMode, error);
							[self _close];
						}
					}
				}

				// Success
				if (error == nil)
				{
					self->_opened = YES;
				}
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
			OCLogDebug(@"Attempt to open OCSQLiteDB %@ more than once", self->_databaseURL);
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
	if (_db != NULL)
	{
		int sqErr = SQLITE_OK;

		[self releaseAllLiveStatementResources];

		do
		{
			sqErr = sqlite3_close(_db);
		}while((sqErr == SQLITE_BUSY) || (sqErr == SQLITE_LOCKED));

		if (sqErr != SQLITE_OK)
		{
			return (OCSQLiteError(sqErr));
		}
		else
		{
			_db = NULL;
			_opened = NO;
		}
	}

	return (nil);
}

#pragma mark - Table Schemas
- (void)addTableSchema:(OCSQLiteTableSchema *)schema
{
	if (schema==nil) { return; }

	if (_tableSchemas == nil) { _tableSchemas = [NSMutableArray new]; }

	[_tableSchemas addObject:schema];
}

- (void)applyTableSchemasWithCompletionHandler:(OCSQLiteDBCompletionHandler)completionHandler
{
	// Set up schema table
	[self executeQuery:[OCSQLiteQuery query:@"CREATE TABLE IF NOT EXISTS tableSchemas (schemaID integer PRIMARY KEY, tableName text NOT NULL UNIQUE, version integer)" withNamedParameters:nil resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
		if (error != nil)
		{
			OCLogDebug(@"Create table error: %@", error);
			if (completionHandler!=nil) { completionHandler(self, error); }
		}
		else
		{
			// Retrieve current versions
			[db executeQuery:[OCSQLiteQuery query:@"SELECT * FROM tableSchemas" withParameters:nil resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
				if (error != nil)
				{
					OCLogDebug(@"Retrieve current versions error: %@", error);
					if (completionHandler!=nil) { completionHandler(self, error); }
				}
				else
				{
					OCSQLiteMigration *migration = [OCSQLiteMigration new];
					NSMutableArray <NSString *> *allOpenStatements = [NSMutableArray new];
					NSMutableSet <NSString *> *allOpenStatementsTableNames = [NSMutableSet new];

					NSError *iterationError = nil;

					[resultSet iterateUsing:^(OCSQLiteResultSet *resultSet, NSUInteger line, NSDictionary<NSString *,id<NSObject>> *rowDictionary, BOOL *stop) {
						NSString *rowTableName = (NSString *)rowDictionary[@"tableName"];
						NSNumber *rowVersion = (NSNumber *)rowDictionary[@"version"];

						if ((rowTableName!=nil) && (rowVersion!=nil))
						{
							migration.versionsByTableName[rowTableName] = rowVersion;
						}
					} error:&iterationError];

					if (iterationError != nil)
					{
						OCLogDebug(@"Error iterating tableSchemas: %@", error);
						if (completionHandler!=nil) { completionHandler(self, error); }
					}
					else
					{
						// Sort schemas by table and version
						[self->_tableSchemas sortUsingDescriptors:@[
							[NSSortDescriptor sortDescriptorWithKey:@"tableName" ascending:YES],
							[NSSortDescriptor sortDescriptorWithKey:@"version"   ascending:YES],
						]];

						// Determine schemas
						for (OCSQLiteTableSchema *tableSchema in self->_tableSchemas)
						{
							NSNumber *currentVersion = nil;
							__block OCSQLiteTableSchema *_latestTableSchema = nil;

							OCSQLiteTableSchema *(^GetLatestTableSchemaForCurrent)(void) = ^{
								if (_latestTableSchema == nil)
								{
									for (OCSQLiteTableSchema *tableSchemaCandidate in self->_tableSchemas)
									{
										if ([tableSchemaCandidate.tableName isEqualToString:tableSchema.tableName])
										{
											if ((_latestTableSchema==nil) || (tableSchemaCandidate.version > _latestTableSchema.version))
											{
												_latestTableSchema = tableSchemaCandidate;
											}
										}
									}
								}

								return (_latestTableSchema);
							};

							// Collect all open statements from the latest table schemas
							if ((tableSchema.tableName!=nil) && ![allOpenStatementsTableNames containsObject:tableSchema.tableName])
							{
								NSArray <NSString *> *openStatements;
								OCSQLiteTableSchema *latestTableSchema;

								if ((latestTableSchema = GetLatestTableSchemaForCurrent()) != nil)
								{
									if (((openStatements = latestTableSchema.openStatements) != nil) && (openStatements.count > 0))
									{
										[allOpenStatements addObjectsFromArray:openStatements];
									}
								}

								[allOpenStatementsTableNames addObject:tableSchema.tableName];
							}

							if ((currentVersion = migration.versionsByTableName[tableSchema.tableName]) != nil)
							{
								// Apply all versions of a table schema that are newer than the current version
								if (tableSchema.version > currentVersion.unsignedIntegerValue)
								{
									[migration.applicableSchemas addObject:tableSchema];
								}
							}
							else
							{
								// For new table schemas, use the latest version right away
								OCSQLiteTableSchema *latestTableSchema;

								if ((latestTableSchema = GetLatestTableSchemaForCurrent()) != nil)
								{
									if ([migration.applicableSchemas indexOfObjectIdenticalTo:latestTableSchema] == NSNotFound)
									{
										[migration.applicableSchemas addObject:latestTableSchema];
									}
								}
							}
						}

						[migration applySchemasToDatabase:self completionHandler:completionHandler];
					}
				}
			}]];
		}
	}]];
}


#pragma mark - Queries (public)
- (void)executeQuery:(OCSQLiteQuery *)query
{
	if ([self isOnSQLiteThread])
	{
		[self _executeQuery:query inTransaction:nil];
	}
	else
	{
		[self queueBlock:^{
			[self _executeQuery:query inTransaction:nil];
		}];
	}
}

- (void)executeTransaction:(OCSQLiteTransaction *)transaction
{
	if ([self isOnSQLiteThread])
	{
		[self _executeTransaction:transaction];
	}
	else
	{
		[self queueBlock:^{
			[self _executeTransaction:transaction];
		}];
	}
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

- (void)executeOperation:(NSError *(^)(OCSQLiteDB *db))operationBlock completionHandler:(OCSQLiteDBCompletionHandler)completionHandler
{
	[self queueBlock:^{
		NSError *error = operationBlock(self);

		if (completionHandler!=nil)
		{
			completionHandler(self,error);
		}
	}];
}

- (nullable NSError *)executeOperationSync:(NSError * _Nullable(^)(OCSQLiteDB *db))operationBlock
{
	__block NSError *error = nil;

	if ([self isOnSQLiteThread])
	{
		// On SQLite thread: execute right away
		error = operationBlock(self);
	}
	else
	{
		// Not on SQLite thread: wait for operatoin to complete
		OCSyncExec(waitForOperation, {
			[self queueBlock:^{
				error = operationBlock(self);
				OCSyncExecDone(waitForOperation);
			}];
		});
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
	NSString *savePointName = nil;

	// Increase transaction nesting level
	_transactionNestingLevel++;

	// Begin transaction
	if (_transactionNestingLevel == 1)
	{
		// Transaction at root level
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
	}
	else
	{
		// Nested transaction, use save points instead
		savePointName = [NSString stringWithFormat:@"sp%lu", _savepointCounter];
		_savepointCounter++;

		error = [self _executeSimpleSQLQuery:[@"SAVEPOINT " stringByAppendingString:savePointName]];
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

			if (savePointName == nil)
			{
				// Transaction at root level
				commitError = [self _executeSimpleSQLQuery:@"COMMIT TRANSACTION"];
			}
			else
			{
				// Nested transaction, use save points instead
				commitError = [self _executeSimpleSQLQuery:[@"RELEASE " stringByAppendingString:savePointName]];
			}

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

		if (savePointName == nil)
		{
			// Transaction at root level
			rollbackError = [self _executeSimpleSQLQuery:@"ROLLBACK TRANSACTION"];
		}
		else
		{
			// Nested transaction, use save points instead
			rollbackError = [self _executeSimpleSQLQuery:[@"ROLLBACK TO " stringByAppendingString:savePointName]];
		}

		if (error == nil)
		{
			error = rollbackError;
		}
	}

	// Decrease transaction nesting level
	_transactionNestingLevel--;

	if (transaction.completionHandler != nil)
	{
		if (IsSQLiteErrorCode(error, SQLITE_DONE))
		{
			error = nil;
		}

		transaction.completionHandler(self, transaction, error);
	}
}

#pragma mark - Debug tools
- (void)executeQueryString:(NSString *)queryString //!< Runs a query and logs the result. Meant to simplify debugging.
{
	[self executeQuery:[OCSQLiteQuery query:queryString resultHandler:^(OCSQLiteDB * _Nonnull db, NSError * _Nullable error, OCSQLiteTransaction * _Nullable transaction, OCSQLiteResultSet * _Nullable resultSet) {
		OCLogDebug(@"Result for '%@':", queryString);
		[resultSet iterateUsing:^(OCSQLiteResultSet * _Nonnull resultSet, NSUInteger line, OCSQLiteRowDictionary  _Nonnull rowDictionary, BOOL * _Nonnull stop) {
			OCLogDebug(@"%lu | %@", (unsigned long)line, rowDictionary);
		} error:NULL];
	}]];
}

#pragma mark - Error handling
- (NSError *)lastError
{
	return (OCSQLiteLastDBError(_db));
}

#pragma mark - Insertion Row ID
- (NSNumber *)lastInsertRowID
{
	if ([self isOnSQLiteThread])
	{
		// May only be used within query and transaction completionHandlers.
		if (_db != NULL)
		{
			sqlite_int64 lastInsertRowID;

			lastInsertRowID = sqlite3_last_insert_rowid(_db);

			if (lastInsertRowID > 0)
			{
				return (@(lastInsertRowID));
			}
		}
	}

	// Will return nil otherwise.
	return (nil);
}

#pragma mark - Miscellaneous
- (void)shrinkMemory
{
	if ([self isOnSQLiteThread])
	{
		sqlite3_db_release_memory(_db);
	}
	else
	{
		[self queueBlock:^{
			sqlite3_db_release_memory(self->_db);
		}];
	}
}

+ (int64_t)setMemoryLimit:(int64_t)memoryLimit
{
	int64_t previousMemoryLimit = sqlite3_soft_heap_limit64(memoryLimit);

	OCLogDebug(@"Changed memory limit from %lld to %lld bytes", previousMemoryLimit, memoryLimit);

	return (previousMemoryLimit);
}

#pragma mark - Log tags
+ (NSArray<OCLogTagName> *)logTags
{
	return (@[@"SQL"]);
}

- (NSArray<OCLogTagName> *)logTags
{
	return (@[@"SQL"]);
}

@end

NSErrorDomain OCSQLiteErrorDomain = @"SQLite";
NSErrorDomain OCSQLiteDBErrorDomain = @"OCSQLiteDB";

OCSQLiteJournalMode OCSQLiteJournalModeDelete = @"delete";
OCSQLiteJournalMode OCSQLiteJournalModeWAL = @"wal";
