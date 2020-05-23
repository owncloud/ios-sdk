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
#import "OCHTTPTypes.h"
#import "OCHTTPCookieStorage.h"
#import "OCProgress.h"
#import "OCCertificate.h"
#import "OCClassSettings.h"
#import "OCLogTag.h"

@class OCHTTPPipeline;

typedef NS_ENUM(NSInteger, OCHTTPPipelineState)
{
	OCHTTPPipelineStateStopped,
	OCHTTPPipelineStateStarting,
	OCHTTPPipelineStateStarted,
	OCHTTPPipelineStateStopping
};

NS_ASSUME_NONNULL_BEGIN

@protocol OCHTTPPipelinePartitionHandler <NSObject>

@property(strong,readonly) OCHTTPPipelinePartitionID partitionID; //!< The ID of the partition

#pragma mark - Requirements
- (BOOL)pipeline:(OCHTTPPipeline *)pipeline meetsSignalRequirements:(NSSet<OCConnectionSignalID> *)requiredSignals failWithError:(NSError **)outError;

#pragma mark - Scheduling
- (OCHTTPRequest *)pipeline:(OCHTTPPipeline *)pipeline prepareRequestForScheduling:(OCHTTPRequest *)request;

- (nullable NSError *)pipeline:(OCHTTPPipeline *)pipeline postProcessFinishedTask:(OCHTTPPipelineTask *)task error:(nullable NSError *)error;
- (OCHTTPRequestInstruction)pipeline:(OCHTTPPipeline *)pipeline instructionForFinishedTask:(OCHTTPPipelineTask *)task error:(nullable NSError *)error;

#pragma mark - Security policy (improved, allowing for scheduling requests without attached pipelineHandler)
/*
// OCHTTPPolicy should allow these things
// - access request before scheduling (to add credentials)
// - access request after certificate is known (to validate, apply custom policies)
// - handle response and provide an instruction (to re-queue requests with failed validation or network errors)
// - be fully serializable (for persistance in pipeline backend)

- (NSArray<OCHTTPPolicy *> *)policiesForPipeline:(OCHTTPPipeline *)pipeline; //!< Array of policies that need to be fulfilled to let a request be sent. Called automatically at every attach. Call -[OCPipeline policiesChangedForPartition:] while attached to ask OCHTTPPipeline to call this.

- (void)pipeline:(OCHTTPPipeline *)pipeline handlePolicy:(OCHTTPPolicy *)policy error:(NSError *)error; //!< Called whenever there is an error validating a security policy. Provides enough info to create an issue and the proceed handler allows reacting to it (f.ex. via error userinfo provide OCCertificate *certificate, BOOL userAcceptanceRequired, OCConnectionCertificateProceedHandler proceedHandler).
*/

#pragma mark - Certificate validation
- (void)pipeline:(OCHTTPPipeline *)pipeline handleValidationOfRequest:(OCHTTPRequest *)request certificate:(OCCertificate *)certificate validationResult:(OCCertificateValidationResult)validationResult validationError:(NSError *)validationError proceedHandler:(OCConnectionCertificateProceedHandler)proceedHandler;

#pragma mark - Mocking
@optional
- (BOOL)pipeline:(OCHTTPPipeline *)pipeline partitionID:(OCHTTPPipelinePartitionID)partitionID simulateRequestHandling:(OCHTTPRequest *)request completionHandler:(void(^)(OCHTTPResponse *response))completionHandler; //!< Return YES if the pipeline should handle the request. NO if the pipelineHandler will take care of it and return the response via the completionHandler.

#pragma mark - Cookie storage
@property(strong,nullable,nonatomic,readonly) OCHTTPCookieStorage *partitionCookieStorage; //!< If provided, used to store and retrieve cookies for the partition

#pragma mark - Pipeline events
- (void)pipelineWillStop:(OCHTTPPipeline *)pipeline; //!< Called when the pipeline is about to be stopped
- (void)pipelineDidStop:(OCHTTPPipeline *)pipeline; //!< Called when the pipeline has stopped
- (void)pipelineInvalidated:(OCHTTPPipeline *)pipeline; //!< Called when the pipeline is about to become invalid (and you should release any reference)

@end

@interface OCHTTPPipeline : NSObject <OCProgressResolver, OCClassSettingsSupport, OCLogTagging, NSURLSessionDelegate, NSURLSessionTaskDelegate, NSURLSessionDataDelegate, NSURLSessionDownloadDelegate>
{
	// URL Session handling
	NSURLSession *_urlSession;
	BOOL _urlSessionInvalidated;
	BOOL _alwaysUseDownloadTasks;

	// Settings
	BOOL _insertXRequestID;

	// Scheduling
	NSMapTable<OCHTTPPipelinePartitionID, id<OCHTTPPipelinePartitionHandler>> *_partitionHandlersByID;

	NSMutableArray<OCHTTPRequestGroupID> *_recentlyScheduledGroupIDs;

	BOOL _needsScheduling;

	// Delivery
	BOOL _needsDelivery;

	// Certificate caching
	NSMutableDictionary <NSString *, OCCertificate *> *_cachedCertificatesByHostnameAndPort;
	NSMutableSet <OCHTTPPipelineTaskID> *_taskIDsInDelivery;

	// Logging
	NSArray<OCLogTagName> *_cachedLogTags;
}

@property(nullable,strong,readonly,class) NSString *userAgent; //!< Custom User-Agent to use (if any)

@property(strong,readonly) OCHTTPPipelineID identifier;
@property(strong,readonly) NSString *bundleIdentifier;

@property(readonly) OCHTTPPipelineState state;

@property(readonly,nonatomic) BOOL backgroundSessionBacked; //!< YES if this pipeline is backed by a background NSURLSession

@property(strong,readonly) OCHTTPPipelineBackend *backend;

@property(assign) NSUInteger maximumConcurrentRequests; //!< The maximum number of concurrently running requests. A value of 0 means no limit.

@property(strong,nullable,readonly) NSString *urlSessionIdentifier;

#pragma mark - Lifecycle
- (instancetype)initWithIdentifier:(OCHTTPPipelineID)identifier backend:(nullable OCHTTPPipelineBackend *)backend configuration:(NSURLSessionConfiguration *)sessionConfiguration;

- (void)startWithCompletionHandler:(OCCompletionHandler)completionHandler;
- (void)stopWithCompletionHandler:(OCCompletionHandler)completionHandler graceful:(BOOL)graceful;

#pragma mark - Request handling
- (void)enqueueRequest:(OCHTTPRequest *)request forPartitionID:(OCHTTPPipelinePartitionID)partitionID; //!< Enqueues a non-final request
- (void)enqueueRequest:(OCHTTPRequest *)request forPartitionID:(OCHTTPPipelinePartitionID)partitionID isFinal:(BOOL)isFinal; //!< Enqueues a request
- (void)cancelRequest:(nullable OCHTTPRequest *)request; //!< Cancels a request
- (void)cancelRequestsForPartitionID:(OCHTTPPipelinePartitionID)partitionID queuedOnly:(BOOL)queuedOnly; //!< Cancels all requests for a partitionID (or only those in the queue if queuedOnly is YES)
- (void)cancelNonCriticalRequestsForPartitionID:(nullable OCHTTPPipelinePartitionID)partitionID; //!< Cancels all non critical requests. If a partitionID is provided, cancels only non-critical requests for that partition.
- (void)finishPendingRequestsForPartitionID:(OCHTTPPipelinePartitionID)partitionID withError:(NSError *)error filter:(BOOL(^)(OCHTTPPipeline *pipeline, OCHTTPPipelineTask *task))filter;

#pragma mark - Scheduling
- (void)setPipelineNeedsScheduling;

#pragma mark - Attach & detach partition handlers
- (void)attachPartitionHandler:(id<OCHTTPPipelinePartitionHandler>)partitionHandler completionHandler:(nullable OCCompletionHandler)completionHandler;  //!< Attaches a partition handler to the pipeline. The partition handler will receive any outstanding responses.

- (void)detachPartitionHandler:(id<OCHTTPPipelinePartitionHandler>)partitionHandler completionHandler:(nullable OCCompletionHandler)completionHandler;	//!< Detaches a partition handler from the pipeline. The pipeline guarantees that - once the completionHandler was called - no delegate calls will be performed anymore.
- (void)detachPartitionHandlerForPartitionID:(OCHTTPPipelinePartitionID)partitionID completionHandler:(nullable OCCompletionHandler)completionHandler;	//!< Convenience method to detach a partition handler by its partitionID.

- (nullable id<OCHTTPPipelinePartitionHandler>)partitionHandlerForPartitionID:(nullable OCHTTPPipelinePartitionID)partitionID; //!< Returns the partitionHandler for the provided partitionID

- (NSUInteger)tasksPendingDeliveryForPartitionID:(OCHTTPPipelinePartitionID)partitionID; //!< Returns the number of tasks pending delivery for the provided partitionID

#pragma mark - Cerificate checks
- (void)evaluateCertificate:(OCCertificate *)certificate forTask:(OCHTTPPipelineTask *)task proceedHandler:(OCConnectionCertificateProceedHandler)proceedHandler;

#pragma mark - Background URL session finishing
- (void)attachBackgroundURLSessionWithConfiguration:(NSURLSessionConfiguration *)backgroundSessionConfiguration handlingCompletionHandler:(dispatch_block_t)handlingCompletionHandler;

#pragma mark - Remove partition
- (void)destroyPartition:(OCHTTPPipelinePartitionID)partitionID completionHandler:(nullable OCCompletionHandler)completionHandler; //!< Attempts to stop all running requests for the partition, remove associated records from the database and remove data stored on disk for requests belonging to the partition. Requests queued for a partition are no longer scheduled after its destruction has been requested. In general, a partitionID should no longer be used once this call was made.

#pragma mark - Progress
- (nullable NSProgress *)progressForRequestID:(OCHTTPRequestID)requestID;

#pragma mark - Metrics
- (nullable NSNumber *)estimatedTimeForRequest:(OCHTTPRequest *)request withExpectedResponseLength:(NSUInteger)expectedResponseLength confidence:(double * _Nullable)outConfidence;//!< If a sufficient amount of metrics could be collected, returns the estimated number of seconds it'll take the request to be sent and a response of expectedResponseLength be received.

#pragma mark - Internal job queue
- (void)queueBlock:(dispatch_block_t)block withBusy:(BOOL)withBusy; //!< Add a block for execution on the internal job queue.

@end

extern OCClassSettingsIdentifier OCClassSettingsIdentifierHTTP;
extern OCClassSettingsKey OCHTTPPipelineSettingUserAgent;

NS_ASSUME_NONNULL_END
