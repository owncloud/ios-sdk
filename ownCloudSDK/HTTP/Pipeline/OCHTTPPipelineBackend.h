//
//  OCHTTPPipelineBackend.h
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

#import <Foundation/Foundation.h>
#import "OCBookmark.h"
#import "OCSQLiteDB.h"
#import "OCHTTPTypes.h"

@class OCHTTPPipeline;
@class OCHTTPPipelineTask;
@class OCHTTPPipelineTaskCache;

NS_ASSUME_NONNULL_BEGIN

@interface OCHTTPPipelineBackend : NSObject
{
	OCSQLiteDB *_sqlDB;
	NSUInteger _openCount;

	OCCompletionHandler _openCompletionHandler;

	OCHTTPPipelineTaskCache *_taskCache;
}

@property(strong,readonly) NSString *bundleIdentifier;
@property(strong,nonatomic) NSURL *temporaryFilesRoot;

@property(readonly,nonatomic) BOOL isOnQueueThread;

- (instancetype)initWithSQLDB:(nullable OCSQLiteDB *)sqlDB temporaryFilesRoot:(nullable NSURL *)temporaryFilesRoot;

#pragma mark - Open & Close
- (void)openWithCompletionHandler:(OCCompletionHandler)completionHandler;
- (void)closeWithCompletionHandler:(OCCompletionHandler)completionHandler;

#pragma mark - Task access
- (NSError *)addPipelineTask:(OCHTTPPipelineTask *)task;
- (NSError *)updatePipelineTask:(OCHTTPPipelineTask *)task;
- (NSError *)removePipelineTask:(OCHTTPPipelineTask *)task;

- (NSError *)removeAllTasksForPipeline:(OCHTTPPipelineID)pipelineID partition:(OCHTTPPipelinePartitionID)partitionID;

- (OCHTTPPipelineTask *)retrieveTaskForRequestID:(OCHTTPRequestID)requestID error:(NSError * _Nullable *)outDBError;
- (OCHTTPPipelineTask *)retrieveTaskForPipeline:(OCHTTPPipeline *)pipeline URLSession:(NSURLSession *)urlSession task:(NSURLSessionTask *)urlSessionTask error:(NSError * _Nullable *)outDBError;

- (NSError *)enumerateTasksForPipeline:(OCHTTPPipeline *)pipeline enumerator:(void (^)(OCHTTPPipelineTask * _Nonnull, BOOL * _Nonnull))taskEnumerator;
- (NSError *)enumerateTasksForPipeline:(OCHTTPPipeline *)pipeline partition:(OCHTTPPipelinePartitionID)partitionID enumerator:(void (^)(OCHTTPPipelineTask * _Nonnull, BOOL * _Nonnull))taskEnumerator;
- (NSError *)enumerateCompletedTasksForPipeline:(OCHTTPPipeline *)pipeline partition:(OCHTTPPipelinePartitionID)partitionID enumerator:(void (^)(OCHTTPPipelineTask * _Nonnull, BOOL * _Nonnull))taskEnumerator;

- (NSError *)enumerateTasksWhere:(nullable NSDictionary<NSString *,id<NSObject>> *)whereConditions orderBy:(nullable NSString *)orderBy limit:(nullable NSString *)limit enumerator:(void (^)(OCHTTPPipelineTask * _Nonnull, BOOL * _Nonnull))taskEnumerator;

- (NSNumber *)numberOfRequestsWithState:(OCHTTPPipelineTaskState)state inPipeline:(OCHTTPPipeline *)pipeline partition:(nullable OCHTTPPipelinePartitionID)partitionID error:(NSError * _Nullable *)outDBError;
- (NSNumber *)numberOfRequestsInPipeline:(OCHTTPPipeline *)pipeline partition:(OCHTTPPipelinePartitionID)partitionID error:(NSError * _Nullable *)outDBError;

#pragma mark - Debugging
- (void)dumpDBTable;

#pragma mark - Execution on DB thread
- (void)queueBlock:(dispatch_block_t)block;

@end

NS_ASSUME_NONNULL_END
