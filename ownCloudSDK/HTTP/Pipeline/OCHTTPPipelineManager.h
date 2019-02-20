//
//  OCHTTPPipelineManager.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 05.02.19.
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
#import "OCHTTPTypes.h"
#import "OCHTTPPipeline.h"
#import "OCHTTPPipelineBackend.h"
#import "OCLogTag.h"
#import "OCProgress.h"

NS_ASSUME_NONNULL_BEGIN

typedef void(^OCHTTPPipelineManagerRequestCompletionHandler)(OCHTTPPipeline * _Nullable pipeline, NSError * _Nullable error);

@interface OCHTTPPipelineManager : NSObject <OCLogTagging, OCProgressResolver>

@property(strong,class,readonly) OCHTTPPipelineManager *sharedPipelineManager; //!< Singleton managing pipelines

@property(strong,readonly,nonatomic) OCHTTPPipelineBackend *backend; //!< Backend that persists tasks via SQLite on-disk.
@property(strong,readonly,nonatomic) OCHTTPPipelineBackend *ephermalBackend; //!< Backend storing tasks in an in-memory SQLite db.

#pragma mark - Set up persistent pipelines
+ (void)setupPersistentPipelines; //!< Makes sure that the pipelines OCHTTPPipelineIDLocal and OCHTTPPipelineIDBackground stay around for the lifetime of the process.

#pragma mark - Requesting and returning pipelines
- (void)requestPipelineWithIdentifier:(OCHTTPPipelineID)pipelineID completionHandler:(OCHTTPPipelineManagerRequestCompletionHandler)completionHandler; //!< Request the pipeline with the provided identifier to start using it
- (void)returnPipelineWithIdentifier:(OCHTTPPipelineID)pipelineID completionHandler:(nullable dispatch_block_t)completionHandler; //!< Return the pipeline with the provided identifier to stop using it

#pragma mark - Background session recovery
- (void)setEventHandlingFinishedBlock:(dispatch_block_t)finishedBlock forURLSessionIdentifier:(NSString *)urlSessionIdentifier; //!< Sets an event handling finished block to be called when all events for a NSURLSession with that identifier have been handled.
- (dispatch_block_t)eventHandlingFinishedBlockForURLSessionIdentifier:(NSString *)urlSessionIdentifier remove:(BOOL)remove; //!< Retrieves the event handling finished block to be called when all events for a NSURLSession with that identifier have been handled. Optionally also removes it.

- (void)handleEventsForBackgroundURLSession:(NSString *)sessionIdentifier completionHandler:(dispatch_block_t)completionHandler; //!< Handles events for a background URLSession with the provided sessionIdentifier and calls the completionHandler when done.

#pragma mark - Miscellaneous
- (void)forceStopAllPipelinesGracefully:(BOOL)gracefully completionHandler:(dispatch_block_t)completionHandler; //!< Stops all pipelines. You should avoid this outside unit tests.
- (void)detachAndDestroyPartitionInAllPipelines:(OCHTTPPipelinePartitionID)partitionID completionHandler:(OCCompletionHandler)completionHandler; //!< Detaches and destroys the given partition in all pipelines.

@end

extern OCHTTPPipelineID OCHTTPPipelineIDEphermal;   //!< The ID of the ephermal pipeline.   Uses an ephermal NSURLSession and an in-memory backend.
extern OCHTTPPipelineID OCHTTPPipelineIDLocal;	    //!< The ID of the local pipeline. 	    Uses an ephermal NSURLSession and a persistent SQL backend.
extern OCHTTPPipelineID OCHTTPPipelineIDBackground; //!< The ID of the background pipeline. Uses a background NSURLSession and a persistent SQL backend.

NS_ASSUME_NONNULL_END
