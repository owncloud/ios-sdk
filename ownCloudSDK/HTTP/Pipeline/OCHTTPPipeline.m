//
//  OCHTTPPipeline.m
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

#import "OCHTTPPipeline.h"
#import "OCHTTPPipelineTask.h"

@implementation OCHTTPPipeline

#pragma mark - Init
- (instancetype)initWithIdentifier:(OCHTTPPipelineID)identifier backend:(nullable OCHTTPPipelineBackend *)backend configuration:(NSURLSessionConfiguration *)sessionConfiguration;
{
	if ((self = [super init]) != nil)
	{
		// Set identifiers
		_identifier = identifier;
		_bundleIdentifier = NSBundle.mainBundle.bundleIdentifier;

		// Set backend
		if (backend == nil)
		{
			backend = [[OCHTTPPipelineBackend alloc] initWithSQLDB:nil];
		}

		_backend = backend;

		// Change sessionConfiguration to not store any session-related data on disk
		sessionConfiguration.URLCredentialStorage = nil; // Do not use credential store at all
		sessionConfiguration.URLCache = nil; // Do not cache responses
		sessionConfiguration.HTTPCookieStorage = nil; // Do not store cookies

		// Grab the session identifier for those sessions that have it
		_urlSessionIdentifier = sessionConfiguration.identifier;

		// Create URL session
		_urlSession = [NSURLSession sessionWithConfiguration:sessionConfiguration
							    delegate:self
						       delegateQueue:nil];
	}

	return (self);
}

#pragma mark - Request handling
- (void)enqueueRequest:(OCHTTPRequest *)request forPartitionID:(OCHTTPPipelinePartitionID)partitionID
{
	OCHTTPPipelineTask *pipelineTask;

	if ((pipelineTask = [[OCHTTPPipelineTask alloc] initWithRequest:request pipeline:self partition:partitionID]) != nil)
	{
		
	}
}

- (void)cancelRequest:(OCHTTPRequest *)request
{

}

- (void)cancelRequestsForPartitionID:(OCHTTPPipelinePartitionID)partitionID queuedOnly:(BOOL)queuedOnly
{

}

#pragma mark - Attach & detach partition handlers
- (void)attachPartitionHandler:(id<OCHTTPPipelinePartitionHandler>)partitionHandler
{
}

- (void)detachPartitionHandler:(id<OCHTTPPipelinePartitionHandler>)partitionHandler
{

}

- (void)detachPartitionHandlerForPartitionID:(OCHTTPPipelinePartitionID)partitionID
{
}

#pragma mark - Shutdown
- (void)finishTasksAndInvalidateWithCompletionHandler:(dispatch_block_t)completionHandler
{
}

- (void)invalidateAndCancelWithCompletionHandler:(dispatch_block_t)completionHandler
{
}

- (void)cancelNonCriticalRequests
{
}

#pragma mark - Scheduling


#pragma mark - NSURLSessionDelegate

#pragma mark - NSURLSessionTaskDelegate
#pragma mark - NSURLSessionDataDelegate
#pragma mark - NSURLSessionDownloadDelegate

@end
