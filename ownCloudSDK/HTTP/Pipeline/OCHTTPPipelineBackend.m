//
//  OCHTTPPipelineBackend.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 04.02.19.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2019, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCHTTPPipelineBackend.h"
#import "OCSQLiteDB.h"
#import "OCSQLiteTableSchema.h"
#import "OCHTTPPipelineTask.h"

static NSString *OCHTTPPipelineTasksTableName = @"httpPipelineTasks";

@implementation OCHTTPPipelineBackend

#pragma mark - Init & dealloc
- (instancetype)init
{
	return ([self initWithSQLDB:nil]);
}

- (instancetype)initWithSQLDB:(OCSQLiteDB *)sqlDB
{
	if ((self = [super init]) != nil)
	{
		if (sqlDB != nil)
		{
			_sqlDB = sqlDB;
		}
		else
		{
			_sqlDB = [[OCSQLiteDB alloc] initWithURL:nil];
		}
	}

	[self addSchemas];

	return (self);
}

- (void)dealloc
{

}

#pragma mark - Open & Close
- (void)openWithCompletionHandler:(OCCompletionHandler)completionHandler
{
	if (_sqlDB != nil)
	{
		[_sqlDB openWithFlags:OCSQLiteOpenFlagsDefault completionHandler:^(OCSQLiteDB * _Nonnull db, NSError * _Nullable error) {
			if (error == nil)
			{
				[self->_sqlDB applyTableSchemasWithCompletionHandler:^(OCSQLiteDB *db, NSError *error) {
					if (completionHandler!=nil)
					{
						completionHandler(self, error);
					}
				}];
			}
			else
			{
				completionHandler(self, error);
			}
		}];
	}
}

- (void)closeWithCompletionHandler:(OCCompletionHandler)completionHandler
{
	if (_sqlDB != nil)
	{
		[_sqlDB closeWithCompletionHandler:^(OCSQLiteDB * _Nonnull db, NSError * _Nullable error) {
			completionHandler(self, error);
		}];
	}
}

#pragma mark - Schemas
- (void)addSchemas
{
	// Version 1
	[_sqlDB addTableSchema:[OCSQLiteTableSchema
		schemaWithTableName:OCHTTPPipelineTasksTableName
		version:1
		creationQueries:@[
			/*
				taskID : INTEGER		- unique ID used to uniquely identify and efficiently update a row

				pipelineID : TEXT		- ID of the pipeline
				bundleID : TEXT			- bundle identifier of the process from which the record originated

				urlSessionID : TEXT		- ID of the pipeline's URL session
				urlSessionTaskID : INTEGER	- the NSURLSessionTask.taskIdentifier of this request

				partitionID : TEXT		- ID of the partition for which this request was scheduled
				groupID : TEXT			- group ID this request belongs to

				state : INTEGER			- status of request: pending, inProcess, completed

				requestID : TEXT		- the OCHTTPRequestID of this request

				requestData : BLOB		- data of serialized OCHTTPRequest
				requestFinal : INTEGER 		- Boolean indicating whether the request is final, i.e. can be sent "as-is" (without going through the delegate)

				responseData : BLOB		- data of serialized OCHTTPResponse
			*/
			@"CREATE TABLE httpPipelineTasks (taskID INTEGER PRIMARY KEY AUTOINCREMENT, pipelineID TEXT NOT NULL, bundleID TEXT NOT NULL, urlSessionID TEXT, urlSessionTaskID INTEGER, partitionID TEXT NOT NULL, groupID TEXT, state INTEGER NOT NULL, requestID TEXT NOT NULL, requestData BLOB NOT NULL, requestFinal INTEGER NOT NULL, responseData BLOB",

			// Create indexes over urlSessionID, taskID, jobID
//			@"CREATE INDEX idx_httpRequests_urlSessionID ON httpRequests (urlSessionID)",
//			@"CREATE INDEX idx_httpRequests_urlSessionTaskID ON httpRequests (urlSessionTaskID)"
		]
		openStatements:nil
		upgradeMigrator:nil]
	];
}

#pragma mark - Task access
- (NSError *)addPipelineTask:(OCHTTPPipelineTask *)task
{
	return([_sqlDB executeOperationSync:^NSError * _Nullable(OCSQLiteDB * _Nonnull db) {
		__block NSError *insertionError = nil;

		[db executeQuery:[OCSQLiteQuery queryInsertingIntoTable:OCHTTPPipelineTasksTableName rowValues:@{
			@"pipelineID" 		: task.pipelineID,
			@"bundleID"		: task.bundleID,

			@"urlSessionID"		: OCSQLiteNullProtect(task.urlSessionID),

			@"partitionID"		: task.partitionID,
			@"groupID"		: OCSQLiteNullProtect(task.groupID),

			@"state"		: @(task.state),

			@"requestID"		: task.requestID,
			@"requestData"		: task.requestData,

			@"requestFinal"		: @(task.requestFinal)
		} resultHandler:^(OCSQLiteDB * _Nonnull db, NSError * _Nullable error, NSNumber * _Nullable rowID) {
			task.taskID = rowID;

			insertionError = error;
		}]];

		return (insertionError);
	}]);
}

- (NSError *)updatePipelineTask:(OCHTTPPipelineTask *)task
{
	if (task.taskID == nil)
	{
		OCLogError(@"Attempt to update task %@ without taskID.", task);
		return (OCError(OCErrorInsufficientParameters));
	}

	return([_sqlDB executeOperationSync:^NSError * _Nullable(OCSQLiteDB * _Nonnull db) {
		__block NSError *updateError = nil;

		[db executeQuery:[OCSQLiteQuery queryUpdatingRowWithID:task.taskID inTable:OCHTTPPipelineTasksTableName withRowValues:@{
			@"bundleID" 		: task.bundleID,

			@"urlSessionID" 	: OCSQLiteNullProtect(task.urlSessionID),
			@"urlSessionTaskID"	: OCSQLiteNullProtect(task.urlSessionTaskID),

			@"state"		: @(task.state),

			@"requestData"		: task.requestData,

			@"responseData"		: OCSQLiteNullProtect(task.responseData),
		} completionHandler:^(OCSQLiteDB * _Nonnull db, NSError * _Nullable error) {
			updateError = error;
		}]];

		return (updateError);
	}]);
}

- (NSError *)removePipelineTask:(OCHTTPPipelineTask *)task
{
	if (task.taskID == nil)
	{
		OCLogError(@"Attempt to remove task %@ without taskID.", task);
		return (OCError(OCErrorInsufficientParameters));
	}

	return([_sqlDB executeOperationSync:^NSError * _Nullable(OCSQLiteDB * _Nonnull db) {
		__block NSError *removeError = nil;

		[db executeQuery:[OCSQLiteQuery queryDeletingRowWithID:task.taskID fromTable:OCHTTPPipelineTasksTableName completionHandler:^(OCSQLiteDB * _Nonnull db, NSError * _Nullable error) {
			removeError = error;
		}]];

		return (removeError);
	}]);
}

- (OCHTTPPipelineTask *)_retrieveTaskWhere:(nullable NSDictionary<NSString *,id<NSObject>> *)whereConditions error:(NSError **)outDBError
{
	NSError *dbError = nil;
	__block OCHTTPPipelineTask *task = nil;

	dbError = [_sqlDB executeOperationSync:^NSError * _Nullable(OCSQLiteDB * _Nonnull db) {
		__block NSError *retrieveError = nil;

		[db executeQuery:[OCSQLiteQuery querySelectingColumns:nil fromTable:OCHTTPPipelineTasksTableName where:whereConditions resultHandler:^(OCSQLiteDB * _Nonnull db, NSError * _Nullable error, OCSQLiteTransaction * _Nullable transaction, OCSQLiteResultSet * _Nullable resultSet) {
			retrieveError = error;

			if (error == nil)
			{
				OCSQLiteRowDictionary rowDictionary;

				if ((rowDictionary = [resultSet nextRowDictionaryWithError:&retrieveError]) != nil)
				{
					task = [[OCHTTPPipelineTask alloc] initWithRowDictionary:rowDictionary];
				}
			}
		}]];

		return (retrieveError);
	}];

	if (outDBError != NULL)
	{
		*outDBError = dbError;
	}

	return (task);
}

- (OCHTTPPipelineTask *)retrieveTaskForID:(OCHTTPPipelineTaskID)taskID error:(NSError **)outDBError
{
	if (taskID == nil)
	{
		OCLogError(@"Attempt to retrieve task without taskID.");
		return (nil);
	}

	return ([self _retrieveTaskWhere:@{
			@"taskID" : taskID
		} error:outDBError]);
}

- (OCHTTPPipelineTask *)retrieveTaskForPipeline:(OCHTTPPipeline *)pipeline URLSession:(NSURLSession *)urlSession task:(NSURLSessionTask *)urlSessionTask error:(NSError **)outDBError
{
	NSString *urlSessionIdentifier = urlSession.configuration.identifier;

	return ([self _retrieveTaskWhere:@{
			@"pipelineID"	  	: pipeline.identifier,
			@"bundleID"	  	: [OCSQLiteQueryCondition queryConditionWithOperator:@"=" value:pipeline.bundleIdentifier apply:(urlSessionIdentifier==nil)],
			@"urlSessionID"	  	: OCSQLiteNullProtect(urlSessionIdentifier),
			@"urlSessionTaskID" 	: @(urlSessionTask.taskIdentifier)
		} error:outDBError]);
}

- (NSError *)enumerateTasksForPipeline:(OCHTTPPipeline *)pipeline enumerator:(void (^)(OCHTTPPipelineTask * _Nonnull, BOOL * _Nonnull))taskEnumerator
{
	return ([self enumerateTasksWhere:@{
			@"pipelineID" : pipeline.identifier,
		} orderBy:@"taskID" limit:nil enumerator:taskEnumerator]);
}

- (NSError *)enumerateTasksWhere:(nullable NSDictionary<NSString *,id<NSObject>> *)whereConditions orderBy:(nullable NSString *)orderBy limit:(nullable NSString *)limit enumerator:(void (^)(OCHTTPPipelineTask * _Nonnull, BOOL * _Nonnull))taskEnumerator
{
	NSError *dbError = nil;

	dbError = [_sqlDB executeOperationSync:^NSError * _Nullable(OCSQLiteDB * _Nonnull db) {
		__block NSError *retrieveError = nil;

		[db executeQuery:[OCSQLiteQuery querySelectingColumns:nil
						fromTable:OCHTTPPipelineTasksTableName
						where:whereConditions
						orderBy:orderBy
						limit:limit
						resultHandler:^(OCSQLiteDB * _Nonnull db, NSError * _Nullable error, OCSQLiteTransaction * _Nullable transaction, OCSQLiteResultSet * _Nullable resultSet)
		{
			retrieveError = error;

			if (error == nil)
			{
				[resultSet iterateUsing:^(OCSQLiteResultSet * _Nonnull resultSet, NSUInteger line, NSDictionary<NSString *,id<NSObject>> * _Nonnull rowDictionary, BOOL * _Nonnull stop) {
					OCHTTPPipelineTask *task;

					if ((task = [[OCHTTPPipelineTask alloc] initWithRowDictionary:rowDictionary]) != nil)
					{
						taskEnumerator(task, stop);
					}
				} error:&retrieveError];
			}
		}]];

		return (retrieveError);
	}];

	return (dbError);
}

- (NSNumber *)numberOfRequestsWithState:(OCHTTPPipelineTaskState)state inPipeline:(OCHTTPPipeline *)pipeline error:(NSError **)outDBError
{
	NSError *dbError = nil;
	__block NSNumber *numberOfRequestsWithState = nil;

	dbError = [_sqlDB executeOperationSync:^NSError * _Nullable(OCSQLiteDB * _Nonnull db) {
		__block NSError *retrieveError = nil;

		[db executeQuery:[OCSQLiteQuery query:@"SELECT COUNT(*) AS cnt FROM httpPipelineTasks WHERE pipeline=:pipelineID AND state=:state" withNamedParameters:@{
			@"pipelineID" : pipeline.identifier,
			@"state" : @(state)
		} resultHandler:^(OCSQLiteDB * _Nonnull db, NSError * _Nullable error, OCSQLiteTransaction * _Nullable transaction, OCSQLiteResultSet * _Nullable resultSet) {
			numberOfRequestsWithState = [resultSet nextRowDictionaryWithError:&retrieveError][@"cnt"];
		}]];

		return (retrieveError);
	}];

	if (outDBError != NULL)
	{
		*outDBError = dbError;
	}

	return (numberOfRequestsWithState);
}

- (void)queueBlock:(dispatch_block_t)block
{
	[_sqlDB executeOperation:^NSError * _Nullable(OCSQLiteDB * _Nonnull db) {
		block();
		return(nil);
	} completionHandler:nil];
}

@end
