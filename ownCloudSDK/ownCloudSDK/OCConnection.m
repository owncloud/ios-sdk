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
		OCConnectionEndpointIDWebDAV 	    : @"remote.php/dav/files",
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

#pragma mark - Base URL Extract
- (NSURL *)extractBaseURLFromRedirectionTargetURL:(NSURL *)inRedirectionTargetURL originalURL:(NSURL *)inOriginalURL
{
	NSURL *bookmarkURL = [_bookmark.url absoluteURL];
	NSURL *originalURL = [inOriginalURL absoluteURL];
	NSURL *redirectionTargetURL = [inRedirectionTargetURL absoluteURL];

	if ((bookmarkURL!=nil) && (originalURL!=nil))
	{
		if ((originalURL.path!=nil) && (bookmarkURL.path!=nil))
		{
			if ([originalURL.path hasPrefix:bookmarkURL.path])
			{
				NSString *endpointPath = [originalURL.path substringFromIndex:bookmarkURL.path.length];
				
				if (endpointPath.length > 1)
				{
					NSRange endpointPathRange = [redirectionTargetURL.absoluteString rangeOfString:endpointPath];
					
					if (endpointPathRange.location != NSNotFound)
					{
						return ([NSURL URLWithString:[redirectionTargetURL.absoluteString substringToIndex:endpointPathRange.location]]);
					}
				}
			}
		}
	}
	
	return(nil);
}

- (BOOL)_isAlternativeBaseURLSafeUpgrade:(NSURL *)alternativeBaseURL
{
	if ((alternativeBaseURL!=nil) && (_bookmark.url!=nil))
	{
		return (([alternativeBaseURL.host isEqual:_bookmark.url.host]) &&
			([alternativeBaseURL.path isEqual:_bookmark.url.path]) &&
			([_bookmark.url.scheme isEqual:@"http"] && [alternativeBaseURL.scheme isEqual:@"https"]));
	}
	
	return(NO);
}

#pragma mark - Authentication
- (void)requestSupportedAuthenticationMethodsWithOptions:(OCAuthenticationMethodDetectionOptions)options completionHandler:(void(^)(NSError *error, NSArray <OCAuthenticationMethodIdentifier> *supportedMethods))completionHandler
{
	NSArray <Class> *authenticationMethodClasses = [OCAuthenticationMethod registeredAuthenticationMethodClasses];
	NSMutableSet <NSURL *> *detectionURLs = [NSMutableSet set];
	NSMutableDictionary <NSString *, NSArray <NSURL *> *> *detectionURLsByMethod = [NSMutableDictionary dictionary];
	NSMutableDictionary <NSURL *, OCConnectionRequest *> *detectionRequestsByDetectionURL = [NSMutableDictionary dictionary];
	
	if (completionHandler==nil) { return; }
	
	// Add OCAuthenticationMethodAllowURLProtocolUpgrades support
	completionHandler = ^(NSError *error, NSArray <OCAuthenticationMethodIdentifier> *supportedMethods){
		if ((error!=nil) && [error isOCErrorWithCode:OCErrorAuthorizationRedirect] &&
		    (options!=nil) && (options[OCAuthenticationMethodAllowURLProtocolUpgradesKey]!=nil) && ((NSNumber *)options[OCAuthenticationMethodAllowURLProtocolUpgradesKey]).boolValue)
		{
			NSURL *redirectURLBase;

			if ((redirectURLBase = [error ocErrorInfoDictionary][OCAuthorizationMethodAlternativeServerURLKey]) != nil)
			{
				if ([self _isAlternativeBaseURLSafeUpgrade:redirectURLBase])
				{
					_bookmark.url = redirectURLBase;
					
					[self requestSupportedAuthenticationMethodsWithOptions:options completionHandler:completionHandler];

					return;
				}
			}
		}
		
		completionHandler(error, supportedMethods);
	};
	
	// Collect detection URLs for pre-loading
	for (Class authenticationMethodClass in authenticationMethodClasses)
	{
		OCAuthenticationMethodIdentifier authMethodIdentifier;
		
		if ((authMethodIdentifier = [authenticationMethodClass identifier]) != nil)
		{
			NSArray <NSURL *> *authMethodDetectionURLs;
			
			if ((authMethodDetectionURLs = [authenticationMethodClass detectionURLsForConnection:self]) != nil)
			{
				[detectionURLs addObjectsFromArray:authMethodDetectionURLs];
				
				detectionURLsByMethod[authMethodIdentifier] = authMethodDetectionURLs;
			}
		}
	}
	
	// Pre-load detection URLs
	dispatch_group_t preloadCompletionGroup = dispatch_group_create();
	
	for (NSURL *detectionURL in detectionURLs)
	{
		OCConnectionRequest *request = [OCConnectionRequest requestWithURL:detectionURL];
		
		request.skipAuthorization = YES;
		
		dispatch_group_enter(preloadCompletionGroup);
		
		request.ephermalResultHandler = ^(OCConnectionRequest *request, NSError *error) {
			dispatch_group_leave(preloadCompletionGroup);
		};
		
		detectionRequestsByDetectionURL[detectionURL] = request;
	
		[self.commandQueue enqueueRequest:request];
	}

	// Schedule block for when all detection URL pre-loads have finished
	dispatch_group_notify(preloadCompletionGroup, dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
		// Pass result to authentication methods
		NSMutableArray<OCAuthenticationMethodIdentifier> *supportedAuthMethodIdentifiers = [NSMutableArray array];

		dispatch_group_t detectionCompletionGroup = dispatch_group_create();

		for (Class authenticationMethodClass in authenticationMethodClasses)
		{
			OCAuthenticationMethodIdentifier authMethodIdentifier;
			
			if ((authMethodIdentifier = [authenticationMethodClass identifier]) != nil)
			{
				NSMutableDictionary <NSURL *, OCConnectionRequest *> *resultsByURL = [NSMutableDictionary dictionary];
				
				// Compile pre-load results
				for (NSURL *detectionURL in detectionURLsByMethod[authMethodIdentifier])
				{
					OCConnectionRequest *request;
					
					if ((request = [detectionRequestsByDetectionURL objectForKey:detectionURL]) != nil)
					{
						resultsByURL[detectionURL] = request;
					}
				}
				
				dispatch_group_enter(detectionCompletionGroup);
				
				[authenticationMethodClass detectAuthenticationMethodSupportForConnection:self withServerResponses:resultsByURL options:options completionHandler:^(OCAuthenticationMethodIdentifier identifier, BOOL supported) {
					if (supported)
					{
						[supportedAuthMethodIdentifiers addObject:identifier];
					}

					dispatch_group_leave(detectionCompletionGroup);
				}];
			}
		}
		
		// Schedule block for when all methods have completed detection
		dispatch_group_notify(detectionCompletionGroup, dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
			__block NSError *error = nil;
			
			if ((supportedAuthMethodIdentifiers.count == 0) && (detectionRequestsByDetectionURL.count > 0))
			{
				[detectionRequestsByDetectionURL enumerateKeysAndObjectsUsingBlock:^(NSURL *url, OCConnectionRequest *request, BOOL * _Nonnull stop) {
					if (request.responseRedirectURL != nil)
					{
						NSURL *alternativeBaseURL;
				
						if ((alternativeBaseURL = [self extractBaseURLFromRedirectionTargetURL:request.responseRedirectURL originalURL:request.url]) != nil)
						{
							error = OCErrorWithInfo(OCErrorAuthorizationRedirect, @{ OCAuthorizationMethodAlternativeServerURLKey : alternativeBaseURL });
						}
						else
						{
							error = OCErrorWithInfo(OCErrorAuthorizationFailed, @{ OCAuthorizationMethodAlternativeServerURLKey : request.responseRedirectURL });
						}
					}
					else if (request.error != nil)
					{
						error = request.error;
					}
				}];
			}
		
			completionHandler(error, supportedAuthMethodIdentifiers);
		});
	});
}

- (void)generateAuthenticationDataWithMethod:(OCAuthenticationMethodIdentifier)methodIdentifier options:(OCAuthenticationMethodBookmarkAuthenticationDataGenerationOptions)options completionHandler:(void(^)(NSError *error, OCAuthenticationMethodIdentifier authenticationMethodIdentifier, NSData *authenticationData))completionHandler
{
	Class authenticationMethodClass;
	
	if ((authenticationMethodClass = [OCAuthenticationMethod registeredAuthenticationMethodForIdentifier:methodIdentifier]) != Nil)
	{
		OCAuthenticationMethod *authenticationMethod = [[authenticationMethodClass alloc] init];

		self.authenticationMethod = authenticationMethod;

		[authenticationMethod generateBookmarkAuthenticationDataWithConnection:self options:options completionHandler:^(NSError *error, OCAuthenticationMethodIdentifier authenticationMethodIdentifier, NSData *authenticationData) {
			if ((error != nil) && [error isOCErrorWithCode:OCErrorAuthorizationRedirect])
			{
				NSNumber *allowURLProtocolUpgrades = options[OCAuthenticationMethodAllowURLProtocolUpgradesKey];
			
				if ((allowURLProtocolUpgrades!=nil) && allowURLProtocolUpgrades.boolValue)
				{
					NSURL *redirectURLBase;
					
					if ((redirectURLBase = [error ocErrorInfoDictionary][OCAuthorizationMethodAlternativeServerURLKey]) != nil)
					{
						if ([self _isAlternativeBaseURLSafeUpgrade:redirectURLBase])
						{
							_bookmark.url = redirectURLBase;
							
							[self generateAuthenticationDataWithMethod:methodIdentifier options:options completionHandler:completionHandler];

							return;
						}
					}
				}
			}
		
			if (completionHandler != nil)
			{
				completionHandler(error, authenticationMethodIdentifier, authenticationData);
			}
		}];
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
		availabilityHandler = [availabilityHandler copy]; // Make a copy of the block. Otherwise ARC will create one for us later and pointers may differ, so that -removeObject: can't remove it because the copy has a different pointer. The result would be that the queue hangs forever for seemingly no reason.
		
		[pendingAuthenticationAvailabilityHandlers addObject:availabilityHandler];

		if (pendingAuthenticationAvailabilityHandlers.count > 1)
		{
			// If others were also already pending, the previous response must already have been NO
			canSend = NO;
		}
		else
		{
			OCAuthenticationMethod *authenticationMethod;
			
			if ((authenticationMethod = self.authenticationMethod) != nil)
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
			}
			else
			{
				canSend = YES;
			}
			
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

@end

OCConnectionEndpointID OCConnectionEndpointIDCapabilities = @"endpoint-capabilities";
OCConnectionEndpointID OCConnectionEndpointIDWebDAV = @"endpoint-webdav";

OCClassSettingsKey OCConnectionInsertXRequestTracingID = @"connection-insert-x-request-id";
