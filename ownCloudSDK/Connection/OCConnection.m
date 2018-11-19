//
//  OCConnection.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 05.02.18.
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

#import <MobileCoreServices/MobileCoreServices.h>

#import "OCConnection.h"
#import "OCConnection+OCConnectionQueue.h"
#import "OCConnectionRequest.h"
#import "OCConnectionQueue+BackgroundSessionRecovery.h"
#import "OCAuthenticationMethod.h"
#import "NSError+OCError.h"
#import "OCMacros.h"
#import "OCConnectionDAVRequest.h"
#import "OCConnectionIssue.h"
#import "OCLogger.h"
#import "OCItem.h"
#import "NSURL+OCURLQueryParameterExtensions.h"
#import "NSProgress+OCExtensions.h"
#import "OCFile.h"
#import "NSDate+OCDateParser.h"
#import "OCEvent.h"
#import "NSProgress+OCEvent.h"

// Imported to use the identifiers in OCConnectionPreferredAuthenticationMethodIDs only
#import "OCAuthenticationMethodOAuth2.h"
#import "OCAuthenticationMethodBasicAuth.h"

#import "OCChecksumAlgorithmSHA1.h"

@implementation OCConnection

@dynamic authenticationMethod;

@synthesize preferredChecksumAlgorithm = _preferredChecksumAlgorithm;

@synthesize bookmark = _bookmark;

@synthesize loggedInUser = _loggedInUser;

@synthesize commandQueue = _commandQueue;

@synthesize uploadQueue = _uploadQueue;
@synthesize downloadQueue = _downloadQueue;

@synthesize state = _state;

@synthesize delegate = _delegate;

@synthesize hostSimulator = _hostSimulator;

#pragma mark - Class settings
+ (OCClassSettingsIdentifier)classSettingsIdentifier
{
	return (@"connection");
}

+ (NSDictionary<NSString *,id> *)defaultSettingsForIdentifier:(OCClassSettingsIdentifier)identifier
{
	return (@{
			
		OCConnectionEndpointIDCapabilities  		: @"ocs/v1.php/cloud/capabilities",
		OCConnectionEndpointIDUser			: @"ocs/v1.php/cloud/user",
		OCConnectionEndpointIDWebDAV 	    		: @"remote.php/dav/files",
		OCConnectionEndpointIDStatus 	    		: @"status.php",
		OCConnectionEndpointIDThumbnail			: @"index.php/apps/files/api/v1/thumbnail",
		OCConnectionPreferredAuthenticationMethodIDs 	: @[ OCAuthenticationMethodOAuth2Identifier, OCAuthenticationMethodBasicAuthIdentifier ],
		OCConnectionInsertXRequestTracingID 		: @(YES),
		OCConnectionStrictBookmarkCertificateEnforcement: @(YES),
		OCConnectionMinimumVersionRequired		: @"9.0",
		OCConnectionAllowBackgroundURLSessions		: @(YES)
	});
}

+ (BOOL)backgroundURLSessionsAllowed
{
	return ([[self classSettingForOCClassSettingsKey:OCConnectionAllowBackgroundURLSessions] boolValue]);
}

#pragma mark - Init
- (instancetype)init
{
	return(nil);
}

- (instancetype)initWithBookmark:(OCBookmark *)bookmark persistentStoreBaseURL:(NSURL *)persistentStoreBaseURL
{
	if ((self = [super init]) != nil)
	{
		OCKeyValueStore *persistentStore = nil;
		NSString *backgroundSessionIdentifier = [OCConnectionQueue localBackgroundSessionIdentifierForUUID:bookmark.uuid];

		self.bookmark = bookmark;

		_persistentStoreBaseURL = persistentStoreBaseURL;
		
		if (self.bookmark.authenticationMethodIdentifier != nil)
		{
			Class authenticationMethodClass;
			
			if ((authenticationMethodClass = [OCAuthenticationMethod registeredAuthenticationMethodForIdentifier:self.bookmark.authenticationMethodIdentifier]) != Nil)
			{
				_authenticationMethod = [authenticationMethodClass new];
			}
		}

		if (_persistentStoreBaseURL != nil)
		{
			persistentStore = [[OCKeyValueStore alloc] initWithRootURL:[_persistentStoreBaseURL URLByAppendingPathComponent:backgroundSessionIdentifier]];
		}
			
		_commandQueue = [[OCConnectionQueue alloc] initEphermalQueueWithConnection:self];
		_downloadQueue = [[OCConnectionQueue alloc] initBackgroundSessionQueueWithIdentifier:backgroundSessionIdentifier persistentStore:persistentStore connection:self];
		_uploadQueue = _downloadQueue;
		_attachedExtensionQueuesBySessionIdentifier = [NSMutableDictionary new];
		_pendingAuthenticationAvailabilityHandlers = [NSMutableArray new];
		_preferredChecksumAlgorithm = OCChecksumAlgorithmIdentifierSHA1;
	}
	
	return (self);
}

- (void)dealloc
{
	[_commandQueue invalidateAndCancelWithCompletionHandler:nil];

	[_uploadQueue invalidateAndCancelWithCompletionHandler:nil];

	if (_uploadQueue != _downloadQueue)
	{
		[_downloadQueue invalidateAndCancelWithCompletionHandler:nil];
	}
}

#pragma mark - State
- (void)setState:(OCConnectionState)state
{
	_state = state;

	switch(state)
	{
		case OCConnectionStateConnected:
			OCLogDebug(@"## Connection State changed to CONNECTED");
		break;

		case OCConnectionStateConnecting:
			OCLogDebug(@"## Connection State changed to CONNECTING");
		break;

		case OCConnectionStateDisconnected:
			OCLogDebug(@"## Connection State changed to DISCONNECTED");
		break;
	}
}

#pragma mark - Prepare request
- (OCConnectionRequest *)prepareRequest:(OCConnectionRequest *)request forSchedulingInQueue:(OCConnectionQueue *)queue
{
	// Insert X-Request-ID for tracing
	if ([[self classSettingForOCClassSettingsKey:OCConnectionInsertXRequestTracingID] boolValue])
	{
		NSUUID *uuid;
		
		if ((uuid = [NSUUID UUID]) != nil)
		{
			[request setValue:uuid.UUIDString forHeaderField:@"X-Request-ID"];
		}
	}

	// Authorization
	if (!request.skipAuthorization)
	{
		// Apply authorization to request
		OCAuthenticationMethod *authenticationMethod;
		
		if ((authenticationMethod = self.authenticationMethod) != nil)
		{
			request = [authenticationMethod authorizeRequest:request forConnection:self];
		}
	}

	return (request);
}

#pragma mark - Handle certificate challenges
- (void)handleValidationOfRequest:(OCConnectionRequest *)request certificate:(OCCertificate *)certificate validationResult:(OCCertificateValidationResult)validationResult validationError:(NSError *)validationError proceedHandler:(OCConnectionCertificateProceedHandler)proceedHandler
{
	BOOL defaultWouldProceed = ((validationResult == OCCertificateValidationResultPassed) || (validationResult == OCCertificateValidationResultUserAccepted));
	BOOL fulfillsBookmarkRequirements = defaultWouldProceed;
	BOOL strictBookmarkCertificateEnforcement = [(NSNumber *)[self classSettingForOCClassSettingsKey:OCConnectionStrictBookmarkCertificateEnforcement] boolValue];

	// Strictly enfore bookmark certificate
	if (strictBookmarkCertificateEnforcement)
	{
		if (_bookmark.certificate != nil)
		{
			fulfillsBookmarkRequirements = [_bookmark.certificate isEqual:certificate];
		}
	}

	if ((_delegate!=nil) && [_delegate respondsToSelector:@selector(connection:request:certificate:validationResult:validationError:defaultProceedValue:proceedHandler:)])
	{
		// Consult delegate
		[_delegate connection:self request:request certificate:certificate validationResult:validationResult validationError:validationError defaultProceedValue:fulfillsBookmarkRequirements proceedHandler:proceedHandler];
	}
	else
	{
		if (proceedHandler != nil)
		{
			NSError *errorIssue = nil;
			BOOL doProceed = NO, changeUserAccepted = NO;

			if (strictBookmarkCertificateEnforcement && defaultWouldProceed && request.forceCertificateDecisionDelegation)
			{
				// strictBookmarkCertificateEnforcement => enfore bookmark certificate where available
				doProceed = fulfillsBookmarkRequirements;
			}
			else
			{
				// Default to safe option: reject
				changeUserAccepted = (validationResult == OCCertificateValidationResultPromptUser);
				doProceed = NO;
			}

			if (!doProceed)
			{
				errorIssue = OCError(OCErrorRequestServerCertificateRejected);

				// Embed issue
				errorIssue = [errorIssue errorByEmbeddingIssue:[OCConnectionIssue issueForCertificate:request.responseCertificate validationResult:validationResult url:request.url level:OCConnectionIssueLevelWarning issueHandler:^(OCConnectionIssue *issue, OCConnectionIssueDecision decision) {
					if (decision == OCConnectionIssueDecisionApprove)
					{
						if (changeUserAccepted)
						{
							certificate.userAccepted = YES;
						}

						self->_bookmark.certificate = request.responseCertificate;
						self->_bookmark.certificateModificationDate = [NSDate date];
					}
				}]];
			}

			proceedHandler(doProceed, errorIssue);
		}
	}
}

#pragma mark - Post process request after it finished
- (NSError *)postProcessFinishedRequest:(OCConnectionRequest *)request error:(NSError *)error
{
	if (!request.skipAuthorization)
	{
		OCAuthenticationMethod *authMethod;

		if ((authMethod = self.authenticationMethod) != nil)
		{
			error = [authMethod handleResponse:request forConnection:self withError:error];
		}
	}

	return (error);
}

#pragma mark - Connect & Disconnect
- (NSProgress *)connectWithCompletionHandler:(void(^)(NSError *error, OCConnectionIssue *issue))completionHandler
{
	/*
		Follow the https://github.com/owncloud/administration/tree/master/redirectServer playbook:
	
		1) Check status endpoint
			- if redirection: create issue & complete
			- if error: check bookmark's originURL for redirection, create issue & complete
			- if neither, continue to step 2

		2) (not in the playbook) Call -authenticateConnection:withCompletionHandler: on the authentication method
			- if error / issue: create issue & complete
			- if not, continue to step 3
	 
		3) Make authenticated WebDAV endpoint request
			- if redirection or issue: create issue & complete
			- if neither, complete with success
	*/
	
	OCAuthenticationMethod *authMethod;

	if ((authMethod = self.authenticationMethod) != nil)
	{
		NSProgress *connectProgress = [NSProgress new];
		OCConnectionRequest *statusRequest;

		// Set up progress
		connectProgress.totalUnitCount = connectProgress.completedUnitCount = 0; // Indeterminate
		connectProgress.localizedDescription = OCLocalizedString(@"Connecting…", @"");

		self.state = OCConnectionStateConnecting;

		completionHandler = ^(NSError *error, OCConnectionIssue *issue) {
			if ((error != nil) && (issue != nil))
			{
				self.state = OCConnectionStateDisconnected;
			}

			completionHandler(error, issue);
		};

		// Reusable Completion Handler
		OCConnectionEphermalResultHandler (^CompletionHandlerWithResultHandler)(OCConnectionEphermalResultHandler) = ^(OCConnectionEphermalResultHandler resultHandler)
		{
			return ^(OCConnectionRequest *request, NSError *error){
				if (error == nil)
				{
					if (request.responseHTTPStatus.isSuccess)
					{
						// Success
						resultHandler(request, error);

						return;
					}
					else if (request.responseHTTPStatus.isRedirection)
					{
						// Redirection
						NSURL *responseRedirectURL;
						NSError *error = nil;
						OCConnectionIssue *issue = nil;

						if ((responseRedirectURL = [request responseRedirectURL]) != nil)
						{
							NSURL *alternativeBaseURL;
							
							if ((alternativeBaseURL = [self extractBaseURLFromRedirectionTargetURL:responseRedirectURL originalURL:request.url]) != nil)
							{
								// Create an issue if the redirectURL replicates the path of our target URL
								issue = [OCConnectionIssue issueForRedirectionFromURL:self->_bookmark.url toSuggestedURL:alternativeBaseURL issueHandler:^(OCConnectionIssue *issue, OCConnectionIssueDecision decision) {
									if (decision == OCConnectionIssueDecisionApprove)
									{
										self->_bookmark.url = alternativeBaseURL;
									}
								}];
							}
							else
							{
								// Create an error if the redirectURL does not replicate the path of our target URL
								issue = [OCConnectionIssue issueForRedirectionFromURL:self->_bookmark.url toSuggestedURL:responseRedirectURL issueHandler:nil];
								issue.level = OCConnectionIssueLevelError;

								error = OCErrorWithInfo(OCErrorServerBadRedirection, @{ OCAuthorizationMethodAlternativeServerURLKey : responseRedirectURL });
							}
						}

						connectProgress.localizedDescription = @"";
						completionHandler(error, issue);
						resultHandler(request, error);

						return;
					}
					else
					{
						// Unknown / Unexpected HTTP status => return an error
						error = [request.responseHTTPStatus error];
					}
				}

				if (error != nil)
				{
					// An error occured
					OCConnectionIssue *issue = error.embeddedIssue;

					if (issue == nil)
					{
						issue = [OCConnectionIssue issueForError:error level:OCConnectionIssueLevelError issueHandler:nil];
					}

					connectProgress.localizedDescription = OCLocalizedString(@"Error", @"");
					completionHandler(error, issue);
					resultHandler(request, error);
				}
			};
		};

		// Check status
		if ((statusRequest =  [OCConnectionRequest requestWithURL:[self URLForEndpoint:OCConnectionEndpointIDStatus options:nil]]) != nil)
		{
			[self sendRequest:statusRequest toQueue:self.commandQueue ephermalCompletionHandler:CompletionHandlerWithResultHandler(^(OCConnectionRequest *request, NSError *error) {
				if ((error == nil) && (request.responseHTTPStatus.isSuccess))
				{
					NSError *jsonError = nil;
					
					if ((self->_serverStatus = [request responseBodyConvertedDictionaryFromJSONWithError:&jsonError]) == nil)
					{
						// JSON decode error
						completionHandler(jsonError, [OCConnectionIssue issueForError:jsonError level:OCConnectionIssueLevelError issueHandler:nil]);
					}
					else
					{
						// Got status successfully => now check minimum version + authenticate connection

						// Check minimum version
						{
							NSString *minimumVersion;

							if ((minimumVersion = [self classSettingForOCClassSettingsKey:OCConnectionMinimumVersionRequired]) != nil)
							{
								if (![self runsServerVersionOrHigher:minimumVersion])
								{
									NSError *minimumVersionError = [NSError errorWithDomain:OCErrorDomain code:OCErrorServerVersionNotSupported userInfo:@{
										NSLocalizedDescriptionKey : [NSString stringWithFormat:OCLocalizedString(@"This server runs an unsupported version (%@). Version %@ or later is required by this app.", @""), self.serverLongProductVersionString, minimumVersion]
									}];

									completionHandler(minimumVersionError, [OCConnectionIssue issueForError:minimumVersionError level:OCConnectionIssueLevelError issueHandler:nil]);

									return;
								}
							}
						}

						// Authenticate connection
						connectProgress.localizedDescription = OCLocalizedString(@"Authenticating…", @"");

						[authMethod authenticateConnection:self withCompletionHandler:^(NSError *authConnError, OCConnectionIssue *authConnIssue) {
							if ((authConnError!=nil) || (authConnIssue!=nil))
							{
								// Error or issue
								completionHandler(authConnError, authConnIssue);
							}
							else
							{
								// Connection authenticated. Now send an authenticated WebDAV request
								OCConnectionDAVRequest *davRequest;
								
								davRequest = [OCConnectionDAVRequest propfindRequestWithURL:[self URLForEndpoint:OCConnectionEndpointIDWebDAV options:nil] depth:0];
								
								[davRequest.xmlRequestPropAttribute addChildren:@[
									[OCXMLNode elementWithName:@"D:supported-method-set"],
								]];
								
								// OCLogDebug(@"%@", davRequest.xmlRequest.XMLString);

								[self sendRequest:davRequest toQueue:self.commandQueue ephermalCompletionHandler:CompletionHandlerWithResultHandler(^(OCConnectionRequest *request, NSError *error) {
									if ((error == nil) && (request.responseHTTPStatus.isSuccess))
									{
										// DAV request executed successfully
										connectProgress.localizedDescription = OCLocalizedString(@"Fetching user information…", @"");

										// Get user info
										[self retrieveLoggedInUserWithCompletionHandler:^(NSError *error, OCUser *loggedInUser) {
											self.loggedInUser = loggedInUser;

											connectProgress.localizedDescription = OCLocalizedString(@"Connected", @"");

											if (error!=nil)
											{
												completionHandler(error, [OCConnectionIssue issueForError:error level:OCConnectionIssueLevelError issueHandler:nil]);
											}
											else
											{
												// DONE!
												connectProgress.localizedDescription = OCLocalizedString(@"Connected", @"");

												self.state = OCConnectionStateConnected;

												completionHandler(nil, nil);
											}
										}];
									}
								})];
							}
						}];
					}
				}
			})];
		}
		
		return (connectProgress);
	}
	else
	{
		// Return error
		NSError *error = OCError(OCErrorAuthorizationNoMethodData);
		completionHandler(error, [OCConnectionIssue issueForError:error level:OCConnectionIssueLevelError issueHandler:nil]);
	}

	return (nil);
}

- (void)disconnectWithCompletionHandler:(dispatch_block_t)completionHandler
{
	[self disconnectWithCompletionHandler:completionHandler invalidate:YES];
}

- (void)disconnectWithCompletionHandler:(dispatch_block_t)completionHandler invalidate:(BOOL)invalidateConnection
{
	OCAuthenticationMethod *authMethod;

	if (invalidateConnection)
	{
		dispatch_block_t invalidationCompletionHandler = ^{
			dispatch_group_t waitQueueTerminationGroup = dispatch_group_create();
			NSMutableSet<OCConnectionQueue *> *connectionQueues = [NSMutableSet new];

			// Make sure every queue is finished and invalidated only once (uploadQueue and downloadQueue f.ex. may be the same queue)
			[connectionQueues addObject:self->_uploadQueue];
			[connectionQueues addObject:self->_downloadQueue];
			[connectionQueues addObject:self->_commandQueue];

			if ((self->_attachedExtensionQueuesBySessionIdentifier != nil) && (self->_attachedExtensionQueuesBySessionIdentifier.allValues.count > 0))
			{
				OCLogWarning(@"OCConnection: clearing out attached extension queues before they finished: %@", self->_attachedExtensionQueuesBySessionIdentifier);
				[connectionQueues addObjectsFromArray:self->_attachedExtensionQueuesBySessionIdentifier.allValues];
			}

			for (OCConnectionQueue *connectionQueue in connectionQueues)
			{
				dispatch_group_enter(waitQueueTerminationGroup);

				// Wait for the queue to finish all tasks, then invalidate it and call the invalidation completion handler
				[connectionQueue finishTasksAndInvalidateWithCompletionHandler:^{
					dispatch_group_leave(waitQueueTerminationGroup);
				}];
			}

			// In order for the invalidation completion handlers to trigger, the NSURLSession.delegate must be the only remaining strong reference to
			// the OCConnectionQueue, so drop ours
			self->_uploadQueue = nil;
			self->_downloadQueue = nil;
			self->_commandQueue = nil;
			[self->_attachedExtensionQueuesBySessionIdentifier removeAllObjects];

			// Wait for all invalidation completion handlers to finish executing, then call the provided completionHandler
			dispatch_group_async(waitQueueTerminationGroup, dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
				if (completionHandler!=nil)
				{
					completionHandler();
				}
			});
		};

		completionHandler = invalidationCompletionHandler;
	}

	if ((authMethod = self.authenticationMethod) != nil)
	{
		// Deauthenticate the connection
		[authMethod deauthenticateConnection:self withCompletionHandler:^(NSError *authConnError, OCConnectionIssue *authConnIssue) {
			self.state = OCConnectionStateDisconnected;

			self->_serverStatus = nil;

			if (completionHandler!=nil)
			{
				completionHandler();
			}
		}];
	}
	else
	{
		self.state = OCConnectionStateDisconnected;

		_serverStatus = nil;

		if (completionHandler!=nil)
		{
			completionHandler();
		}
	}
}

#pragma mark - Metadata actions
- (OCConnectionDAVRequest *)_propfindDAVRequestForPath:(OCPath)path endpointURL:(NSURL *)endpointURL depth:(NSUInteger)depth
{
	OCConnectionDAVRequest *davRequest;
	NSURL *url = endpointURL;

	if (endpointURL == nil)
	{
		return (nil);
	}

	if (path != nil)
	{
		url = [url URLByAppendingPathComponent:path];
	}

	if ((davRequest = [OCConnectionDAVRequest propfindRequestWithURL:url depth:depth]) != nil)
	{
		[davRequest.xmlRequestPropAttribute addChildren:@[
			[OCXMLNode elementWithName:@"D:resourcetype"],
			[OCXMLNode elementWithName:@"D:getlastmodified"],
			// [OCXMLNode elementWithName:@"D:creationdate"],
			[OCXMLNode elementWithName:@"D:getcontentlength"],
			// [OCXMLNode elementWithName:@"D:displayname"],
			[OCXMLNode elementWithName:@"D:getcontenttype"],
			[OCXMLNode elementWithName:@"D:getetag"],
			[OCXMLNode elementWithName:@"D:quota-available-bytes"],
			[OCXMLNode elementWithName:@"D:quota-used-bytes"],
			[OCXMLNode elementWithName:@"size" attributes:@[[OCXMLNode namespaceWithName:nil stringValue:@"http://owncloud.org/ns"]]],
			[OCXMLNode elementWithName:@"id" attributes:@[[OCXMLNode namespaceWithName:nil stringValue:@"http://owncloud.org/ns"]]],
			[OCXMLNode elementWithName:@"permissions" attributes:@[[OCXMLNode namespaceWithName:nil stringValue:@"http://owncloud.org/ns"]]],
			[OCXMLNode elementWithName:@"favorite" attributes:@[[OCXMLNode namespaceWithName:nil stringValue:@"http://owncloud.org/ns"]]]

//			[OCXMLNode elementWithName:@"tags" attributes:@[[OCXMLNode namespaceWithName:nil stringValue:@"http://owncloud.org/ns"]]],
//			[OCXMLNode elementWithName:@"share-types" attributes:@[[OCXMLNode namespaceWithName:nil stringValue:@"http://owncloud.org/ns"]]],
//			[OCXMLNode elementWithName:@"comments-count" attributes:@[[OCXMLNode namespaceWithName:nil stringValue:@"http://owncloud.org/ns"]]],
//			[OCXMLNode elementWithName:@"comments-href" attributes:@[[OCXMLNode namespaceWithName:nil stringValue:@"http://owncloud.org/ns"]]],
//			[OCXMLNode elementWithName:@"comments-unread" attributes:@[[OCXMLNode namespaceWithName:nil stringValue:@"http://owncloud.org/ns"]]],
//			[OCXMLNode elementWithName:@"owner-display-name" attributes:@[[OCXMLNode namespaceWithName:nil stringValue:@"http://owncloud.org/ns"]]]
		]];
	}

	return (davRequest);
}

- (NSProgress *)retrieveItemListAtPath:(OCPath)path depth:(NSUInteger)depth completionHandler:(void(^)(NSError *error, NSArray <OCItem *> *items))completionHandler
{
	OCConnectionDAVRequest *davRequest;
	NSURL *endpointURL = [self URLForEndpoint:OCConnectionEndpointIDWebDAVRoot options:nil];
	NSProgress *progress = nil;

	if ((davRequest = [self _propfindDAVRequestForPath:path endpointURL:endpointURL depth:depth]) != nil)
	{
		[self sendRequest:davRequest toQueue:self.commandQueue ephermalCompletionHandler:^(OCConnectionRequest *request, NSError *error) {
			if ((error==nil) && !request.responseHTTPStatus.isSuccess)
			{
				error = request.responseHTTPStatus.error;
			}

			OCLogDebug(@"Error: %@ - Response: %@", error, request.responseBodyAsString);

			completionHandler(error, [((OCConnectionDAVRequest *)request) responseItemsForBasePath:endpointURL.path]);
		}];

		progress = davRequest.progress;
		progress.eventType = OCEventTypeRetrieveItemList;
		progress.localizedDescription = [NSString stringWithFormat:OCLocalized(@"Retrieving file list for %@…"), path];
	}
	else
	{
		if (completionHandler != nil)
		{
			completionHandler(OCError(OCErrorInternal), nil);
		}
	}

	return(progress);
}

- (NSProgress *)retrieveItemListAtPath:(OCPath)path depth:(NSUInteger)depth notBefore:(NSDate *)notBeforeDate options:(NSDictionary<OCConnectionOptionKey,id> *)options resultTarget:(OCEventTarget *)eventTarget
{
	OCConnectionDAVRequest *davRequest;
	NSProgress *progress = nil;
	NSURL *endpointURL = [self URLForEndpoint:OCConnectionEndpointIDWebDAVRoot options:nil];

	if ((davRequest = [self _propfindDAVRequestForPath:path endpointURL:endpointURL depth:depth]) != nil)
	{
		davRequest.resultHandlerAction = @selector(_handleRetrieveItemListAtPathResult:error:);
		davRequest.userInfo = @{
			@"path" : path,
			@"depth" : @(depth),
			@"endpointURL" : endpointURL,
			@"options" : ((options != nil) ? options : [NSNull null])
		};
		davRequest.eventTarget = eventTarget;
		davRequest.downloadRequest = YES;
		davRequest.earliestBeginDate = notBeforeDate;
		davRequest.downloadedFileIsTemporary = YES;

		if (options[OCConnectionOptionRequestObserverKey] != nil)
		{
			davRequest.requestObserver = options[OCConnectionOptionRequestObserverKey];
		}

		// Enqueue request
		[self.downloadQueue enqueueRequest:davRequest];

		progress = davRequest.progress;
		progress.eventType = OCEventTypeRetrieveItemList;
		progress.localizedDescription = [NSString stringWithFormat:OCLocalized(@"Retrieving file list for %@…"), path];
	}
	else
	{
		[eventTarget handleError:OCError(OCErrorInternal) type:OCEventTypeRetrieveItemList sender:self];
	}

	return(progress);
}

- (void)_handleRetrieveItemListAtPathResult:(OCConnectionRequest *)request error:(NSError *)error
{
	OCEvent *event;
	NSDictionary<OCConnectionOptionKey,id> *options = [request.userInfo[@"options"] isKindOfClass:[NSDictionary class]] ? request.userInfo[@"options"] : nil;
	OCEventType eventType = OCEventTypeRetrieveItemList;

	if ((options!=nil) && (options[@"alternativeEventType"]!=nil))
	{
		eventType = (OCEventType)[options[@"alternativeEventType"] integerValue];
	}

	if ((event = [OCEvent eventForEventTarget:request.eventTarget type:eventType attributes:nil]) != nil)
	{
		if (request.error != nil)
		{
			event.error = request.error;
		}
		else
		{
			NSURL *endpointURL = request.userInfo[@"endpointURL"];

			if ((error==nil) && !request.responseHTTPStatus.isSuccess)
			{
				event.error = request.responseHTTPStatus.error;
			}

			OCLogDebug(@"Error: %@ - Response: %@", OCLogPrivate(error), ((request.downloadRequest && (request.downloadedFileURL != nil)) ? OCLogPrivate([NSString stringWithContentsOfURL:request.downloadedFileURL encoding:NSUTF8StringEncoding error:NULL]) : nil));

			switch (eventType)
			{
				case OCEventTypeUpload:
					event.result = [((OCConnectionDAVRequest *)request) responseItemsForBasePath:endpointURL.path].firstObject;
				break;

				default:
					event.path = request.userInfo[@"path"];
					event.depth = [(NSNumber *)request.userInfo[@"depth"] unsignedIntegerValue];

					event.result = [((OCConnectionDAVRequest *)request) responseItemsForBasePath:endpointURL.path];
				break;
			}
		}

		[request.eventTarget handleEvent:event sender:self];
	}
}

#pragma mark - Actions

#pragma mark - File transfer: upload
- (NSProgress *)uploadFileFromURL:(NSURL *)sourceURL withName:(NSString *)fileName to:(OCItem *)newParentDirectory replacingItem:(OCItem *)replacedItem options:(NSDictionary<OCConnectionOptionKey,id> *)options resultTarget:(OCEventTarget *)eventTarget
{
	NSProgress *progress = nil;
	NSURL *uploadURL;

	if ((sourceURL == nil) || (newParentDirectory == nil))
	{
		return(nil);
	}

	if (fileName == nil)
	{
		if (replacedItem != nil)
		{
			fileName = replacedItem.name;
		}
		else
		{
			fileName = sourceURL.lastPathComponent;
		}
	}

	if ((uploadURL = [[[self URLForEndpoint:OCConnectionEndpointIDWebDAVRoot options:nil] URLByAppendingPathComponent:newParentDirectory.path] URLByAppendingPathComponent:fileName]) != nil)
	{
		OCConnectionRequest *request = [OCConnectionRequest requestWithURL:uploadURL];

		request.method = OCConnectionRequestMethodPUT;

		// Set Content-Type
		[request setValue:@"application/octet-stream" forHeaderField:@"Content-Type"];

		// Set conditions
		if (replacedItem != nil)
		{
			// Ensure the upload fails if there's a different version at the target already
			[request setValue:replacedItem.eTag forHeaderField:@"If-Match"];
		}
		else
		{
			// Ensure the upload fails if there's any file at the target already
			[request setValue:@"*" forHeaderField:@"If-None-Match"];
		}

		// Set Content-Length
		NSNumber *fileSize = nil;
		if ([sourceURL getResourceValue:&fileSize forKey:NSURLFileSizeKey error:NULL])
		{
			OCLogDebug(@"Uploading file %@ (%@ bytes)..", OCLogPrivate(fileName), fileSize);
			[request setValue:fileSize.stringValue forHeaderField:@"Content-Length"];
		}

		// Set modification date
		NSDate *modDate = nil;
		if ([sourceURL getResourceValue:&modDate forKey:NSURLAttributeModificationDateKey error:NULL])
		{
			[request setValue:[@((SInt64)[modDate timeIntervalSince1970]) stringValue] forHeaderField:@"X-OC-Mtime"];
		}

		// Compute and set checksum header
		OCChecksumHeaderString checksumHeaderValue = nil;
		__block OCChecksum *checksum = nil;

		if ((checksum = options[OCConnectionOptionChecksumKey]) == nil)
		{
			OCChecksumAlgorithmIdentifier checksumAlgorithmIdentifier = options[OCConnectionOptionChecksumAlgorithmKey];

			if (checksumAlgorithmIdentifier==nil)
			{
				checksumAlgorithmIdentifier = _preferredChecksumAlgorithm;
			}

			OCSyncExec(checksumComputation, {
				[OCChecksum computeForFile:sourceURL checksumAlgorithm:checksumAlgorithmIdentifier completionHandler:^(NSError *error, OCChecksum *computedChecksum) {
					checksum = computedChecksum;
					OCSyncExecDone(checksumComputation);
				}];
			});
		}

		if ((checksum != nil) && ((checksumHeaderValue = checksum.headerString) != nil))
		{
			[request setValue:checksumHeaderValue forHeaderField:@"OC-Checksum"];
		}

		// Set meta data for handling
		request.resultHandlerAction = @selector(_handleUploadFileResult:error:);
		request.userInfo = @{
			@"sourceURL" : sourceURL,
			@"fileName" : fileName,
			@"parentItem" : newParentDirectory,
			@"modDate" : modDate,
			@"fileSize" : fileSize
		};
		request.eventTarget = eventTarget;
		request.bodyURL = sourceURL;

		// Enqueue request
		if (options[OCConnectionOptionRequestObserverKey] != nil)
		{
			request.requestObserver = options[OCConnectionOptionRequestObserverKey];
		}

		[self.uploadQueue enqueueRequest:request];

		progress = request.progress;
		progress.eventType = OCEventTypeUpload;
		progress.localizedDescription = [NSString stringWithFormat:OCLocalized(@"Uploading %@…"), fileName];
	}
	else
	{
		[eventTarget handleError:OCError(OCErrorInternal) type:OCEventTypeUpload sender:self];
	}

	return(progress);
}

- (void)_handleUploadFileResult:(OCConnectionRequest *)request error:(NSError *)error
{
	if (request.responseHTTPStatus.isSuccess)
	{
		NSString *fileName = request.userInfo[@"fileName"];
		OCItem *parentItem = request.userInfo[@"parentItem"];

		/*
			Almost there! Only lacking permissions and mime type and we'd not have to do this PROPFIND 0.

			{
			    "Cache-Control" = "no-store, no-cache, must-revalidate";
			    "Content-Length" = 0;
			    "Content-Type" = "text/html; charset=UTF-8";
			    Date = "Tue, 31 Jul 2018 09:35:22 GMT";
			    Etag = "\"b4e54628946633eba3a601228e638f21\"";
			    Expires = "Thu, 19 Nov 1981 08:52:00 GMT";
			    Pragma = "no-cache";
			    Server = Apache;
			    "Strict-Transport-Security" = "max-age=15768000; preload";
			    "content-security-policy" = "default-src 'none';";
			    "oc-etag" = "\"b4e54628946633eba3a601228e638f21\"";
			    "oc-fileid" = 00000066ocxll7pjzvku;
			    "x-content-type-options" = nosniff;
			    "x-download-options" = noopen;
			    "x-frame-options" = SAMEORIGIN;
			    "x-permitted-cross-domain-policies" = none;
			    "x-robots-tag" = none;
			    "x-xss-protection" = "1; mode=block";
			}
		*/

		// Retrieve item information and continue in _handleUploadFileItemResult:error:
		[self retrieveItemListAtPath:[parentItem.path stringByAppendingPathComponent:fileName] depth:0 notBefore:nil options:@{
			@"alternativeEventType"  : @(OCEventTypeUpload),
			@"_originalUserInfo"	: request.userInfo
		} resultTarget:request.eventTarget];
	}
	else
	{
		OCEvent *event = nil;

		if ((event = [OCEvent eventForEventTarget:request.eventTarget type:OCEventTypeUpload attributes:nil]) != nil)
		{
			if (request.error != nil)
			{
				event.error = request.error;
			}
			else
			{
				event.error = request.responseHTTPStatus.error;
			}

			[request.eventTarget handleEvent:event sender:self];
		}
	}
}

#pragma mark - File transfer: download
- (NSProgress *)downloadItem:(OCItem *)item to:(NSURL *)targetURL options:(NSDictionary<OCConnectionOptionKey,id> *)options resultTarget:(OCEventTarget *)eventTarget
{
	NSProgress *progress = nil;
	NSURL *downloadURL;

	if (item == nil)
	{
		return(nil);
	}

	if ((downloadURL = [[self URLForEndpoint:OCConnectionEndpointIDWebDAVRoot options:nil] URLByAppendingPathComponent:item.path]) != nil)
	{
		OCConnectionRequest *request = [OCConnectionRequest requestWithURL:downloadURL];

		request.method = OCConnectionRequestMethodGET;

		request.resultHandlerAction = @selector(_handleDownloadItemResult:error:);
		request.userInfo = @{
			@"item" : item
		};
		request.eventTarget = eventTarget;
		request.downloadRequest = YES;
		request.downloadedFileURL = targetURL;
		request.downloadedFileIsTemporary = (targetURL == nil);

		[request setValue:item.eTag forHeaderField:@"If-Match"];

		if (options[OCConnectionOptionRequestObserverKey] != nil)
		{
			request.requestObserver = options[OCConnectionOptionRequestObserverKey];
		}

		// Enqueue request
		[self.downloadQueue enqueueRequest:request];

		progress = request.progress;
		progress.eventType = OCEventTypeDownload;
		progress.localizedDescription = [NSString stringWithFormat:OCLocalized(@"Downloading %@…"), item.name];
	}
	else
	{
		[eventTarget handleError:OCError(OCErrorInternal) type:OCEventTypeDownload sender:self];
	}

	return(progress);
}

- (void)_handleDownloadItemResult:(OCConnectionRequest *)request error:(NSError *)error
{
	OCEvent *event;

	if ((event = [OCEvent eventForEventTarget:request.eventTarget type:OCEventTypeDownload attributes:nil]) != nil)
	{
		if (request.cancelled)
		{
			event.error = OCError(OCErrorCancelled);
		}
		else
		{
			if (request.error != nil)
			{
				event.error = request.error;
			}
			else
			{
				if (request.responseHTTPStatus.isSuccess)
				{
					OCFile *file = [OCFile new];
					OCChecksumHeaderString checksumString;

					file.item = request.userInfo[@"item"];

					file.url = request.downloadedFileURL;

					if ((checksumString = request.response.allHeaderFields[@"oc-checksum"]) != nil)
					{
						file.checksum = [OCChecksum checksumFromHeaderString:checksumString];
					}

					file.eTag = request.response.allHeaderFields[@"oc-etag"];
					file.fileID = file.item.fileID;

					event.file = file;
				}
				else
				{
					switch (request.responseHTTPStatus.code)
					{
						default:
							event.error = request.responseHTTPStatus.error;
						break;
					}
				}
			}
		}

		[request.eventTarget handleEvent:event sender:self];
	}
}

#pragma mark - Action: Item update
- (NSProgress *)updateItem:(OCItem *)item properties:(NSArray <OCItemPropertyName> *)properties options:(NSDictionary *)options resultTarget:(OCEventTarget *)eventTarget
{
	NSProgress *progress = nil;
	NSURL *itemURL;

	if ((itemURL = [[self URLForEndpoint:OCConnectionEndpointIDWebDAVRoot options:nil] URLByAppendingPathComponent:item.path]) != nil)
	{
		OCXMLNode *setPropNode = [OCXMLNode elementWithName:@"D:prop"];
		OCXMLNode *removePropNode = [OCXMLNode elementWithName:@"D:prop"];
		NSMutableArray <OCXMLNode *> *contentNodes = [NSMutableArray new];
		NSMutableDictionary <OCItemPropertyName, NSString *> *responseTagsByPropertyName = [NSMutableDictionary new];

		for (OCItemPropertyName propertyName in properties)
		{
			// Favorite
			if ([propertyName isEqualToString:OCItemPropertyNameIsFavorite])
			{
				if ([item.isFavorite isEqual:@(1)])
				{
					// Set favorite
					[setPropNode addChild:[OCXMLNode elementWithName:@"favorite" attributes:@[[OCXMLNode namespaceWithName:nil stringValue:@"http://owncloud.org/ns"]] stringValue:@"1"]];
				}
				else
				{
					// Remove favorite
					[removePropNode addChild:[OCXMLNode elementWithName:@"favorite" attributes:@[[OCXMLNode namespaceWithName:nil stringValue:@"http://owncloud.org/ns"]]]];
				}

				responseTagsByPropertyName[OCItemPropertyNameIsFavorite] = @"oc:favorite";
			}

			// Last modified
			if ([propertyName isEqualToString:OCItemPropertyNameLastModified])
			{
				// Set last modified date
				[setPropNode addChild:[OCXMLNode elementWithName:@"D:lastmodified" stringValue:[item.lastModified davDateString]]];

				responseTagsByPropertyName[OCItemPropertyNameLastModified] = @"d:lastmodified";
			}
		}

		if (setPropNode.children.count > 0)
		{
			OCXMLNode *setNode = [OCXMLNode elementWithName:@"D:set"];

			[setNode addChild:setPropNode];
			[contentNodes addObject:setNode];
		}

		if (removePropNode.children.count > 0)
		{
			OCXMLNode *removeNode = [OCXMLNode elementWithName:@"D:remove"];

			[removeNode addChild:removePropNode];
			[contentNodes addObject:removeNode];
		}

		if (contentNodes.count > 0)
		{
			OCConnectionDAVRequest *patchRequest;

			if ((patchRequest = [OCConnectionDAVRequest proppatchRequestWithURL:itemURL content:contentNodes]) != nil)
			{
				patchRequest.resultHandlerAction = @selector(_handleUpdateItemResult:error:);
				patchRequest.userInfo = @{
					@"item" : item,
					@"properties" : properties,
					@"responseTagsByPropertyName" : responseTagsByPropertyName
				};
				patchRequest.eventTarget = eventTarget;

				OCLogDebug(@"PROPPATCH XML: %@", patchRequest.xmlRequest.XMLString);

				// Enqueue request
				[self.commandQueue enqueueRequest:patchRequest];

				progress = patchRequest.progress;
				progress.eventType = OCEventTypeUpdate;
				progress.localizedDescription = [NSString stringWithFormat:OCLocalized(@"Updating metadata for '%@'…"), item.name];
			}
		}
		else
		{
			[eventTarget handleError:OCError(OCErrorInsufficientParameters) type:OCEventTypeUpdate sender:self];
		}
	}
	else
	{
		[eventTarget handleError:OCError(OCErrorInternal) type:OCEventTypeUpdate sender:self];
	}

	return (progress);
}

- (void)_handleUpdateItemResult:(OCConnectionRequest *)request error:(NSError *)error
{
	OCEvent *event;
	NSURL *endpointURL = [self URLForEndpoint:OCConnectionEndpointIDWebDAVRoot options:nil];

	OCLogDebug(@"Update response: %@", request.responseBodyAsString);

	if ((event = [OCEvent eventForEventTarget:request.eventTarget type:OCEventTypeUpdate attributes:nil]) != nil)
	{
		if (request.error != nil)
		{
			event.error = request.error;
		}
		else
		{
			if (request.responseHTTPStatus.isSuccess)
			{
				NSDictionary <OCPath, OCConnectionDAVMultistatusResponse *> *multistatusResponsesByPath;
				NSDictionary <OCItemPropertyName, NSString *> *responseTagsByPropertyName = request.userInfo[@"responseTagsByPropertyName"];

				if (((multistatusResponsesByPath = [((OCConnectionDAVRequest *)request) multistatusResponsesForBasePath:endpointURL.path]) != nil) && (responseTagsByPropertyName != nil))
				{
					OCConnectionDAVMultistatusResponse *multistatusResponse;

					OCLogDebug(@"Response parsed: %@", multistatusResponsesByPath);

					if ((multistatusResponse = multistatusResponsesByPath.allValues.firstObject) != nil)
					{
						OCConnectionPropertyUpdateResult propertyUpdateResults = [NSMutableDictionary new];

						// Success
						[responseTagsByPropertyName enumerateKeysAndObjectsUsingBlock:^(OCItemPropertyName  _Nonnull propertyName, NSString * _Nonnull tagName, BOOL * _Nonnull stop) {
							OCHTTPStatus *status;

							if ((status = [multistatusResponse statusForProperty:tagName]) != nil)
							{
								((NSMutableDictionary *)propertyUpdateResults)[propertyName] = status;
							}
						}];

						event.result = propertyUpdateResults;
					}
				}

				if (event.result == nil)
				{
					event.error = OCError(OCErrorInternal);
				}
			}
			else
			{
				event.error = request.responseHTTPStatus.error;
			}
		}
	}

	[request.eventTarget handleEvent:event sender:self];
}

#pragma mark - Action: Create Directory
- (NSProgress *)createFolder:(NSString *)folderName inside:(OCItem *)parentItem options:(NSDictionary *)options resultTarget:(OCEventTarget *)eventTarget;
{
	NSProgress *progress = nil;
	NSURL *createFolderURL;
	OCPath fullFolderPath = nil;

	if ((parentItem==nil) || (folderName==nil))
	{
		return(nil);
	}

	fullFolderPath =  [parentItem.path stringByAppendingPathComponent:folderName];

	if ((createFolderURL = [[self URLForEndpoint:OCConnectionEndpointIDWebDAVRoot options:nil] URLByAppendingPathComponent:fullFolderPath]) != nil)
	{
		OCConnectionRequest *request = [OCConnectionRequest requestWithURL:createFolderURL];

		request.method = OCConnectionRequestMethodMKCOL;

		request.resultHandlerAction = @selector(_handleCreateFolderResult:error:);
		request.userInfo = @{
			@"parentItem" : parentItem,
			@"folderName" : folderName,
			@"fullFolderPath" : fullFolderPath
		};
		request.eventTarget = eventTarget;

		// Enqueue request
		[self.commandQueue enqueueRequest:request];

		progress = request.progress;
		progress.eventType = OCEventTypeCreateFolder;
		progress.localizedDescription = [NSString stringWithFormat:OCLocalized(@"Creating folder %@…"), folderName];
	}
	else
	{
		[eventTarget handleError:OCError(OCErrorInternal) type:OCEventTypeCreateFolder sender:self];
	}

	return(progress);
}

- (void)_handleCreateFolderResult:(OCConnectionRequest *)request error:(NSError *)error
{
	OCEvent *event;
	BOOL postEvent = YES;

	if ((event = [OCEvent eventForEventTarget:request.eventTarget type:OCEventTypeCreateFolder attributes:nil]) != nil)
	{
		if (request.error != nil)
		{
			event.error = request.error;
		}
		else
		{
			OCPath fullFolderPath = request.userInfo[@"fullFolderPath"];
			OCItem *parentItem = request.userInfo[@"parentItem"];

			if (request.responseHTTPStatus.code == OCHTTPStatusCodeCREATED)
			{
				postEvent = NO; // Wait until all info on the new item has been received

				// Retrieve all details on the new folder (OC server returns an "Oc-Fileid" in the HTTP headers, but we really need the full set here)
				[self retrieveItemListAtPath:fullFolderPath depth:0 completionHandler:^(NSError *error, NSArray<OCItem *> *items) {
					OCItem *newFolderItem = items.firstObject;

					newFolderItem.parentFileID = parentItem.fileID;

					if (error == nil)
					{
						event.result = newFolderItem;
					}
					else
					{
						event.error = error;
					}

					// Post event
					[request.eventTarget handleEvent:event sender:self];
				}];
			}
			else
			{
				switch (request.responseHTTPStatus.code)
				{
					default:
						event.error = request.responseHTTPStatus.error;
					break;
				}
			}
		}
	}

	if (postEvent)
	{
		[request.eventTarget handleEvent:event sender:self];
	}
}

#pragma mark - Action: Copy Item + Move Item
- (NSProgress *)moveItem:(OCItem *)item to:(OCItem *)parentItem withName:(NSString *)newName options:(NSDictionary *)options resultTarget:(OCEventTarget *)eventTarget
{
	NSProgress *progress;

	if ((progress = [self _copyMoveMethod:OCConnectionRequestMethodMOVE type:OCEventTypeMove item:item to:parentItem withName:newName options:options resultTarget:eventTarget]) != nil)
	{
		progress.eventType = OCEventTypeMove;

		if ([item.parentFileID isEqualToString:parentItem.fileID])
		{
			progress.localizedDescription = [NSString stringWithFormat:OCLocalized(@"Renaming %@ to %@…"), item.name, newName];
		}
		else
		{
			progress.localizedDescription = [NSString stringWithFormat:OCLocalized(@"Moving %@ to %@…"), item.name, parentItem.name];
		}
	}

	return (progress);
}

- (NSProgress *)copyItem:(OCItem *)item to:(OCItem *)parentItem withName:(NSString *)newName options:(NSDictionary *)options resultTarget:(OCEventTarget *)eventTarget
{
	NSProgress *progress;

	if ((progress = [self _copyMoveMethod:OCConnectionRequestMethodCOPY type:OCEventTypeCopy item:item to:parentItem withName:newName options:options resultTarget:eventTarget]) != nil)
	{
		progress.eventType = OCEventTypeCopy;
		progress.localizedDescription = [NSString stringWithFormat:OCLocalized(@"Copying %@ to %@…"), item.name, parentItem.name];
	}

	return (progress);
}

- (NSProgress *)_copyMoveMethod:(OCConnectionRequestMethod)requestMethod type:(OCEventType)eventType item:(OCItem *)item to:(OCItem *)parentItem withName:(NSString *)newName options:(NSDictionary *)options resultTarget:(OCEventTarget *)eventTarget
{
	NSProgress *progress = nil;
	NSURL *sourceItemURL, *destinationURL;
	NSURL *webDAVRootURL = [self URLForEndpoint:OCConnectionEndpointIDWebDAVRoot options:nil];

	if ((sourceItemURL = [webDAVRootURL URLByAppendingPathComponent:item.path]) != nil)
	{
		if ((destinationURL = [[webDAVRootURL URLByAppendingPathComponent:parentItem.path] URLByAppendingPathComponent:newName]) != nil)
		{
			OCConnectionRequest *request = [OCConnectionRequest requestWithURL:sourceItemURL];

			request.method = requestMethod;

			request.resultHandlerAction = @selector(_handleCopyMoveItemResult:error:);
			request.eventTarget = eventTarget;
			request.userInfo = @{
				@"item" : item,
				@"parentItem" : parentItem,
				@"newName" : newName,
				@"eventType" : @(eventType)
			};

			[request setValue:[destinationURL absoluteString] forHeaderField:@"Destination"];
			[request setValue:@"infinity" forHeaderField:@"Depth"];
			[request setValue:@"F" forHeaderField:@"Overwrite"]; // "F" for False, "T" for True

			// Enqueue request
			[self.commandQueue enqueueRequest:request];

			progress = request.progress;
		}
	}
	else
	{
		[eventTarget handleError:OCError(OCErrorInternal) type:eventType sender:self];
	}

	return(progress);
}

- (void)_handleCopyMoveItemResult:(OCConnectionRequest *)request error:(NSError *)error
{
	OCEvent *event;
	BOOL postEvent = YES;
	OCEventType eventType = (OCEventType) ((NSNumber *)request.userInfo[@"eventType"]).integerValue;

	if ((event = [OCEvent eventForEventTarget:request.eventTarget type:eventType attributes:nil]) != nil)
	{
		if (request.error != nil)
		{
			event.error = request.error;
		}
		else
		{
			OCItem *item = request.userInfo[@"item"];
			OCItem *parentItem = request.userInfo[@"parentItem"];
			NSString *newName = request.userInfo[@"newName"];
			NSString *newFullPath = [parentItem.path stringByAppendingPathComponent:newName];

			if ((item.type == OCItemTypeCollection) && (![newFullPath hasSuffix:@"/"]))
			{
				newFullPath = [newFullPath stringByAppendingString:@"/"];
			}

			if (request.responseHTTPStatus.code == OCHTTPStatusCodeCREATED)
			{
				postEvent = NO; // Wait until all info on the new item has been received

				// Retrieve all details on the new item
				[self retrieveItemListAtPath:newFullPath depth:0 completionHandler:^(NSError *error, NSArray<OCItem *> *items) {
					OCItem *newItem = items.firstObject;

					newItem.parentFileID = parentItem.fileID;

					if (error == nil)
					{
						event.result = newItem;
					}
					else
					{
						event.error = error;
					}

					// Post event
					[request.eventTarget handleEvent:event sender:self];
				}];
			}
			else
			{
				switch (request.responseHTTPStatus.code)
				{
					case OCHTTPStatusCodeFORBIDDEN:
						event.error = OCError(OCErrorItemOperationForbidden);
					break;

					case OCHTTPStatusCodeNOT_FOUND:
						event.error = OCError(OCErrorItemNotFound);
					break;

					case OCHTTPStatusCodeCONFLICT:
						event.error = OCError(OCErrorItemDestinationNotFound);
					break;

					case OCHTTPStatusCodePRECONDITION_FAILED:
						event.error = OCError(OCErrorItemAlreadyExists);
					break;

					case OCHTTPStatusCodeBAD_GATEWAY:
						event.error = OCError(OCErrorItemInsufficientPermissions);
					break;

					default:
						event.error = request.responseHTTPStatus.error;
					break;
				}
			}
		}
	}

	if (postEvent)
	{
		[request.eventTarget handleEvent:event sender:self];
	}
}

#pragma mark - Action: Delete Item
- (NSProgress *)deleteItem:(OCItem *)item requireMatch:(BOOL)requireMatch resultTarget:(OCEventTarget *)eventTarget
{
	NSProgress *progress = nil;
	NSURL *deleteItemURL;

	if ((deleteItemURL = [[self URLForEndpoint:OCConnectionEndpointIDWebDAVRoot options:nil] URLByAppendingPathComponent:item.path]) != nil)
	{
		OCConnectionRequest *request = [OCConnectionRequest requestWithURL:deleteItemURL];

		request.method = OCConnectionRequestMethodDELETE;

		request.resultHandlerAction = @selector(_handleDeleteItemResult:error:);
		request.eventTarget = eventTarget;

		if (requireMatch && (item.eTag!=nil))
		{
			if (item.type != OCItemTypeCollection) // Right now, If-Match returns a 412 response when used with directories. This appears to be a bug. TODO: enforce this for directories as well when future versions address the issue
			{
				[request setValue:item.eTag forHeaderField:@"If-Match"];
			}
		}

		// Enqueue request
		[self.commandQueue enqueueRequest:request];

		progress = request.progress;

		progress.eventType = OCEventTypeDelete;
		progress.localizedDescription = [NSString stringWithFormat:OCLocalized(@"Deleting %@…"), item.name];
	}
	else
	{
		[eventTarget handleError:OCError(OCErrorInternal) type:OCEventTypeDelete sender:self];
	}

	return(progress);
}

- (void)_handleDeleteItemResult:(OCConnectionRequest *)request error:(NSError *)error
{
	OCEvent *event;

	if ((event = [OCEvent eventForEventTarget:request.eventTarget type:OCEventTypeDelete attributes:nil]) != nil)
	{
		if (request.error != nil)
		{
			event.error = request.error;
		}
		else
		{
			if (request.responseHTTPStatus.isSuccess)
			{
				// Success (at the time of writing (2018-06-18), OC core doesn't support a multi-status response for this
				// command, so this scenario isn't handled here
				event.result = request.responseHTTPStatus;
			}
			else
			{
				switch (request.responseHTTPStatus.code)
				{
					case OCHTTPStatusCodeFORBIDDEN:
						/*
							Status code: 403
							Content-Type: application/xml; charset=utf-8

							<?xml version="1.0" encoding="utf-8"?>
							<d:error xmlns:d="DAV:" xmlns:s="http://sabredav.org/ns">
							  <s:exception>Sabre\DAV\Exception\Forbidden</s:exception>
							  <s:message/>
							</d:error>
						*/
						event.error = OCError(OCErrorItemOperationForbidden);
					break;

					case OCHTTPStatusCodeNOT_FOUND:
						/*
							Status code: 404
							Content-Type: application/xml; charset=utf-8

							<?xml version="1.0" encoding="utf-8"?>
							<d:error xmlns:d="DAV:" xmlns:s="http://sabredav.org/ns">
							  <s:exception>Sabre\DAV\Exception\NotFound</s:exception>
							  <s:message>File with name specfile-9.xml could not be located</s:message>
							</d:error>
						*/
						event.error = OCError(OCErrorItemNotFound);
					break;

					case OCHTTPStatusCodePRECONDITION_FAILED:
						/*
							Status code: 412
							Content-Type: application/xml; charset=utf-8

							<?xml version="1.0" encoding="utf-8"?>
							<d:error xmlns:d="DAV:" xmlns:s="http://sabredav.org/ns">
							  <s:exception>Sabre\DAV\Exception\PreconditionFailed</s:exception>
							  <s:message>An If-Match header was specified, but none of the specified the ETags matched.</s:message>
							  <s:header>If-Match</s:header>
							</d:error>
						*/
						event.error = OCError(OCErrorItemChanged);
					break;

					default:
						event.error = request.responseHTTPStatus.error;
					break;
				}
			}
		}
	}

	[request.eventTarget handleEvent:event sender:self];
}

#pragma mark - Action: Retrieve Thumbnail
- (NSProgress *)retrieveThumbnailFor:(OCItem *)item to:(NSURL *)localThumbnailURL maximumSize:(CGSize)size resultTarget:(OCEventTarget *)eventTarget
{
	NSURL *url = nil;
	OCConnectionRequest *request = nil;
	NSError *error = nil;
	NSProgress *progress = nil;

	if (item.type != OCItemTypeCollection)
	{
		if (self.supportsPreviewAPI)
		{
			// Preview API (OC 10.0.9+)
			url = [self URLForEndpoint:OCConnectionEndpointIDWebDAVRoot options:nil];

			// Add path
			if (item.path != nil)
			{
				url = [url URLByAppendingPathComponent:item.path];
			}

			// Compose request
			request = [OCConnectionRequest requestWithURL:url];

			request.groupID = item.path.stringByDeletingLastPathComponent;
			request.priority = NSURLSessionTaskPriorityLow;

			request.parameters = [NSMutableDictionary dictionaryWithObjectsAndKeys:
				@(size.width).stringValue, 	@"x",
				@(size.height).stringValue,	@"y",
				item.eTag, 			@"c",
				@"1",				@"a", // Request resize respecting aspect ratio 
				@"1", 				@"preview",
			nil];
		}
		else
		{
			// Thumbnail API (OC < 10.0.9)
			url = [self URLForEndpoint:OCConnectionEndpointIDThumbnail options:nil];

			url = [url URLByAppendingPathComponent:[NSString stringWithFormat:@"%d/%d/%@", (int)size.height, (int)size.width, item.path]];

			// Compose request
			request = [OCConnectionRequest requestWithURL:url];
			/*

			// Not supported for OC < 10.0.9
			error = [NSError errorWithOCError:OCErrorFeatureNotSupportedByServer];
			*/
		}
	}
	else
	{
		error = [NSError errorWithOCError:OCErrorFeatureNotSupportedForItem];
	}

	if (request != nil)
	{
		request.eventTarget = eventTarget;
		request.userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
			item.itemVersionIdentifier,	@"itemVersionIdentifier",
			[NSValue valueWithCGSize:size],	@"maximumSize",
		nil];
		request.resultHandlerAction = @selector(_handleRetrieveThumbnailResult:error:);

		if (localThumbnailURL != nil)
		{
			request.downloadRequest = YES;
			request.downloadedFileURL = localThumbnailURL;
		}

		// Enqueue request
		if (request.downloadRequest)
		{
			[self.downloadQueue enqueueRequest:request];
		}
		else
		{
			[self.commandQueue enqueueRequest:request];
		}

		progress = request.progress;
	}

	if (error != nil)
	{
		[eventTarget handleError:error type:OCEventTypeRetrieveThumbnail sender:self];
	}

	return(progress);
}

- (void)_handleRetrieveThumbnailResult:(OCConnectionRequest *)request error:(NSError *)error
{
	OCEvent *event;

	if ((event = [OCEvent eventForEventTarget:request.eventTarget type:OCEventTypeRetrieveThumbnail attributes:nil]) != nil)
	{
		if (request.error != nil)
		{
			event.error = request.error;
		}
		else
		{
			if (request.responseHTTPStatus.isSuccess)
			{
				OCItemThumbnail *thumbnail = [OCItemThumbnail new];
				OCItemVersionIdentifier *itemVersionIdentifier = request.userInfo[@"itemVersionIdentifier"];
				CGSize maximumSize = ((NSValue *)request.userInfo[@"maximumSize"]).CGSizeValue;

				thumbnail.mimeType = request.response.allHeaderFields[@"Content-Type"];

				if (request.responseBodyData != nil)
				{
					thumbnail.data = request.responseBodyData;
				}
				else
				{
					if (request.downloadedFileURL)
					{
						if (request.downloadedFileIsTemporary)
						{
							thumbnail.data = [NSData dataWithContentsOfURL:request.downloadedFileURL];
						}
						else
						{
							thumbnail.url = request.downloadedFileURL;
						}
					}
				}

				thumbnail.itemVersionIdentifier = itemVersionIdentifier;
				thumbnail.maximumSizeInPixels = maximumSize;

				event.result = thumbnail;
			}
			else
			{
				event.error = request.responseHTTPStatus.error;
			}
		}
	}

	[request.eventTarget handleEvent:event sender:self];
}

#pragma mark - Actions
- (NSProgress *)shareItem:(OCItem *)item options:(OCShareOptions)options resultTarget:(OCEventTarget *)eventTarget
{
	// Stub implementation
	return(nil);
}

#pragma mark - Sending requests
- (NSProgress *)sendRequest:(OCConnectionRequest *)request toQueue:(OCConnectionQueue *)queue ephermalCompletionHandler:(OCConnectionEphermalResultHandler)ephermalResultHandler
{
	request.ephermalResultHandler = ephermalResultHandler;
	request.resultHandlerAction = @selector(_handleSendRequestResult:error:);

	// Strictly enfore bookmark certificate ..
	if (self.state != OCConnectionStateDisconnected) // .. for all requests if connecting or connected ..
	{
		BOOL strictBookmarkCertificateEnforcement = [(NSNumber *)[self classSettingForOCClassSettingsKey:OCConnectionStrictBookmarkCertificateEnforcement] boolValue];

		if (strictBookmarkCertificateEnforcement) // .. and the option is turned on
		{

			request.forceCertificateDecisionDelegation = YES;
		}
	}
	
	[queue enqueueRequest:request];
	
	return (request.progress);
}

- (void)_handleSendRequestResult:(OCConnectionRequest *)request error:(NSError *)error
{
	if (request.ephermalResultHandler != nil)
	{
		request.ephermalResultHandler(request, error);
	}
}

#pragma mark - Sending requests synchronously
- (NSError *)sendSynchronousRequest:(OCConnectionRequest *)request toQueue:(OCConnectionQueue *)queue
{
	__block NSError *retError = nil;

	OCSyncExec(requestCompletion, {
		[self sendRequest:request toQueue:queue ephermalCompletionHandler:^(OCConnectionRequest *request, NSError *error) {
			retError = error;
			OCSyncExecDone(requestCompletion);
		}];
	});

	return (retError);
}

#pragma mark - Resume background sessions
- (void)resumeBackgroundSessions
{
	NSArray <NSString *> *otherBackgroundSessionIdentifiers = [OCConnectionQueue otherBackgroundSessionIdentifiersForUUID:self.bookmark.uuid];

	for (NSString *otherBackgroundSessionIdentifier in otherBackgroundSessionIdentifiers)
	{
		OCKeyValueStore *otherPersistentStore = nil;

		if (_persistentStoreBaseURL != nil)
		{
			otherPersistentStore = [[OCKeyValueStore alloc] initWithRootURL:[_persistentStoreBaseURL URLByAppendingPathComponent:otherBackgroundSessionIdentifier]];
		}

		@synchronized(_attachedExtensionQueuesBySessionIdentifier)
		{
			if (_attachedExtensionQueuesBySessionIdentifier[otherBackgroundSessionIdentifier] == nil)
			{
				_attachedExtensionQueuesBySessionIdentifier[otherBackgroundSessionIdentifier] = [[OCConnectionQueue alloc] initBackgroundSessionQueueWithIdentifier:otherBackgroundSessionIdentifier persistentStore:otherPersistentStore connection:self];
			}
		}
	}
}

- (void)finishedQueueForResumedBackgroundSessionWithIdentifier:(NSString *)backgroundSessionIdentifier
{
	OCConnectionQueue *resumedBackgroundConnectionQueue = nil;

	if (backgroundSessionIdentifier == nil) { return; }

	if ((resumedBackgroundConnectionQueue = _attachedExtensionQueuesBySessionIdentifier[backgroundSessionIdentifier]) != nil)
	{
		@synchronized(_attachedExtensionQueuesBySessionIdentifier)
		{
			[_attachedExtensionQueuesBySessionIdentifier removeObjectForKey:backgroundSessionIdentifier];
		}

		[resumedBackgroundConnectionQueue finishTasksAndInvalidateWithCompletionHandler:nil];
	}
}

@end

OCConnectionEndpointID OCConnectionEndpointIDCapabilities = @"endpoint-capabilities";
OCConnectionEndpointID OCConnectionEndpointIDUser = @"endpoint-user";
OCConnectionEndpointID OCConnectionEndpointIDWebDAV = @"endpoint-webdav";
OCConnectionEndpointID OCConnectionEndpointIDWebDAVRoot = @"endpoint-webdav-root";
OCConnectionEndpointID OCConnectionEndpointIDThumbnail = @"endpoint-thumbnail";
OCConnectionEndpointID OCConnectionEndpointIDStatus = @"endpoint-status";

OCClassSettingsKey OCConnectionInsertXRequestTracingID = @"connection-insert-x-request-id";
OCClassSettingsKey OCConnectionPreferredAuthenticationMethodIDs = @"connection-preferred-authentication-methods";
OCClassSettingsKey OCConnectionAllowedAuthenticationMethodIDs = @"connection-allowed-authentication-methods";
OCClassSettingsKey OCConnectionStrictBookmarkCertificateEnforcement = @"connection-strict-bookmark-certificate-enforcement";
OCClassSettingsKey OCConnectionMinimumVersionRequired = @"connection-minimum-server-version";
OCClassSettingsKey OCConnectionAllowBackgroundURLSessions = @"allow-background-url-sessions";

OCConnectionOptionKey OCConnectionOptionRequestObserverKey = @"request-observer";
OCConnectionOptionKey OCConnectionOptionChecksumKey = @"checksum";
OCConnectionOptionKey OCConnectionOptionChecksumAlgorithmKey = @"checksum-algorithm";
