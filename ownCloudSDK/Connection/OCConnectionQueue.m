//
//  OCConnectionQueue.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 07.02.18.
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

#import "OCConnectionQueue.h"
#import "OCConnection+OCConnectionQueue.h"
#import "NSError+OCError.h"
#import "OCCertificate.h"
#import "OCLogger.h"
#import "OCConnectionQueue+BackgroundSessionRecovery.h"
#import "OCAppIdentity.h"

@implementation OCConnectionQueue

@synthesize connection = _connection;
@synthesize maxConcurrentRequests = _maxConcurrentRequests;

#pragma mark - Init
- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_queuedRequests = [NSMutableArray new];

		_runningRequests = [NSMutableArray new];
		_runningRequestsGroupIDs = [NSMutableSet new];

		_runningRequestsByTaskIdentifier = [NSMutableDictionary new];

		_cachedCertificatesByHostnameAndPort = [NSMutableDictionary new];
		
		_actionQueue = dispatch_queue_create("OCConnectionQueue", DISPATCH_QUEUE_SERIAL);
		
		_maxConcurrentRequests = 10;
		
		_authenticatedRequestsCanBeScheduled = YES;
	}
	
	return (self);
}

- (instancetype)initBackgroundSessionQueueWithIdentifier:(NSString *)identifier persistentStore:(OCKeyValueStore *)persistentStore connection:(OCConnection *)connection
{
	if ((self = [self init]) != nil)
	{
		NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:identifier];

		sessionConfiguration.sharedContainerIdentifier = [OCAppIdentity sharedAppIdentity].appGroupIdentifier;
		sessionConfiguration.URLCredentialStorage = nil; // Do not use credential store at all
		sessionConfiguration.URLCache = nil; // Do not cache responses
		sessionConfiguration.HTTPCookieStorage = nil; // Do not store cookies

		_connection = connection;

		_persistentStore = persistentStore;

		[self restoreState];

		_urlSession = [NSURLSession sessionWithConfiguration:sessionConfiguration
					    delegate:self
					    delegateQueue:nil];

		_urlSessionIdentifier = identifier;

		[self updateStateWithURLSession];
	}
	
	return (self);
}

- (instancetype)initEphermalQueueWithConnection:(OCConnection *)connection
{
	if ((self = [self init]) != nil)
	{
		NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
		sessionConfiguration.URLCredentialStorage = nil; // Do not use credential store at all
		sessionConfiguration.URLCache = nil; // Do not cache responses
		sessionConfiguration.HTTPCookieStorage = nil; // Do not store cookies

		_connection = connection;

		_encloseRunningRequestsInSystemActivities = YES;

		_urlSession = [NSURLSession sessionWithConfiguration:sessionConfiguration
					    delegate:self
					    delegateQueue:nil];
	}
	
	return (self);
}

- (void)dealloc
{
	if (_invalidationCompletionHandler)
	{
		_invalidationCompletionHandler();
		_invalidationCompletionHandler = nil;
	}
}

#pragma mark - Invalidation
- (void)finishTasksAndInvalidateWithCompletionHandler:(dispatch_block_t)completionHandler
{
	OCLogDebug(@"finish tasks and invalidate");

	_invalidationCompletionHandler = completionHandler;

	// Find and cancel non-critical requests
	[self cancelNonCriticalRequests];

	// Finish and invalidate remaining tasks in session
	[_urlSession finishTasksAndInvalidate];
}

- (void)invalidateAndCancelWithCompletionHandler:(dispatch_block_t)completionHandler
{
	OCLogDebug(@"cancel tasks and invalidate");

	_invalidationCompletionHandler = completionHandler;

	[_urlSession invalidateAndCancel];
}

- (void)cancelNonCriticalRequests
{
	NSMutableArray <OCConnectionRequest *> *cancelRequests = [NSMutableArray new];

	// Find and cancel non-critical requests
	@synchronized(self)
	{
		for (OCConnectionRequest *runningRequest in _runningRequests)
		{
			if (runningRequest.isNonCritial)
			{
				[cancelRequests addObject:runningRequest];
			}
		}
	}

	for (OCConnectionRequest *cancelRequest in cancelRequests)
	{
		OCLogDebug(@"Cancelling non-critical request=%@ to speed up connection queue shutdown", cancelRequest);
		[cancelRequest cancel];
	}
}

#pragma mark - Queue management
- (void)enqueueRequest:(OCConnectionRequest *)request
{
	@synchronized(self)
	{
		// Add request to queue
		[_queuedRequests addObject:request];
	}
	
	[self scheduleQueuedRequests];
}

- (void)cancelRequest:(OCConnectionRequest *)request
{
	[request cancel];
}

- (void)cancelRequestsWithGroupID:(OCConnectionRequestGroupID)groupID queuedOnly:(BOOL)queuedOnly
{
	// Stub implementation
}

- (void)scheduleQueuedRequests
{
	[self _queueBlock:^{
		[self _scheduleQueuedRequests];
	}];
}

- (void)_scheduleQueuedRequests
{
	@synchronized(self)
	{
		if (((_maxConcurrentRequests==0) || (_runningRequests.count < _maxConcurrentRequests)) && // No limitation - or free slots?
		    (_queuedRequests.count > 0)) // Something to schedule?
		{
			NSArray *queuedRequests = [NSArray arrayWithArray:_queuedRequests]; // Make a copy, because _queuedRequests will be modified during enumeration
			
			// Make sure the authentication method is ready to authorize the request, but try to avoid unnecessary calls (like when previous calls returned NO)
			if (_authenticatedRequestsCanBeScheduled)
			{
				_authenticatedRequestsCanBeScheduled = [_connection canSendAuthenticatedRequestsForQueue:self availabilityHandler:^(NSError *error, BOOL authenticationIsAvailable) {
					// Set _authenticatedRequestsCanBeScheduled to YES regardless of authenticationIsAvailable's value in order to ensure -[OCConnection canSendAuthenticatedRequestsForQueue:availabilityHandler:] is called ever again (for requests queued in the future)
					[self _queueBlock:^{
						self->_authenticatedRequestsCanBeScheduled = YES;
					}];

					if (authenticationIsAvailable)
					{
						// Authentication is now available => schedule queued requests
						[self scheduleQueuedRequests];
					}
					else
					{
						// Authentication is not available => end scheduled requests that need authentication with error
						[self _finishQueuedRequestsWithError:error filter:^BOOL(OCConnectionRequest *request) {
							return (!request.skipAuthorization);
						}];
					}
				}];
			}

			NSMutableSet <OCConnectionRequestGroupID> *pendingGroupIDs = nil;
		
			for (OCConnectionRequest *queuedRequest in queuedRequests)
			{
				if ((_maxConcurrentRequests==0) || (_runningRequests.count < _maxConcurrentRequests))
				{
					BOOL scheduleRequest = YES;
				
					// Does the request belong to a group?
					if (queuedRequest.groupID!=nil)
					{
						// Make sure to only schedule this request if no other request from this group is running
						scheduleRequest = ![_runningRequestsGroupIDs containsObject:queuedRequest.groupID];

						// Make sure no other request in this group is still pending
						scheduleRequest = scheduleRequest && ((pendingGroupIDs == nil) || ((pendingGroupIDs != nil) && ![pendingGroupIDs containsObject:queuedRequest.groupID]));
					}

					if (scheduleRequest && (queuedRequest.requiredSignals != nil))
					{
						// Make sure requests meet the required signals before scheduling them
						scheduleRequest = [_connection meetsSignalRequirements:queuedRequest.requiredSignals];

						// Mark group as pending when one is specified and the request should not yet be scheduled
						if (!scheduleRequest && (queuedRequest.groupID!=nil))
						{
							if (pendingGroupIDs == nil) { pendingGroupIDs = [NSMutableSet new]; }
							[pendingGroupIDs addObject:queuedRequest.groupID];
						}
					}
					
					if (scheduleRequest && !queuedRequest.skipAuthorization)
					{
						// Make sure requests that need to be authenticated are not sent before the authentication method isn't ready to authorize it
						scheduleRequest = _authenticatedRequestsCanBeScheduled;
					}
					
					if (scheduleRequest)
					{
						// Schedule the request
						[self _scheduleRequest:queuedRequest];
					}
				}
				else
				{
					// Capacity reached
					break;
				}
			}
		}
	}
}

- (void)_scheduleRequest:(OCConnectionRequest *)scheduleRequest
{
	OCConnectionRequest *request = scheduleRequest;
	NSError *error = nil;

	// Remove request from queue
	[_queuedRequests removeObject:request];

	if (request.cancelled)
	{
		// This request has been cancelled
		error = OCError(OCErrorRequestCancelled);
	}
	else if (_urlSessionInvalidated)
	{
		// The underlying NSURLSession has been invalidated
		error = OCError(OCErrorRequestURLSessionInvalidated);
	}
	else
	{
		// Prepare request
		[self _prepareRequestForScheduling:request];

		if (_connection!=nil)
		{
			// Apply authentication and other connection-level changes
			request = [_connection prepareRequest:request forSchedulingInQueue:self];
		}
		
		// Schedule request
		if (request != nil)
		{
			NSURLRequest *urlRequest;
			NSURLSessionTask *task = nil;
			BOOL createTask = YES;

			// Invoke host simulation (if any)
			if (_connection.hostSimulator != nil)
			{
				createTask = [_connection.hostSimulator connection:_connection queue:self handleRequest:request completionHandler:^(NSError *error) {
					[self _handleFinishedRequest:request error:error scheduleQueuedRequests:YES];
				}];
			}

			if (createTask)
			{
				// Generate NSURLRequest and create an NSURLSessionTask with it
				if ((urlRequest = [request generateURLRequestForQueue:self]) != nil)
				{
					@try
					{
						// Construct NSURLSessionTask
						if (request.downloadRequest)
						{
							// Request is a download request. Make it a download task.
							task = [_urlSession downloadTaskWithRequest:urlRequest];
						}
						else if (request.bodyURL != nil)
						{
							// Body comes from a file. Make it an upload task.
							task = [_urlSession uploadTaskWithRequest:urlRequest fromFile:request.bodyURL];
						}
						else
						{
							// Create a regular data task
							task = [_urlSession dataTaskWithRequest:urlRequest];
						}

						// Apply priority
						task.priority = request.priority;

						// Apply earliest date
						if (request.earliestBeginDate != nil)
						{
							task.earliestBeginDate = request.earliestBeginDate;
						}
					}
					@catch (NSException *exception)
					{
						OCLogDebug(@"Exception creating a task: %@", exception);
						error = OCErrorWithInfo(OCErrorException, exception);
					}
				}

				if (task != nil)
				{
					BOOL resumeTask = YES;

					// Save task to request
					request.urlSessionTask = task;
					request.urlSessionTaskIdentifier = @(task.taskIdentifier);

					// Connect task progress to request progress
					request.progress.totalUnitCount += 200;
					[request.progress addChild:task.progress withPendingUnitCount:200];

					// Update internal tracking collections
					if (request.groupID!=nil)
					{
						[_runningRequestsGroupIDs addObject:request.groupID];
					}

					[_runningRequests addObject:request];

					_runningRequestsByTaskIdentifier[request.urlSessionTaskIdentifier] = request;

					OCLogDebug(@"saved request for taskIdentifier <%@>, URL: %@, %p, %p", request.urlSessionTaskIdentifier, urlRequest, self, _runningRequestsByTaskIdentifier);

					// Start task
					if (resumeTask)
					{
						// Prevent suspension for as long as this runs
						if (_encloseRunningRequestsInSystemActivities)
						{
							NSString *absoluteURLString = request.url.absoluteString;

							if (absoluteURLString==nil)
							{
								absoluteURLString = @"";
							}

							request.systemActivity = [[NSProcessInfo processInfo] beginActivityWithOptions:NSActivityUserInitiatedAllowingIdleSystemSleep reason:[@"Request to " stringByAppendingString:absoluteURLString]];
						}

						// Notify request observer
						if (request.requestObserver != nil)
						{
							resumeTask = !request.requestObserver(request, OCConnectionRequestObserverEventTaskResume);
						}
					}

					if (resumeTask)
					{
						[task resume];
					}
				}
				else
				{
					// Request failure
					if (error == nil)
					{
						error = OCError(OCErrorRequestURLSessionTaskConstructionFailed);
					}
				}
			}
		}
		else
		{
			request = scheduleRequest;
			error = OCError(OCErrorRequestRemovedBeforeScheduling);
		}
	}

	// Log request
	if (OCLogger.logLevel <= OCLogLevelDebug)
	{
		NSArray <OCLogTagName> *extraTags = [NSArray arrayWithObjects: @"HTTP", @"Request", request.method, OCLogTagTypedID(@"RequestID", request.headerFields[@"X-Request-ID"]), OCLogTagTypedID(@"URLSessionTaskID", request.urlSessionTaskIdentifier), nil];
		OCPLogDebug(OCLogOptionLogRequestsAndResponses, extraTags, @"Sending request:\n# REQUEST ---------------------------------------------------------\nURL:   %@\nError: %@\n- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -\n%@-----------------------------------------------------------------", request.effectiveURL, ((error != nil) ? error : @"-"), request.requestDescription);
	}

	if (error != nil)
	{
		// Finish with error
		[self _queueBlock:^{
			[self handleFinishedRequest:request error:error];
		}];
	}

	[self saveState];
}

- (void)_prepareRequestForScheduling:(OCConnectionRequest *)request
{
	[request prepareForSchedulingInQueue:self];
}

- (void)_finishQueuedRequestsWithError:(NSError *)error filter:(BOOL(^)(OCConnectionRequest *request))requestFilter
{
	[self _queueBlock:^{
		NSMutableArray <OCConnectionRequest *> *finishRequests = nil;
	
		@synchronized(self)
		{
			if ((finishRequests = [[NSMutableArray alloc] initWithArray:self->_queuedRequests]) != nil)
			{
				if (requestFilter!=nil)
				{
					for (OCConnectionRequest *request in self->_queuedRequests)
					{
						if (!requestFilter(request))
						{
							[finishRequests removeObject:request];
						}
					}
				}
				
				[self->_queuedRequests removeObjectsInArray:finishRequests];
			}
		}
		
		for (OCConnectionRequest *request in finishRequests)
		{
			[self _handleFinishedRequest:request error:error scheduleQueuedRequests:NO];
		}
	}];
}

- (void)_queueBlock:(dispatch_block_t)block
{
	if (block != NULL)
	{
		dispatch_async(_actionQueue, block);
	}
}

#pragma mark - Result handling
- (void)handleFinishedRequest:(OCConnectionRequest *)request error:(NSError *)error
{
	[self _queueBlock:^{
		[self _handleFinishedRequest:request error:error scheduleQueuedRequests:YES];
	}];
}

- (void)_handleFinishedRequest:(OCConnectionRequest *)request error:(NSError *)error scheduleQueuedRequests:(BOOL)scheduleQueuedRequests
{
	BOOL reschedulingAllowed = scheduleQueuedRequests;

	if (request==nil) { return; }

	// Check if this request should have a responseCertificate ..
	if (error == nil)
	{
		NSURL *requestURL = request.url;

		if ([requestURL.scheme.lowercaseString isEqualToString:@"https"])
		{
			// .. but hasn't ..
			if (request.responseCertificate == nil)
			{
				NSString *hostnameAndPort;

				// .. and if we have one available in that case
				if ((hostnameAndPort = [NSString stringWithFormat:@"%@:%@", requestURL.host.lowercaseString, ((requestURL.port!=nil)?requestURL.port : @"443" )]) != nil)
				{
					@synchronized(self)
					{
						// Attach certificate from cache (NSURLSession probably didn't do because the certificate is still cached in its internal TLS cache and we were asked before. Also see https://developer.apple.com/library/content/qa/qa1727/_index.html and https://github.com/AFNetworking/AFNetworking/issues/991 .)
						if ((request.responseCertificate = _cachedCertificatesByHostnameAndPort[hostnameAndPort]) != nil)
						{
							OCConnectionCertificateProceedHandler proceedHandler = ^(BOOL proceed, NSError *proceedError) {
								if (proceed)
								{
									[self _handleFinishedRequest:request error:error scheduleQueuedRequests:scheduleQueuedRequests];
								}
								else
								{
									request.error = (proceedError != nil) ? proceedError : OCError(OCErrorRequestServerCertificateRejected);
									[self _handleFinishedRequest:request error:proceedError scheduleQueuedRequests:scheduleQueuedRequests];
								}
							};

							[self evaluateCertificate:request.responseCertificate forRequest:request proceedHandler:proceedHandler];
						}
						else
						{
							[self _handleFinishedRequest:request error:OCError(OCErrorCertificateMissing) scheduleQueuedRequests:scheduleQueuedRequests];

							if (request.systemActivity != nil)
							{
								[[NSProcessInfo processInfo] endActivity:request.systemActivity];
								request.systemActivity = nil;
							}
						}
						return;
					}
				}
			}
		}
	}

	// If error is that request was cancelled, use request.error if set
	if ([error.domain isEqualToString:NSURLErrorDomain] && (error.code==NSURLErrorCancelled) && (request.error!=nil))
	{
		error = request.error;
	}

	// Give connection a chance to pass it off to authentication methods / interpret the error before delivery to the sender
	if (_connection!=nil)
	{
		error = [_connection postProcessFinishedRequest:request error:error];
	}

	// Log response
	if (OCLogger.logLevel <= OCLogLevelDebug)
	{
		NSArray <OCLogTagName> *extraTags = [NSArray arrayWithObjects: @"HTTP", @"Response", request.method, OCLogTagTypedID(@"RequestID", request.headerFields[@"X-Request-ID"]), OCLogTagTypedID(@"URLSessionTaskID", request.urlSessionTaskIdentifier), nil];
		OCPLogDebug(OCLogOptionLogRequestsAndResponses, extraTags, @"Received response:\n# RESPONSE --------------------------------------------------------\nMethod:     %@\nURL:        %@\nRequest-ID: %@\nError:      %@\n- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -\n%@-----------------------------------------------------------------", request.method, request.effectiveURL, request.headerFields[@"X-Request-ID"], ((error != nil) ? error : @"-"), request.responseDescription);
	}

	// Determine request instruction
	OCConnectionRequestInstruction requestInstruction = OCConnectionRequestInstructionDeliver;

	if ((_connection!=nil) && reschedulingAllowed)
	{
		requestInstruction = [_connection instructionForFinishedRequest:request];
	}

	if (requestInstruction == OCConnectionRequestInstructionDeliver)
	{
		// Deliver Finished Request
		if ((_connection!=nil) && (request.resultHandlerAction != NULL))
		{
			// Below is identical to [_connection performSelector:request.resultHandlerAction withObject:request withObject:error], but in an ARC-friendly manner.
			void (*impFunction)(id, SEL, OCConnectionRequest *, NSError *) = (void *)[_connection methodForSelector:request.resultHandlerAction];

			if (impFunction != NULL)
			{
				impFunction(_connection, request.resultHandlerAction, request, error);
			}
		}
		else
		{
			if (request.ephermalResultHandler != nil)
			{
				request.ephermalResultHandler(request, error);
			}
		}
	}

	// Update internal tracking collections
	@synchronized(self)
	{
		if ([_runningRequests indexOfObjectIdenticalTo:request] != NSNotFound)
		{
			if (request.groupID!=nil)
			{
				[_runningRequestsGroupIDs removeObject:request.groupID];
			}

			[_runningRequests removeObject:request];

			if (request.urlSessionTaskIdentifier != nil)
			{
				OCLogDebug(@"Removing request %@ with taskIdentifier <%@>", OCLogPrivate(request.url), request.urlSessionTaskIdentifier);
				[_runningRequestsByTaskIdentifier removeObjectForKey:request.urlSessionTaskIdentifier];

				request.urlSessionTaskIdentifier = nil;
			}
		}
	}

	// Remove temporarily downloaded files
	if (request.downloadRequest && request.downloadedFileIsTemporary && (request.downloadedFileURL!=nil))
	{
		[[NSFileManager defaultManager] removeItemAtURL:request.downloadedFileURL error:nil];
		request.downloadedFileURL = nil;
	}

	// Reschedule request if instructed so
	if ((requestInstruction == OCConnectionRequestInstructionReschedule) && reschedulingAllowed)
	{
		[request scrubForRescheduling];

		if (scheduleQueuedRequests)
		{
			@synchronized(self)
			{
				[_queuedRequests insertObject:request atIndex:0];
			}
		}
	}

	// Continue with scheduling
	if (scheduleQueuedRequests)
	{
		[self _scheduleQueuedRequests];
	}

	// Save state
	[self saveState];

	// End system activity
	if (request.systemActivity != nil)
	{
		[[NSProcessInfo processInfo] endActivity:request.systemActivity];
		request.systemActivity = nil;
	}
}

#pragma mark - Request retrieval
- (OCConnectionRequest *)requestForTask:(NSURLSessionTask *)task
{
	OCConnectionRequest *request = nil;
	
	if (task != nil)
	{
		@synchronized(self)
		{
			request = _runningRequestsByTaskIdentifier[@(task.taskIdentifier)];
			
			if (request.urlSessionTask == nil)
			{
				request.urlSessionTask = task;
			}

			if (request == nil)
			{
				OCLogError(@"could not find request for task=%@, taskIdentifier=<%lu>, url=%@, %p %p", OCLogPrivate(task), task.taskIdentifier, OCLogPrivate(task.currentRequest.URL), self, _runningRequestsByTaskIdentifier);
			}
		}
	}
	
	return (request);
}

- (void)handleFinishedTask:(NSURLSessionTask *)task error:(NSError *)error
{
	OCConnectionRequest *request;
	
	if ((request = [self requestForTask:task]) != nil)
	{
		if (request.urlSessionTask == nil)
		{
			request.urlSessionTask = task;
		}

		[self handleFinishedRequest:request error:error];
	}
}

#pragma mark - NSURLSessionTaskDelegate
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(nullable NSError *)error
{
	// OCLogDebug(@"DID COMPLETE: task=%@ error=%@", task, error);
	OCLogDebug(@"%@ [taskIdentifier=<%lu>]: didCompleteWithError=%@", task.currentRequest.URL, task.taskIdentifier, error);

	[self handleFinishedRequest:[self requestForTask:task] error:error];
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
	[self _queueBlock:^{
		OCConnectionRequest *request = [self requestForTask:dataTask];
		
		if (!request.downloadRequest)
		{
			[request appendDataToResponseBody:data];
		}
	}];
}

- (void)URLSession:(NSURLSession *)session
        task:(NSURLSessionTask *)task
        willPerformHTTPRedirection:(NSHTTPURLResponse *)response
        newRequest:(NSURLRequest *)request
        completionHandler:(void (^)(NSURLRequest * _Nullable))completionHandler
{
	OCLogDebug(@"%@: wants to perform redirection from %@ to %@ via %@", OCLogPrivate(task.currentRequest.URL), OCLogPrivate(task.currentRequest.URL), OCLogPrivate(request.URL), response);

	// Don't allow redirections. Deliver the redirect response instead - these really need to be handled locally on a case-by-case basis.
	if (completionHandler != nil)
	{
		completionHandler(NULL);
	}
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location
{
	OCConnectionRequest *request;

	if ((request = [self requestForTask:downloadTask]) != nil)
	{
		if (request.downloadedFileURL == nil)
		{
			NSURL *temporaryDirectoryURL = [NSURL fileURLWithPath:NSTemporaryDirectory()];
			NSURL *temporaryFileURL = [temporaryDirectoryURL URLByAppendingPathComponent:[NSUUID UUID].UUIDString];

			request.downloadedFileURL = temporaryFileURL;
			request.downloadedFileIsTemporary = YES;
		}
		else
		{
			request.downloadedFileIsTemporary = NO;
		}

		if (request.downloadedFileURL != nil)
		{
			NSError *error = nil;
			[[NSFileManager defaultManager] moveItemAtURL:location toURL:request.downloadedFileURL error:&error];
		}
	}

	OCLogDebug(@"%@: downloadTask:didFinishDownloadingToURL: %@", downloadTask.currentRequest.URL, location);
	// OCLogDebug(@"DOWNLOADTASK FINISHED: %@ %@ %@", downloadTask, location, request);
}

- (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session
{
	dispatch_block_t completionHandler;

	OCLogDebug(@"URLSessionDidFinishEventsForBackgroundSession: %@", session);

	// Call completion handler
	if ((completionHandler = [OCConnectionQueue completionHandlerForBackgroundSessionWithIdentifier:session.configuration.identifier remove:YES]) != nil)
	{
		// Apple docs: "Because the provided completion handler is part of UIKit, you must call it on your main thread."
		dispatch_async(dispatch_get_main_queue(), ^{
			completionHandler();
		});
	}

	// Tell connection that handling this queue finished
	[_connection finishedQueueForResumedBackgroundSessionWithIdentifier:session.configuration.identifier];
}

- (void)URLSession:(NSURLSession *)session didBecomeInvalidWithError:(NSError *)error
{
	_urlSessionInvalidated = YES;

	OCLogDebug(@"did become invalid, running completionHandler %p", _invalidationCompletionHandler);

	if (_invalidationCompletionHandler != nil)
	{
		_invalidationCompletionHandler();
		_invalidationCompletionHandler = nil;
	}
}

- (void)evaluateCertificate:(OCCertificate *)certificate forRequest:(OCConnectionRequest *)request proceedHandler:(OCConnectionCertificateProceedHandler)proceedHandler
{
	[certificate evaluateWithCompletionHandler:^(OCCertificate *certificate, OCCertificateValidationResult validationResult, NSError *validationError) {
		[self _queueBlock:^{
			if (request != nil)
			{
				request.responseCertificate = certificate;

				if (((validationResult == OCCertificateValidationResultUserAccepted) ||
				     (validationResult == OCCertificateValidationResultPassed)) &&
				     !request.forceCertificateDecisionDelegation)
				{
					proceedHandler(YES, nil);
				}
				else
				{
					if (request.ephermalRequestCertificateProceedHandler != nil)
					{
						request.ephermalRequestCertificateProceedHandler(request, certificate, validationResult, validationError, proceedHandler);
					}
					else
					{
						[self->_connection handleValidationOfRequest:request certificate:certificate validationResult:validationResult validationError:validationError proceedHandler:proceedHandler];
					}
				}
			}
		}];
	}];
}

- (void)URLSession:(NSURLSession *)session
        task:(NSURLSessionTask *)task
        didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
        completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable))completionHandler
{
	OCLogDebug(@"%@: %@ => protection space: %@ method: %@", OCLogPrivate(task.currentRequest.URL), OCLogPrivate(challenge), OCLogPrivate(challenge.protectionSpace), challenge.protectionSpace.authenticationMethod);

	if ([challenge.protectionSpace.authenticationMethod isEqual:NSURLAuthenticationMethodServerTrust])
	{
		SecTrustRef serverTrust;
		
		if ((serverTrust = challenge.protectionSpace.serverTrust) != NULL)
		{
			// Handle server trust challenges
			OCCertificate *certificate = [OCCertificate certificateWithTrustRef:serverTrust hostName:task.currentRequest.URL.host];
			OCConnectionRequest *request = nil;
			NSURL *requestURL = task.currentRequest.URL;
			NSString *hostnameAndPort;

			if ((hostnameAndPort = [NSString stringWithFormat:@"%@:%@", requestURL.host.lowercaseString, ((requestURL.port!=nil)?requestURL.port : @"443" )]) != nil)
			{
				// Cache certificates
				@synchronized(self)
				{
					if (certificate != nil)
					{
						[_cachedCertificatesByHostnameAndPort setObject:certificate forKey:hostnameAndPort];
					}
					else
					{
						[_cachedCertificatesByHostnameAndPort removeObjectForKey:hostnameAndPort];
					}
				}
			}

			request = [self requestForTask:task];

			OCConnectionCertificateProceedHandler proceedHandler = ^(BOOL proceed, NSError *error) {
				if (proceed)
				{
					completionHandler(NSURLSessionAuthChallengeUseCredential, [NSURLCredential credentialForTrust:serverTrust]);
				}
				else
				{
					request.error = (error != nil) ? error : OCError(OCErrorRequestServerCertificateRejected);
					completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
				}
			};

			if (request != nil)
			{
				[self evaluateCertificate:certificate forRequest:request proceedHandler:proceedHandler];
			}
		}
		else
		{
			completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
		}
	}
	else
	{
		// All other challenges
		completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
	}
}


#pragma mark - Log tags
+ (nonnull NSArray<OCLogTagName> *)logTags
{
	return (@[@"CONNQ"]);
}

- (nonnull NSArray<OCLogTagName> *)logTags
{
	NSArray<OCLogTagName> *logTags = nil;

	if (_cachedLogTags == nil)
	{
		@synchronized(self)
		{
			if (_cachedLogTags == nil)
			{
				_cachedLogTags = [NSArray arrayWithObjects:@"CONNQ", ((_urlSessionIdentifier != nil) ? @"Background" : @"Local"), OCLogTagInstance(self), OCLogTagTypedID(@"URLSessionID", _urlSessionIdentifier), nil];

				if ((_connection.bookmark != nil) && !OCLogger.maskPrivateData)
				{
					NSString *hostTag, *userTag;

					if ((hostTag = OCLogTagTypedID(@"Host", _connection.bookmark.url.host)) != nil)
					{
						_cachedLogTags = [_cachedLogTags arrayByAddingObject:hostTag];
					}

					if ((userTag = OCLogTagTypedID(@"User", _connection.bookmark.userName)) != nil)
					{
						_cachedLogTags = [_cachedLogTags arrayByAddingObject:userTag];
					}
				}
			}
		}
	}

	logTags = _cachedLogTags;

	if (_connection == nil)
	{
		logTags = [logTags arrayByAddingObject:@"ConnectionIsNil"];
	}

	return (logTags);
}

@end

@implementation OCConnectionQueue (BackgroundSessionRecovery)

#pragma mark - Background URL session recovery
+ (NSMutableDictionary<NSString *, dispatch_block_t> *)_completionHandlersByBackgroundSessionIdentifiers
{
	static NSMutableDictionary <NSString *, dispatch_block_t> *_queuedSessionCompletionHandlersByIdentifiers = nil;
	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		_queuedSessionCompletionHandlersByIdentifiers = [NSMutableDictionary new];
	});

	return (_queuedSessionCompletionHandlersByIdentifiers);
}

+ (dispatch_block_t)completionHandlerForBackgroundSessionWithIdentifier:(NSString *)backgroundSessionIdentifier remove:(BOOL)remove
{
	NSMutableDictionary <NSString *, dispatch_block_t> *_queuedSessionCompletionHandlersByIdentifiers = [self _completionHandlersByBackgroundSessionIdentifiers];
	dispatch_block_t completionHandler = nil;

	if (backgroundSessionIdentifier != nil)
	{
		@synchronized(_queuedSessionCompletionHandlersByIdentifiers)
		{
			completionHandler = _queuedSessionCompletionHandlersByIdentifiers[backgroundSessionIdentifier];

			if (remove)
			{
				[_queuedSessionCompletionHandlersByIdentifiers removeObjectForKey:backgroundSessionIdentifier];
			}
		}
	}

	return (completionHandler);
}

+ (void)setCompletionHandler:(dispatch_block_t)completionHandler forBackgroundSessionWithIdentifier:(NSString *)backgroundSessionIdentifier
{
	NSMutableDictionary <NSString *, dispatch_block_t> *_queuedSessionCompletionHandlersByIdentifiers = [self _completionHandlersByBackgroundSessionIdentifiers];

	if (backgroundSessionIdentifier == nil) { return; }

	@synchronized(_queuedSessionCompletionHandlersByIdentifiers)
	{
		if (completionHandler != nil)
		{
			_queuedSessionCompletionHandlersByIdentifiers[backgroundSessionIdentifier] = completionHandler;
		}
		else
		{
			[_queuedSessionCompletionHandlersByIdentifiers removeObjectForKey:backgroundSessionIdentifier];
		}
	}
}

+ (NSUUID *)uuidForBackgroundSessionIdentifier:(NSString *)backgroundSessionIdentifier
{
	NSString *uuidString;

	if ((uuidString = [[backgroundSessionIdentifier componentsSeparatedByString:@";"] firstObject]) != nil)
	{
		return ([[NSUUID alloc] initWithUUIDString:uuidString]);
	}

	return (nil);
}

+ (NSString *)localBackgroundSessionIdentifierForUUID:(NSUUID *)uuid
{
	return ([NSString stringWithFormat:@"%@;%@", uuid.UUIDString, NSBundle.mainBundle.bundleIdentifier]);
}

+ (BOOL)backgroundSessionOriginatesLocallyForIdentifier:(NSString *)backgroundSessionIdentifier
{
	NSString *originatingBundleIdentifier;

	if ((originatingBundleIdentifier = [[backgroundSessionIdentifier componentsSeparatedByString:@";"] lastObject]) != nil)
	{
		return ([originatingBundleIdentifier isEqual:NSBundle.mainBundle.bundleIdentifier]);
	}

	return (NO);
}

+ (NSArray <NSString *> *)otherBackgroundSessionIdentifiersForUUID:(NSUUID *)uuid
{
	NSMutableDictionary <NSString *, dispatch_block_t> *_queuedSessionCompletionHandlersByIdentifiers = [self _completionHandlersByBackgroundSessionIdentifiers];
	NSMutableArray <NSString *> *otherBackgroundSessionIdentifiers = nil;

	@synchronized(_queuedSessionCompletionHandlersByIdentifiers)
	{
		for (NSString *backgroundSessionIdentifier in _queuedSessionCompletionHandlersByIdentifiers)
		{
			if ([[self uuidForBackgroundSessionIdentifier:backgroundSessionIdentifier] isEqual:uuid])
			{
				if (![self backgroundSessionOriginatesLocallyForIdentifier:backgroundSessionIdentifier])
				{
					if (otherBackgroundSessionIdentifiers == nil) { otherBackgroundSessionIdentifiers = [NSMutableArray new]; }

					[otherBackgroundSessionIdentifiers addObject:backgroundSessionIdentifier];
				}
			}
		}
	}

	return (otherBackgroundSessionIdentifiers);
}

#pragma mark - State management
- (void)saveState
{
	OCLogDebug(@"Saving state to %@", _persistentStore);

	if (_persistentStore != nil)
	{
		@synchronized(self)
		{
			NSDictionary *state = @{
				@"queuedRequests" : _queuedRequests,

				@"runningRequests" : _runningRequests,
				@"runningRequestsGroupIDs" : _runningRequestsGroupIDs,
				@"runningRequestsByTaskIdentifier" : _runningRequestsByTaskIdentifier,

				@"cachedCertificatesByHostnameAndPort" : _cachedCertificatesByHostnameAndPort,
			};

			_persistentStore[@"state"] = state;

			OCLogDebug(@"Saving state=%@", state);
		}
	}

	OCLogDebug(@"Done saving state to %@", _persistentStore);
}

- (void)restoreState
{
	OCLogDebug(@"Restoring state from %@", _persistentStore);

	if (_persistentStore != nil)
	{
		@synchronized(self)
		{
			NSDictionary *state;

			if ((state = _persistentStore[@"state"]) != nil)
			{
				OCLogDebug(@"Restoring from state=%@", state);

				_queuedRequests = state[@"queuedRequests"];

				_runningRequests = state[@"runningRequests"];
				_runningRequestsGroupIDs = state[@"runningRequestsGroupIDs"];
				_runningRequestsByTaskIdentifier = state[@"runningRequestsByTaskIdentifier"];

				_cachedCertificatesByHostnameAndPort = state[@"cachedCertificatesByHostnameAndPort"];
			}
		}
	}

	OCLogDebug(@"Restored state from %@", _persistentStore);
}

- (void)updateStateWithURLSession
{
	[_urlSession getAllTasksWithCompletionHandler:^(NSArray<NSURLSessionTask *> *tasks) {
		[self _queueBlock:^{
			@synchronized(self)
			{
				NSMutableArray<OCConnectionRequest *> *droppedRequests = [[NSMutableArray alloc] initWithArray:self->_runningRequests];

				// Compare tasks against list of runningRequests
				for (NSURLSessionTask *task in tasks)
				{
					OCConnectionRequest *runningRequest;

					if ((runningRequest = [self requestForTask:task]) != nil)
					{
						// Remove requests that are still running on the NSURLSessionTask
						[droppedRequests removeObjectIdenticalTo:runningRequest];
					}
				}

				// Handle "running" requests dropped by the NSURLSession
				for (OCConnectionRequest *droppedRequest in droppedRequests)
				{
					// End with OCErrorRequestDroppedByURLSession
					[self _handleFinishedRequest:droppedRequest error:OCError(OCErrorRequestDroppedByURLSession) scheduleQueuedRequests:NO];
				}
			}

			// Schedule queued requests
			[self scheduleQueuedRequests];
		}];
	}];
}

@end
