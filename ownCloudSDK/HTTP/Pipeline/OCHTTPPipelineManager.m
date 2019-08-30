//
//  OCHTTPPipelineManager.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 05.02.19.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2019, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCHTTPPipelineManager.h"
#import "OCAppIdentity.h"
#import "OCVault.h"
#import "OCLogger.h"
#import "OCMacros.h"

@interface OCHTTPPipelineManager ()
{
	NSMutableDictionary<OCHTTPPipelineID, OCHTTPPipeline *> *_pipelineByIdentifier;
	NSMutableDictionary<OCHTTPPipelineID, NSNumber *> *_usersByIdentifier;

	NSMutableDictionary<OCHTTPPipelineID, NSMutableArray<OCHTTPPipelineManagerRequestCompletionHandler> *> *_requestCompletionHandlersByIdentifier;
	NSMutableDictionary<OCHTTPPipelineID, NSMutableArray<dispatch_block_t> *> *_returnCompletionHandlersByIdentifier;

	NSMutableDictionary<NSString*, dispatch_block_t> *_eventHandlingFinishedBlockBySessionIdentifier;

	OCHTTPPipelineBackend *_backend;
	OCHTTPPipelineBackend *_ephermalBackend;

	dispatch_queue_t _adminQueue;
}

@end

@implementation OCHTTPPipelineManager

+ (OCHTTPPipelineManager *)sharedPipelineManager
{
	static dispatch_once_t onceToken;
	static OCHTTPPipelineManager *sharedPipelineManager;

	dispatch_once(&onceToken, ^{
		sharedPipelineManager = [OCHTTPPipelineManager new];
	});

	return (sharedPipelineManager);
}

#pragma mark - Set up persistent pipelines
+ (void)setupPersistentPipelines
{
	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		NSArray <OCHTTPPipelineID> *persistentPipelineIDs = @[ OCHTTPPipelineIDLocal, OCHTTPPipelineIDBackground ];

		for (OCHTTPPipelineID pipelineID in persistentPipelineIDs)
		{
			OCLogDebug(@"Setting up pipeline=%@ for persistance", pipelineID);

			[OCHTTPPipelineManager.sharedPipelineManager requestPipelineWithIdentifier:pipelineID completionHandler:^(OCHTTPPipeline * _Nullable pipeline, NSError * _Nullable error) {
				OCLogDebug(@"Started pipeline=%@ (%@) for persistance with error=%@", pipelineID, pipeline, error);
			}];
		}
	});
}

#pragma mark - Init & Dealloc
- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_pipelineByIdentifier = [NSMutableDictionary new];
		_usersByIdentifier = [NSMutableDictionary new];
		_requestCompletionHandlersByIdentifier = [NSMutableDictionary new];
		_returnCompletionHandlersByIdentifier = [NSMutableDictionary new];
		_eventHandlingFinishedBlockBySessionIdentifier = [NSMutableDictionary new];

		_adminQueue = dispatch_queue_create("OCHTTPPipelineManager queue", DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL);
	}

	return(self);
}

#pragma mark - Backend
- (NSURL *)backendRootURL
{
	return [[[OCAppIdentity sharedAppIdentity] appGroupContainerURL] URLByAppendingPathComponent:OCVaultPathHTTPPipeline];
}

- (OCHTTPPipelineBackend *)backend
{
	if (_backend == nil)
	{
		NSURL *backendRootURL = self.backendRootURL;
		NSURL *backendDBURL = [backendRootURL URLByAppendingPathComponent:@"backend.sqlite"];
		NSURL *backendTemporaryFilesRootURL = [backendRootURL URLByAppendingPathComponent:@"tmp"];
		NSError *error = nil;

		if (![[NSFileManager defaultManager] createDirectoryAtURL:backendRootURL withIntermediateDirectories:YES attributes:@{ NSFileProtectionKey : NSFileProtectionCompleteUntilFirstUserAuthentication } error:&error])
		{
			OCLogDebug(@"Creation of %@ failed with error=%@", backendRootURL, error);
		}

		_backend = [[OCHTTPPipelineBackend alloc] initWithSQLDB:[[OCSQLiteDB alloc] initWithURL:backendDBURL] temporaryFilesRoot:backendTemporaryFilesRootURL];
	}

	return (_backend);
}

- (OCHTTPPipelineBackend *)ephermalBackend
{
	NSURL *backendTemporaryFilesRootURL = [self.backendRootURL URLByAppendingPathComponent:@"tmp"];

	if (_ephermalBackend == nil)
	{
		_ephermalBackend = [[OCHTTPPipelineBackend alloc] initWithSQLDB:[[OCSQLiteDB alloc] initWithURL:nil] temporaryFilesRoot:backendTemporaryFilesRootURL];
	}

	return (_ephermalBackend);
}

#pragma mark -
- (void)_addRequestCompletionHandler:(OCHTTPPipelineManagerRequestCompletionHandler)completionHandler forPipelineID:(OCHTTPPipelineID)pipelineID
{
	NSMutableArray<OCHTTPPipelineManagerRequestCompletionHandler> *requestCompletionHandlers;

	if ((requestCompletionHandlers = _requestCompletionHandlersByIdentifier[pipelineID]) == nil)
	{
		requestCompletionHandlers = [NSMutableArray new];
		_requestCompletionHandlersByIdentifier[pipelineID] = requestCompletionHandlers;
	}

	[requestCompletionHandlers addObject:[completionHandler copy]];
}

- (void)_addReturnCompletionHandler:(dispatch_block_t)completionHandler forPipelineID:(OCHTTPPipelineID)pipelineID
{
	NSMutableArray<dispatch_block_t> *returnCompletionHandlers;

	if ((returnCompletionHandlers = _returnCompletionHandlersByIdentifier[pipelineID]) == nil)
	{
		returnCompletionHandlers = [NSMutableArray new];
		_returnCompletionHandlersByIdentifier[pipelineID] = returnCompletionHandlers;
	}

	[returnCompletionHandlers addObject:[completionHandler copy]];
}

- (void)_startPipeline:(OCHTTPPipeline *)pipeline
{
	NSMutableArray<OCHTTPPipelineManagerRequestCompletionHandler> *requestCompletionHandlers = nil;
	OCHTTPPipelineID pipelineID = pipeline.identifier;
	__block NSError *startError = nil;

	// Start pipeline
	OCSyncExec(waitForPipelineStart, {
		[pipeline startWithCompletionHandler:^(id sender, NSError *error) {
			startError = error;
			OCSyncExecDone(waitForPipelineStart);
		}];
	});

	// Run completion handlers
	requestCompletionHandlers = _requestCompletionHandlersByIdentifier[pipelineID];
	[_requestCompletionHandlersByIdentifier removeObjectForKey:pipelineID];

	for (OCHTTPPipelineManagerRequestCompletionHandler completionHandler in requestCompletionHandlers)
	{
		completionHandler((startError==nil) ? pipeline : nil, startError);
	}
}

- (void)_stopPipeline:(OCHTTPPipeline *)pipeline graceful:(BOOL)graceful
{
	OCHTTPPipelineID pipelineID = pipeline.identifier;
	__block NSError *stopError = nil;
	NSMutableArray<dispatch_block_t> *returnCompletionHandlers = nil;

	// Stop pipeline
	OCSyncExec(waitForPipelineStop, {
		[pipeline stopWithCompletionHandler:^(id sender, NSError *error) {
			stopError = error;
			OCSyncExecDone(waitForPipelineStop);
		} graceful:graceful];
	});

	// Remove pipeline
	@synchronized(self->_pipelineByIdentifier)
	{
		[self->_pipelineByIdentifier removeObjectForKey:pipelineID];
	}
	self->_usersByIdentifier[pipelineID] = @(0);

	// Run completion handlers
	returnCompletionHandlers = _returnCompletionHandlersByIdentifier[pipelineID];
	[_returnCompletionHandlersByIdentifier removeObjectForKey:pipelineID];

	for (dispatch_block_t completionHandler in returnCompletionHandlers)
	{
		completionHandler();
	}
}

- (nullable NSURLSessionConfiguration *)_backgroundURLSessionConfigurationWithIdentifier:(NSString *)identifier
{
	NSURLSessionConfiguration *sessionConfiguration = nil;

	sessionConfiguration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:identifier];

	sessionConfiguration.sharedContainerIdentifier = [OCAppIdentity sharedAppIdentity].appGroupIdentifier;
	sessionConfiguration.URLCredentialStorage = nil; // Do not use credential store at all
	sessionConfiguration.URLCache = nil; // Do not cache responses
	sessionConfiguration.HTTPCookieStorage = nil; // Do not store cookies
	sessionConfiguration.networkServiceType = NSURLNetworkServiceTypeResponsiveData;

	return (sessionConfiguration);
}

- (nullable OCHTTPPipeline *)buildPipelineForIdentifier:(OCHTTPPipelineID)pipelineID
{
	OCHTTPPipeline *pipeline = nil;
	OCHTTPPipelineBackend *backend = nil;
	NSURLSessionConfiguration *sessionConfiguration = nil;

	if ([pipelineID isEqual:OCHTTPPipelineIDLocal] ||
	    [pipelineID isEqual:OCHTTPPipelineIDEphermal])
	{
		sessionConfiguration = [NSURLSessionConfiguration ephemeralSessionConfiguration];

		sessionConfiguration.URLCredentialStorage = nil; // Do not use credential store at all
		sessionConfiguration.URLCache = nil; // Do not cache responses
		sessionConfiguration.HTTPCookieStorage = nil; // Do not store cookies

		sessionConfiguration.shouldUseExtendedBackgroundIdleMode = YES;
	}

	if ([pipelineID isEqual:OCHTTPPipelineIDLocal])
	{
		backend = self.backend;
	}

	if ([pipelineID isEqual:OCHTTPPipelineIDEphermal])
	{
		backend = self.ephermalBackend;
	}

	if ([pipelineID isEqual:OCHTTPPipelineIDBackground])
	{
		sessionConfiguration = [self _backgroundURLSessionConfigurationWithIdentifier:[pipelineID stringByAppendingFormat:@";%@", self.backend.bundleIdentifier]];

		backend = self.backend;
	}

	if (sessionConfiguration != nil)
	{
		pipeline = [[OCHTTPPipeline alloc] initWithIdentifier:pipelineID backend:backend configuration:sessionConfiguration];
	}

	return (pipeline);
}

- (void)requestPipelineWithIdentifier:(OCHTTPPipelineID)pipelineID completionHandler:(OCHTTPPipelineManagerRequestCompletionHandler)inCompletionHandler
{
	dispatch_async(_adminQueue, ^{
		OCHTTPPipeline *startPipeline = nil;
		OCHTTPPipelineManagerRequestCompletionHandler completionHandler = inCompletionHandler;

		OCHTTPPipeline *pipeline;

		OCLogDebug(@"Request for pipelineID=%@", pipelineID);

		if ([OCLogger logsForLevel:OCLogLevelDebug])
		{
			completionHandler = ^(OCHTTPPipeline * _Nullable pipeline, NSError * _Nullable error) {
				OCLogDebug(@"Served request for pipelineID=%@ with pipeline=%@, error=%@", pipelineID, pipeline, error);

				completionHandler(pipeline, error);
			};
		}

		@synchronized(self->_pipelineByIdentifier)
		{
			pipeline = [self->_pipelineByIdentifier objectForKey:pipelineID];
		}

		if (pipeline != nil)
		{
			if (pipeline.state != OCHTTPPipelineStateStopping)
			{
				// Increase user count
				self->_usersByIdentifier[pipelineID] = @(self->_usersByIdentifier[pipelineID].integerValue + 1);
			}

			__weak OCHTTPPipelineManager *weakSelf = self;

			switch (pipeline.state)
			{
				case OCHTTPPipelineStateStarting:
					// Start already in progress => add completionHandler
					[self _addRequestCompletionHandler:completionHandler forPipelineID:pipelineID];
				break;

				case OCHTTPPipelineStateStopped:
					// Pipeline stopped => add completionHandler and start pipeline
					[self _addRequestCompletionHandler:completionHandler forPipelineID:pipelineID];
					[self _startPipeline:pipeline];
				break;

				case OCHTTPPipelineStateStarted:
					// Pipeline started => call completionHandler
					completionHandler(pipeline, nil);
				break;

				case OCHTTPPipelineStateStopping:
					// Pipeline about to stop => add return completionHandler retrying the call
					[self _addReturnCompletionHandler:^{
						[weakSelf requestPipelineWithIdentifier:pipelineID completionHandler:completionHandler];
					} forPipelineID:pipelineID];
				break;
			}
		}
		else
		{
			if ((pipeline = [self buildPipelineForIdentifier:pipelineID]) != nil)
			{
				// Increase user count
				self->_usersByIdentifier[pipelineID] = @(self->_usersByIdentifier[pipelineID].integerValue + 1);

				if (self->_usersByIdentifier[pipelineID].integerValue == 1)
				{
					@synchronized(self->_pipelineByIdentifier)
					{
						self->_pipelineByIdentifier[pipelineID] = pipeline;
					}

					[self _addRequestCompletionHandler:completionHandler forPipelineID:pipelineID];

					startPipeline = pipeline;
				}
			}
		}

		if (startPipeline != nil)
		{
			[self _startPipeline:startPipeline];
		}
	});
}

- (void)returnPipelineWithIdentifier:(OCHTTPPipelineID)pipelineID completionHandler:(dispatch_block_t)completionHandler
{
	dispatch_async(_adminQueue, ^{
		OCHTTPPipeline *stopPipeline = nil;

		// Decrease user count
		NSInteger newUsersCount;

		if ((newUsersCount = self->_usersByIdentifier[pipelineID].integerValue - 1) < 0)
		{
			OCLogWarning(@"Over-return of pipeline %@ detected. Check if queues where force-stopped.", pipelineID);
			if (completionHandler != nil)
			{
				completionHandler();
			}
			return;
		}

		self->_usersByIdentifier[pipelineID] = @(newUsersCount);

		if (newUsersCount == 0)
		{
			@synchronized(self->_pipelineByIdentifier)
			{
				stopPipeline = [self->_pipelineByIdentifier objectForKey:pipelineID];
			}

			if (stopPipeline != nil)
			{
				if (completionHandler != nil)
				{
					[self _addReturnCompletionHandler:completionHandler forPipelineID:pipelineID];
				}
			}
		}

		if (stopPipeline != nil)
		{
			[self _stopPipeline:stopPipeline graceful:YES];
		}
		else
		{
			if (completionHandler != nil)
			{
				completionHandler();
			}
		}
	});
}

#pragma mark - Background session recovery
- (void)setEventHandlingFinishedBlock:(dispatch_block_t)finishedBlock forURLSessionIdentifier:(NSString *)urlSessionIdentifier
{
	@synchronized(self)
	{
		_eventHandlingFinishedBlockBySessionIdentifier[urlSessionIdentifier] = finishedBlock;
	}
}

- (dispatch_block_t)eventHandlingFinishedBlockForURLSessionIdentifier:(NSString *)urlSessionIdentifier remove:(BOOL)remove
{
	dispatch_block_t eventHandlingFinishedBlock;

	@synchronized(self)
	{
		eventHandlingFinishedBlock = _eventHandlingFinishedBlockBySessionIdentifier[urlSessionIdentifier];

		if (remove)
		{
			[_eventHandlingFinishedBlockBySessionIdentifier removeObjectForKey:urlSessionIdentifier];
		}
	}

	return (eventHandlingFinishedBlock);
}

- (void)handleEventsForBackgroundURLSession:(NSString *)sessionIdentifier completionHandler:(dispatch_block_t)completionHandler
{
	NSArray <NSString *> *idComponents;

	OCLogDebug(@"Handling events for backgroundURLSession %@", sessionIdentifier);

	if (((idComponents = [sessionIdentifier componentsSeparatedByString:@";"]) != nil) && (idComponents.count == 2))
	{
		OCHTTPPipelineID pipelineID = [idComponents firstObject];
		NSString *bundleIdentifier = [idComponents lastObject];
		__weak OCHTTPPipelineManager *weakSelf = self;
		dispatch_block_t returnPipelineAndCallCompletionHandlerBlock = ^{
			OCLogDebug(@"Done handling events for backgroundURLSession %@", sessionIdentifier);
			if (completionHandler != nil)
			{
				completionHandler();
			}

			[weakSelf returnPipelineWithIdentifier:pipelineID completionHandler:^{
				OCLogDebug(@"Returned background event handling pipeline %@ for %@", pipelineID, sessionIdentifier);
			}];
		};

		if ([bundleIdentifier isEqual:self.backend.bundleIdentifier])
		{
			// This queue belongs to this process
			OCLogDebug(@"Handling backgroundURLSession requests for app");

			[self setEventHandlingFinishedBlock:returnPipelineAndCallCompletionHandlerBlock forURLSessionIdentifier:sessionIdentifier];

			[self requestPipelineWithIdentifier:pipelineID completionHandler:^(OCHTTPPipeline * _Nullable pipeline, NSError * _Nullable error) {
				OCLogDebug(@"Request for background event handling pipeline for %@ returned with pipeline=%@, error=%@", sessionIdentifier, pipeline, error);
			}];
		}
		else
		{
			// This queue belongs to another process (likely an extension)
			OCLogDebug(@"Handling backgroundURLSession requests for extension");

			[self requestPipelineWithIdentifier:pipelineID completionHandler:^(OCHTTPPipeline * _Nullable pipeline, NSError * _Nullable error) {
				OCLogDebug(@"Request for background event handling pipeline for %@ returned with pipeline=%@, error=%@", sessionIdentifier, pipeline, error);

				[pipeline attachBackgroundURLSessionWithConfiguration:[self _backgroundURLSessionConfigurationWithIdentifier:sessionIdentifier] handlingCompletionHandler:returnPipelineAndCallCompletionHandlerBlock];
			}];
		}
	}
	else
	{
		OCLogDebug(@"Can't handle events for unknown formatted backgroundURLSession %@", sessionIdentifier);
		completionHandler();
	}
}

+ (NSArray<OCLogTagName> *)logTags
{
	return (@[@"PLManager"]);
}

- (NSArray<OCLogTagName> *)logTags
{
	return (@[@"PLManager"]);
}

#pragma mark - Miscellaneous
- (void)forceStopAllPipelinesGracefully:(BOOL)gracefully completionHandler:(dispatch_block_t)completionHandler
{
	dispatch_async(_adminQueue, ^{
		OCLogWarning(@"Force-stopping all pipelines");
		NSDictionary<OCHTTPPipelineID, OCHTTPPipeline *> *pipelineByIdentifier;

		@synchronized(self->_pipelineByIdentifier)
		{
			pipelineByIdentifier = [self->_pipelineByIdentifier copy];
		}

		[pipelineByIdentifier enumerateKeysAndObjectsUsingBlock:^(OCHTTPPipelineID  _Nonnull pipelineID, OCHTTPPipeline * _Nonnull pipeline, BOOL * _Nonnull stop) {
			OCLogWarning(@"Force-stopping pipeline %@", pipelineID);
			[self _stopPipeline:pipeline graceful:gracefully];
		}];

		completionHandler();
	});
}

- (void)detachAndDestroyPartitionInAllPipelines:(OCHTTPPipelinePartitionID)partitionID completionHandler:(OCCompletionHandler)completionHandler
{
	// Go through all managed and default queues and destroy data as needed
	dispatch_async(_adminQueue, ^{
		NSMutableSet<OCHTTPPipelineID> *pipelineIDs;
		dispatch_group_t waitGroup = dispatch_group_create();
		__block NSError *destroyError = nil;

		@synchronized(self->_pipelineByIdentifier)
		{
			pipelineIDs = [[NSMutableSet alloc] initWithArray:self->_pipelineByIdentifier.allKeys];
		}

		[pipelineIDs addObjectsFromArray:@[OCHTTPPipelineIDLocal, OCHTTPPipelineIDEphermal, OCHTTPPipelineIDBackground]];

		for (OCHTTPPipelineID pipelineID in pipelineIDs)
		{
			dispatch_group_enter(waitGroup);

			[self requestPipelineWithIdentifier:pipelineID completionHandler:^(OCHTTPPipeline * _Nullable pipeline, NSError * _Nullable error) {
				if (destroyError==nil) { destroyError = error; }

				if (pipeline != nil)
				{
					[pipeline destroyPartition:partitionID completionHandler:^(id sender, NSError *error) {
						if (destroyError==nil) { destroyError = error; }

						[self returnPipelineWithIdentifier:pipelineID completionHandler:^{
							dispatch_group_leave(waitGroup);
						}];
					}];
				}
				else
				{
					dispatch_group_leave(waitGroup);
				}
			}];
		}

		dispatch_group_notify(waitGroup, self->_adminQueue, ^{
			if (completionHandler != nil)
			{
				completionHandler(self, destroyError);
			}
		});
	});
}

#pragma mark - Progress resolution
- (NSProgress *)resolveProgress:(OCProgress *)progress withContext:(nullable OCProgressResolutionContext)context
{
	__block NSProgress *resolvedProgress = nil;

	if (!progress.nextPathElementIsLast)
	{
		if (![progress.nextPathElement isEqual:OCHTTPRequestGlobalPath])
		{
			return (nil);
		}
	}

	if (progress.nextPathElementIsLast)
	{
		OCHTTPRequestID requestID;

		if ((requestID = progress.nextPathElement) != nil)
		{
			NSDictionary<OCHTTPPipelineID, OCHTTPPipeline *> *pipelineByIdentifier;

			@synchronized(self->_pipelineByIdentifier)
			{
				pipelineByIdentifier = [self->_pipelineByIdentifier copy];
			}

			[pipelineByIdentifier enumerateKeysAndObjectsUsingBlock:^(OCHTTPPipelineID pipelineID, OCHTTPPipeline *pipeline, BOOL *stop) {
				if ((resolvedProgress = [pipeline progressForRequestID:requestID]) != nil)
				{
					*stop = YES;
				}
			}];
		}
	}

	return (resolvedProgress);
}

@end

OCHTTPPipelineID OCHTTPPipelineIDLocal = @"default";
OCHTTPPipelineID OCHTTPPipelineIDEphermal = @"ephermal";
OCHTTPPipelineID OCHTTPPipelineIDBackground = @"background";
