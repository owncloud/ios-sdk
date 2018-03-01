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

// Imported to use the identifiers in OCConnectionPreferredAuthenticationMethodIDs only
#import "OCAuthenticationMethodOAuth2.h"
#import "OCAuthenticationMethodBasicAuth.h"

@implementation OCConnection

@dynamic authenticationMethod;

@synthesize bookmark = _bookmark;

@synthesize commandQueue = _commandQueue;

@synthesize uploadQueue = _uploadQueue;
@synthesize downloadQueue = _downloadQueue;

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

#pragma mark - Metadata actions
- (NSProgress *)retrieveItemListAtPath:(OCPath)path completionHandler:(void(^)(NSError *error, NSArray <OCItem *> *items))completionHandler
{
	// Stub implementation
	return(nil);
}

#pragma mark - Actions
- (NSProgress *)createFolderNamed:(NSString *)newFolderName atPath:(OCPath)path options:(NSDictionary *)options resultTarget:(OCEventTarget *)eventTarget
{
	// Stub implementation
	return(nil);
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

