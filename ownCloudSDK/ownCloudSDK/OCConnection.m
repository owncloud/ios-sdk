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

@implementation OCConnection

@synthesize bookmark = _bookmark;
@synthesize authenticationMethod = _authenticationMethod;

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
			
		OCConnectionEndpointIDCapabilities  : @"ocs/v1.php/cloud/capabilities",
		OCConnectionEndpointIDWebDAV 	    : @"remote.php/webdav",
		OCConnectionInsertXRequestTracingID : @(YES)
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

#pragma mark - Endpoints
- (NSString *)pathForEndpoint:(OCConnectionEndpointID)endpoint
{
	if (endpoint != nil)
	{
		return ([self classSettingForOCClassSettingsKey:endpoint]);
	}
	
	return (nil);
}

- (NSURL *)URLForEndpoint:(OCConnectionEndpointID)endpoint options:(NSDictionary <NSString *,id> *)options
{
	NSString *endpointPath;
	
	if ((endpointPath = [self pathForEndpoint:endpoint]) != nil)
	{
		return ([[NSURL URLWithString:endpointPath relativeToURL:_bookmark.url] absoluteURL]);
	}

	return (nil);
}

- (NSURL *)URLForEndpointPath:(OCPath)endpointPath
{
	if (endpointPath != nil)
	{
		return ([[NSURL URLWithString:endpointPath relativeToURL:_bookmark.url] absoluteURL]);
	}
	
	return (_bookmark.url);
}

#pragma mark - Authentication
- (void)requestSupportedAuthenticationMethodsWithCompletionHandler:(void(^)(NSError *error, NSArray <OCAuthenticationMethodIdentifier> *))completionHandler
{
	// Stub implementation
}

- (void)generateAuthenticationDataWithMethod:(OCAuthenticationMethodIdentifier)methodIdentifier options:(OCAuthenticationMethodBookmarkAuthenticationDataGenerationOptions)options completionHandler:(void(^)(NSError *error, OCAuthenticationMethodIdentifier authenticationMethodIdentifier, NSData *authenticationData))completionHandler
{
	Class authenticationMethodClass;
	
	if ((authenticationMethodClass = [OCAuthenticationMethod registeredAuthenticationMethodForIdentifier:methodIdentifier]) != Nil)
	{
		OCAuthenticationMethod *authenticationMethod = [[authenticationMethodClass alloc] init];

		self.authenticationMethod = authenticationMethod;

		[authenticationMethod generateBookmarkAuthenticationDataWithConnection:self options:options completionHandler:completionHandler];
	}
}

- (BOOL)canSendAuthenticatedRequestsForQueue:(OCConnectionQueue *)queue availabilityHandler:(OCConnectionAuthenticationAvailabilityHandler)availabilityHandler
{
	__weak id<OCConnectionDelegate> delegate = _delegate;
	__weak OCConnection *weakSelf = self;
	BOOL canSend = YES;
	NSMutableArray <OCConnectionAuthenticationAvailabilityHandler> *pendingAuthenticationAvailabilityHandlers = _pendingAuthenticationAvailabilityHandlers;

	// Make sure the authentication method only receives calls to -canSendAuthenticatedRequestsForConnection:withAvailabilityHandler: after previous calls have finished
	@synchronized(pendingAuthenticationAvailabilityHandlers)
	{
		// Add availabilityHandler to pending
		[pendingAuthenticationAvailabilityHandlers addObject:availabilityHandler];

		if (pendingAuthenticationAvailabilityHandlers.count > 1)
		{
			// If others were also already pending, the previous response must already have been NO
			canSend = NO;
		}
		else
		{
			canSend = [self.authenticationMethod canSendAuthenticatedRequestsForConnection:self withAvailabilityHandler:^(NSError *error, BOOL authenticationIsAvailable) {
				// Share result with all pending Authentication Availability Handlers
				@synchronized(pendingAuthenticationAvailabilityHandlers)
				{
					for (OCConnectionAuthenticationAvailabilityHandler handler in pendingAuthenticationAvailabilityHandlers)
					{
						handler(error, authenticationIsAvailable);
					}
					
					[pendingAuthenticationAvailabilityHandlers removeAllObjects];
				};
				
				//
				if ((error != nil) && (weakSelf!=nil) && (delegate!=nil) && [delegate respondsToSelector:@selector(connection:handleError:)])
				{
					[delegate connection:weakSelf handleError:error];
				}
			}];
			
			if (canSend)
			{
				// Remove availabilityHandler from pending because it won't ever be called
				[pendingAuthenticationAvailabilityHandlers removeObject:availabilityHandler];
			}
		}
	}
	
	return (canSend);
}

- (OCAuthenticationMethod *)_authenticationMethodWithIdentifier:(OCAuthenticationMethodIdentifier)methodIdentifier
{
	Class authenticationMethodClass;

	if ((authenticationMethodClass = [OCAuthenticationMethod registeredAuthenticationMethodForIdentifier:methodIdentifier]) != Nil)
	{
		return ([[authenticationMethodClass alloc] init]);
	}
	
	return (nil);
}

- (OCAuthenticationMethod *)authenticationMethod
{
	if ((_authenticationMethod == nil) || ([[[_authenticationMethod class] identifier] isEqual:_bookmark.authenticationMethodIdentifier]))
	{
		self.authenticationMethod = [self _authenticationMethodWithIdentifier:_bookmark.authenticationMethodIdentifier];
	}
	
	return (_authenticationMethod);
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

@end

OCConnectionEndpointID OCConnectionEndpointIDCapabilities = @"endpoint-capabilities";
OCConnectionEndpointID OCConnectionEndpointIDWebDAV = @"endpoint-webdav";

OCClassSettingsKey OCConnectionInsertXRequestTracingID = @"connection-insert-x-request-id";
