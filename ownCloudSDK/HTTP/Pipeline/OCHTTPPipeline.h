//
//  OCHTTPPipeline.h
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
#import "OCHTTPPipelineBackend.h"
#import "OCConnection.h"
#import "OCHostSimulator.h"
#import "OCProgress.h"

@class OCHTTPPipeline;

typedef NSString* OCHTTPPipelineID;
typedef NSString* OCHTTPPipelinePartitionID;

NS_ASSUME_NONNULL_BEGIN

@protocol OCHTTPPipelinePartitionHandler <NSObject>

@property(strong,readonly) OCHTTPPipelinePartitionID partitionID; //!< The ID of the partition
@property(nullable,strong,readonly) OCCertificate *certificate; //!< The certificate used by the partition.

#pragma mark - Requirements
- (void)pipeline:(OCHTTPPipeline *)pipeline meetsSignalRequirements:(NSSet<OCConnectionSignalID> *)requiredSignals;
- (BOOL)pipeline:(OCHTTPPipeline *)pipeline canProvideAuthenticationForRequests:(void(^)(NSError *error, BOOL authenticationIsAvailable))availabilityHandler;

#pragma mark - Scheduling
- (OCHTTPRequest *)pipeline:(OCHTTPPipeline *)pipeline prepareRequestForScheduling:(OCHTTPRequest *)request;

- (nullable id<OCConnectionHostSimulator>)pipeline:(OCHTTPPipeline *)pipeline hostSimulatorForRequest:(OCHTTPRequest *)request;

- (nullable NSError *)pipeline:(OCHTTPPipeline *)pipeline postProcessFinishedRequest:(OCHTTPRequest *)request error:(nullable NSError *)error;
- (OCHTTPRequestInstruction)pipeline:(OCHTTPPipeline *)pipeline instructionForFinishedRequest:(OCHTTPRequest *)finishedRequest error:(nullable NSError *)error;

#pragma mark - Certificate validation
- (void)pipeline:(OCHTTPPipeline *)pipeline handleValidationOfRequest:(OCHTTPRequest *)request certificate:(OCCertificate *)certificate validationResult:(OCCertificateValidationResult)validationResult validationError:(NSError *)validationError proceedHandler:(OCConnectionCertificateProceedHandler)proceedHandler;

@end

@interface OCHTTPPipeline : NSObject <NSURLSessionDelegate, NSURLSessionTaskDelegate, NSURLSessionDataDelegate, NSURLSessionDownloadDelegate>
{
	NSURLSession *_urlSession;

	NSMutableDictionary<NSString*, NSURLSession*> *_attachedURLSessionsByIdentifier;

	OCHTTPPipelineBackend *_backend;

	NSMutableDictionary<OCHTTPPipelinePartitionID, id<OCHTTPPipelinePartitionHandler>> *_partitionHandlersByID;
	NSMutableArray<OCHTTPPipelinePartitionID> *_attachedParititionHandlerIDs;

	NSMutableArray<OCHTTPRequestGroupID> *_recentlyScheduledGroupIDs;

	BOOL _needsScheduling;
}

@property(strong,readonly) OCHTTPPipelineID identifier;
@property(strong,readonly) NSString *bundleIdentifier;

@property(assign) NSUInteger maximumConcurrentRequests; //!< The maximum number of concurrently running requests. A value of 0 means no limit.

@property(strong,nullable,readonly) NSString *urlSessionIdentifier;

#pragma mark - Init
- (instancetype)initWithIdentifier:(OCHTTPPipelineID)identifier backend:(nullable OCHTTPPipelineBackend *)backend configuration:(NSURLSessionConfiguration *)sessionConfiguration;

#pragma mark - Request handling
- (void)enqueueRequest:(OCHTTPRequest *)request forPartitionID:(OCHTTPPipelinePartitionID)partitionID; //!< Enqueues a request
- (void)cancelRequest:(OCHTTPRequest *)request; //!< Cancels a request
- (void)cancelRequestsForPartitionID:(OCHTTPPipelinePartitionID)partitionID queuedOnly:(BOOL)queuedOnly; //!< Cancels all requests for a partitionID (or only those in the queue if queuedOnly is YES)

#pragma mark - Attach & detach partition handlers
- (void)attachPartitionHandler:(id<OCHTTPPipelinePartitionHandler>)partitionHandler completionHandler:(nullable OCCompletionHandler)completionHandler;  //!< Attaches a partition handler to the pipeline. The partition handler will receive any outstanding responses.

- (void)detachPartitionHandler:(id<OCHTTPPipelinePartitionHandler>)partitionHandler completionHandler:(nullable OCCompletionHandler)completionHandler;	//!< Detaches a partition handler from the pipeline. The pipeline guarantees that - once the completionHandler was called - no delegate calls will be performed anymore.
- (void)detachPartitionHandlerForPartitionID:(OCHTTPPipelinePartitionID)partitionID completionHandler:(nullable OCCompletionHandler)completionHandler;	//!< Convenience method to detach a partition handler by its partitionID.

#pragma mark - Shutdown
- (void)finishTasksAndInvalidateWithCompletionHandler:(dispatch_block_t)completionHandler;
- (void)invalidateAndCancelWithCompletionHandler:(dispatch_block_t)completionHandler;

- (void)cancelNonCriticalRequests; //!< Cancels .isNonCritical requests

@end

NS_ASSUME_NONNULL_END
