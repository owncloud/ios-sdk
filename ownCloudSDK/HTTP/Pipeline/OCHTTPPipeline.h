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
#import "OCProgress.h"
#import "OCClassSettings.h"
#import "OCLogTag.h"

@class OCHTTPPipeline;

typedef NSString* OCHTTPPipelineID;
typedef NSString* OCHTTPPipelinePartitionID;

NS_ASSUME_NONNULL_BEGIN

@protocol OCHTTPPipelinePartitionHandler <NSObject>

@property(strong,readonly) OCHTTPPipelinePartitionID partitionID; //!< The ID of the partition
@property(nullable,strong,readonly) OCCertificate *certificate; //!< The certificate used by the partition.

#pragma mark - Requirements
- (BOOL)pipeline:(OCHTTPPipeline *)pipeline meetsSignalRequirements:(NSSet<OCConnectionSignalID> *)requiredSignals failWithError:(NSError **)outError;
- (BOOL)pipeline:(OCHTTPPipeline *)pipeline canProvideAuthenticationForRequests:(void(^)(NSError *error, BOOL authenticationIsAvailable))availabilityHandler;

#pragma mark - Scheduling
- (OCHTTPRequest *)pipeline:(OCHTTPPipeline *)pipeline prepareRequestForScheduling:(OCHTTPRequest *)request;

- (nullable NSError *)pipeline:(OCHTTPPipeline *)pipeline postProcessFinishedRequest:(OCHTTPRequest *)request error:(nullable NSError *)error;
- (OCHTTPRequestInstruction)pipeline:(OCHTTPPipeline *)pipeline instructionForFinishedRequest:(OCHTTPRequest *)finishedRequest error:(nullable NSError *)error;

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

@end

@interface OCHTTPPipeline : NSObject <OCProgressResolver, OCClassSettingsSupport, OCLogTagging, NSURLSessionDelegate, NSURLSessionTaskDelegate, NSURLSessionDataDelegate, NSURLSessionDownloadDelegate>
{
	// URL Session handling
	NSURLSession *_urlSession;
	BOOL _urlSessionInvalidated;

	NSMutableDictionary<NSString*, NSURLSession*> *_attachedURLSessionsByIdentifier;

	// Settings
	BOOL _insertXRequestID;

	// Backend
	OCHTTPPipelineBackend *_backend;

	// Scheduling
	NSMutableDictionary<OCHTTPPipelinePartitionID, id<OCHTTPPipelinePartitionHandler>> *_partitionHandlersByID;
	NSMutableArray<OCHTTPPipelinePartitionID> *_attachedParititionHandlerIDs;

	NSMutableArray<OCHTTPRequestGroupID> *_recentlyScheduledGroupIDs;

	BOOL _needsScheduling;

	// Logging
	NSArray<OCLogTagName> *_cachedLogTags;
}

@property(strong,readonly) OCHTTPPipelineID identifier;
@property(strong,readonly) NSString *bundleIdentifier;

@property(assign) BOOL generateSystemActivityWhileRequestAreRunning;
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

#pragma mark - Remove partition
- (void)destroyPartition:(OCHTTPPipelinePartitionID)partitionID completionHandler:(nullable OCCompletionHandler)completionHandler; //!< Attempts to stop all running requests for the partition, remove associated records from the database and remove data stored on disk for requests belonging to the partition.

#pragma mark - Shutdown
- (void)finishTasksAndInvalidateWithCompletionHandler:(dispatch_block_t)completionHandler;
- (void)invalidateAndCancelWithCompletionHandler:(dispatch_block_t)completionHandler;

- (void)cancelNonCriticalRequests; //!< Cancels .isNonCritical requests

@end

extern OCClassSettingsKey OCHTTPPipelineInsertXRequestTracingID; //!< Controls whether a X-Request-ID should be included into the header of every request. Defaults to YES. [NSNumber]

NS_ASSUME_NONNULL_END
