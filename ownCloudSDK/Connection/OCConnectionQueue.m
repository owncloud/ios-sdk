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

- (instancetype)initBackgroundSessionQueueWithIdentifier:(NSString *)identifier connection:(OCConnection *)connection
{
	if ((self = [self init]) != nil)
	{
		_connection = connection;

		_urlSession = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:identifier]
					    delegate:self
					    delegateQueue:nil];
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

		_connection = connection;

		_urlSession = [NSURLSession sessionWithConfiguration:sessionConfiguration
					    delegate:self
					    delegateQueue:nil];
	}
	
	return (self);
}

- (void)dealloc
{
	[_urlSession finishTasksAndInvalidate];
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
						_authenticatedRequestsCanBeScheduled = YES;
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
	
	if (!request.cancelled) // Make sure this request hasn't been cancelled
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
					// Construct NSURLSessionTask
					if (request.downloadRequest)
					{
						// Request is a download request. Make it a download task.
						task = [_urlSession downloadTaskWithRequest:urlRequest];
					}
					else if (request.bodyURL != nil)
					{
						// Body comes from a file. Make it an upload task.
						task = [_urlSession uploadTaskWithStreamedRequest:urlRequest];
					}
					else
					{
						// Create a regular data task
						task = [_urlSession dataTaskWithRequest:urlRequest];
					}

					// Apply priority
					task.priority = request.priority;
				}

				if (task != nil)
				{
					BOOL resumeTask = YES;

					// Save task to request
					request.urlSessionTask = task;
					request.urlSessionTaskIdentifier = @(task.taskIdentifier);

					// Connect task progress to request progress
					[request.progress addChild:task.progress withPendingUnitCount:100];

					// Update internal tracking collections
					if (request.groupID!=nil)
					{
						[_runningRequestsGroupIDs addObject:request.groupID];
					}

					[_runningRequests addObject:request];

					_runningRequestsByTaskIdentifier[request.urlSessionTaskIdentifier] = request;

					// Start task
					if (resumeTask)
					{
						[task resume];
					}
				}
				else
				{
					// Request failure
					error = OCError(OCErrorRequestURLSessionTaskConstructionFailed);
				}
			}
		}
		else
		{
			request = scheduleRequest;
			error = OCError(OCErrorRequestRemovedBeforeScheduling);
		}
	}
	else
	{
		error = OCError(OCErrorRequestCancelled);
	}
	
	if (error != nil)
	{
		// Finish with error
		[self _queueBlock:^{
			[self handleFinishedRequest:request error:error];
		}];
	}
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
			if ((finishRequests = [[NSMutableArray alloc] initWithArray:_queuedRequests]) != nil)
			{
				if (requestFilter!=nil)
				{
					for (OCConnectionRequest *request in _queuedRequests)
					{
						if (!requestFilter(request))
						{
							[finishRequests removeObject:request];
						}
					}
				}
				
				[_queuedRequests removeObjectsInArray:finishRequests];
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
				[_runningRequestsByTaskIdentifier removeObjectForKey:request.urlSessionTaskIdentifier];
			}
		}
	}

	if (scheduleQueuedRequests)
	{
		[self _scheduleQueuedRequests];
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
	// NSLog(@"DID COMPLETE: task=%@ error=%@", task, error);

	[self _queueBlock:^{
		[self handleFinishedRequest:[self requestForTask:task] error:error];
	}];
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
	// Don't allow redirections. Deliver the redirect response instead - these really need to be handled locally on a case-by-case basis.
	if (completionHandler != nil)
	{
		completionHandler(NULL);
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
						[_connection handleValidationOfRequest:request certificate:certificate validationResult:validationResult validationError:validationError proceedHandler:proceedHandler];
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
	NSLog(@"%@: %@ => protection space: %@ method: %@", task.currentRequest.URL, challenge, challenge.protectionSpace, challenge.protectionSpace.authenticationMethod);

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

			if ((request = [self requestForTask:task]) != nil)
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

@end
