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
#import "OCSyncRecord.h"
#import "NSString+OCParentPath.h"
#import "OCCore+FileProvider.h"
#import "OCCore+ItemList.h"
#import "OCCoreManager.h"
#import "OCChecksumAlgorithmSHA1.h"
#import "OCIPNotificationCenter.h"
#import "OCCoreReachabilityConnectionStatusSignalProvider.h"
#import "OCCoreNetworkPathMonitorSignalProvider.h"
#import "OCCoreMaintenanceModeStatusSignalProvider.h"
#import "OCCore+ConnectionStatus.h"
#import "OCCore+Thumbnails.h"
#import "OCCore+ItemUpdates.h"

@interface OCCore ()
{
	dispatch_group_t _runningActivitiesGroup;
	NSInteger _runningActivities;
	NSMutableArray <NSString *> *_runningActivitiesStrings;
	dispatch_block_t _runningActivitiesCompleteBlock;
}

@end

@implementation OCCore

@synthesize bookmark = _bookmark;

@synthesize vault = _vault;
@synthesize connection = _connection;

@synthesize memoryConfiguration = _memoryConfiguration;

@synthesize state = _state;
@synthesize stateChangedHandler = _stateChangedHandler;

@synthesize connectionStatus = _connectionStatus;
@synthesize connectionStatusSignals = _connectionStatusSignals;
@synthesize connectionStatusShortDescription = _connectionStatusShortDescription;

@synthesize eventHandlerIdentifier = _eventHandlerIdentifier;

@synthesize latestSyncAnchor = _latestSyncAnchor;

@synthesize postFileProviderNotifications = _postFileProviderNotifications;

@synthesize delegate = _delegate;

@synthesize preferredChecksumAlgorithm = _preferredChecksumAlgorithm;

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
		__weak OCCore *weakSelf = self;

		_bookmark = bookmark;

		_automaticItemListUpdatesEnabled = YES;

		// Quick note: according to https://github.com/owncloud/documentation/issues/2964 the algorithm should actually be determined by the capabilities
		// specified by the server. This is currently not done because SHA1 is the only supported algorithm of interest (ADLER32 is much weaker) at the time
		// of writing and requesting the capabilities upon every connect to the server would increase load on the server and increase the time it takes to
		// connect. By the time the server adds an even more secure hash in the future, server information endpoints have hopefully also been consolidated.
		// Alternatively, preferred checksum algorithms could be requested upon first connect and be cached for f.ex. 24-48 hours.
		_preferredChecksumAlgorithm = OCChecksumAlgorithmIdentifierSHA1;

		_eventHandlerIdentifier = [@"OCCore-" stringByAppendingString:_bookmark.uuid.UUIDString];
		_pendingThumbnailRequests = [NSMutableDictionary new];

		_fileProviderSignalCountByContainerItemIdentifiers = [NSMutableDictionary new];
		_fileProviderSignalCountByContainerItemIdentifiersLock = @"_fileProviderSignalCountByContainerItemIdentifiersLock";

		_ipNotificationCenter = OCIPNotificationCenter.sharedNotificationCenter;

		_vault = [[OCVault alloc] initWithBookmark:bookmark];

		_queries = [NSMutableArray new];

		_itemListTasksByPath = [NSMutableDictionary new];
		_queuedItemListTaskPaths = [NSMutableArray new];
		_scheduledItemListTasks = [NSMutableArray new];
		_itemListTasksRequestQueue = [OCAsyncSequentialQueue new];
		_itemListTasksRequestQueue.executor = ^(OCAsyncSequentialQueueJob  _Nonnull job, dispatch_block_t  _Nonnull completionHandler) {
			OCCore *strongSelf;

			if ((strongSelf = weakSelf) != nil)
			{
				[strongSelf queueBlock:^{
					job(completionHandler);
				}];
			}
		};

		_progressByFileID = [NSMutableDictionary new];

		_thumbnailCache = [OCCache new];

		_queue = dispatch_queue_create("OCCore work queue", DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL);
		_connectivityQueue = dispatch_queue_create("OCCore connectivity queue", DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL);

		_runningActivitiesGroup = dispatch_group_create();

		[OCEvent registerEventHandler:self forIdentifier:_eventHandlerIdentifier];

		_connection = [[OCConnection alloc] initWithBookmark:bookmark persistentStoreBaseURL:_vault.connectionDataRootURL];
		_connection.preferredChecksumAlgorithm = _preferredChecksumAlgorithm;
		_connection.actionSignals = [NSSet setWithObjects: OCConnectionSignalIDCoreOnline, nil];
		_connection.delegate = self;

		_connectionStatusSignalProviders = [NSMutableArray new];

		if (@available(iOS 12, *))
		{
			_reachabilityStatusSignalProvider = [[OCCoreNetworkPathMonitorSignalProvider alloc] initWithHostname:self.bookmark.url.host];
		}
		else
		{
			_reachabilityStatusSignalProvider = [[OCCoreReachabilityConnectionStatusSignalProvider alloc] initWithHostname:self.bookmark.url.host];
		}
		_maintenanceModeStatusSignalProvider = [OCCoreMaintenanceModeStatusSignalProvider new];
		_connectionStatusSignalProvider = [[OCCoreConnectionStatusSignalProvider alloc] initWithSignal:OCCoreConnectionStatusSignalConnected initialState:OCCoreConnectionStatusSignalStateFalse stateProvider:nil];

		[self addSignalProvider:_reachabilityStatusSignalProvider];
		[self addSignalProvider:_maintenanceModeStatusSignalProvider];
		[self addSignalProvider:_connectionStatusSignalProvider];

		self.memoryConfiguration = OCCoreManager.sharedCoreManager.memoryConfiguration;

		[self startIPCObservation];
	}

	return(self);
}

- (void)dealloc
{
	[self stopIPCObserveration];

	[self removeSignalProviders];
}

- (void)unregisterEventHandler
{
	[OCEvent unregisterEventHandlerForIdentifier:_eventHandlerIdentifier];
}

- (void)_updateState:(OCCoreState)newState
{
	[self willChangeValueForKey:@"state"];
	_state = newState;
	[self didChangeValueForKey:@"state"];

	if (_stateChangedHandler)
	{
		_stateChangedHandler(self);
	}
}

#pragma mark - Start / Stop
- (void)startWithCompletionHandler:(nullable OCCompletionHandler)completionHandler
{
	OCTLogDebug(@[@"START"], @"queuing start request in work queue");

	[self queueBlock:^{
		OCTLogDebug(@[@"START"], @"performing start request");

		if (self->_state == OCCoreStateStopped)
		{
			__block NSError *startError = nil;
			dispatch_group_t startGroup = nil;

			[self recomputeConnectionStatus];

			[self _updateState:OCCoreStateStarting];

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
				// Setup sync engine
				[self setupSyncEngine];

				self->_attemptConnect = YES;
				[self _attemptConnect];
			}
			else
			{
				self->_attemptConnect = NO;
				[self _updateState:OCCoreStateStopped];
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

- (void)stopWithCompletionHandler:(nullable OCCompletionHandler)completionHandler
{
	OCTLogDebug(@[@"STOP"], @"queuing stop request in connectivity queue");

	[self queueConnectivityBlock:^{
		OCTLogDebug(@[@"STOP"], @"queuing stop request in work queue");

		[self queueBlock:^{
			__block NSError *stopError = nil;

			OCTLogDebug(@[@"STOP"], @"performing stop request");

			if ((self->_state == OCCoreStateRunning) || (self->_state == OCCoreStateStarting))
			{
				__weak OCCore *weakSelf = self;

				[self _updateState:OCCoreStateStopping];

				// Cancel non-critical requests to speed up shutdown
				[self->_connection cancelNonCriticalRequests];

				// Wait for running operations to finish
				self->_runningActivitiesCompleteBlock = ^{
					dispatch_group_t stopGroup = nil;

					// Stop..
					stopGroup = dispatch_group_create();

					// Shut down Sync Engine
					[weakSelf shutdownSyncEngine];

					// Close connection
					OCCore *strongSelf;
					if ((strongSelf = weakSelf) != nil)
					{
						strongSelf->_attemptConnect = NO;
					}

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

					[weakSelf _updateState:OCCoreStateStopped];

					if (completionHandler != nil)
					{
						completionHandler(weakSelf, stopError);
					}
				};

				if (self->_runningActivities == 0)
				{
					if (self->_runningActivitiesCompleteBlock != nil)
					{
						self->_runningActivitiesCompleteBlock();
						self->_runningActivitiesCompleteBlock = nil;
					}
				}
			}
			else if (completionHandler != nil)
			{
				completionHandler(self, stopError);
			}
		}];
	}];
}

#pragma mark - Attempt Connect
- (void)attemptConnect:(BOOL)doAttempt
{
	[self queueBlock:^{
		self->_attemptConnect = doAttempt;

		[self _attemptConnect];
	}];
}

- (void)_attemptConnect
{
	[self queueConnectivityBlock:^{
		if ((self->_state == OCCoreStateStarting) && self->_attemptConnect)
		{
			// Open connection
			dispatch_suspend(self->_connectivityQueue);

			[self beginActivity:@"Connection connect"];

			[self.connection connectWithCompletionHandler:^(NSError *error, OCIssue *issue) {
				[self queueBlock:^{
					// Change state
					if (error == nil)
					{
						[self _updateState:OCCoreStateRunning];

						if (self.automaticItemListUpdatesEnabled)
						{
							[self startCheckingForUpdates];
						}
					}

					// Relay error and issues to delegate
					if ((error != nil) || (issue != nil))
					{
						if ((self->_delegate!=nil) && [self->_delegate respondsToSelector:@selector(core:handleError:issue:)])
						{
							[self->_delegate core:self handleError:error issue:issue];
						}
					}

					dispatch_resume(self->_connectivityQueue);

					[self endActivity:@"Connection connect"];
				}];
			}];
		}
	}];
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
			[self scheduleItemListTaskForPath:query.queryPath forQuery:YES];
		}
		else
		{
			if (query.queryItem.path != nil)
			{
				// Start item list task for parent directory of queried item
				[self scheduleItemListTaskForPath:[query.queryItem.path parentPath] forQuery:YES];
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
		[self->_queries addObject:query];
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
		[self->_queries removeObject:query];
		query.state = OCQueryStateStopped;
	}];
}

#pragma mark - Tools
- (OCDatabase *)database
{
	return (_vault.database);
}

- (void)retrieveLatestDatabaseVersionOfItem:(OCItem *)item completionHandler:(void(^)(NSError *error, OCItem *requestedItem, OCItem *databaseItem))completionHandler
{
	[self.vault.database retrieveCacheItemsAtPath:item.path itemOnly:YES completionHandler:^(OCDatabase *db, NSError *error, OCSyncAnchor syncAnchor, NSArray<OCItem *> *items) {
		completionHandler(error, item, items.firstObject);
	}];
}

#pragma mark - Memory configuration
- (void)setMemoryConfiguration:(OCCoreMemoryConfiguration)memoryConfiguration
{
	_memoryConfiguration = memoryConfiguration;

	switch (_memoryConfiguration)
	{
		case OCCoreMemoryConfigurationDefault:
			_thumbnailCache.countLimit = OCCacheLimitNone;
		break;

		case OCCoreMemoryConfigurationMinimum:
			_thumbnailCache.countLimit = 1;
		break;
	}
}

#pragma mark - Inter-Process change notification/handling
- (NSString *)ipcNotificationName
{
	if (_ipNotificationName == nil)
	{
		_ipNotificationName = [[NSString alloc] initWithFormat:@"com.owncloud.occore.update.%@", self.bookmark.uuid.UUIDString];
	}

	return (_ipNotificationName);
}

- (void)startIPCObservation
{
	[_ipNotificationCenter addObserver:self forName:self.ipcNotificationName withHandler:^(OCIPNotificationCenter * _Nonnull notificationCenter, OCCore *  _Nonnull core, OCIPCNotificationName  _Nonnull notificationName) {
		[core handleIPCChangeNotification];
	}];
}

- (void)stopIPCObserveration
{
	[_ipNotificationCenter removeObserver:self forName:self.ipcNotificationName];
}

- (void)_postIPCChangeNotification
{
	[_ipNotificationCenter postNotificationForName:self.ipcNotificationName ignoreSelf:YES];
}

- (void)postIPCChangeNotification
{
	// Wait for database transaction to settle and current task on the queue to finish before posting the notification
	@synchronized(OCIPNotificationCenter.class)
	{
		_pendingIPCChangeNotifications++;
	}

	[self beginActivity:@"Post IPC change notification"];
	[self queueBlock:^{
		// Transaction is not yet closed, so post IPC change notification only after changes have settled
		[self.database.sqlDB executeOperation:^NSError *(OCSQLiteDB *db) {
			@synchronized(OCIPNotificationCenter.class)
			{
				if (self->_pendingIPCChangeNotifications != 0)
				{
					self->_pendingIPCChangeNotifications = 0;
					[self _postIPCChangeNotification];
				}
			}
			[self endActivity:@"Post IPC change notification"];
			return(nil);
		} completionHandler:nil];
	}];
}

- (void)handleIPCChangeNotification
{
	OCLogDebug(@"Received IPC change notification");

	[self queueBlock:^{
		[self _checkForChangesByOtherProcessesAndUpdateQueries];
	}];
}

#pragma mark - Check for changes by other processes
- (void)_checkForChangesByOtherProcessesAndUpdateQueries
{
	// Needs to run in queue
	OCSyncAnchor lastKnownSyncAnchor = _latestSyncAnchor;
	OCSyncAnchor latestSyncAnchor = nil;
	NSError *error = nil;

	OCTLogDebug(@[@"IPC"], @"Checking for changes by other processes and updating queries..");

	if ((latestSyncAnchor = [self retrieveLatestSyncAnchorWithError:&error]) != nil)
	{
		if (![lastKnownSyncAnchor isEqual:latestSyncAnchor])
		{
			OCTLogDebug(@[@"IPC"], @"Sync anchors differ (%@ < %@)", lastKnownSyncAnchor, latestSyncAnchor);

			// Sync anchor changed, so there may be changes => replay any you can find
			_latestSyncAnchor = lastKnownSyncAnchor;
			[self _replayChangesSinceSyncAnchor:lastKnownSyncAnchor];
		}
		else
		{
			OCTLogDebug(@[@"IPC"], @"Sync anchors unchanged (%@ == %@)", lastKnownSyncAnchor, latestSyncAnchor);
		}
	}
	else
	{
		OCTLogDebug(@[@"IPC"], @"Could not retrieve latst sync anchor.");
	}
}

- (void)_replayChangesSinceSyncAnchor:(OCSyncAnchor)fromSyncAnchor
{
	[self beginActivity:@"Replaying changes since sync anchor"];

	[self.database retrieveCacheItemsUpdatedSinceSyncAnchor:fromSyncAnchor foldersOnly:NO completionHandler:^(OCDatabase *db, NSError *error, OCSyncAnchor syncAnchor, NSArray<OCItem *> *items) {
		NSMutableArray <OCItem *> *addedOrUpdatedItems = [NSMutableArray new];
		NSMutableArray <OCItem *> *removedItems = [NSMutableArray new];

		for (OCItem *item in items)
		{
			if (item.removed)
			{
				[removedItems addObject:item];
			}
			else
			{
				[addedOrUpdatedItems addObject:item];
			}
		}

		OCTLogDebug(@[@"Replay"], @"Found removedItems=%@, addedOrUpdatedItems=%@ since fromSyncAnchor=%@", removedItems, addedOrUpdatedItems, fromSyncAnchor);

		if ((addedOrUpdatedItems.count > 0) || (removedItems.count > 0))
		{
			OCCoreItemList *addedOrUpdatedItemsList = [OCCoreItemList itemListWithItems:addedOrUpdatedItems];

			[self performUpdatesForAddedItems:nil
			   	removedItems:removedItems
				updatedItems:addedOrUpdatedItems
				refreshPaths:nil
				newSyncAnchor:syncAnchor
				beforeQueryUpdates:^(dispatch_block_t  _Nonnull completionHandler) {
					// Find items that moved to a different path
					for (OCQuery *query in self->_queries)
					{
						OCCoreItemList *queryItemList;

						if ((queryItemList = [OCCoreItemList itemListWithItems:query.fullQueryResults]) != nil)
						{
							NSMutableSet <OCFileID> *sharedFileIDs = [[NSMutableSet alloc] initWithSet:addedOrUpdatedItemsList.itemFileIDsSet];
							[sharedFileIDs intersectSet:queryItemList.itemFileIDsSet];

							for (OCFileID sharedFileID in sharedFileIDs)
							{
								OCItem *queryItem = queryItemList.itemsByFileID[sharedFileID];
								OCItem *newItem = addedOrUpdatedItemsList.itemsByFileID[sharedFileID];

								if (![newItem.path.stringByDeletingLastPathComponent isEqual:queryItem.path.stringByDeletingLastPathComponent])
								{
									OCTLogDebug(@[@"Replay"], @"Found moved item (from=%@ to=%@)", queryItem.path, newItem.path);

									newItem.previousPath = queryItem.path;
								}
								else
								{
									OCTLogDebug(@[@"Replay"], @"Found item didn't move (queryItem=%@ newItem=%@)", queryItem, newItem);
								}
							}
						}
					}

					completionHandler();
				}
				afterQueryUpdates:nil
				queryPostProcessor:nil
				skipDatabase:YES
			];
		}

		[self endActivity:@"Replaying changes since sync anchor"];
	}];
}

#pragma mark - ## Commands
- (nullable NSProgress *)shareItem:(OCItem *)item options:(nullable OCShareOptions)options resultHandler:(nullable OCCoreActionResultHandler)resultHandler
{
	return(nil); // Stub implementation
}

- (nullable NSProgress *)requestAvailableOfflineCapabilityForItem:(OCItem *)item completionHandler:(nullable OCCoreCompletionHandler)completionHandler
{
	return(nil); // Stub implementation
}

- (nullable NSProgress *)terminateAvailableOfflineCapabilityForItem:(OCItem *)item completionHandler:(nullable OCCoreCompletionHandler)completionHandler
{
	return(nil); // Stub implementation
}

#pragma mark - Progress tracking
- (void)registerProgress:(NSProgress *)progress forItem:(OCItem *)item
{
	OCFileID fileID;

	if ((fileID = item.fileID) != nil)
	{
		@synchronized(_progressByFileID)
		{
			NSMutableArray <NSProgress *> *progressObjects;

			if ((progressObjects = _progressByFileID[fileID]) == nil)
			{
				progressObjects = (_progressByFileID[fileID] = [NSMutableArray new]);
			}

			[progressObjects addObject:progress];

			[progress addObserver:self forKeyPath:@"isFinished" options:NSKeyValueObservingOptionInitial context:(__bridge void *)_progressByFileID];
			[progress addObserver:self forKeyPath:@"isCancelled" options:0 context:(__bridge void *)_progressByFileID];
			progress.fileID = fileID;
		}
	}
}

- (void)unregisterProgress:(NSProgress *)progress forItem:(OCItem *)item
{
	OCFileID fileID;

	if ((fileID = item.fileID) != nil)
	{
		[self unregisterProgress:progress forFileID:fileID];
	}
}

- (void)unregisterProgress:(NSProgress *)progress forFileID:(OCFileID)fileID
{
	if (fileID != nil)
	{
		@synchronized(_progressByFileID)
		{
			NSMutableArray <NSProgress *> *progressObjects;

			if ((progressObjects = _progressByFileID[fileID]) != nil)
			{
				[progressObjects removeObjectIdenticalTo:progress];

				[progress removeObserver:self forKeyPath:@"isFinished" context:(__bridge void *)_progressByFileID];
				[progress removeObserver:self forKeyPath:@"isCancelled" context:(__bridge void *)_progressByFileID];
			}
		}
	}
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if (context == (__bridge void *)_progressByFileID)
	{
		if ([object isKindOfClass:[NSProgress class]])
		{
			NSProgress *progress = object;

			if ((progress.isFinished || progress.isCancelled) && (progress.fileID != nil))
			{
				[self unregisterProgress:progress forFileID:progress.fileID];
			}
		}
	}
	else
	{
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}

- (NSArray <NSProgress *> *)progressForItem:(OCItem *)item matchingEventType:(OCEventType)eventType
{
	NSMutableArray <NSProgress *> *resultProgressObjects = nil;

	OCFileID fileID;

	if ((fileID = item.fileID) != nil)
	{
		@synchronized(_progressByFileID)
		{
			NSMutableArray <NSProgress *> *progressObjects;

			if ((progressObjects = _progressByFileID[fileID]) != nil)
			{
				if (eventType == OCEventTypeNone)
				{
					resultProgressObjects = [[NSMutableArray alloc] initWithArray:progressObjects];
				}
				else
				{
					for (NSProgress *progress in progressObjects)
					{
						if (progress.eventType == eventType)
						{
							if (resultProgressObjects == nil)
							{
								resultProgressObjects = [NSMutableArray new];
							}

							[resultProgressObjects addObject:progress];
						}
					}
				}
			}
		}
	}

	return (resultProgressObjects);
}

#pragma mark - Item location & directory lifecycle
- (NSURL *)localURLForItem:(OCItem *)item
{
	if (item.localRelativePath != nil)
	{
		return ([self.vault.filesRootURL URLByAppendingPathComponent:item.localRelativePath isDirectory:NO]);
	}

	return ([self.vault localURLForItem:item]);
}

- (NSURL *)localParentDirectoryURLForItem:(OCItem *)item
{
	return ([[self localURLForItem:item] URLByDeletingLastPathComponent]);
}

- (nullable NSURL *)availableTemporaryURLAlongsideItem:(OCItem *)item fileName:(__autoreleasing NSString **)returnFileName
{
	NSURL *temporaryURL = nil;
	NSURL *baseURL = [self localParentDirectoryURLForItem:item];

	for (NSUInteger attempt=0; attempt < 100; attempt++)
	{
		NSString *filename;

		if ((filename = [NSString stringWithFormat:@"%lu-%@.tmp", (unsigned long)attempt, NSUUID.UUID.UUIDString]) != nil)
		{
			NSURL *temporaryURLCandidate;

			if ((temporaryURLCandidate = [baseURL URLByAppendingPathComponent:filename]) != nil)
			{
				if (![[NSFileManager defaultManager] fileExistsAtPath:temporaryURLCandidate.path])
				{
					temporaryURL = temporaryURLCandidate;

					if (returnFileName != NULL)
					{
						*returnFileName = filename;
					}
				}
			}
		}
	}

	return (temporaryURL);
}

- (BOOL)isURL:(NSURL *)url temporaryAlongsideItem:(OCItem *)item
{
	return ([[url URLByDeletingLastPathComponent] isEqual:[self localParentDirectoryURLForItem:item]] && [url.pathExtension isEqual:@"tmp"]);
}

- (NSError *)createDirectoryForItem:(OCItem *)item
{
	NSError *error = nil;
	NSURL *parentURL;

	if ((parentURL = [self localParentDirectoryURLForItem:item]) != nil)
	{
		if (![[NSFileManager defaultManager] fileExistsAtPath:[parentURL path]])
		{
			if (![[NSFileManager defaultManager] createDirectoryAtURL:parentURL withIntermediateDirectories:YES attributes:nil error:&error])
			{
				OCLogError(@"Item parent directory creation at %@ failed with error %@", OCLogPrivate(parentURL), error);
			}
		}
	}
	else
	{
		error = OCError(OCErrorInternal);
	}

	return (error);
}

- (NSError *)deleteDirectoryForItem:(OCItem *)item
{
	NSError *error = nil;
	NSURL *parentURL;

	if ((parentURL = [self localParentDirectoryURLForItem:item]) != nil)
	{
		if ([[NSFileManager defaultManager] fileExistsAtPath:[parentURL path]])
		{
			if (![[NSFileManager defaultManager] removeItemAtURL:parentURL error:&error])
			{
				OCLogError(@"Item parent directory deletion at %@ failed with error %@", OCLogPrivate(parentURL), error);
			}
		}
	}
	else
	{
		error = OCError(OCErrorInternal);
	}

	return (error);
}

- (NSError *)renameDirectoryFromItem:(OCItem *)fromItem forItem:(OCItem *)toItem adjustLocalMetadata:(BOOL)adjustLocalMetadata
{
	NSURL *fromItemParentURL = [self localParentDirectoryURLForItem:fromItem];
	NSURL *toItemParentURL = [self localParentDirectoryURLForItem:toItem];
	NSError *error = nil;

	if ((fromItemParentURL != nil) && (toItemParentURL != nil))
	{
		// Move parent directory as needed
		if (![fromItemParentURL isEqual:toItemParentURL])
		{
			if (![[NSFileManager defaultManager] moveItemAtURL:fromItemParentURL toURL:toItemParentURL error:&error])
			{
				OCLogError(@"Item parent directory %@ could not be renamed to %@, error=%@", OCLogPrivate(fromItemParentURL), OCLogPrivate(toItemParentURL), error);
				return (error);
			}
		}

		// Rename local file as needed
		if (fromItem.localRelativePath != nil)
		{
			NSString *fromName = fromItem.localRelativePath.lastPathComponent;
			NSString *toName = toItem.name;

			if ((fromName != nil) && (toName != nil) && (![fromName isEqual:toName]))
			{
				// Renamed
				NSURL *fromLocalFileURL = [toItemParentURL URLByAppendingPathComponent:fromName];
				NSURL *toLocalFileURL = [toItemParentURL URLByAppendingPathComponent:toName];

				if (![[NSFileManager defaultManager] moveItemAtURL:fromLocalFileURL toURL:toLocalFileURL error:&error])
				{
					OCLogError(@"Item file %@ could not be moved to %@, error=%@", OCLogPrivate(fromLocalFileURL), OCLogPrivate(toLocalFileURL), error);
					return (error);
				}
				else if (adjustLocalMetadata)
				{
					toItem.locallyModified = fromItem.locallyModified;
					toItem.localCopyVersionIdentifier = fromItem.localCopyVersionIdentifier;
					toItem.localRelativePath = [_vault relativePathForItem:toItem];
				}
			}
			else if (adjustLocalMetadata)
			{
				// Name unchanged
				toItem.locallyModified = fromItem.locallyModified;
				toItem.localCopyVersionIdentifier = fromItem.localCopyVersionIdentifier;
				toItem.localRelativePath = fromItem.localRelativePath;
			}
		}
	}
	else
	{
		error = OCError(OCErrorInsufficientParameters);
	}

	return (error);
}

#pragma mark - OCEventHandler methods
- (void)handleEvent:(OCEvent *)event sender:(id)sender
{
	[self beginActivity:@"Handling event"];

	[self queueBlock:^{
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

		[self endActivity:@"Handling event"];
	}];
}

#pragma mark - Busy count
- (void)beginActivity:(NSString *)description
{
	OCLogDebug(@"Beginning activity '%@' ..", description);
	
	@synchronized(OCCore.class)
	{
		self->_runningActivities++;

		if (self->_runningActivities == 1)
		{
			dispatch_group_enter(self->_runningActivitiesGroup);

			if (self->_runningActivitiesStrings == nil)
			{
				self->_runningActivitiesStrings = [NSMutableArray new];
			}
		}

		[self->_runningActivitiesStrings addObject:description];
	}
}

- (void)endActivity:(NSString *)description
{
	OCLogDebug(@"Ended activity '%@' ..", description);
	[self queueBlock:^{
		BOOL allActivitiesEnded = NO;

		@synchronized(OCCore.class)
		{
			self->_runningActivities--;

			NSUInteger oldestIndex;

			if ((oldestIndex = [self->_runningActivitiesStrings indexOfObject:description]) != NSNotFound)
			{
				[self->_runningActivitiesStrings removeObjectAtIndex:oldestIndex];
			}
			else
			{
				OCLogError(@"ERROR! Over-ending activity - core may shutdown abruptly! Activity: %@", description);
			}

			if (self->_runningActivities == 0)
			{
				allActivitiesEnded = YES;
			}
		}

		if (allActivitiesEnded)
		{
			dispatch_group_leave(self->_runningActivitiesGroup);

			if (self->_runningActivitiesCompleteBlock != nil)
			{
				self->_runningActivitiesCompleteBlock();
				self->_runningActivitiesCompleteBlock = nil;
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

#pragma mark - Log tags
+ (void)initialize
{
	if (self == [OCCore self])
	{
		[[OCLogger sharedLogger] addFilter:^BOOL(OCLogger * _Nonnull logger, OCLogLevel logLevel, NSString * _Nullable functionName, NSString * _Nullable file, NSUInteger line, NSArray<OCLogTagName> *__autoreleasing * _Nullable pTags, NSString *__autoreleasing *pLogMessage, uint64_t threadID, NSDate * _Nonnull timestamp) {
			NSString *fileName = [file lastPathComponent];

			// Automatically detect messages from OCCore+[Category].m and add [Category] as tag
			if ([fileName hasPrefix:@"OCCore+"])
			{
				NSString *autoTag;

				if ((autoTag = [fileName substringWithRange:NSMakeRange(7, fileName.length-(7+2))]) != nil)
				{
					if (pTags!=NULL)
					{
						if (*pTags!=nil)
						{
							*pTags = [*pTags arrayByAddingObject:autoTag];
						}
						else
						{
							*pTags = @[autoTag];
						}
					}
				}
			}

			return (YES);
		}];
	}
}

+ (NSArray<OCLogTagName> *)logTags
{
	return (@[@"CORE"]);
}

- (NSArray<OCLogTagName> *)logTags
{
	return (@[@"CORE"]);
}

@end

OCClassSettingsKey OCCoreThumbnailAvailableForMIMETypePrefixes = @"thumbnail-available-for-mime-type-prefixes";

OCDatabaseCounterIdentifier OCCoreSyncAnchorCounter = @"syncAnchor";
OCDatabaseCounterIdentifier OCCoreSyncJournalCounter = @"syncJournal";

OCConnectionSignalID OCConnectionSignalIDCoreOnline = @"coreOnline";

OCCoreOption OCCoreOptionImportByCopying = @"importByCopying";
OCCoreOption OCCoreOptionReturnImmediatelyIfOfflineOrUnavailable = @"returnImmediatelyIfOfflineOrUnavailable";
