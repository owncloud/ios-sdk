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

// Imported to use the identifiers in OCConnectionPreferredAuthenticationMethodIDs only
#import "OCAuthenticationMethodOAuth2.h"
#import "OCAuthenticationMethodBasicAuth.h"

#import "OCChecksumAlgorithmSHA1.h"

@implementation OCConnection

@dynamic authenticationMethod;

@synthesize preferredChecksumAlgorithmIdentifier = _preferredChecksumAlgorithmIdentifier;

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
		OCConnectionMinimumVersionRequired		: @"9.0"
	});
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
		_uploadQueue = _downloadQueue = [[OCConnectionQueue alloc] initBackgroundSessionQueueWithIdentifier:backgroundSessionIdentifier persistentStore:persistentStore connection:self];
		_attachedExtensionQueuesBySessionIdentifier = [NSMutableDictionary new];
		_pendingAuthenticationAvailabilityHandlers = [NSMutableArray new];
		_preferredChecksumAlgorithmIdentifier = OCChecksumAlgorithmIdentifierSHA1;
	}
	
	return (self);
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
			fulfillsBookmarkRequirements = NO;

			if ([_bookmark.certificate isEqual:certificate])
			{
				fulfillsBookmarkRequirements = YES;
			}
		}
	}

	if ((_delegate!=nil) && [_delegate respondsToSelector:@selector(connection:request:certificate:validationResult:validationError:defaultProceedValue:proceedHandler:)])
	{
		// Consult delegate
		[_delegate connection:self request:request certificate:certificate validationResult:validationResult validationError:validationError defaultProceedValue:fulfillsBookmarkRequirements proceedHandler:proceedHandler];
	}
	else
	{
		if (strictBookmarkCertificateEnforcement && defaultWouldProceed && request.forceCertificateDecisionDelegation)
		{
			// strictBookmarkCertificateEnforcement => enfore bookmark certificate where available
			if (proceedHandler != nil)
			{
				NSError *errorIssue = nil;

				if (!fulfillsBookmarkRequirements)
				{
					errorIssue = OCError(OCErrorRequestServerCertificateRejected);

					// Embed issue
					errorIssue = [errorIssue errorByEmbeddingIssue:[OCConnectionIssue issueForCertificate:request.responseCertificate validationResult:validationResult url:request.url level:OCConnectionIssueLevelWarning issueHandler:^(OCConnectionIssue *issue, OCConnectionIssueDecision decision) {
						if (decision == OCConnectionIssueDecisionApprove)
						{
							_bookmark.certificate = request.responseCertificate;
							_bookmark.certificateModificationDate = [NSDate date];
						}
					}]];
				}

				proceedHandler(fulfillsBookmarkRequirements, errorIssue);
			}
		}
		else
		{
			// Default to safe option: reject
			if (proceedHandler != nil)
			{
				proceedHandler(NO, nil);
			}
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
								issue = [OCConnectionIssue issueForRedirectionFromURL:_bookmark.url toSuggestedURL:alternativeBaseURL issueHandler:^(OCConnectionIssue *issue, OCConnectionIssueDecision decision) {
									if (decision == OCConnectionIssueDecisionApprove)
									{
										_bookmark.url = alternativeBaseURL;
									}
								}];
							}
							else
							{
								// Create an error if the redirectURL does not replicate the path of our target URL
								issue = [OCConnectionIssue issueForRedirectionFromURL:_bookmark.url toSuggestedURL:responseRedirectURL issueHandler:nil];
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
					connectProgress.localizedDescription = OCLocalizedString(@"Error", @"");
					completionHandler(error, [OCConnectionIssue issueForError:error level:OCConnectionIssueLevelError issueHandler:nil]);
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
					
					if ((_serverStatus = [request responseBodyConvertedDictionaryFromJSONWithError:&jsonError]) == nil)
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
	OCAuthenticationMethod *authMethod;
	
	if ((authMethod = self.authenticationMethod) != nil)
	{
		// Deauthenticate the connection
		[authMethod deauthenticateConnection:self withCompletionHandler:^(NSError *authConnError, OCConnectionIssue *authConnIssue) {
			self.state = OCConnectionStateDisconnected;

			_serverStatus = nil;

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
- (NSProgress *)retrieveItemListAtPath:(OCPath)path depth:(NSUInteger)depth completionHandler:(void(^)(NSError *error, NSArray <OCItem *> *items))completionHandler
{
	OCConnectionDAVRequest *davRequest;
	NSURL *endpointURL = [self URLForEndpoint:OCConnectionEndpointIDWebDAVRoot options:nil];
	NSURL *url = endpointURL;

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
		]];

		// OCLog(@"%@", davRequest.xmlRequest.XMLString);
		
		[self sendRequest:davRequest toQueue:self.commandQueue ephermalCompletionHandler:^(OCConnectionRequest *request, NSError *error) {
			if ((error==nil) && !request.responseHTTPStatus.isSuccess)
			{
				error = request.responseHTTPStatus.error;
			}

			NSLog(@"Error: %@ - Response: %@", error, request.responseBodyAsString);

			completionHandler(error, [((OCConnectionDAVRequest *)request) responseItemsForBasePath:endpointURL.path]);
		}];
	}

	return(nil);
}

#pragma mark - Actions
- (NSProgress *)createEmptyFile:(NSString *)fileName inside:(OCItem *)parentItem options:(NSDictionary *)options resultTarget:(OCEventTarget *)eventTarget
{
	// Stub implementation
	return(nil);
}

- (NSProgress *)uploadFileFromURL:(NSURL *)url to:(OCItem *)newParentDirectory options:(NSDictionary *)options resultTarget:(OCEventTarget *)eventTarget
{
	// Stub implementation
	return(nil);
}

#pragma mark - File transfer: download
- (NSProgress *)downloadItem:(OCItem *)item to:(NSURL *)targetURL options:(NSDictionary *)options resultTarget:(OCEventTarget *)eventTarget
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

		// Enqueue request
		[self.downloadQueue enqueueRequest:request];

		progress = request.progress;
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
	BOOL postEvent = YES;

	if ((event = [OCEvent eventForEventTarget:request.eventTarget type:OCEventTypeDownload attributes:nil]) != nil)
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

				file.item = request.userInfo[@"item"];

				file.url = request.downloadedFileURL;

				file.checksum = [OCChecksum checksumFromHeaderString:request.response.allHeaderFields[@"oc-checksum"]];

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

	if (postEvent)
	{
		[request.eventTarget handleEvent:event sender:self];
	}
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
	return ([self _copyMoveMethod:OCConnectionRequestMethodMOVE type:OCEventTypeMove item:item to:parentItem withName:newName options:options resultTarget:eventTarget]);
}

- (NSProgress *)copyItem:(OCItem *)item to:(OCItem *)parentItem withName:(NSString *)newName options:(NSDictionary *)options resultTarget:(OCEventTarget *)eventTarget
{
	return ([self _copyMoveMethod:OCConnectionRequestMethodCOPY type:OCEventTypeCopy item:item to:parentItem withName:newName options:options resultTarget:eventTarget]);
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
	dispatch_group_t waitForCompletionGroup = dispatch_group_create();

	dispatch_group_enter(waitForCompletionGroup);
	
	[self sendRequest:request toQueue:queue ephermalCompletionHandler:^(OCConnectionRequest *request, NSError *error) {
		retError = error;
		dispatch_group_leave(waitForCompletionGroup);
	}];
	
	dispatch_group_wait(waitForCompletionGroup, DISPATCH_TIME_FOREVER);

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
	if (backgroundSessionIdentifier == nil) { return; }

	@synchronized(_attachedExtensionQueuesBySessionIdentifier)
	{
		[_attachedExtensionQueuesBySessionIdentifier removeObjectForKey:backgroundSessionIdentifier];
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
