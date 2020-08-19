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

#import <CoreServices/CoreServices.h>

#import "OCConnection.h"
#import "OCHTTPRequest.h"
#import "OCAuthenticationMethod.h"
#import "NSError+OCError.h"
#import "OCMacros.h"
#import "OCHTTPDAVRequest.h"
#import "OCIssue.h"
#import "OCLogger.h"
#import "OCItem.h"
#import "NSURL+OCURLQueryParameterExtensions.h"
#import "NSProgress+OCExtensions.h"
#import "OCFile.h"
#import "NSDate+OCDateParser.h"
#import "OCEvent.h"
#import "NSProgress+OCEvent.h"
#import "OCAppIdentity.h"
#import "OCHTTPPipelineManager.h"
#import "OCHTTPPipelineTask.h"
#import "OCHTTPResponse+DAVError.h"
#import "OCCertificateRuleChecker.h"
#import "OCProcessManager.h"
#import "NSString+OCPath.h"
#import "OCMacros.h"
#import "OCCore.h"
#import "OCCellularManager.h"
#import "OCCellularSwitch.h"
#import "OCHTTPPolicyManager.h"
#import "OCHTTPPolicyBookmark.h"

// Imported to use the identifiers in OCConnectionPreferredAuthenticationMethodIDs only
#import "OCAuthenticationMethodOpenIDConnect.h"
#import "OCAuthenticationMethodOAuth2.h"
#import "OCAuthenticationMethodBasicAuth.h"

#import "OCChecksumAlgorithmSHA1.h"

static OCConnectionSetupHTTPPolicy sSetupHTTPPolicy = OCConnectionSetupHTTPPolicyAuto;

@implementation OCConnection

@dynamic authenticationMethod;

@synthesize partitionID = _partitionID;

@synthesize preferredChecksumAlgorithm = _preferredChecksumAlgorithm;

@synthesize bookmark = _bookmark;

@synthesize loggedInUser = _loggedInUser;
@synthesize capabilities = _capabilities;

@synthesize actionSignals = _actionSignals;
@synthesize propFindSignals = _propFindSignals;
@synthesize authSignals = _authSignals;

@synthesize state = _state;

@synthesize delegate = _delegate;

@synthesize hostSimulator = _hostSimulator;

@dynamic allHTTPPipelines;

#pragma mark - Class settings
+ (OCClassSettingsIdentifier)classSettingsIdentifier
{
	return (@"connection");
}

+ (NSDictionary<NSString *,id> *)defaultSettingsForIdentifier:(OCClassSettingsIdentifier)identifier
{
	return (@{
		OCConnectionEndpointIDWellKnown			: @".well-known",
		OCConnectionEndpointIDCapabilities  		: @"ocs/v2.php/cloud/capabilities",			// Requested once on login
		OCConnectionEndpointIDUser			: @"ocs/v2.php/cloud/user",				// Requested once on login
		OCConnectionEndpointIDWebDAV 	    		: @"remote.php/dav/files",				// Polled in intervals to detect changes to the root directory ETag
		OCConnectionEndpointIDWebDAVMeta 	    	: @"remote.php/dav/meta",				// Metadata DAV endpoint, used for private link resolution
		OCConnectionEndpointIDStatus 	    		: @"status.php",					// Requested during login and polled in intervals during maintenance mode
		OCConnectionEndpointIDThumbnail			: @"index.php/apps/files/api/v1/thumbnail",		// Requested once per item thumbnail request
		OCConnectionEndpointIDShares			: @"ocs/v2.php/apps/files_sharing/api/v1/shares",	// Polled in intervals to detect changes if OCShareQuery is used with the interval option
		OCConnectionEndpointIDRemoteShares		: @"ocs/v2.php/apps/files_sharing/api/v1/remote_shares",// Polled in intervals to detect changes if OCShareQuery is used with the interval option
		OCConnectionEndpointIDRecipients		: @"ocs/v2.php/apps/files_sharing/api/v1/sharees",	// Requested once per search string change when searching for recipients
		OCConnectionPreferredAuthenticationMethodIDs 	: @[ OCAuthenticationMethodIdentifierOpenIDConnect, OCAuthenticationMethodIdentifierOAuth2, OCAuthenticationMethodIdentifierBasicAuth ],
		OCConnectionCertificateExtendedValidationRule	: @"bookmarkCertificate == serverCertificate",
		OCConnectionRenewedCertificateAcceptanceRule	: @"(bookmarkCertificate.publicKeyData == serverCertificate.publicKeyData) OR ((check.parentCertificatesHaveIdenticalPublicKeys == true) AND (serverCertificate.passedValidationOrIsUserAccepted == true))",
		OCConnectionMinimumVersionRequired		: @"10.0",
		OCConnectionAllowBackgroundURLSessions		: @(YES),
		OCConnectionForceBackgroundURLSessions		: @(NO),
		OCConnectionAllowCellular			: @(YES),
		OCConnectionPlainHTTPPolicy			: @"warn",
		OCConnectionAlwaysRequestPrivateLink		: @(NO)
	});
}

+ (BOOL)allowUserPreferenceForClassSettingsKey:(OCClassSettingsKey)key
{
	if ([key isEqualToString:OCConnectionForceBackgroundURLSessions])
	{
		return (YES);
	}

	return (NO);
}

+ (BOOL)backgroundURLSessionsAllowed
{
	if ([[self classSettingForOCClassSettingsKey:OCConnectionForceBackgroundURLSessions] boolValue])
	{
		return (YES);
	}

	if (@available(iOS 13.1, *))
	{
		if (OCVault.hostHasFileProvider && !OCProcessManager.isProcessExtension)
		{
			// Under iOS 13.1.3, the app's background NSURLSession is receiving
			// penalties (in the form of long delays) despite not meeting the
			// criteria for them - and even if running in the foreground. Either
			// this is a bug in general - or background NSURLSession usage of the
			// FileProvider is assessed as if the FileProvider was the app (always in
			// background) and then penalties applied to the app's session.
			return (NO);
		}
	}

	return ([[self classSettingForOCClassSettingsKey:OCConnectionAllowBackgroundURLSessions] boolValue]);
}

+ (BOOL)allowCellular
{
	return ([[self classSettingForOCClassSettingsKey:OCConnectionAllowCellular] boolValue]);
}

+ (void)setSetupHTTPPolicy:(OCConnectionSetupHTTPPolicy)setupHTTPPolicy
{
	sSetupHTTPPolicy = setupHTTPPolicy;
}

+ (OCConnectionSetupHTTPPolicy)setupHTTPPolicy
{
	if (sSetupHTTPPolicy == OCConnectionSetupHTTPPolicyAuto)
	{
 		NSString *policyName = [self classSettingForOCClassSettingsKey:OCConnectionPlainHTTPPolicy];

 		if ([policyName isEqual:@"warn"])
 		{
 			sSetupHTTPPolicy = OCConnectionSetupHTTPPolicyWarn;
		}

 		if ([policyName isEqual:@"forbidden"])
 		{
 			sSetupHTTPPolicy = OCConnectionSetupHTTPPolicyForbidden;
		}
	}

	if (sSetupHTTPPolicy == OCConnectionSetupHTTPPolicyAuto)
	{
		sSetupHTTPPolicy = OCConnectionSetupHTTPPolicyWarn;
	}

	return (sSetupHTTPPolicy);
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
		_partitionID = bookmark.uuid.UUIDString;

		self.bookmark = bookmark;

		if (self.bookmark.authenticationMethodIdentifier != nil)
		{
			Class authenticationMethodClass;
			
			if ((authenticationMethodClass = [OCAuthenticationMethod registeredAuthenticationMethodForIdentifier:self.bookmark.authenticationMethodIdentifier]) != Nil)
			{
				_authenticationMethod = [authenticationMethodClass new];
			}
		}

		_pendingAuthenticationAvailabilityHandlers = [NSMutableArray new];
		_signals = [[NSMutableSet alloc] initWithObjects:OCConnectionSignalIDAuthenticationAvailable, nil];
		_preferredChecksumAlgorithm = OCChecksumAlgorithmIdentifierSHA1;

		_actionSignals = [NSSet setWithObject:OCConnectionSignalIDAuthenticationAvailable];
		_propFindSignals = [NSSet setWithObject:OCConnectionSignalIDAuthenticationAvailable];
		_authSignals = [NSSet set];

		_usersByUserID = [NSMutableDictionary new];

		[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(_connectionCertificateUserApproved) name:self.bookmark.certificateUserApprovalUpdateNotificationName object:nil];

		// Get pipelines
		[self spinUpPipelines];
	}
	
	return (self);
}

- (void)dealloc
{
	[NSNotificationCenter.defaultCenter removeObserver:self name:self.bookmark.certificateUserApprovalUpdateNotificationName object:nil];

	[self.allHTTPPipelines enumerateObjectsUsingBlock:^(OCHTTPPipeline *pipeline, BOOL * _Nonnull stop) {
		[OCHTTPPipelineManager.sharedPipelineManager returnPipelineWithIdentifier:pipeline.identifier completionHandler:nil];
	}];

	OCTLogDebug(@[@"DEALLOC"], @"connection deallocated");
}

#pragma mark - Pipelines
- (void)spinUpPipelines
{
	OCSyncExec(waitForPipelines, {
		[OCHTTPPipelineManager.sharedPipelineManager requestPipelineWithIdentifier:OCHTTPPipelineIDEphermal completionHandler:^(OCHTTPPipeline * _Nullable pipeline, NSError * _Nullable error) {
			self->_ephermalPipeline = pipeline;

			OCLogDebug(@"Retrieved ephermal pipeline %@ with error=%@", pipeline, error);

			[OCHTTPPipelineManager.sharedPipelineManager requestPipelineWithIdentifier:OCHTTPPipelineIDLocal completionHandler:^(OCHTTPPipeline * _Nullable pipeline, NSError * _Nullable error) {
				self->_commandPipeline = pipeline;

				OCLogDebug(@"Retrieved local pipeline %@ with error=%@", pipeline, error);

				if (OCConnection.backgroundURLSessionsAllowed)
				{
					[OCHTTPPipelineManager.sharedPipelineManager requestPipelineWithIdentifier:OCHTTPPipelineIDBackground completionHandler:^(OCHTTPPipeline * _Nullable pipeline, NSError * _Nullable error) {
						self->_longLivedPipeline = pipeline;

						OCLogDebug(@"Retrieved longlived pipeline %@ with error=%@", pipeline, error);

						OCSyncExecDone(waitForPipelines);
					}];
				}
				else
				{
					self->_longLivedPipeline = pipeline;

					OCSyncExecDone(waitForPipelines);
				}
			}];
		}];
	});
}

- (void)attachToPipelines
{
	BOOL attach = NO;

	@synchronized(self)
	{
		if (!_attachedToPipelines)
		{
			attach = YES;
			_attachedToPipelines = YES;
		}
	}

	if (attach)
	{
		OCCore *delegateCore = OCTypedCast(_delegate, OCCore);
		if (delegateCore != nil)
		{
			OCLogDebug(@"Attach pipelines for connection %@ with core.state = %lu via %@", self, (unsigned long)delegateCore.state, [NSThread callStackSymbols]);

			if (delegateCore.state == OCCoreStateStopped)
			{
				OCLogError(@"Connection %@ was prompted to attach to pipelines while core is stopped via %@", self, [NSThread callStackSymbols]);
				attach = NO;
			}
		}
	}

	if (attach)
	{
		[self.allHTTPPipelines enumerateObjectsUsingBlock:^(OCHTTPPipeline *pipeline, BOOL *stop) {
			OCSyncExec(waitForAttach, {
				[pipeline attachPartitionHandler:self completionHandler:^(id sender, NSError *error) {
					OCSyncExecDone(waitForAttach);
				}];
			});
		}];
	}
}

- (void)detachFromPipelinesWithCompletionHandler:(dispatch_block_t)completionHandler
{
	dispatch_group_t waitPipelineDetachGroup = dispatch_group_create();
	NSSet<OCHTTPPipeline *> *pipelines = nil;
	BOOL returnImmediately = NO;

	@synchronized (self)
	{
		if (_attachedToPipelines)
		{
			_attachedToPipelines = NO;
		}
		else
		{
			returnImmediately = YES;
		}
	}

	if (returnImmediately && (completionHandler != nil))
	{
		completionHandler();
		return;
	}

	// Detach from all pipelines
	pipelines = self.allHTTPPipelines;

	for (OCHTTPPipeline *pipeline in pipelines)
	{
		OCLogDebug(@"detaching from pipeline %@ (connection=%@)", pipeline, self);

		dispatch_group_enter(waitPipelineDetachGroup);

		// Cancel non-critical requests and detach from the pipeline
		[pipeline cancelNonCriticalRequestsForPartitionID:self.partitionID];
		[pipeline detachPartitionHandler:self completionHandler:^(id sender, NSError *error) {
			OCLogDebug(@"detach from pipeline %@ (connection=%@) returned with error=%@", pipeline, self, error);
			dispatch_group_leave(waitPipelineDetachGroup);
		}];
	}

	// Wait for all invalidation completion handlers to finish executing, then call the provided completionHandler
	OCConnection *strongReference = self;

	dispatch_group_notify(waitPipelineDetachGroup, dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
		@autoreleasepool
		{
			// In order for the OCConnection to be able to process outstanding responses,
			// A REFERENCE TO SELF MUST BE KEPT AROUND UNTIL ALL PIPELINES HAVE DETACHED.
			// this is done through this log message, which makes this block retain
			// strongReference (aka self):
			OCLogDebug(@"detached from all pipelines, calling completionHandler: %@, bookmark: %@", completionHandler, strongReference.bookmark);

			if (completionHandler!=nil)
			{
				completionHandler();
			}
		}
	});
}

- (NSSet<OCHTTPPipeline *> *)allHTTPPipelines
{
	NSMutableSet<OCHTTPPipeline *> *connectionPipelines = [NSMutableSet new];

	if (self->_ephermalPipeline != nil)
	{
		[connectionPipelines addObject:self->_ephermalPipeline];
	}
	if (self->_longLivedPipeline != nil)
	{
		[connectionPipelines addObject:self->_longLivedPipeline];
	}
	if (self->_commandPipeline != nil)
	{
		[connectionPipelines addObject:self->_commandPipeline];
	}

	return (connectionPipelines);
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

	if ((_delegate!=nil) && [_delegate respondsToSelector:@selector(connectionChangedState:)])
	{
		[_delegate connectionChangedState:self];
	}
}

#pragma mark - Cookies
- (OCHTTPCookieStorage *)partitionCookieStorage
{
	return (_cookieStorage);
}

#pragma mark - Prepare request
- (OCHTTPRequest *)pipeline:(OCHTTPPipeline *)pipeline prepareRequestForScheduling:(OCHTTPRequest *)request
{
	// Insert X-Request-ID for tracing
	{
		NSString *xRequestID = request.identifier;

		if (xRequestID == nil)
		{
			xRequestID = NSUUID.UUID.UUIDString;
		}

		if (xRequestID != nil)
		{
			[request setValue:xRequestID forHeaderField:@"X-Request-ID"];
		}
	}

	// Authorization
	if ([request.requiredSignals containsObject:OCConnectionSignalIDAuthenticationAvailable])
	{
		// Apply authorization to request
		OCAuthenticationMethod *authenticationMethod;
		
		if ((authenticationMethod = self.authenticationMethod) != nil)
		{
			request = [authenticationMethod authorizeRequest:request forConnection:self];
		}
	}

	// Static header fields
	if (_staticHeaderFields != nil)
	{
		[request addHeaderFields:_staticHeaderFields];
	}

	return (request);
}

#pragma mark - Handle certificate challenges
// -> moved to OCHTTPPolicyBookmark that's created on-the-fly by OCHTTPPolicyManager for now 

#pragma mark - Post process request after it finished
- (NSError *)pipeline:(OCHTTPPipeline *)pipeline postProcessFinishedTask:(OCHTTPPipelineTask *)task error:(NSError *)error
{
	if ([task.request.requiredSignals containsObject:OCConnectionSignalIDAuthenticationAvailable])
	{
		OCAuthenticationMethod *authMethod;

		if ((authMethod = self.authenticationMethod) != nil)
		{
 			error = [authMethod handleRequest:task.request response:task.response forConnection:self withError:error];
		}
	}

	return (error);
}

- (BOOL)pipeline:(nonnull OCHTTPPipeline *)pipeline meetsSignalRequirements:(nonnull NSSet<OCConnectionSignalID> *)requiredSignals forTask:(nullable OCHTTPPipelineTask *)task failWithError:(NSError * _Nullable __autoreleasing * _Nullable)outError
{
	// Authentication
	BOOL authenticationAvailable = [self isSignalOn:OCConnectionSignalIDAuthenticationAvailable];

	if (authenticationAvailable)
	{
		authenticationAvailable = [self canSendAuthenticatedRequestsWithAvailabilityHandler:^(NSError *error, BOOL authenticationIsAvailable) {
			// Set OCConnectionSignalIDAuthenticationAvailable to YES regardless of authenticationIsAvailable's value in order to ensure -[OCConnection canSendAuthenticatedRequestsForQueue:availabilityHandler:] is called ever again (for requests queued in the future)
			[pipeline queueBlock:^{
				[self setSignal:OCConnectionSignalIDAuthenticationAvailable on:YES];
			} withBusy:YES];

			if (authenticationIsAvailable)
			{
				// Authentication is now available => schedule queued requests
				[pipeline setPipelineNeedsScheduling];
			}
			else
			{
				// Authentication is not available => end scheduled requests that need authentication with error
				[pipeline finishPendingRequestsForPartitionID:self.partitionID withError:error filter:^BOOL(OCHTTPPipeline * _Nonnull pipeline, OCHTTPPipelineTask * _Nonnull task) {
					return ([task.request.requiredSignals containsObject:OCConnectionSignalIDAuthenticationAvailable]);
				}];
			}
		}];

		[self setSignal:OCConnectionSignalIDAuthenticationAvailable on:authenticationAvailable];
	}

	return ([self meetsSignalRequirements:requiredSignals]);
}

- (BOOL)pipeline:(OCHTTPPipeline *)pipeline partitionID:(OCHTTPPipelinePartitionID)partitionID simulateRequestHandling:(OCHTTPRequest *)request completionHandler:(void (^)(OCHTTPResponse * _Nonnull))completionHandler
{
	if (_hostSimulator != nil)
	{
		return ([_hostSimulator connection:self pipeline:pipeline simulateRequestHandling:request completionHandler:completionHandler]);
	}

	return (YES);
}

#pragma mark - Rescheduling support
- (OCHTTPRequestInstruction)pipeline:(OCHTTPPipeline *)pipeline instructionForFinishedTask:(OCHTTPPipelineTask *)task instruction:(OCHTTPRequestInstruction)incomingInstruction error:(NSError *)error
{
	OCHTTPRequestInstruction instruction = OCHTTPRequestInstructionDeliver;

	if ([error isOCErrorWithCode:OCErrorAuthorizationRetry])
	{
		// Reschedule requested by auth method
		instruction = OCHTTPRequestInstructionReschedule;
	}

	if ((_delegate!=nil) && [_delegate respondsToSelector:@selector(connection:instructionForFinishedRequest:withResponse:error:defaultsTo:)])
	{
		instruction = [_delegate connection:self instructionForFinishedRequest:task.request withResponse:task.response error:error defaultsTo:instruction];
	}

	return (instruction);
}

#pragma mark - User certificate approval changes
- (void)_connectionCertificateUserApproved
{
	if ((_delegate!=nil) && [_delegate respondsToSelector:@selector(connectionCertificateUserApproved:)])
	{
		[_delegate connectionCertificateUserApproved:self];
	}
}

#pragma mark - Connect & Disconnect
- (NSProgress *)connectWithCompletionHandler:(void(^)(NSError *error, OCIssue *issue))completionHandler
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
		OCHTTPRequest *statusRequest;

		// Attach to pipelines
		[self attachToPipelines];

		// Set up progress
		connectProgress.totalUnitCount = connectProgress.completedUnitCount = 0; // Indeterminate
		connectProgress.localizedDescription = OCLocalizedString(@"Connecting…", @"");

		self.state = OCConnectionStateConnecting;

		completionHandler = ^(NSError *error, OCIssue *issue) {
			if ((error != nil) && (issue != nil))
			{
				self.state = OCConnectionStateDisconnected;
			}

			completionHandler(error, issue);
		};

		// Reusable Completion Handler
		OCHTTPRequestEphermalResultHandler (^CompletionHandlerWithResultHandler)(OCHTTPRequestEphermalResultHandler) = ^(OCHTTPRequestEphermalResultHandler resultHandler)
		{
			return ^(OCHTTPRequest *request, OCHTTPResponse *response, NSError *error){
				if (error == nil)
				{
					if (response.status.isSuccess)
					{
						// Success
						resultHandler(request, response, error);

						return;
					}
					else if (response.status.isRedirection)
					{
						// Redirection
						NSURL *responseRedirectURL;
						NSError *error = nil;
						OCIssue *issue = nil;

						if ((responseRedirectURL = response.redirectURL) != nil)
						{
							NSURL *alternativeBaseURL;
							
							if ((alternativeBaseURL = [self extractBaseURLFromRedirectionTargetURL:responseRedirectURL originalURL:request.url]) != nil)
							{
								// Create an issue if the redirectURL replicates the path of our target URL
								issue = [OCIssue issueForRedirectionFromURL:self->_bookmark.url toSuggestedURL:alternativeBaseURL issueHandler:^(OCIssue *issue, OCIssueDecision decision) {
									if (decision == OCIssueDecisionApprove)
									{
										self->_bookmark.url = alternativeBaseURL;
									}
								}];
							}
							else
							{
								// Create an error if the redirectURL does not replicate the path of our target URL
								issue = [OCIssue issueForRedirectionFromURL:self->_bookmark.url toSuggestedURL:responseRedirectURL issueHandler:nil];
								issue.level = OCIssueLevelError;

								error = OCErrorWithInfo(OCErrorServerBadRedirection, @{ OCAuthorizationMethodAlternativeServerURLKey : responseRedirectURL });
							}
						}

						OCErrorAddDateFromResponse(error, response);

						connectProgress.localizedDescription = @"";
						completionHandler(error, issue);
						resultHandler(request, response, error);

						return;
					}
					else if (response.status.code == OCHTTPStatusCodeSERVICE_UNAVAILABLE)
					{
						// Maintenance mode
						error = OCError(OCErrorServerInMaintenanceMode);
					}
					else
					{
						// Unknown / Unexpected HTTP status => return an error
						error = [response.status error];
					}
				}

				if (error != nil)
				{
					// An error occured
					OCIssue *issue = error.embeddedIssue;

					OCErrorAddDateFromResponse(error, response);

					if (issue == nil)
					{
						issue = [OCIssue issueForError:error level:OCIssueLevelError issueHandler:nil];
					}

					connectProgress.localizedDescription = OCLocalizedString(@"Error", @"");
					completionHandler(error, issue);
					resultHandler(request, response, error);
				}
			};
		};

		// Check status
		if ((statusRequest =  [OCHTTPRequest requestWithURL:[self URLForEndpoint:OCConnectionEndpointIDStatus options:nil]]) != nil)
		{
			[self sendRequest:statusRequest ephermalCompletionHandler:CompletionHandlerWithResultHandler(^(OCHTTPRequest *request, OCHTTPResponse *response, NSError *error) {
				self.connectionInitializationPhaseCompleted = YES;

				if ((error == nil) && (response.status.isSuccess))
				{
					NSError *jsonError = nil;
					NSDictionary <NSString *, id> *serverStatus;

					serverStatus = [response bodyConvertedDictionaryFromJSONWithError:&jsonError];

					if (serverStatus == nil)
					{
						// JSON decode error
						completionHandler(jsonError, [OCIssue issueForError:jsonError level:OCIssueLevelError issueHandler:nil]);
					}
					else
					{
						// Got status successfully => now check minimum version + authenticate connection
						self->_serverStatus = serverStatus;

						// Check minimum version
						NSError *minimumVersionError;

						if ((minimumVersionError = [self supportsServerVersion:self.serverVersion product:self.serverProductName longVersion:self.serverLongProductVersionString allowHiddenVersion:YES]) != nil)
						{
							completionHandler(minimumVersionError, [OCIssue issueForError:minimumVersionError level:OCIssueLevelError issueHandler:nil]);

							return;
						}

						// Check maintenance status
						if ([serverStatus[@"maintenance"] isKindOfClass:[NSNumber class]])
						{
							if (((NSNumber *)serverStatus[@"maintenance"]).boolValue)
							{
								NSError *maintenanceModeError = OCError(OCErrorServerInMaintenanceMode);

								OCErrorAddDateFromResponse(maintenanceModeError, response);

								completionHandler(maintenanceModeError, [OCIssue issueForError:maintenanceModeError level:OCIssueLevelError issueHandler:nil]);

								return;
							}
						}

						// Save server status to bookmark
						if ((serverStatus != nil) && (self->_bookmark != nil))
						{
							[self->_bookmark.userInfo setObject:serverStatus forKey:OCBookmarkUserInfoKeyStatusInfo];
							[[NSNotificationCenter defaultCenter] postNotificationName:OCBookmarkUpdatedNotification object:self->_bookmark];
						}

						// Authenticate connection
						connectProgress.localizedDescription = OCLocalizedString(@"Authenticating…", @"");

						[authMethod authenticateConnection:self withCompletionHandler:^(NSError *authConnError, OCIssue *authConnIssue) {
							if ((authConnError!=nil) || (authConnIssue!=nil))
							{
								// Error or issue
								completionHandler(authConnError, authConnIssue);
							}
							else
							{
								// Connection authenticated. Now send an authenticated WebDAV request
								OCHTTPDAVRequest *davRequest;
								
								davRequest = [OCHTTPDAVRequest propfindRequestWithURL:[self URLForEndpoint:OCConnectionEndpointIDWebDAV options:nil] depth:0];
								davRequest.requiredSignals = [NSSet setWithObject:OCConnectionSignalIDAuthenticationAvailable];
								
								[davRequest.xmlRequestPropAttribute addChildren:@[
									[OCXMLNode elementWithName:@"D:supported-method-set"],
								]];
								
								// OCLogDebug(@"%@", davRequest.xmlRequest.XMLString);

								[self sendRequest:davRequest ephermalCompletionHandler:CompletionHandlerWithResultHandler(^(OCHTTPRequest *request, OCHTTPResponse *response, NSError *error) {
									if ((error == nil) && (response.status.isSuccess))
									{
										// DAV request executed successfully

										// Retrieve capabilities
										connectProgress.localizedDescription = OCLocalizedString(@"Retrieving capabilities…", @"");

										[self retrieveCapabilitiesWithCompletionHandler:^(NSError * _Nullable error, OCCapabilities * _Nullable capabilities) {
											if (error == nil)
											{
												// Check minimum version
												NSError *minimumVersionError;

												if ((minimumVersionError = [self supportsServerVersion:capabilities.version product:capabilities.productName longVersion:capabilities.longProductVersionString allowHiddenVersion:NO]) != nil)
												{
													completionHandler(minimumVersionError, [OCIssue issueForError:minimumVersionError level:OCIssueLevelError issueHandler:nil]);

													return;
												}

												// Get user info
												connectProgress.localizedDescription = OCLocalizedString(@"Fetching user information…", @"");

												[self retrieveLoggedInUserWithCompletionHandler:^(NSError *error, OCUser *loggedInUser) {
													self.loggedInUser = loggedInUser;

													connectProgress.localizedDescription = OCLocalizedString(@"Connected", @"");

													if (error!=nil)
													{
														completionHandler(error, [OCIssue issueForError:error level:OCIssueLevelError issueHandler:nil]);
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
											else
											{
												completionHandler(error, [OCIssue issueForError:error level:OCIssueLevelError issueHandler:nil]);
											}
										}];
									}
									else
									{
										// Intentionally no error handling here! If an error occurs here, it's handled by the auth system, so that calling the completionHandler here will lead to a crash.
										// (crash reproducable in CoreTests.testInvalidLoginData)
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
		completionHandler(error, [OCIssue issueForError:error level:OCIssueLevelError issueHandler:nil]);
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
			[self detachFromPipelinesWithCompletionHandler:completionHandler];
		};

		completionHandler = invalidationCompletionHandler;
	}

	if ((authMethod = self.authenticationMethod) != nil)
	{
		// Deauthenticate the connection
		[authMethod deauthenticateConnection:self withCompletionHandler:^(NSError *authConnError, OCIssue *authConnIssue) {
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

- (void)cancelNonCriticalRequests
{
	NSMutableSet<OCHTTPPipeline *> *pipelines = nil;

	// Attach to pipelines
	[self attachToPipelines];

	pipelines = [[NSMutableSet alloc] initWithSet:self.allHTTPPipelines];

	for (OCHTTPPipeline *pipeline in pipelines)
	{
		OCLogDebug(@"cancelling non-critical requests from pipeline %@", pipeline);

		// Cancel non-critical requests
		[pipeline cancelNonCriticalRequestsForPartitionID:self.partitionID];
	}
}

#pragma mark - Server Status
- (NSProgress *)requestServerStatusWithCompletionHandler:(void(^)(NSError *error, OCHTTPRequest *request, NSDictionary<NSString *,id> *statusInfo))completionHandler
{
	OCHTTPRequest *statusRequest;

	if ((statusRequest = [OCHTTPRequest requestWithURL:[self URLForEndpoint:OCConnectionEndpointIDStatus options:nil]]) != nil)
	{
		[self sendRequest:statusRequest ephermalCompletionHandler:^(OCHTTPRequest *request, OCHTTPResponse *response, NSError *error) {
			if ((error == nil) && (response.status.isSuccess))
			{
				NSError *jsonError = nil;
				NSDictionary <NSString *, id> *serverStatus;

				if ((serverStatus = [response bodyConvertedDictionaryFromJSONWithError:&jsonError]) == nil)
				{
					// JSON decode error
					completionHandler(jsonError, request, nil);
				}
				else
				{
					// Got status successfully
					self->_serverStatus = serverStatus;
					completionHandler(nil, request, serverStatus);
				}
			}
			else
			{
				completionHandler(error, request, nil);
			}
		}];
	}

	return (nil);
}

#pragma mark - Metadata actions
- (NSMutableArray <OCXMLNode *> *)_davItemAttributes
{
	NSMutableArray <OCXMLNode *> *ocPropAttributes = [[NSMutableArray alloc] initWithObjects:
		// WebDAV properties
		[OCXMLNode elementWithName:@"D:resourcetype"],
		[OCXMLNode elementWithName:@"D:getlastmodified"],
		[OCXMLNode elementWithName:@"D:getcontentlength"],
		[OCXMLNode elementWithName:@"D:getcontenttype"],
		[OCXMLNode elementWithName:@"D:getetag"],

		// OC properties
		[OCXMLNode elementWithName:@"oc:id"],
		[OCXMLNode elementWithName:@"oc:size"],
		[OCXMLNode elementWithName:@"oc:permissions"],
		[OCXMLNode elementWithName:@"oc:favorite"],
		[OCXMLNode elementWithName:@"oc:share-types"],

		[OCXMLNode elementWithName:@"oc:owner-id"],
		[OCXMLNode elementWithName:@"oc:owner-display-name"],

		// [OCXMLNode elementWithName:@"D:creationdate"],
		// [OCXMLNode elementWithName:@"D:displayname"],

		// [OCXMLNode elementWithName:@"oc:tags"],
		// [OCXMLNode elementWithName:@"oc:comments-count"],
		// [OCXMLNode elementWithName:@"oc:comments-href"],
		// [OCXMLNode elementWithName:@"oc:comments-unread"],
	nil];

	return (ocPropAttributes);
}

- (OCHTTPDAVRequest *)_propfindDAVRequestForPath:(OCPath)path endpointURL:(NSURL *)endpointURL depth:(NSUInteger)depth
{
	OCHTTPDAVRequest *davRequest;
	NSURL *url = endpointURL;

	if (endpointURL == nil)
	{
		return (nil);
	}

	if (path != nil)
	{
		url = [url URLByAppendingPathComponent:path];
	}

	if ((davRequest = [OCHTTPDAVRequest propfindRequestWithURL:url depth:depth]) != nil)
	{
		NSMutableArray <OCXMLNode *> *ocPropAttributes = [self _davItemAttributes];

		if (depth == 0)
		{
			[ocPropAttributes addObject:[OCXMLNode elementWithName:@"D:quota-available-bytes"]];
			[ocPropAttributes addObject:[OCXMLNode elementWithName:@"D:quota-used-bytes"]];
			[ocPropAttributes addObject:[OCXMLNode elementWithName:@"oc:checksums"]];
		}

		if ([[self classSettingForOCClassSettingsKey:OCConnectionAlwaysRequestPrivateLink] boolValue])
		{
			[ocPropAttributes addObject:[OCXMLNode elementWithName:@"oc:privatelink"]];
		}

		[davRequest.xmlRequestPropAttribute addChildren:ocPropAttributes];

		davRequest.requiredSignals = self.propFindSignals;
	}

	return (davRequest);
}

- (NSProgress *)retrieveItemListAtPath:(OCPath)path depth:(NSUInteger)depth completionHandler:(void(^)(NSError *error, NSArray <OCItem *> *items))completionHandler
{
	return ([self retrieveItemListAtPath:path depth:depth options:nil completionHandler:completionHandler]);
}

- (NSProgress *)retrieveItemListAtPath:(OCPath)path depth:(NSUInteger)depth options:(NSDictionary<OCConnectionOptionKey,id> *)options completionHandler:(void(^)(NSError *error, NSArray <OCItem *> *items))completionHandler
{
	return ([self retrieveItemListAtPath:path depth:depth options:options resultTarget:[OCEventTarget eventTargetWithEphermalEventHandlerBlock:^(OCEvent * _Nonnull event, id  _Nonnull sender) {
			if (event.error != nil)
			{
				completionHandler(event.error, nil);
			}
			else
			{
				completionHandler(nil, OCTypedCast(event.result, NSArray));
			}
		} userInfo:nil ephermalUserInfo:nil]]);
}

- (NSProgress *)retrieveItemListAtPath:(OCPath)path depth:(NSUInteger)depth options:(NSDictionary<OCConnectionOptionKey,id> *)options resultTarget:(OCEventTarget *)eventTarget
{
	OCHTTPDAVRequest *davRequest;
	NSProgress *progress = nil;
	NSURL *endpointURL = [self URLForEndpoint:OCConnectionEndpointIDWebDAVRoot options:nil];

	if ((davRequest = [self _propfindDAVRequestForPath:path endpointURL:endpointURL depth:depth]) != nil)
	{
		// davRequest.requiredSignals = self.actionSignals;
		davRequest.resultHandlerAction = @selector(_handleRetrieveItemListAtPathResult:error:);
		davRequest.userInfo = @{
			@"path" : path,
			@"depth" : @(depth),
			@"endpointURL" : endpointURL,
			@"options" : ((options != nil) ? options : [NSNull null])
		};
		davRequest.eventTarget = eventTarget;
		davRequest.downloadRequest = YES;
		davRequest.priority = NSURLSessionTaskPriorityHigh;
		davRequest.forceCertificateDecisionDelegation = YES;

		if (options[OCConnectionOptionRequestObserverKey] != nil)
		{
			davRequest.requestObserver = options[OCConnectionOptionRequestObserverKey];
		}

		if (options[OCConnectionOptionIsNonCriticalKey] != nil)
		{
			davRequest.isNonCritial = ((NSNumber *)options[OCConnectionOptionIsNonCriticalKey]).boolValue;
		}

		if (options[OCConnectionOptionGroupIDKey] != nil)
		{
			davRequest.groupID = options[OCConnectionOptionGroupIDKey];
		}

		if (options[OCConnectionOptionRequiredSignalsKey] != nil)
		{
			davRequest.requiredSignals = options[OCConnectionOptionRequiredSignalsKey];
		}

		// Attach to pipelines
		[self attachToPipelines];

		// Enqueue request
		if (options[@"alternativeEventType"] != nil)
		{
			[self.commandPipeline enqueueRequest:davRequest forPartitionID:self.partitionID];
		}
		else
		{
			[self.ephermalPipeline enqueueRequest:davRequest forPartitionID:self.partitionID];
		}

		progress = davRequest.progress.progress;
		progress.eventType = OCEventTypeRetrieveItemList;
		progress.localizedDescription = [NSString stringWithFormat:OCLocalized(@"Retrieving file list for %@…"), path];
	}
	else
	{
		[eventTarget handleError:OCError(OCErrorInternal) type:OCEventTypeRetrieveItemList uuid:nil sender:self];
	}

	return(progress);
}

- (void)_handleRetrieveItemListAtPathResult:(OCHTTPRequest *)request error:(NSError *)error
{
	OCEvent *event;
	NSDictionary<OCConnectionOptionKey,id> *options = [request.userInfo[@"options"] isKindOfClass:[NSDictionary class]] ? request.userInfo[@"options"] : nil;
	OCEventType eventType = OCEventTypeRetrieveItemList;

	if ((options!=nil) && (options[@"alternativeEventType"]!=nil))
	{
		eventType = (OCEventType)[options[@"alternativeEventType"] integerValue];
	}

	if ((event = [OCEvent eventForEventTarget:request.eventTarget type:eventType uuid:request.identifier attributes:nil]) != nil)
	{
		if (error != nil)
		{
			event.error = error;
		}

		if (request.error != nil)
		{
			event.error = request.error;
		}

		if (!request.httpResponse.status.isSuccess && (event.error == nil))
		{
			event.error = request.httpResponse.status.error;
		}

		if (event.error == nil)
		{
			NSURL *endpointURL = request.userInfo[@"endpointURL"];
			NSArray <NSError *> *errors = nil;
			NSArray <OCItem *> *items = nil;

			// OCLogDebug(@"Error: %@ - Response: %@", OCLogPrivate(error), ((request.downloadRequest && (request.downloadedFileURL != nil)) ? OCLogPrivate([NSString stringWithContentsOfURL:request.downloadedFileURL encoding:NSUTF8StringEncoding error:NULL]) : nil));

			items = [((OCHTTPDAVRequest *)request) responseItemsForBasePath:endpointURL.path reuseUsersByID:_usersByUserID withErrors:&errors];

			if ((items.count == 0) && (errors.count > 0) && (event.error == nil))
			{
				event.error = errors.firstObject;
			}

			switch (eventType)
			{
				case OCEventTypeUpload:
					{
						OCItem *uploadedItem = items.firstObject;
						OCChecksum *expectedChecksum = OCTypedCast(options[@"checksumExpected"], OCChecksum);
						NSError *expectedChecksumMismatchError = OCTypedCast(options[@"checksumMismatchError"], NSError);

						if (expectedChecksum != nil)
						{
							if ([uploadedItem.checksums containsObject:expectedChecksum])
							{
								event.result = uploadedItem;
							}
							else
							{
								event.error = expectedChecksumMismatchError;
							}
						}
						else
						{
							event.result = uploadedItem;
						}
					}
				break;

				default: {
					event.path = request.userInfo[@"path"];
					event.depth = [(NSNumber *)request.userInfo[@"depth"] unsignedIntegerValue];

					OCTUSHeader *tusHeader;

					if ((tusHeader = [[OCTUSHeader alloc] initWithHTTPHeaderFields:request.httpResponse.headerFields]) != nil)
					{
						OCTUSSupport tusSupportLevel = tusHeader.supportFlags;

						if (tusSupportLevel != OCTUSSupportNone)
						{
							for (OCItem *item in items)
							{
								if ([item.path isEqual:event.path])
								{
									item.tusInfo = tusHeader.info;
									break;
								}
							}
						}
					}

					event.result = items;
				}
				break;
			}

			if ((event.error==nil) && !request.httpResponse.status.isSuccess)
			{
				event.error = request.httpResponse.status.error;
			}
		}

		OCErrorAddDateFromResponse(event.error, request.httpResponse);

		[request.eventTarget handleEvent:event sender:self];
	}
}

#pragma mark - Estimates
- (NSNumber *)estimatedTimeForTransferRequest:(OCHTTPRequest *)request withExpectedResponseLength:(NSUInteger)expectedResponseLength confidence:(double * _Nullable)outConfidence
{
	double longlivedConfidence = 0;
	NSNumber *longLivedEstimatedTime = [self.longLivedPipeline estimatedTimeForRequest:request withExpectedResponseLength:expectedResponseLength confidence:&longlivedConfidence];

	double commandConfidence = 0;
	NSNumber *commandEstimatedTime = [self.commandPipeline estimatedTimeForRequest:request withExpectedResponseLength:expectedResponseLength confidence:&commandConfidence];

	double estimationConfidence = 0;
	NSNumber *estimatedTime = nil;

	if ((commandEstimatedTime != nil) && (commandConfidence > longlivedConfidence))
	{
		estimatedTime = commandEstimatedTime;
		estimationConfidence = commandConfidence;
	}
	else if ((longLivedEstimatedTime != nil) && (longlivedConfidence > commandConfidence))
	{
		estimatedTime = longLivedEstimatedTime;
		estimationConfidence = longlivedConfidence;
	}

	if (outConfidence != NULL)
	{
		*outConfidence = estimationConfidence;
	}

	return (estimatedTime);
}

- (OCHTTPPipeline *)transferPipelineForRequest:(OCHTTPRequest *)request withExpectedResponseLength:(NSUInteger)expectedResponseLength
{
	double confidenceLevel = 0;
	NSNumber *estimatedTime = nil;

	if (!OCProcessManager.isProcessExtension)
	{
		if ((estimatedTime = [self estimatedTimeForTransferRequest:request withExpectedResponseLength:expectedResponseLength confidence:&confidenceLevel]) != nil)
		{
			BOOL useCommandPipeline = (estimatedTime.doubleValue <= 120.0) && (confidenceLevel >= 0.15);

			OCLogDebug(@"Expected finish time: %@ (in %@ seconds, confidence %.02f) - pipeline: %@", [NSDate dateWithTimeIntervalSinceNow:estimatedTime.doubleValue], estimatedTime, confidenceLevel, (useCommandPipeline ? @"command" : @"longLived"));

			if (useCommandPipeline)
			{
				return (self.commandPipeline);
			}
		}
	}

	return (self.longLivedPipeline);
}

#pragma mark - Actions

#pragma mark - File transfer: upload
// => please see OCConnection+Upload

#pragma mark - File transfer: download
- (OCProgress *)downloadItem:(OCItem *)item to:(NSURL *)targetURL options:(NSDictionary<OCConnectionOptionKey,id> *)options resultTarget:(OCEventTarget *)eventTarget
{
	OCProgress *requestProgress = nil;
	NSURL *downloadURL;

	if (item == nil)
	{
		return(nil);
	}

	if ((downloadURL = [[self URLForEndpoint:OCConnectionEndpointIDWebDAVRoot options:nil] URLByAppendingPathComponent:item.path]) != nil)
	{
		OCHTTPRequest *request = [OCHTTPRequest requestWithURL:downloadURL];

		request.method = OCHTTPMethodGET;
		request.requiredSignals = self.actionSignals;

		request.resultHandlerAction = @selector(_handleDownloadItemResult:error:);
		request.userInfo = @{
			@"item" : item
		};
		request.eventTarget = eventTarget;
		request.downloadRequest = YES;
		request.downloadedFileURL = targetURL;
		request.forceCertificateDecisionDelegation = YES;
		request.autoResume = YES;

		[request setValue:item.eTag forHeaderField:@"If-Match"];

		// Apply cellular options
		if (options[OCConnectionOptionRequiredCellularSwitchKey] != nil)
		{
			request.requiredCellularSwitch = options[OCConnectionOptionRequiredCellularSwitchKey];
		}

		if (options[OCConnectionOptionRequestObserverKey] != nil)
		{
			request.requestObserver = options[OCConnectionOptionRequestObserverKey];
		}

		// Attach to pipelines
		[self attachToPipelines];

		// Enqueue request
		[[self transferPipelineForRequest:request withExpectedResponseLength:item.size] enqueueRequest:request forPartitionID:self.partitionID];

		requestProgress = request.progress;
		requestProgress.progress.eventType = OCEventTypeDownload;
		requestProgress.progress.localizedDescription = [NSString stringWithFormat:OCLocalized(@"Downloading %@…"), item.name];
	}
	else
	{
		[eventTarget handleError:OCError(OCErrorInternal) type:OCEventTypeDownload uuid:nil sender:self];
	}

	return(requestProgress);
}

- (void)_handleDownloadItemResult:(OCHTTPRequest *)request error:(NSError *)error
{
	OCEvent *event;

	if ((event = [OCEvent eventForEventTarget:request.eventTarget type:OCEventTypeDownload uuid:request.identifier attributes:nil]) != nil)
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
				if (request.httpResponse.status.isSuccess)
				{
					OCFile *file = [OCFile new];
					OCChecksumHeaderString checksumString;

					file.item = request.userInfo[@"item"];

					file.url = request.httpResponse.bodyURL;

					if ((checksumString = request.httpResponse.headerFields[@"oc-checksum"]) != nil)
					{
						file.checksum = [OCChecksum checksumFromHeaderString:checksumString];
					}

					file.eTag = request.httpResponse.headerFields[@"oc-etag"];
					file.fileID = file.item.fileID;

					event.file = file;
				}
				else
				{
					switch (request.httpResponse.status.code)
					{
						default:
							event.error = request.httpResponse.status.error;
						break;
					}
				}
			}
		}

		OCErrorAddDateFromResponse(event.error, request.httpResponse);

		[request.eventTarget handleEvent:event sender:self];
	}
}

#pragma mark - Action: Item update
- (OCProgress *)updateItem:(OCItem *)item properties:(NSArray <OCItemPropertyName> *)properties options:(NSDictionary *)options resultTarget:(OCEventTarget *)eventTarget
{
	OCProgress *requestProgress = nil;
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
			OCHTTPDAVRequest *patchRequest;

			if ((patchRequest = [OCHTTPDAVRequest proppatchRequestWithURL:itemURL content:contentNodes]) != nil)
			{
				patchRequest.requiredSignals = self.actionSignals;
				patchRequest.resultHandlerAction = @selector(_handleUpdateItemResult:error:);
				patchRequest.userInfo = @{
					@"item" : item,
					@"properties" : properties,
					@"responseTagsByPropertyName" : responseTagsByPropertyName
				};
				patchRequest.eventTarget = eventTarget;
				patchRequest.priority = NSURLSessionTaskPriorityHigh;
				patchRequest.forceCertificateDecisionDelegation = YES;

				OCLogDebug(@"PROPPATCH XML: %@", patchRequest.xmlRequest.XMLString);

				// Attach to pipelines
				[self attachToPipelines];

				// Enqueue request
				[self.commandPipeline enqueueRequest:patchRequest forPartitionID:self.partitionID];

				requestProgress = patchRequest.progress;
				requestProgress.progress.eventType = OCEventTypeUpdate;
				requestProgress.progress.localizedDescription = [NSString stringWithFormat:OCLocalized(@"Updating metadata for '%@'…"), item.name];
			}
		}
		else
		{
			[eventTarget handleError:OCError(OCErrorInsufficientParameters) type:OCEventTypeUpdate uuid:nil sender:self];
		}
	}
	else
	{
		[eventTarget handleError:OCError(OCErrorInternal) type:OCEventTypeUpdate uuid:nil sender:self];
	}

	return (requestProgress);
}

- (void)_handleUpdateItemResult:(OCHTTPRequest *)request error:(NSError *)error
{
	OCEvent *event;
	NSURL *endpointURL = [self URLForEndpoint:OCConnectionEndpointIDWebDAVRoot options:nil];

	if ((event = [OCEvent eventForEventTarget:request.eventTarget type:OCEventTypeUpdate uuid:request.identifier attributes:nil]) != nil)
	{
		if (request.error != nil)
		{
			event.error = request.error;
		}
		else
		{
			if (request.httpResponse.status.isSuccess)
			{
				NSDictionary <OCPath, OCHTTPDAVMultistatusResponse *> *multistatusResponsesByPath;
				NSDictionary <OCItemPropertyName, NSString *> *responseTagsByPropertyName = request.userInfo[@"responseTagsByPropertyName"];

				if (((multistatusResponsesByPath = [((OCHTTPDAVRequest *)request) multistatusResponsesForBasePath:endpointURL.path]) != nil) && (responseTagsByPropertyName != nil))
				{
					OCHTTPDAVMultistatusResponse *multistatusResponse;

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
				event.error = request.httpResponse.status.error;
			}
		}
	}

	if (event != nil)
	{
		OCErrorAddDateFromResponse(event.error, request.httpResponse);

		[request.eventTarget handleEvent:event sender:self];
	}
}

#pragma mark - Action: Create Directory
- (OCProgress *)createFolder:(NSString *)folderName inside:(OCItem *)parentItem options:(NSDictionary *)options resultTarget:(OCEventTarget *)eventTarget;
{
	OCProgress *requestProgress = nil;
	NSURL *createFolderURL;
	OCPath fullFolderPath = nil;

	if ((parentItem==nil) || (folderName==nil))
	{
		return(nil);
	}

	fullFolderPath =  [parentItem.path pathForSubdirectoryWithName:folderName];

	if ((createFolderURL = [[self URLForEndpoint:OCConnectionEndpointIDWebDAVRoot options:nil] URLByAppendingPathComponent:fullFolderPath]) != nil)
	{
		OCHTTPRequest *request = [OCHTTPRequest requestWithURL:createFolderURL];

		request.method = OCHTTPMethodMKCOL;
		request.requiredSignals = self.actionSignals;

		request.resultHandlerAction = @selector(_handleCreateFolderResult:error:);
		request.userInfo = @{
			@"parentItem" : parentItem,
			@"folderName" : folderName,
			@"fullFolderPath" : fullFolderPath
		};
		request.eventTarget = eventTarget;
		request.priority = NSURLSessionTaskPriorityHigh;
		request.forceCertificateDecisionDelegation = YES;

		// Attach to pipelines
		[self attachToPipelines];

		// Enqueue request
		[self.commandPipeline enqueueRequest:request forPartitionID:self.partitionID];

		requestProgress = request.progress;
		requestProgress.progress.eventType = OCEventTypeCreateFolder;
		requestProgress.progress.localizedDescription = [NSString stringWithFormat:OCLocalized(@"Creating folder %@…"), folderName];
	}
	else
	{
		[eventTarget handleError:OCError(OCErrorInternal) type:OCEventTypeCreateFolder uuid:nil sender:self];
	}

	return(requestProgress);
}

- (void)_handleCreateFolderResult:(OCHTTPRequest *)request error:(NSError *)error
{
	OCEvent *event;
	BOOL postEvent = YES;

	if ((event = [OCEvent eventForEventTarget:request.eventTarget type:OCEventTypeCreateFolder uuid:request.identifier attributes:nil]) != nil)
	{
		if (request.error != nil)
		{
			event.error = request.error;
		}
		else
		{
			OCPath fullFolderPath = request.userInfo[@"fullFolderPath"];
			OCItem *parentItem = request.userInfo[@"parentItem"];

			if (request.httpResponse.status.code == OCHTTPStatusCodeCREATED)
			{
				postEvent = NO; // Wait until all info on the new item has been received

				// Retrieve all details on the new folder (OC server returns an "Oc-Fileid" in the HTTP headers, but we really need the full set here)
				[self retrieveItemListAtPath:fullFolderPath depth:0 completionHandler:^(NSError *error, NSArray<OCItem *> *items) {
					OCItem *newFolderItem = items.firstObject;

					newFolderItem.parentFileID = parentItem.fileID;
					newFolderItem.parentLocalID = parentItem.localID;

					if (error == nil)
					{
						event.result = newFolderItem;
					}
					else
					{
						event.error = error;
					}

					// Post event
					OCErrorAddDateFromResponse(event.error, request.httpResponse);
					[request.eventTarget handleEvent:event sender:self];
				}];
			}
			else
			{
				NSError *error = request.httpResponse.status.error;
				NSError *davError = [request.httpResponse bodyParsedAsDAVError];
				NSString *davMessage = davError.davExceptionMessage;

				switch (request.httpResponse.status.code)
				{
					case OCHTTPStatusCodeFORBIDDEN:
						// Server doesn't allow creation of folder here
						error = OCErrorWithDescription(OCErrorItemInsufficientPermissions, davMessage);
					break;

					case OCHTTPStatusCodeMETHOD_NOT_ALLOWED:
						// Folder already exists
						error = OCErrorWithDescription(OCErrorItemAlreadyExists, davMessage);
					break;

					case OCHTTPStatusCodeCONFLICT:
						// Parent folder doesn't exist
						error = OCErrorWithDescription(OCErrorItemNotFound, davMessage);
					break;

					default:
						if (davError != nil)
						{
							error = davError;
						}
					break;
				}

				event.error = error;
			}
		}
	}

	if (postEvent && (event!=nil))
	{
		OCErrorAddDateFromResponse(event.error, request.httpResponse);

		[request.eventTarget handleEvent:event sender:self];
	}
}

#pragma mark - Action: Copy Item + Move Item
- (OCProgress *)moveItem:(OCItem *)item to:(OCItem *)parentItem withName:(NSString *)newName options:(NSDictionary *)options resultTarget:(OCEventTarget *)eventTarget
{
	OCProgress *requestProgress;

	if ((requestProgress = [self _copyMoveMethod:OCHTTPMethodMOVE type:OCEventTypeMove item:item to:parentItem withName:newName options:options resultTarget:eventTarget]) != nil)
	{
		requestProgress.progress.eventType = OCEventTypeMove;

		if ([item.parentFileID isEqualToString:parentItem.fileID])
		{
			requestProgress.progress.localizedDescription = [NSString stringWithFormat:OCLocalized(@"Renaming %@ to %@…"), item.name, newName];
		}
		else
		{
			requestProgress.progress.localizedDescription = [NSString stringWithFormat:OCLocalized(@"Moving %@ to %@…"), item.name, parentItem.name];
		}
	}

	return (requestProgress);
}

- (OCProgress *)copyItem:(OCItem *)item to:(OCItem *)parentItem withName:(NSString *)newName options:(NSDictionary *)options resultTarget:(OCEventTarget *)eventTarget
{
	OCProgress *requestProgress;

	if ((requestProgress = [self _copyMoveMethod:OCHTTPMethodCOPY type:OCEventTypeCopy item:item to:parentItem withName:newName options:options resultTarget:eventTarget]) != nil)
	{
		requestProgress.progress.eventType = OCEventTypeCopy;
		requestProgress.progress.localizedDescription = [NSString stringWithFormat:OCLocalized(@"Copying %@ to %@…"), item.name, parentItem.name];
	}

	return (requestProgress);
}

- (OCProgress *)_copyMoveMethod:(OCHTTPMethod)requestMethod type:(OCEventType)eventType item:(OCItem *)item to:(OCItem *)parentItem withName:(NSString *)newName options:(NSDictionary *)options resultTarget:(OCEventTarget *)eventTarget
{
	OCProgress *requestProgress = nil;
	NSURL *sourceItemURL, *destinationURL;
	NSURL *webDAVRootURL = [self URLForEndpoint:OCConnectionEndpointIDWebDAVRoot options:nil];

	if ((sourceItemURL = [webDAVRootURL URLByAppendingPathComponent:item.path]) != nil)
	{
		if ((destinationURL = [[webDAVRootURL URLByAppendingPathComponent:parentItem.path] URLByAppendingPathComponent:newName]) != nil)
		{
			OCHTTPRequest *request = [OCHTTPRequest requestWithURL:sourceItemURL];

			request.method = requestMethod;
			request.requiredSignals = self.actionSignals;

			request.resultHandlerAction = @selector(_handleCopyMoveItemResult:error:);
			request.eventTarget = eventTarget;
			request.userInfo = @{
				@"item" : item,
				@"parentItem" : parentItem,
				@"newName" : newName,
				@"eventType" : @(eventType)
			};
			request.priority = NSURLSessionTaskPriorityHigh;

			request.forceCertificateDecisionDelegation = YES;

			[request setValue:[destinationURL absoluteString] forHeaderField:@"Destination"];
			[request setValue:@"infinity" forHeaderField:@"Depth"];
			[request setValue:@"F" forHeaderField:@"Overwrite"]; // "F" for False, "T" for True

			// Attach to pipelines
			[self attachToPipelines];

			// Enqueue request
			[self.commandPipeline enqueueRequest:request forPartitionID:self.partitionID];

			requestProgress = request.progress;
		}
	}
	else
	{
		[eventTarget handleError:OCError(OCErrorInternal) type:eventType uuid:nil sender:self];
	}

	return(requestProgress);
}

- (void)_handleCopyMoveItemResult:(OCHTTPRequest *)request error:(NSError *)error
{
	OCEvent *event;
	BOOL postEvent = YES;
	OCEventType eventType = (OCEventType) ((NSNumber *)request.userInfo[@"eventType"]).integerValue;

	if ((event = [OCEvent eventForEventTarget:request.eventTarget type:eventType uuid:request.identifier attributes:nil]) != nil)
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

			if (item.type == OCItemTypeCollection)
			{
				newFullPath = [newFullPath normalizedDirectoryPath];
			}

			if (request.httpResponse.status.code == OCHTTPStatusCodeCREATED)
			{
				postEvent = NO; // Wait until all info on the new item has been received

				// Retrieve all details on the new item
				[self retrieveItemListAtPath:newFullPath depth:0 completionHandler:^(NSError *error, NSArray<OCItem *> *items) {
					OCItem *newItem = items.firstObject;

					newItem.parentFileID = parentItem.fileID;
					newItem.parentLocalID  = parentItem.localID;

					if (error == nil)
					{
						event.result = newItem;
					}
					else
					{
						event.error = error;
					}

					// Post event
					OCErrorAddDateFromResponse(event.error, request.httpResponse);
					[request.eventTarget handleEvent:event sender:self];
				}];
			}
			else
			{
				switch (request.httpResponse.status.code)
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
						event.error = request.httpResponse.status.error;
					break;
				}
			}
		}
	}

	if (postEvent && (event!=nil))
	{
		OCErrorAddDateFromResponse(event.error, request.httpResponse);

		[request.eventTarget handleEvent:event sender:self];
	}
}

#pragma mark - Action: Delete Item
- (OCProgress *)deleteItem:(OCItem *)item requireMatch:(BOOL)requireMatch resultTarget:(OCEventTarget *)eventTarget
{
	OCProgress *requestProgress = nil;
	NSURL *deleteItemURL;

	if ((deleteItemURL = [[self URLForEndpoint:OCConnectionEndpointIDWebDAVRoot options:nil] URLByAppendingPathComponent:item.path]) != nil)
	{
		OCHTTPRequest *request = [OCHTTPRequest requestWithURL:deleteItemURL];

		request.method = OCHTTPMethodDELETE;
		request.requiredSignals = self.actionSignals;

		request.resultHandlerAction = @selector(_handleDeleteItemResult:error:);
		request.eventTarget = eventTarget;
		request.priority = NSURLSessionTaskPriorityHigh;
		request.forceCertificateDecisionDelegation = YES;

		if (requireMatch && (item.eTag!=nil))
		{
			if (item.type != OCItemTypeCollection) // Right now, If-Match returns a 412 response when used with directories. This appears to be a bug. TODO: enforce this for directories as well when future versions address the issue
			{
				[request setValue:item.eTag forHeaderField:@"If-Match"];
			}
		}

		// Attach to pipelines
		[self attachToPipelines];

		// Enqueue request
		[self.commandPipeline enqueueRequest:request forPartitionID:self.partitionID];

		requestProgress = request.progress;

		requestProgress.progress.eventType = OCEventTypeDelete;
		requestProgress.progress.localizedDescription = [NSString stringWithFormat:OCLocalized(@"Deleting %@…"), item.name];
	}
	else
	{
		[eventTarget handleError:OCError(OCErrorInternal) type:OCEventTypeDelete uuid:nil sender:self];
	}

	return(requestProgress);
}

- (void)_handleDeleteItemResult:(OCHTTPRequest *)request error:(NSError *)error
{
	OCEvent *event;

	if ((event = [OCEvent eventForEventTarget:request.eventTarget type:OCEventTypeDelete uuid:request.identifier attributes:nil]) != nil)
	{
		if (request.error != nil)
		{
			event.error = request.error;
		}
		else
		{
			if (request.httpResponse.status.isSuccess)
			{
				// Success (at the time of writing (2018-06-18), OC core doesn't support a multi-status response for this
				// command, so this scenario isn't handled here
				event.result = request.httpResponse.status;
			}
			else
			{
				switch (request.httpResponse.status.code)
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

					case OCHTTPStatusCodeLOCKED:
						/*
							Status code: 423
							Content-Type: application/xml; charset=utf-8

							<?xml version="1.0" encoding="utf-8"?>
							<d:error xmlns:d="DAV:" xmlns:s="http://sabredav.org/ns">
							  <s:exception>OCA\DAV\Connector\Sabre\Exception\FileLocked</s:exception>
							  <s:message>"new folder/newfile.pdf" is locked</s:message>
							</d:error>
						*/

					default: {
						NSString *davMessage = [request.httpResponse bodyParsedAsDAVError].davExceptionMessage;

						event.error = ((davMessage != nil) ? OCErrorWithDescription(OCErrorItemOperationForbidden, davMessage) : request.httpResponse.status.error);
					}
					break;
				}
			}
		}
	}

	if (event != nil)
	{
		OCErrorAddDateFromResponse(event.error, request.httpResponse);
		[request.eventTarget handleEvent:event sender:self];
	}
}

#pragma mark - Action: Retrieve Thumbnail
- (NSProgress *)retrieveThumbnailFor:(OCItem *)item to:(NSURL *)localThumbnailURL maximumSize:(CGSize)size resultTarget:(OCEventTarget *)eventTarget
{
	return ([self retrieveThumbnailFor:item to:localThumbnailURL maximumSize:size waitForConnectivity:YES resultTarget:eventTarget]);
}

- (NSProgress *)retrieveThumbnailFor:(OCItem *)item to:(NSURL *)localThumbnailURL maximumSize:(CGSize)size waitForConnectivity:(BOOL)waitForConnectivity resultTarget:(OCEventTarget *)eventTarget
{
	NSURL *url = nil;
	OCHTTPRequest *request = nil;
	NSError *error = nil;
	NSProgress *progress = nil;

	if (item.isPlaceholder)
	{
		// No remote thumbnails available for placeholders
		[eventTarget handleError:OCError(OCErrorItemNotFound) type:OCEventTypeRetrieveThumbnail uuid:nil sender:self];
		return (nil);
	}

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
			request = [OCHTTPRequest requestWithURL:url];

			request.groupID = item.path.stringByDeletingLastPathComponent;
			request.priority = NSURLSessionTaskPriorityDefault;

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
			request = [OCHTTPRequest requestWithURL:url];
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
		request.requiredSignals = waitForConnectivity ? self.actionSignals : self.propFindSignals;
		request.eventTarget = eventTarget;
		request.userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
			item.itemVersionIdentifier,	OCEventUserInfoKeyItemVersionIdentifier,
			[NSValue valueWithCGSize:size],	@"maximumSize",
		nil];
		request.resultHandlerAction = @selector(_handleRetrieveThumbnailResult:error:);

		if (localThumbnailURL != nil)
		{
			request.downloadRequest = YES;
			request.downloadedFileURL = localThumbnailURL;
		}

		request.forceCertificateDecisionDelegation = YES;

		// Attach to pipelines
		[self attachToPipelines];

		// Enqueue request
		[self.ephermalPipeline enqueueRequest:request forPartitionID:self.partitionID];

		progress = request.progress.progress;
	}

	if (error != nil)
	{
		[eventTarget handleError:error type:OCEventTypeRetrieveThumbnail uuid:nil sender:self];
	}

	return(progress);
}

- (void)_handleRetrieveThumbnailResult:(OCHTTPRequest *)request error:(NSError *)error
{
	OCEvent *event;

	if ((event = [OCEvent eventForEventTarget:request.eventTarget type:OCEventTypeRetrieveThumbnail uuid:request.identifier attributes:nil]) != nil)
	{
		if (request.error != nil)
		{
			event.error = request.error;
		}
		else
		{
			if (request.httpResponse.status.isSuccess)
			{
				OCItemThumbnail *thumbnail = [OCItemThumbnail new];
				OCItemVersionIdentifier *itemVersionIdentifier = request.userInfo[OCEventUserInfoKeyItemVersionIdentifier];
				CGSize maximumSize = ((NSValue *)request.userInfo[@"maximumSize"]).CGSizeValue;

				thumbnail.mimeType = request.httpResponse.headerFields[@"Content-Type"];

				if ((request.httpResponse.bodyURL != nil) && !request.httpResponse.bodyURLIsTemporary)
				{
					thumbnail.url = request.downloadedFileURL;
				}
				else
				{
					thumbnail.data = request.httpResponse.bodyData;
				}

				thumbnail.itemVersionIdentifier = itemVersionIdentifier;
				thumbnail.maximumSizeInPixels = maximumSize;

				event.result = thumbnail;
			}
			else
			{
				event.error = request.httpResponse.status.error;
			}
		}
	}

	if (event != nil)
	{
		OCErrorAddDateFromResponse(event.error, request.httpResponse);
		[request.eventTarget handleEvent:event sender:self];
	}
}

#pragma mark - Report API
- (nullable OCProgress *)filterFilesWithRules:(nullable NSDictionary<OCItemPropertyName, id> *)filterRules properties:(nullable NSArray<OCXMLNode *> *)properties resultTarget:(OCEventTarget *)eventTarget
{
	NSURL *endpointURL = [self URLForEndpoint:OCConnectionEndpointIDWebDAVRoot options:nil];
	NSMutableArray<OCXMLNode *> *filterRulesXML = [NSMutableArray new];
	OCHTTPDAVRequest *request;

	for (OCItemPropertyName propertyName in filterRules)
	{
		if ([propertyName isEqual:OCItemPropertyNameIsFavorite])
		{
			NSNumber *favoriteValue;

			if ((favoriteValue = OCTypedCast(filterRules[propertyName], NSNumber)) != nil)
			{
				[filterRulesXML addObject:[OCXMLNode elementWithName:@"oc:favorite" stringValue:favoriteValue.stringValue]];
			}
		}
	}

	if (filterRulesXML.count == 0)
	{
		[eventTarget handleError:OCError(OCErrorInsufficientParameters) type:OCEventTypeFilterFiles uuid:nil sender:self];
		return(nil);
	}

	if (properties == nil)
	{
		properties = [self _davItemAttributes];
	}

	request = [OCHTTPDAVRequest reportRequestWithURL:endpointURL rootElementName:@"oc:filter-files" content:[[NSArray alloc] initWithObjects:
		[OCXMLNode elementWithName:@"oc:filter-rules" children:filterRulesXML],
		(properties!=nil) ? [OCXMLNode elementWithName:@"D:prop" children:properties] : nil,
	nil]];
	request.eventTarget = eventTarget;
	request.resultHandlerAction = @selector(_handleFilterFilesResult:error:);
	request.requiredSignals = self.actionSignals;

	// Attach to pipelines
	[self attachToPipelines];

	// Enqueue request
	[self.ephermalPipeline enqueueRequest:request forPartitionID:self.partitionID];

	return (request.progress);
}

- (void)_handleFilterFilesResult:(OCHTTPRequest *)request error:(NSError *)error
{
	OCEvent *event;

	if ((event = [OCEvent eventForEventTarget:request.eventTarget type:OCEventTypeFilterFiles uuid:request.identifier attributes:nil]) != nil)
	{
		if (request.error != nil)
		{
			event.error = request.error;
		}
		else
		{
			if (request.httpResponse.status.isSuccess)
			{
				NSArray<OCItem *> *items = nil;
				NSArray <NSError *> *errors = nil;
				NSURL *endpointURL = [self URLForEndpoint:OCConnectionEndpointIDWebDAVRoot options:nil];

				if ((items = [((OCHTTPDAVRequest *)request) responseItemsForBasePath:endpointURL.path reuseUsersByID:self->_usersByUserID withErrors:&errors]) != nil)
				{
					event.result = items;
				}
				else
				{
					event.error = errors.firstObject;
				}
			}
			else
			{
				event.error = request.httpResponse.status.error;
			}
		}
	}

	if (event != nil)
	{
		OCErrorAddDateFromResponse(event.error, request.httpResponse);
		[request.eventTarget handleEvent:event sender:self];
	}
}

#pragma mark - Sending requests
- (NSProgress *)sendRequest:(OCHTTPRequest *)request ephermalCompletionHandler:(OCHTTPRequestEphermalResultHandler)ephermalResultHandler
{
	// Attach to pipelines
	[self attachToPipelines];

	request.ephermalResultHandler = ephermalResultHandler;

	// Strictly enforce bookmark certificate ..
	if (self.state != OCConnectionStateDisconnected) // .. for all requests if connecting or connected ..
	{
		request.forceCertificateDecisionDelegation = YES;
	}
	
	[self.ephermalPipeline enqueueRequest:request forPartitionID:self.partitionID];
	
	return (request.progress.progress);
}

#pragma mark - Sending requests synchronously
- (NSError *)sendSynchronousRequest:(OCHTTPRequest *)request
{
	__block NSError *retError = nil;

	OCSyncExec(requestCompletion, {
		[self sendRequest:request ephermalCompletionHandler:^(OCHTTPRequest *request, OCHTTPResponse *response, NSError *error) {
			retError = error;
			OCSyncExecDone(requestCompletion);
		}];
	});

	return (retError);
}

#pragma mark - Log tags
+ (NSArray<OCLogTagName> *)logTags
{
	return (@[@"CONN"]);
}

- (NSArray<OCLogTagName> *)logTags
{
	return (@[@"CONN"]);
}

@end

OCConnectionEndpointID OCConnectionEndpointIDWellKnown = @"well-known";
OCConnectionEndpointID OCConnectionEndpointIDCapabilities = @"endpoint-capabilities";
OCConnectionEndpointID OCConnectionEndpointIDUser = @"endpoint-user";
OCConnectionEndpointID OCConnectionEndpointIDWebDAV = @"endpoint-webdav";
OCConnectionEndpointID OCConnectionEndpointIDWebDAVMeta = @"endpoint-webdav-meta";
OCConnectionEndpointID OCConnectionEndpointIDWebDAVRoot = @"endpoint-webdav-root";
OCConnectionEndpointID OCConnectionEndpointIDThumbnail = @"endpoint-thumbnail";
OCConnectionEndpointID OCConnectionEndpointIDStatus = @"endpoint-status";
OCConnectionEndpointID OCConnectionEndpointIDShares = @"endpoint-shares";
OCConnectionEndpointID OCConnectionEndpointIDRemoteShares = @"endpoint-remote-shares";
OCConnectionEndpointID OCConnectionEndpointIDRecipients = @"endpoint-recipients";

OCConnectionEndpointURLOption OCConnectionEndpointURLOptionWellKnownSubPath = @"well-known-subpath";

OCClassSettingsKey OCConnectionPreferredAuthenticationMethodIDs = @"connection-preferred-authentication-methods";
OCClassSettingsKey OCConnectionAllowedAuthenticationMethodIDs = @"connection-allowed-authentication-methods";
OCClassSettingsKey OCConnectionCertificateExtendedValidationRule = @"connection-certificate-extended-validation-rule";
OCClassSettingsKey OCConnectionRenewedCertificateAcceptanceRule = @"connection-renewed-certificate-acceptance-rule";
OCClassSettingsKey OCConnectionMinimumVersionRequired = @"connection-minimum-server-version";
OCClassSettingsKey OCConnectionAllowBackgroundURLSessions = @"allow-background-url-sessions";
OCClassSettingsKey OCConnectionForceBackgroundURLSessions = @"force-background-url-sessions";
OCClassSettingsKey OCConnectionAllowCellular = @"allow-cellular";
OCClassSettingsKey OCConnectionPlainHTTPPolicy = @"plain-http-policy";
OCClassSettingsKey OCConnectionAlwaysRequestPrivateLink = @"always-request-private-link";

OCConnectionOptionKey OCConnectionOptionRequestObserverKey = @"request-observer";
OCConnectionOptionKey OCConnectionOptionLastModificationDateKey = @"last-modification-date";
OCConnectionOptionKey OCConnectionOptionIsNonCriticalKey = @"is-non-critical";
OCConnectionOptionKey OCConnectionOptionChecksumKey = @"checksum";
OCConnectionOptionKey OCConnectionOptionChecksumAlgorithmKey = @"checksum-algorithm";
OCConnectionOptionKey OCConnectionOptionGroupIDKey = @"group-id";
OCConnectionOptionKey OCConnectionOptionRequiredSignalsKey = @"required-signals";
OCConnectionOptionKey OCConnectionOptionRequiredCellularSwitchKey = @"required-cellular-switch";
OCConnectionOptionKey OCConnectionOptionTemporarySegmentFolderURLKey = @"temporary-segment-folder-url";

OCConnectionSignalID OCConnectionSignalIDAuthenticationAvailable = @"authAvailable";
