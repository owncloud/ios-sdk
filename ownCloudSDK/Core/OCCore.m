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
#import "OCItem+OCThumbnail.h"
#import "OCIPNotificationCenter.h"

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
@synthesize stateChangedHandler = _stateChangedHandler;

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

		_thumbnailCache = [OCCache new];

		_queue = dispatch_queue_create("OCCore work queue", DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL);
		_connectivityQueue = dispatch_queue_create("OCCore connectivity queue", DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL);

		_runningActivitiesGroup = dispatch_group_create();

		[OCEvent registerEventHandler:self forIdentifier:_eventHandlerIdentifier];

		_connection = [[OCConnection alloc] initWithBookmark:bookmark persistentStoreBaseURL:_vault.connectionDataRootURL];
		_connection.preferredChecksumAlgorithm = _preferredChecksumAlgorithm;

		_reachabilityMonitor = [[OCReachabilityMonitor alloc] initWithHostname:bookmark.url.host];
		_reachabilityMonitor.enabled = YES;
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_reachabilityChanged:) name:OCReachabilityMonitorAvailabilityChangedNotification object:_reachabilityMonitor];

		[self startIPCObservation];
	}

	return(self);
}

- (void)dealloc
{
	[self stopIPCObserveration];

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
	[self queueBlock:^{
		if (self->_state == OCCoreStateStopped)
		{
			__block NSError *startError = nil;
			dispatch_group_t startGroup = nil;

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
	[self queueBlock:^{
		__block NSError *stopError = nil;

		if ((self->_state == OCCoreStateRunning) || (self->_state == OCCoreStateStarting))
		{
			__weak OCCore *weakSelf = self;

			[self _updateState:OCCoreStateStopping];

			// Wait for running operations to finish
			self->_runningActivitiesCompleteBlock = ^{
				dispatch_group_t stopGroup = nil;

				// Stop..
				stopGroup = dispatch_group_create();

				// Close connection
				self->_attemptConnect = NO;

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

			[self.connection connectWithCompletionHandler:^(NSError *error, OCConnectionIssue *issue) {
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
					if ((self->_delegate!=nil) && [self->_delegate respondsToSelector:@selector(core:handleError:issue:)])
					{
						[self->_delegate core:self handleError:error issue:issue];
					}

					dispatch_resume(self->_connectivityQueue);
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
			if (self->_state == OCCoreStateStarting)
			{
				[self _attemptConnect];
			}

			[self queueConnectivityBlock:^{	// Wait for _attemptConnect to finish
				[self queueBlock:^{ // See if we can proceed
					if (self->_state == OCCoreStateRunning)
					{
						for (OCQuery *query in self->_queries)
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
			[self scheduleItemListTaskForPath:query.queryPath];
		}
		else
		{
			if (query.queryItem.path != nil)
			{
				// Start item list task for parent directory of queried item
				[self scheduleItemListTaskForPath:[query.queryItem.path parentPath]];
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
	[_ipNotificationCenter addObserver:self forName:self.ipcNotificationName withHandler:^(OCIPNotificationCenter * _Nonnull notificationCenter, id  _Nonnull observer, OCIPCNotificationName  _Nonnull notificationName) {
		[(OCCore *)observer handleIPCChangeNotification];
	}];
}

- (void)stopIPCObserveration
{
	[_ipNotificationCenter removeObserver:self forName:self.ipcNotificationName];
}

- (void)postIPCChangeNotification
{
	[_ipNotificationCenter postNotificationForName:self.ipcNotificationName ignoreSelf:YES];
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

	if ((latestSyncAnchor = [self retrieveLatestSyncAnchorWithError:&error]) != nil)
	{
		if (![lastKnownSyncAnchor isEqual:latestSyncAnchor])
		{
			// Sync anchor changed, so there may be changes

		}
	}
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

#pragma mark - Command: Retrieve Thumbnail
- (nullable NSProgress *)retrieveThumbnailFor:(OCItem *)item maximumSize:(CGSize)requestedMaximumSizeInPoints scale:(CGFloat)scale retrieveHandler:(OCCoreThumbnailRetrieveHandler)retrieveHandler
{
	NSProgress *progress = [NSProgress indeterminateProgress];
	OCFileID fileID = item.fileID;
	OCItemVersionIdentifier *versionIdentifier = item.itemVersionIdentifier;
	NSString *specID = item.thumbnailSpecID;
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
			if ((thumbnail = [self->_thumbnailCache objectForKey:item.fileID]) != nil)
			{
				// Yes! But is it the version we want?
				if ([thumbnail.itemVersionIdentifier isEqual:item.itemVersionIdentifier] && [thumbnail.specID isEqual:item.thumbnailSpecID])
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
					[self->_thumbnailCache removeObjectForKey:item.fileID];

					thumbnail = nil;
				}
			}

			// Should a thumbnail be requested?
			if (requestThumbnail)
			{
				if (!progress.cancelled)
				{
					// Thumbnail
					[self.vault.database retrieveThumbnailDataForItemVersion:versionIdentifier specID:specID maximumSizeInPixels:requestedMaximumSizeInPixels completionHandler:^(OCDatabase *db, NSError *error, CGSize maxSize, NSString *mimeType, NSData *thumbnailData) {
						OCItemThumbnail *cachedThumbnail = nil;

						if (thumbnailData != nil)
						{
							// Create OCItemThumbnail from data returned from database
							OCItemThumbnail *cachedThumbnail = [OCItemThumbnail new];

							cachedThumbnail.maximumSizeInPixels = maxSize;
							cachedThumbnail.mimeType = mimeType;
							cachedThumbnail.data = thumbnailData;
							cachedThumbnail.specID = specID;
							cachedThumbnail.itemVersionIdentifier = versionIdentifier;

							if ([cachedThumbnail canProvideForMaximumSizeInPixels:requestedMaximumSizeInPixels])
							{
								[self queueBlock:^{
									[self->_thumbnailCache setObject:cachedThumbnail forKey:fileID cost:(maxSize.width * maxSize.height * 4)];
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
							NSString *requestID = [NSString stringWithFormat:@"%@:%@-%@-%fx%f", versionIdentifier.fileID, versionIdentifier.eTag, specID, requestedMaximumSizeInPixels.width, requestedMaximumSizeInPixels.height];

							[self queueBlock:^{
								BOOL sendRequest = YES;

								// Queue retrieve handlers
								NSMutableArray <OCCoreThumbnailRetrieveHandler> *retrieveHandlersQueue;

								if ((retrieveHandlersQueue = self->_pendingThumbnailRequests[requestID]) == nil)
								{
									retrieveHandlersQueue = [NSMutableArray new];

									self->_pendingThumbnailRequests[requestID] = retrieveHandlersQueue;
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
										@"specID" : item.thumbnailSpecID,
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
		NSString *specID = event.userInfo[@"specID"];
		NSString *requestID = event.ephermalUserInfo[@"requestID"];

		if ((event.error == nil) && (event.result != nil))
		{
			// Update cache
			[self->_thumbnailCache setObject:thumbnail forKey:itemVersionIdentifier.fileID];

			// Store in database
			[self.vault.database storeThumbnailData:thumbnail.data withMIMEType:thumbnail.mimeType specID:specID forItemVersion:itemVersionIdentifier maximumSizeInPixels:thumbnail.maximumSizeInPixels completionHandler:nil];
		}

		// Call all retrieveHandlers
		if (requestID != nil)
		{
			NSMutableArray <OCCoreThumbnailRetrieveHandler> *retrieveHandlersQueue = self->_pendingThumbnailRequests[requestID];

			if (retrieveHandlersQueue != nil)
			{
				[self->_pendingThumbnailRequests removeObjectForKey:requestID];
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
	[self queueBlock:^{
		self->_runningActivities++;

		if (self->_runningActivities == 1)
		{
			dispatch_group_enter(self->_runningActivitiesGroup);
		}
	}];
}

- (void)endActivity:(NSString *)description
{
	OCLogDebug(@"Ended activity '%@' ..", description);
	[self queueBlock:^{
		self->_runningActivities--;
		
		if (self->_runningActivities == 0)
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

@end

OCClassSettingsKey OCCoreThumbnailAvailableForMIMETypePrefixes = @"thumbnail-available-for-mime-type-prefixes";

OCDatabaseCounterIdentifier OCCoreSyncAnchorCounter = @"syncAnchor";
OCDatabaseCounterIdentifier OCCoreSyncJournalCounter = @"syncJournal";

OCCoreOption OCCoreOptionImportByCopying = @"importByCopying";

