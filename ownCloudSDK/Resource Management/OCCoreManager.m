//
//  OCCoreManager.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 08.06.18.
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

#import "OCCoreManager.h"
#import "NSError+OCError.h"
#import "OCBookmarkManager.h"
#import "OCConnectionQueue+BackgroundSessionRecovery.h"

@implementation OCCoreManager

#pragma mark - Shared instance
+ (instancetype)sharedCoreManager
{
	static dispatch_once_t onceToken;
	static OCCoreManager *sharedManager = nil;

	dispatch_once(&onceToken, ^{
		sharedManager = [OCCoreManager new];
	});

	return (sharedManager);
}

- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_coresByUUID = [NSMutableDictionary new];
		_requestCountByUUID = [NSMutableDictionary new];

		_queuedOfflineOperationsByUUID = [NSMutableDictionary new];
		_runningOfflineOperationByUUID = [NSMutableDictionary new];
	}

	return(self);
}

#pragma mark - Requesting and returning cores
- (OCCore *)requestCoreForBookmark:(OCBookmark *)bookmark completionHandler:(void (^)(OCCore *core, NSError *error))completionHandler
{
	OCCore *returnCore = nil;

	@synchronized(self)
	{
		if (_runningOfflineOperationByUUID[bookmark.uuid] != nil)
		{
			if (completionHandler != nil)
			{
				completionHandler(nil, OCError(OCErrorRunningOperation));
			}
		}
		else
		{
			NSNumber *requestCount = _requestCountByUUID[bookmark.uuid];

			requestCount = @(requestCount.integerValue + 1);
			_requestCountByUUID[bookmark.uuid] = requestCount;

			if (requestCount.integerValue == 1)
			{
				OCCore *core;

				// Create and start core
				if ((core = [[OCCore alloc] initWithBookmark:bookmark]) != nil)
				{
					returnCore = core;

					_coresByUUID[bookmark.uuid] = core;

					[core startWithCompletionHandler:^(id sender, NSError *error) {
						if (completionHandler != nil)
						{
							completionHandler((OCCore *)sender, error);
						}
					}];
				}
				else
				{
					if (completionHandler != nil)
					{
						completionHandler(nil, OCError(OCErrorInternal));
					}
				}
			}
			else
			{
				OCCore *core;

				if ((core = _coresByUUID[bookmark.uuid]) != nil)
				{
					returnCore = core;

					if (core.state != OCCoreStateRunning)
					{
						[core startWithCompletionHandler:^(id sender, NSError *error) {
							if (completionHandler != nil)
							{
								completionHandler((OCCore *)sender, error);
							}
						}];
					}
					else if (completionHandler != nil)
					{
						completionHandler(core, nil);
					}
				}
			}
		}
	}

	return (returnCore);
}

- (void)returnCoreForBookmark:(OCBookmark *)bookmark completionHandler:(dispatch_block_t)completionHandler
{
	@synchronized(self)
	{
		NSNumber *requestCount = _requestCountByUUID[bookmark.uuid];

		if (requestCount.integerValue > 0)
		{
			requestCount = @(requestCount.integerValue - 1);
			_requestCountByUUID[bookmark.uuid] = requestCount;
		}

		if (requestCount.integerValue == 0)
		{
			// Stop and release core
			OCCore *core;

			if ((core = _coresByUUID[bookmark.uuid]) != nil)
			{
				[_coresByUUID removeObjectForKey:bookmark.uuid];

				[core stopWithCompletionHandler:^(id sender, NSError *error) {
					[core unregisterEventHandler];

					if (completionHandler != nil)
					{
						completionHandler();
					}

					[self _runNextOfflineOperationForBookmark:bookmark];
				}];
			}
		}
		else
		{
			if (completionHandler != nil)
			{
				completionHandler();
			}
		}
	}
}

#pragma mark - Background session recovery
- (void)handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(dispatch_block_t)completionHandler
{
	@synchronized(self)
	{
		if ((identifier != nil) && (completionHandler != nil))
		{
			NSUUID *sessionBookmarkUUID;

			if ((sessionBookmarkUUID = [OCConnectionQueue uuidForBackgroundSessionIdentifier:identifier]) != nil)
			{
				OCBookmark *bookmark;

				if ((bookmark = [[OCBookmarkManager sharedBookmarkManager] bookmarkForUUID:sessionBookmarkUUID]) != nil)
				{
					// Save completion handler
					[OCConnectionQueue setCompletionHandler:^{
						// Return core
						[[OCCoreManager sharedCoreManager] returnCoreForBookmark:bookmark completionHandler:^{
							completionHandler();
						}];
					} forBackgroundSessionWithIdentifier:identifier];

					// Request core, so it can pick up and handle this
					[[OCCoreManager sharedCoreManager] requestCoreForBookmark:bookmark completionHandler:^(OCCore *core, NSError *error) {
						if (core != nil)
						{
							// Resume pending background sessions
							[core.connection resumeBackgroundSessions];
						}
					}];
				}
				else
				{
					// No bookmark
					completionHandler();
				}
			}
		}
	}
}

#pragma mark - Scheduling offline operations on cores
- (void)scheduleOfflineOperation:(OCCoreManagerOfflineOperation)offlineOperation forBookmark:(OCBookmark *)bookmark
{
	@synchronized(self)
	{
		NSMutableArray<OCCoreManagerOfflineOperation> *queuedOfflineOperations;

		if ((queuedOfflineOperations = _queuedOfflineOperationsByUUID[bookmark.uuid]) == nil)
		{
			queuedOfflineOperations = [NSMutableArray new];
			_queuedOfflineOperationsByUUID[bookmark.uuid] = queuedOfflineOperations;
		}

		[queuedOfflineOperations addObject:offlineOperation];
	}

	[self _runNextOfflineOperationForBookmark:bookmark];
}

- (void)_runNextOfflineOperationForBookmark:(OCBookmark *)bookmark
{
	@synchronized(self)
	{
		if ((_requestCountByUUID[bookmark.uuid].integerValue == 0) && (_runningOfflineOperationByUUID[bookmark.uuid] == nil))
		{
			OCCoreManagerOfflineOperation offlineOperation;

			if ((offlineOperation = _queuedOfflineOperationsByUUID[bookmark.uuid].firstObject) != nil)
			{
				[_queuedOfflineOperationsByUUID[bookmark.uuid] removeObjectAtIndex:0];

				_runningOfflineOperationByUUID[bookmark.uuid] = @(YES);

				offlineOperation(bookmark, ^{
					@synchronized(self)
					{
						[_runningOfflineOperationByUUID removeObjectForKey:bookmark.uuid];

						[self _runNextOfflineOperationForBookmark:bookmark];
					}
				});
			}
		}
	}
}

@end
