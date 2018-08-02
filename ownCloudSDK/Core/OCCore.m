//
//  OCCore.m
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

#import "OCCore.h"
#import "OCQuery+Internal.h"
#import "OCLogger.h"
#import "NSProgress+OCExtensions.h"
#import "OCMacros.h"
#import "NSError+OCError.h"
#import "OCDatabase.h"
#import "OCDatabaseConsistentOperation.h"
#import "OCCore+Internal.h"
#import "OCCore+SyncEngine.h"
#import "OCCoreSyncRoute.h"
#import "OCSyncRecord.h"
#import "NSString+OCParentPath.h"
#import "OCCore+FileProvider.h"
#import "OCCore+ItemList.h"

@interface OCCore ()
{
	dispatch_group_t _runningActivitiesGroup;
	NSInteger _runningActivities;
	dispatch_block_t _runningActivitiesCompleteBlock;
}

@end

@implementation OCCore

@synthesize bookmark = _bookmark;

@synthesize vault = _vault;
@synthesize connection = _connection;

@synthesize state = _state;

@synthesize eventHandlerIdentifier = _eventHandlerIdentifier;

@synthesize latestSyncAnchor = _latestSyncAnchor;

@synthesize postFileProviderNotifications = _postFileProviderNotifications;

@synthesize delegate = _delegate;

@synthesize automaticItemListUpdatesEnabled = _automaticItemListUpdatesEnabled;

#pragma mark - Class settings
+ (OCClassSettingsIdentifier)classSettingsIdentifier
{
	return (@"core");
}

+ (NSDictionary<NSString *,id> *)defaultSettingsForIdentifier:(OCClassSettingsIdentifier)identifier
{
	return (@{
		OCCoreThumbnailAvailableForMIMETypePrefixes : @[
			@"*"
		]
	});
}

+ (BOOL)thumbnailSupportedForMIMEType:(NSString *)mimeType
{
	static dispatch_once_t onceToken;
	static NSArray <NSString *> *supportedPrefixes;
	static BOOL loadThumbnailsForAll=NO, loadThumbnailsForNone=NO;

	dispatch_once(&onceToken, ^{
		supportedPrefixes = [[[OCClassSettings sharedSettings] settingsForClass:[OCCore class]] objectForKey:OCCoreThumbnailAvailableForMIMETypePrefixes];

		if (supportedPrefixes.count == 0)
		{
			loadThumbnailsForNone = YES;
		}
		else
		{
			if ([supportedPrefixes containsObject:@"*"])
			{
				loadThumbnailsForAll = YES;
			}
		}
	});

	if (loadThumbnailsForAll)  { return(YES); }
	if (loadThumbnailsForNone) { return(NO);  }

	for (NSString *prefix in supportedPrefixes)
	{
		if ([mimeType hasPrefix:prefix])
		{
			return (YES);
		}
	}

	return (NO);
}


#pragma mark - Init
- (instancetype)init
{
	// Enforce use of designated initializer
	return (nil);
}

- (instancetype)initWithBookmark:(OCBookmark *)bookmark
{
	if ((self = [super init]) != nil)
	{
		_bookmark = bookmark;

		_automaticItemListUpdatesEnabled = YES;

		_eventHandlerIdentifier = [@"OCCore-" stringByAppendingString:_bookmark.uuid.UUIDString];
		_pendingThumbnailRequests = [NSMutableDictionary new];

		_fileProviderSignalCountByContainerItemIdentifiers = [NSMutableDictionary new];
		_fileProviderSignalCountByContainerItemIdentifiersLock = @"_fileProviderSignalCountByContainerItemIdentifiersLock";

		_vault = [[OCVault alloc] initWithBookmark:bookmark];

		_queries = [NSMutableArray new];

		_itemListTasksByPath = [NSMutableDictionary new];

		_thumbnailCache = [OCCache new];

		_syncRoutesByAction = [NSMutableDictionary new];

		_queue = dispatch_queue_create("OCCore work queue", DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL);
		_connectivityQueue = dispatch_queue_create("OCCore connectivity queue", DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL);

		_runningActivitiesGroup = dispatch_group_create();

		[OCEvent registerEventHandler:self forIdentifier:_eventHandlerIdentifier];

		[self registerSyncRoutes];

		_connection = [[OCConnection alloc] initWithBookmark:bookmark persistentStoreBaseURL:_vault.connectionDataRootURL];

		_reachabilityMonitor = [[OCReachabilityMonitor alloc] initWithHostname:bookmark.url.host];
		_reachabilityMonitor.enabled = YES;
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_reachabilityChanged:) name:OCReachabilityMonitorAvailabilityChangedNotification object:_reachabilityMonitor];
	}

	return(self);
}

- (void)dealloc
{
	if (_reachabilityMonitor != nil)
	{
		[[NSNotificationCenter defaultCenter] removeObserver:self name:OCReachabilityMonitorAvailabilityChangedNotification object:_reachabilityMonitor];
		_reachabilityMonitor.enabled = NO;
		_reachabilityMonitor = nil;
	}
}

- (void)unregisterEventHandler
{
	[OCEvent unregisterEventHandlerForIdentifier:_eventHandlerIdentifier];
}

#pragma mark - Start / Stop
- (void)startWithCompletionHandler:(OCCompletionHandler)completionHandler
{
	[self queueBlock:^{
		if (_state == OCCoreStateStopped)
		{
			__block NSError *startError = nil;
			dispatch_group_t startGroup = nil;

			[self willChangeValueForKey:@"state"];
			_state = OCCoreStateStarting;
			[self didChangeValueForKey:@"state"];

			startGroup = dispatch_group_create();

			// Open vault (incl. database)
			dispatch_group_enter(startGroup);

			[self.vault openWithCompletionHandler:^(id sender, NSError *error) {
				startError = error;
				dispatch_group_leave(startGroup);
			}];

			dispatch_group_wait(startGroup, DISPATCH_TIME_FOREVER);

			// Get latest sync anchor
			dispatch_group_enter(startGroup);

			[self retrieveLatestSyncAnchorWithCompletionHandler:^(NSError *error, OCSyncAnchor latestSyncAnchor) {
				dispatch_group_leave(startGroup);
			}];

			dispatch_group_wait(startGroup, DISPATCH_TIME_FOREVER);

			// Proceed with connecting - or stop
			if (startError == nil)
			{
				_attemptConnect = YES;
				[self _attemptConnect];
			}
			else
			{
				_attemptConnect = NO;

				[self willChangeValueForKey:@"state"];
				_state = OCCoreStateStopped;
				[self didChangeValueForKey:@"state"];
			}

			if (completionHandler != nil)
			{
				completionHandler(self, startError);
			}
		}
		else
		{
			if (completionHandler != nil)
			{
				completionHandler(self, nil);
			}
		}
	}];
}

- (void)stopWithCompletionHandler:(OCCompletionHandler)completionHandler
{
	[self queueBlock:^{
		__block NSError *stopError = nil;

		if ((_state == OCCoreStateRunning) || (_state == OCCoreStateStarting))
		{
			__weak OCCore *weakSelf = self;

			[self willChangeValueForKey:@"state"];
			_state = OCCoreStateStopping;
			[self didChangeValueForKey:@"state"];

			// Wait for running operations to finish
			_runningActivitiesCompleteBlock = ^{
				dispatch_group_t stopGroup = nil;

				// Stop..
				stopGroup = dispatch_group_create();

				// Close connection
				_attemptConnect = NO;

				dispatch_group_enter(stopGroup);

				[weakSelf.connection disconnectWithCompletionHandler:^{
					dispatch_group_leave(stopGroup);
				}];

				dispatch_group_wait(stopGroup, DISPATCH_TIME_FOREVER);

				// Close vault (incl. database)
				dispatch_group_enter(stopGroup);

				[weakSelf.vault closeWithCompletionHandler:^(OCDatabase *db, NSError *error) {
					stopError = error;
					dispatch_group_leave(stopGroup);
				}];

				dispatch_group_wait(stopGroup, DISPATCH_TIME_FOREVER);

				[weakSelf willChangeValueForKey:@"state"];
				_state = OCCoreStateStopped;
				[weakSelf didChangeValueForKey:@"state"];

				if (completionHandler != nil)
				{
					completionHandler(weakSelf, stopError);
				}
			};

			if (_runningActivities == 0)
			{
				if (_runningActivitiesCompleteBlock != nil)
				{
					_runningActivitiesCompleteBlock();
					_runningActivitiesCompleteBlock = nil;
				}
			}
		}
		else if (completionHandler != nil)
		{
			completionHandler(self, stopError);
		}
	}];
}

#pragma mark - Attempt Connect
- (void)attemptConnect:(BOOL)doAttempt
{
	[self queueBlock:^{
		_attemptConnect = doAttempt;

		[self _attemptConnect];
	}];
}

- (void)_attemptConnect
{
	[self queueConnectivityBlock:^{
		if ((_state == OCCoreStateStarting) && _attemptConnect)
		{
			// Open connection
			dispatch_suspend(_connectivityQueue);

			[self.connection connectWithCompletionHandler:^(NSError *error, OCConnectionIssue *issue) {
				[self queueBlock:^{
					// Change state
					if (error == nil)
					{
						[self willChangeValueForKey:@"state"];
						_state = OCCoreStateRunning;
						[self didChangeValueForKey:@"state"];

						if (self.automaticItemListUpdatesEnabled)
						{
							[self startCheckingForUpdates];
						}
					}

					// Relay error and issues to delegate
					if ((_delegate!=nil) && [_delegate respondsToSelector:@selector(core:handleError:issue:)])
					{
						[_delegate core:self handleError:error issue:issue];
					}

					dispatch_resume(_connectivityQueue);
				}];
			}];
		}
	}];
}

#pragma mark - Reachability
- (void)_reachabilityChanged:(NSNotification *)notification
{
	if (_reachabilityMonitor.available)
	{
		[self queueBlock:^{
			if (_state == OCCoreStateStarting)
			{
				[self _attemptConnect];
			}

			[self queueConnectivityBlock:^{	// Wait for _attemptConnect to finish
				[self queueBlock:^{ // See if we can proceed
					if (_state == OCCoreStateRunning)
					{
						for (OCQuery *query in _queries)
						{
							if (query.state == OCQueryStateContentsFromCache)
							{
								[self reloadQuery:query];
							}
						}

						[self setNeedsToProcessSyncRecords];
					}
				}];
			}];
		}];
	}
}

#pragma mark - Query
- (void)_startItemListTaskForQuery:(OCQuery *)query
{
	[self queueBlock:^{
		// Update query state to "started"
		query.state = OCQueryStateStarted;

		// Start task
		if (query.queryPath != nil)
		{
			// Start item list task for queried directory
			[self startItemListTaskForPath:query.queryPath];
		}
		else
		{
			if (query.queryItem.path != nil)
			{
				// Start item list task for parent directory of queried item
				[self startItemListTaskForPath:[query.queryItem.path parentPath]];
			}
		}
	}];
}

- (void)_startSyncAnchorDatabaseRequestForQuery:(OCQuery *)query
{
	[self queueBlock:^{
		// Update query state to "started"
		query.state = OCQueryStateStarted;

		// Retrieve known changes from the cache
		[self.vault.database retrieveCacheItemsUpdatedSinceSyncAnchor:query.querySinceSyncAnchor foldersOnly:YES completionHandler:^(OCDatabase *db, NSError *error, OCSyncAnchor syncAnchor, NSArray<OCItem *> *items) {
			[self queueBlock:^{
				if ((error == nil) && (items != nil))
				{
					[query mergeItemsToFullQueryResults:items syncAnchor:syncAnchor];
					query.state = OCQueryStateContentsFromCache;

					[query setNeedsRecomputation];
				}

				query.state = OCQueryStateIdle;
			}];
		}];
	}];
}

- (void)startQuery:(OCQuery *)query
{
	if (query == nil) { return; }

	// Add query to list of queries
	[self queueBlock:^{
		[_queries addObject:query];
	}];

	if (query.querySinceSyncAnchor == nil)
	{
		[self _startItemListTaskForQuery:query];
	}
	else
	{
		[self _startSyncAnchorDatabaseRequestForQuery:query];
	}
}

- (void)reloadQuery:(OCQuery *)query
{
	if (query == nil) { return; }

	if (query.querySinceSyncAnchor == nil)
	{
		[self _startItemListTaskForQuery:query];
	}
}

- (void)stopQuery:(OCQuery *)query
{
	if (query == nil) { return; }

	[self queueBlock:^{
		[_queries removeObject:query];
		query.state = OCQueryStateStopped;
	}];
}

#pragma mark - Convenience
- (OCDatabase *)database
{
	return (_vault.database);
}

#pragma mark - Tools
- (void)retrieveLatestDatabaseVersionOfItem:(OCItem *)item completionHandler:(void(^)(NSError *error, OCItem *requestedItem, OCItem *databaseItem))completionHandler
{
	[self.vault.database retrieveCacheItemsAtPath:item.path itemOnly:YES completionHandler:^(OCDatabase *db, NSError *error, OCSyncAnchor syncAnchor, NSArray<OCItem *> *items) {
		completionHandler(error, item, items.firstObject);
	}];
}

#pragma mark - ## Commands
- (NSProgress *)shareItem:(OCItem *)item options:(OCShareOptions)options resultHandler:(OCCoreActionResultHandler)resultHandler
{
	return(nil); // Stub implementation
}

- (NSProgress *)requestAvailableOfflineCapabilityForItem:(OCItem *)item completionHandler:(OCCoreCompletionHandler)completionHandler
{
	return(nil); // Stub implementation
}

- (NSProgress *)terminateAvailableOfflineCapabilityForItem:(OCItem *)item completionHandler:(OCCoreCompletionHandler)completionHandler
{
	return(nil); // Stub implementation
}

#pragma mark - Command: Retrieve Thumbnail
- (NSProgress *)retrieveThumbnailFor:(OCItem *)item maximumSize:(CGSize)requestedMaximumSizeInPoints scale:(CGFloat)scale retrieveHandler:(OCCoreThumbnailRetrieveHandler)retrieveHandler
{
	NSProgress *progress = [NSProgress indeterminateProgress];
	OCFileID fileID = item.fileID;
	OCItemVersionIdentifier *versionIdentifier = item.itemVersionIdentifier;
	CGSize requestedMaximumSizeInPixels;

	retrieveHandler = [retrieveHandler copy];

	if (scale == 0)
	{
		scale = UIScreen.mainScreen.scale;
	}

	requestedMaximumSizeInPixels = CGSizeMake(floor(requestedMaximumSizeInPoints.width * scale), floor(requestedMaximumSizeInPoints.height * scale));

	progress.eventType = OCEventTypeRetrieveThumbnail;
	progress.localizedDescription = OCLocalizedString(@"Retrieving thumbnail…", @"");

	if (fileID != nil)
	{
		[self queueBlock:^{
			OCItemThumbnail *thumbnail;
			BOOL requestThumbnail = YES;

			// Is there a thumbnail for this file in the cache?
			if ((thumbnail = [_thumbnailCache objectForKey:item.fileID]) != nil)
			{
				// Yes! But is it the version we want?
				if ([thumbnail.itemVersionIdentifier isEqual:item.itemVersionIdentifier])
				{
					// Yes it is!
					if ([thumbnail canProvideForMaximumSizeInPixels:requestedMaximumSizeInPixels])
					{
						// The size is fine, too!
						retrieveHandler(nil, self, item, thumbnail, NO, progress);

						requestThumbnail = NO;
					}
					else
					{
						// The size isn't sufficient
						retrieveHandler(nil, self, item, thumbnail, YES, progress);
					}
				}
				else
				{
					// No it's not => remove outdated version from cache
					[_thumbnailCache removeObjectForKey:item.fileID];

					thumbnail = nil;
				}
			}

			// Should a thumbnail be requested?
			if (requestThumbnail)
			{
				if (!progress.cancelled)
				{
					// Thumbnail
					[self.vault.database retrieveThumbnailDataForItemVersion:versionIdentifier maximumSizeInPixels:requestedMaximumSizeInPixels completionHandler:^(OCDatabase *db, NSError *error, CGSize maxSize, NSString *mimeType, NSData *thumbnailData) {
						OCItemThumbnail *cachedThumbnail = nil;

						if (thumbnailData != nil)
						{
							// Create OCItemThumbnail from data returned from data base
							OCItemThumbnail *cachedThumbnail = [OCItemThumbnail new];

							cachedThumbnail.maximumSizeInPixels = maxSize;
							cachedThumbnail.mimeType = mimeType;
							cachedThumbnail.data = thumbnailData;
							cachedThumbnail.itemVersionIdentifier = versionIdentifier;

							if ([cachedThumbnail canProvideForMaximumSizeInPixels:requestedMaximumSizeInPixels])
							{
								[self queueBlock:^{
									[_thumbnailCache setObject:cachedThumbnail forKey:fileID cost:(maxSize.width * maxSize.height * 4)];
									retrieveHandler(nil, self, item, cachedThumbnail, NO, progress);
								}];

								return;
							}
						}

						// Update the retrieveHandler with a thumbnail if it doesn't already have one
						if ((thumbnail == nil) && (cachedThumbnail != nil))
						{
							retrieveHandler(nil, self, item, cachedThumbnail, YES, progress);
						}

						// Request a thumbnail from the server if the operation hasn't been cancelled yet.
						if (!progress.cancelled)
						{
							NSString *requestID = [NSString stringWithFormat:@"%@:%@-%fx%f", versionIdentifier.fileID, versionIdentifier.eTag, requestedMaximumSizeInPixels.width, requestedMaximumSizeInPixels.height];

							[self queueBlock:^{
								BOOL sendRequest = YES;

								// Queue retrieve handlers
								NSMutableArray <OCCoreThumbnailRetrieveHandler> *retrieveHandlersQueue;

								if ((retrieveHandlersQueue = _pendingThumbnailRequests[requestID]) == nil)
								{
									retrieveHandlersQueue = [NSMutableArray new];

									_pendingThumbnailRequests[requestID] = retrieveHandlersQueue;
								}

								if (retrieveHandlersQueue.count != 0)
								{
									// Another request is already pending
									sendRequest = NO;
								}

								[retrieveHandlersQueue addObject:retrieveHandler];

								if (sendRequest)
								{
									OCEventTarget *target;
									NSProgress *retrieveProgress;

									// Define result event target
									target = [OCEventTarget eventTargetWithEventHandlerIdentifier:self.eventHandlerIdentifier userInfo:@{
										@"requestedMaximumSize" : [NSValue valueWithCGSize:requestedMaximumSizeInPixels],
										@"scale" : @(scale),
										@"itemVersionIdentifier" : item.itemVersionIdentifier,
										@"item" : item,
									} ephermalUserInfo:@{
										@"requestID" : requestID
									}];

									// Request thumbnail from connection
									retrieveProgress = [self.connection retrieveThumbnailFor:item to:nil maximumSize:requestedMaximumSizeInPixels resultTarget:target];

									if (retrieveProgress != nil) {
										[progress addChild:retrieveProgress withPendingUnitCount:0];
									}
								}
							}];
						}
						else
						{
							if (retrieveHandler != nil)
							{
								retrieveHandler(OCError(OCErrorRequestCancelled), self, item, nil, NO, progress);
							}
						}
					}];
				}
				else
				{
					if (retrieveHandler != nil)
					{
						retrieveHandler(OCError(OCErrorRequestCancelled), self, item, nil, NO, progress);
					}
				}
			}
		}];
	}

	return(progress);
}

- (void)_handleRetrieveThumbnailEvent:(OCEvent *)event sender:(id)sender
{
	[self queueBlock:^{
		OCItemThumbnail *thumbnail = event.result;
		// CGSize requestedMaximumSize = ((NSValue *)event.userInfo[@"requestedMaximumSize"]).CGSizeValue;
		// CGFloat scale = ((NSNumber *)event.userInfo[@"scale"]).doubleValue;
		OCItemVersionIdentifier *itemVersionIdentifier = event.userInfo[@"itemVersionIdentifier"];
		OCItem *item = event.userInfo[@"item"];
		NSString *requestID = event.ephermalUserInfo[@"requestID"];

		if ((event.error == nil) && (event.result != nil))
		{
			// Update cache
			[_thumbnailCache setObject:thumbnail forKey:itemVersionIdentifier.fileID];

			// Store in database
			[self.vault.database storeThumbnailData:thumbnail.data withMIMEType:thumbnail.mimeType forItemVersion:itemVersionIdentifier maximumSizeInPixels:thumbnail.maximumSizeInPixels completionHandler:nil];
		}

		// Call all retrieveHandlers
		if (requestID != nil)
		{
			NSMutableArray <OCCoreThumbnailRetrieveHandler> *retrieveHandlersQueue = _pendingThumbnailRequests[requestID];

			if (retrieveHandlersQueue != nil)
			{
				[_pendingThumbnailRequests removeObjectForKey:requestID];
			}

			item.thumbnail = thumbnail;

			dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
				for (OCCoreThumbnailRetrieveHandler retrieveHandler in retrieveHandlersQueue)
				{
					retrieveHandler(event.error, self, item, thumbnail, NO, nil);
				}
			});
		}
	}];
}

#pragma mark - OCEventHandler methods
- (void)handleEvent:(OCEvent *)event sender:(id)sender
{
	switch (event.eventType)
	{
		case OCEventTypeRetrieveThumbnail:
			[self _handleRetrieveThumbnailEvent:event sender:sender];
		break;

		case OCEventTypeRetrieveItemList:
			[self _handleRetrieveItemListEvent:event sender:sender];
		break;

		default:
			[self _handleSyncEvent:event sender:sender];
		break;
	}
}

#pragma mark - Busy count
- (void)beginActivity:(NSString *)description
{
	OCLogDebug(@"Beginning activity '%@' ..", description);
	[self queueBlock:^{
		_runningActivities++;

		if (_runningActivities == 1)
		{
			dispatch_group_enter(_runningActivitiesGroup);
		}
	}];
}

- (void)endActivity:(NSString *)description
{
	OCLogDebug(@"Ended activity '%@' ..", description);
	[self queueBlock:^{
		_runningActivities--;
		
		if (_runningActivities == 0)
		{
			dispatch_group_leave(_runningActivitiesGroup);

			if (_runningActivitiesCompleteBlock != nil)
			{
				_runningActivitiesCompleteBlock();
				_runningActivitiesCompleteBlock = nil;
			}
		}
	}];
}

#pragma mark - Queues
- (void)queueBlock:(dispatch_block_t)block
{
	if (block != nil)
	{
		dispatch_async(_queue, block);
	}
}

- (void)queueConnectivityBlock:(dispatch_block_t)block
{
	if (block != nil)
	{
		dispatch_async(_connectivityQueue, block);
	}
}

@end

OCClassSettingsKey OCCoreThumbnailAvailableForMIMETypePrefixes = @"thumbnail-available-for-mime-type-prefixes";

OCDatabaseCounterIdentifier OCCoreSyncAnchorCounter = @"syncAnchor";
OCDatabaseCounterIdentifier OCCoreSyncJournalCounter = @"syncJournal";
