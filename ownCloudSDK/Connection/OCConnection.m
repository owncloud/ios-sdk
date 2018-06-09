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
#import "OCConnectionQueue.h"
#import "OCAuthenticationMethod.h"
#import "NSError+OCError.h"
#import "OCMacros.h"
#import "OCConnectionDAVRequest.h"
#import "OCConnectionIssue.h"
#import "OCLogger.h"
#import "OCItem.h"
#import "NSURL+OCURLQueryParameterExtensions.h"

// Imported to use the identifiers in OCConnectionPreferredAuthenticationMethodIDs only
#import "OCAuthenticationMethodOAuth2.h"
#import "OCAuthenticationMethodBasicAuth.h"

@implementation OCConnection

@dynamic authenticationMethod;

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

- (instancetype)initWithBookmark:(OCBookmark *)bookmark
{
	if ((self = [super init]) != nil)
	{
		self.bookmark = bookmark;
		
		if (self.bookmark.authenticationMethodIdentifier != nil)
		{
			Class authenticationMethodClass;
			
			if ((authenticationMethodClass = [OCAuthenticationMethod registeredAuthenticationMethodForIdentifier:self.bookmark.authenticationMethodIdentifier]) != Nil)
			{
				_authenticationMethod = [authenticationMethodClass new];
			}
		}
			
		_commandQueue = [[OCConnectionQueue alloc] initEphermalQueueWithConnection:self];
		_uploadQueue = _downloadQueue = [[OCConnectionQueue alloc] initBackgroundSessionQueueWithIdentifier:_bookmark.uuid.UUIDString connection:self];
		_pendingAuthenticationAvailabilityHandlers = [NSMutableArray new];
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
- (NSProgress *)createFolderNamed:(NSString *)newFolderName atPath:(OCPath)path options:(NSDictionary *)options resultTarget:(OCEventTarget *)eventTarget
{
	// Stub implementation
	return(nil);
}

- (void)_handleCreateFolderResult:(OCConnectionRequest *)request error:(NSError *)error
{
	
}

- (NSProgress *)createEmptyFileNamed:(NSString *)newFileName atPath:(OCPath)path options:(NSDictionary *)options resultTarget:(OCEventTarget *)eventTarget
{
	// Stub implementation
	return(nil);
}

- (NSProgress *)moveItem:(OCItem *)item to:(OCPath)newParentDirectoryPath resultTarget:(OCEventTarget *)eventTarget
{
	// Stub implementation
	return(nil);
}

- (NSProgress *)copyItem:(OCItem *)item to:(OCPath)newParentDirectoryPath options:(NSDictionary *)options resultTarget:(OCEventTarget *)eventTarget
{
	// Stub implementation
	return(nil);
}

- (NSProgress *)deleteItem:(OCItem *)item resultTarget:(OCEventTarget *)eventTarget
{
	// Stub implementation
	return(nil);
}

- (NSProgress *)uploadFileAtURL:(NSURL *)url to:(OCPath)newParentDirectoryPath resultTarget:(OCEventTarget *)eventTarget
{
	// Stub implementation
	return(nil);
}

- (NSProgress *)downloadItem:(OCItem *)item to:(OCPath)newParentDirectoryPath resultTarget:(OCEventTarget *)eventTarget
{
	// Stub implementation
	return(nil);
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
			item.itemVersionIdentifier,	  	@"itemVersionIdentifier",
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
	else
	{
		
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

				thumbnail.versionIdentifier = itemVersionIdentifier;
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
