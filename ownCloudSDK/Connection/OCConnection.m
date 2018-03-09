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
#import "OCLogger.h"

// Imported to use the identifiers in OCConnectionPreferredAuthenticationMethodIDs only
#import "OCAuthenticationMethodOAuth2.h"
#import "OCAuthenticationMethodBasicAuth.h"

@implementation OCConnection

@dynamic authenticationMethod;

@synthesize bookmark = _bookmark;

@synthesize commandQueue = _commandQueue;

@synthesize uploadQueue = _uploadQueue;
@synthesize downloadQueue = _downloadQueue;

@synthesize state = _state;

@synthesize delegate = _delegate;

#pragma mark - Class settings
+ (OCClassSettingsIdentifier)classSettingsIdentifier
{
	return (@"connection");
}

+ (NSDictionary<NSString *,id> *)defaultSettingsForIdentifier:(OCClassSettingsIdentifier)identifier
{
	return (@{
			
		OCConnectionEndpointIDCapabilities  		: @"ocs/v1.php/cloud/capabilities",
		OCConnectionEndpointIDWebDAV 	    		: @"remote.php/dav/files",
		OCConnectionEndpointIDStatus 	    		: @"status.php",
		OCConnectionPreferredAuthenticationMethodIDs 	: @[ OCAuthenticationMethodOAuth2Identifier, OCAuthenticationMethodBasicAuthIdentifier ],
		OCConnectionInsertXRequestTracingID 		: @(YES)
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
	if ((_delegate!=nil) && [_delegate respondsToSelector:@selector(connection:request:certificate:validationResult:validationError:proceedHandler:)])
	{
		// Consult delegate
		[_delegate connection:self request:request certificate:certificate validationResult:validationResult validationError:validationError proceedHandler:proceedHandler];
	}
	else
	{
		// Default to safe option: reject
		if (proceedHandler != nil)
		{
			proceedHandler(NO);
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

		// Reusable Completion Handler
		OCConnectionEphermalResultHandler (^CompletionHandlerWithResultHandler)(OCConnectionEphermalResultHandler) = ^(OCConnectionEphermalResultHandler resultHandler)
		{
			return ^(OCConnectionRequest *request, NSError *error){
				if (error != nil)
				{
					// An error occured
					connectProgress.localizedDescription = OCLocalizedString(@"Error", @"");
					completionHandler(error, [OCConnectionIssue issueForError:error level:OCConnectionIssueLevelError issueHandler:nil]);
					resultHandler(request, error);
				}
				else
				{
					if (request.responseHTTPStatus.isSuccess)
					{
						// Success
						resultHandler(request, error);
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
								issue = [OCConnectionIssue issueForRedirectionFromURL:_bookmark.url toSuggestedURL:alternativeBaseURL issueHandler:nil];
								issue.level = OCConnectionIssueLevelError;

								error = OCErrorWithInfo(OCErrorServerBadRedirection, @{ OCAuthorizationMethodAlternativeServerURLKey : responseRedirectURL });
							}
						}

						connectProgress.localizedDescription = @"";
						completionHandler(error, issue);
						resultHandler(request, error);
					}
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
					
					if ([request responseBodyConvertedDictionaryFromJSONWithError:&jsonError] == nil)
					{
						// JSON decode error
						completionHandler(jsonError, [OCConnectionIssue issueForError:jsonError level:OCConnectionIssueLevelError issueHandler:nil]);
					}
					else
					{
						// Got status successfully => now authenticate connection
						connectProgress.localizedDescription = OCLocalizedString(@"Authenticating…", @"");

						[authMethod authenticateConnection:self withCompletionHandler:^(NSError *authConnError, OCConnectionIssue *authConnIssue) {
							if ((authConnError!=nil) || (authConnIssue!=nil))
							{
								// Error or issue
								completionHandler(authConnError, authConnIssue);
							}
							else
							{
								// Connected authenticated. Now send an authenticated WebDAV request
								OCConnectionDAVRequest *davRequest;
								
								davRequest = [OCConnectionDAVRequest propfindRequestWithURL:[self URLForEndpoint:OCConnectionEndpointIDWebDAV options:nil] depth:0];
								
								[davRequest.xmlRequestPropAttribute addChildren:@[
									[OCXMLNode elementWithName:@"D:supported-method-set"],
								]];
								
								OCLog(@"%@", davRequest.xmlRequest.XMLString);

								[self sendRequest:davRequest toQueue:self.commandQueue ephermalCompletionHandler:CompletionHandlerWithResultHandler(^(OCConnectionRequest *request, NSError *error) {
									if ((error == nil) && (request.responseHTTPStatus.isSuccess))
									{
										// DAV request executed successfully
										connectProgress.localizedDescription = OCLocalizedString(@"Connected", @"");
										
										NSLog(@"%@ - %@", request.response, request.responseBodyAsString);

										completionHandler(nil, nil);
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
			if (completionHandler!=nil)
			{
				completionHandler();
			}
		}];
	}
	else
	{
		if (completionHandler!=nil)
		{
			completionHandler();
		}
	}
}

#pragma mark - Metadata actions
- (NSProgress *)retrieveItemListAtPath:(OCPath)path completionHandler:(void(^)(NSError *error, NSArray <OCItem *> *items))completionHandler
{
	OCConnectionDAVRequest *davRequest;
	NSURL *url = [self URLForEndpoint:OCConnectionEndpointIDWebDAV options:nil];
	
	if (path != nil)
	{
		url = [url URLByAppendingPathComponent:path];
	}
	
	if ((davRequest = [OCConnectionDAVRequest propfindRequestWithURL:url depth:1]) != nil)
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

		OCLog(@"%@", davRequest.xmlRequest.XMLString);
		
		[self sendRequest:davRequest toQueue:self.commandQueue ephermalCompletionHandler:^(OCConnectionRequest *request, NSError *error) {
			NSLog(@"Error: %@ - Response: %@", error, request.responseBodyAsString);
			[(OCConnectionDAVRequest *)davRequest responseItems];
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


- (NSProgress *)retrieveThumbnailFor:(OCItem *)item resultTarget:(OCEventTarget *)eventTarget
{
	// Stub implementation
	return(nil);
}


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
OCConnectionEndpointID OCConnectionEndpointIDWebDAV = @"endpoint-webdav";
OCConnectionEndpointID OCConnectionEndpointIDStatus = @"endpoint-status";

OCClassSettingsKey OCConnectionInsertXRequestTracingID = @"connection-insert-x-request-id";
OCClassSettingsKey OCConnectionPreferredAuthenticationMethodIDs = @"connection-preferred-authentication-methods";
OCClassSettingsKey OCConnectionAllowedAuthenticationMethodIDs = @"connection-allowed-authentication-methods";

