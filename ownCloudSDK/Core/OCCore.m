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
#import "OCCoreItemListTask.h"
#import "OCLogger.h"
#import "NSProgress+OCExtensions.h"
#import "OCMacros.h"
#import "NSError+OCError.h"
#import "OCDatabase.h"
#import "OCDatabaseConsistentOperation.h"
#import "OCCore+SyncEngine.h"

@interface OCCore ()
{
	NSMutableDictionary <OCPath,OCCoreItemListTask*> *_itemListTasksByPath;
}

@end

@implementation OCCore

@synthesize bookmark = _bookmark;

@synthesize vault = _vault;
@synthesize connection = _connection;

@synthesize state = _state;

@synthesize eventHandlerIdentifier = _eventHandlerIdentifier;

@synthesize delegate = _delegate;

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

		_eventHandlerIdentifier = [@"OCCore-" stringByAppendingString:_bookmark.uuid.UUIDString];
		_pendingThumbnailRequests = [NSMutableDictionary new];

		_vault = [[OCVault alloc] initWithBookmark:bookmark];

		_connection = [[OCConnection alloc] initWithBookmark:bookmark];

		_reachabilityMonitor = [[OCReachabilityMonitor alloc] initWithHostname:bookmark.url.host];
		_reachabilityMonitor.enabled = YES;
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_reachabilityChanged:) name:OCReachabilityMonitorAvailabilityChangedNotification object:_reachabilityMonitor];

		_queries = [NSMutableArray new];

		_itemListTasksByPath = [NSMutableDictionary new];

		_thumbnailCache = [OCCache new];

		_queue = dispatch_queue_create("OCCore work queue", DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL);
		_connectivityQueue = dispatch_queue_create("OCCore connectivity queue", DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL);

		_runningActivitiesGroup = dispatch_group_create();

		[OCEvent registerEventHandler:self forIdentifier:_eventHandlerIdentifier];
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
			dispatch_group_t stopGroup = nil;

			[self willChangeValueForKey:@"state"];
			_state = OCCoreStateStopping;
			[self didChangeValueForKey:@"state"];

			// Wait for running operations to finish
			dispatch_group_wait(_runningActivitiesGroup, DISPATCH_TIME_FOREVER);

			// Stop..
			stopGroup = dispatch_group_create();

			// Close connection
			_attemptConnect = NO;

			dispatch_group_enter(stopGroup);

			[self.connection disconnectWithCompletionHandler:^{
				dispatch_group_leave(stopGroup);
			}];

			dispatch_group_wait(stopGroup, DISPATCH_TIME_FOREVER);

			// Close vault (incl. database)
			dispatch_group_enter(stopGroup);

			[self.vault closeWithCompletionHandler:^(OCDatabase *db, NSError *error) {
				stopError = error;
				dispatch_group_leave(stopGroup);
			}];

			dispatch_group_wait(stopGroup, DISPATCH_TIME_FOREVER);

			[self willChangeValueForKey:@"state"];
			_state = OCCoreStateStopped;
			[self didChangeValueForKey:@"state"];
		}

		if (completionHandler != nil)
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
				[self startItemListTaskForPath:[query.queryItem.path stringByDeletingLastPathComponent]];
			}
		}
	}];
}

- (void)startQuery:(OCQuery *)query
{
	if (query == nil) { return; }

	// Add query to list of queries
	[self queueBlock:^{
		[_queries addObject:query];
	}];

	[self _startItemListTaskForQuery:query];
}

- (void)reloadQuery:(OCQuery *)query
{
	if (query == nil) { return; }

	[self _startItemListTaskForQuery:query];
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

#pragma mark - Item List Tasks
- (void)startItemListTaskForPath:(OCPath)path
{
	if (path==nil) { return; }

	if (_itemListTasksByPath[path] == nil) // Don't start a new item list task if one is already running for the path
	{
		OCCoreItemListTask *task;

		if ((task = [[OCCoreItemListTask alloc] initWithCore:self path:path]) != nil)
		{
			_itemListTasksByPath[path] = task;

			task.changeHandler = ^(OCCore *core, OCCoreItemListTask *task) {
				[core handleUpdatedTask:task];
			};

			// Retrieve and store current sync anchor value
			[self retrieveLatestSyncAnchorWithCompletionHandler:^(NSError *error, OCSyncAnchor syncAnchor) {
				task.syncAnchorAtStart = syncAnchor;

				[task update];
			}];
		}
	}
}

- (void)handleUpdatedTask:(OCCoreItemListTask *)task
{
	OCQueryState queryState = OCQueryStateStarted;
	BOOL performMerge = NO;
	BOOL removeTask = NO;
	BOOL targetRemoved = NO;
	NSMutableArray <OCItem *> *queryResults = nil;
	OCItem *taskRootItem = nil;
	NSString *taskPath = task.path;

	OCLogDebug(@"Cached Set(%lu): %@", (unsigned long)task.cachedSet.state, OCLogPrivate(task.cachedSet.items));
	OCLogDebug(@"Retrieved Set(%lu): %@", (unsigned long)task.retrievedSet.state, OCLogPrivate(task.retrievedSet.items));

	[self beginActivity:@"item list task"];

	switch (task.cachedSet.state)
	{
		case OCCoreItemListStateSuccess:
			if (task.retrievedSet.state == OCCoreItemListStateSuccess)
			{
				// Merge item sets to final result and update cache
				queryState = OCQueryStateIdle;
				performMerge = YES;
				removeTask = YES;
			}
			else
			{
				// Use items from cache
				if (task.retrievedSet.state == OCCoreItemListStateStarted)
				{
					queryState = OCQueryStateWaitingForServerReply;
				}
				else
				{
					queryState = OCQueryStateContentsFromCache;

					if (task.retrievedSet.state == OCCoreItemListStateFailed)
					{
						if (task.retrievedSet.error != nil)
						{
							// Not Found => removed
							if (IsHTTPErrorWithStatus(task.retrievedSet.error, OCHTTPStatusCodeNOT_FOUND))
							{
								queryState = OCQueryStateTargetRemoved;
								targetRemoved = YES;
								performMerge = YES;
							}
						}

						removeTask = YES;
					}
				}
			}
		break;

		case OCCoreItemListStateFailed:
			// Error retrieving items from cache. This should never happen.
			OCLogError(@"Error retrieving items from cache for %@: %@", OCLogPrivate(task.path), OCLogPrivate(task.cachedSet.error));
			performMerge = YES;
			removeTask = YES;
		break;

		default:
		break;
	}

	if (performMerge)
	{
		// Perform merge
		OCCoreItemList *cacheSet = task.cachedSet;
		OCCoreItemList *retrievedSet = task.retrievedSet;
		NSMutableDictionary <OCPath, OCItem *> *cacheItemsByPath = cacheSet.itemsByPath;
		NSMutableDictionary <OCPath, OCItem *> *retrievedItemsByPath = retrievedSet.itemsByPath;

		NSMutableArray <OCItem *> *changedCacheItems = [NSMutableArray new];
		NSMutableArray <OCItem *> *deletedCacheItems = [NSMutableArray new];
		NSMutableArray <OCItem *> *newItems = [NSMutableArray new];

		__block NSError *cacheUpdateError = nil;

		queryResults = [NSMutableArray new];

		dispatch_group_t cacheUpdateGroup = dispatch_group_create();

		dispatch_group_enter(cacheUpdateGroup);

		[self incrementSyncAnchorWithProtectedBlock:^NSError *(OCSyncAnchor previousSyncAnchor, OCSyncAnchor newSyncAnchor) {
			if (![previousSyncAnchor isEqualToNumber:task.syncAnchorAtStart])
			{
				// Out of sync - trigger catching the latest from the cache again, rinse and repeat
				OCLogDebug(@"Sync anchor changed before task finished: %@ != %@", previousSyncAnchor, task.syncAnchorAtStart);

				task.syncAnchorAtStart = newSyncAnchor; // Update sync anchor before triggering the reload from cache

				cacheUpdateError = OCError(OCErrorOutdatedCache);
				dispatch_group_leave(cacheUpdateGroup);

				return(nil);
			}

			// Iterate retrieved set
			[retrievedSet.itemsByPath enumerateKeysAndObjectsUsingBlock:^(OCPath  _Nonnull retrievedPath, OCItem * _Nonnull retrievedItem, BOOL * _Nonnull stop) {
				OCItem *cacheItem;

				// Item for this path already in the cache?
				if ((cacheItem = cacheItemsByPath[retrievedPath]) != nil)
				{
					// Existing local item?
					if (cacheItem.locallyModified || (cacheItem.localRelativePath!=nil))
					{
						// Preserve local item, but merge in info on latest server version
						cacheItem.remoteItem = retrievedItem;

						// Return updated cached version
						[queryResults addObject:cacheItem];

						// Update cache
						[changedCacheItems addObject:cacheItem];
					}
					else
					{
						// Attach databaseID of cached items to the retrieved items
						retrievedItem.databaseID = cacheItem.databaseID;

						// Return server version
						[queryResults addObject:retrievedItem];
					}
				}
				else
				{
					// New item!
					[queryResults addObject:retrievedItem];
					[newItems addObject:retrievedItem];
				}
			}];

			// Iterate cache set
			[cacheSet.itemsByPath enumerateKeysAndObjectsUsingBlock:^(OCPath  _Nonnull cachePath, OCItem * _Nonnull cacheItem, BOOL * _Nonnull stop) {
				OCItem *retrievedItem;

				// Item for this cached path still on the server?
				if ((retrievedItem = retrievedItemsByPath[cachePath]) == nil)
				{
					// Cache item no longer on the server
					if (cacheItem.locallyModified)
					{
						// Preserve locally modified items
						[queryResults addObject:cacheItem];
					}
					else
					{
						// Remove item
						[deletedCacheItems addObject:cacheItem];
					}
				}
			}];

			// Commit changes to the cache
			[self.database performBatchUpdates:^(OCDatabase *database){
				__block NSError *returnError = nil;

				if ((deletedCacheItems.count > 0) && (returnError==nil))
				{
					[self.database removeCacheItems:deletedCacheItems syncAnchor:newSyncAnchor completionHandler:^(OCDatabase *db, NSError *error) {
						returnError = error;
					}];
				}

				if ((changedCacheItems.count > 0) && (returnError==nil))
				{
					[self.database updateCacheItems:changedCacheItems syncAnchor:newSyncAnchor completionHandler:^(OCDatabase *db, NSError *error) {
						returnError = error;
					}];
				}

				if ((newItems.count > 0) && (returnError==nil))
				{
					[self.database addCacheItems:newItems syncAnchor:newSyncAnchor completionHandler:^(OCDatabase *db, NSError *error) {
						returnError = error;
					}];
				}

				return (returnError);
			} completionHandler:^(OCDatabase *db, NSError *error) {
				cacheUpdateError = error;
				dispatch_group_leave(cacheUpdateGroup);
			}];

			// In parallel: remove thumbnails from in-memory cache
			dispatch_group_enter(cacheUpdateGroup);

			dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
				for (OCItem *deleteItem in deletedCacheItems)
				{
					[_thumbnailCache removeObjectForKey:deleteItem.fileID];
				}

				dispatch_group_leave(cacheUpdateGroup);
			});

			return (nil);
		} completionHandler:^(NSError *error, OCSyncAnchor previousSyncAnchor, OCSyncAnchor newSyncAnchor) {
			NSLog(@"Sync anchor increase result: %@ for %@ => %@", error, previousSyncAnchor, newSyncAnchor);
		}];

		dispatch_group_wait(cacheUpdateGroup, DISPATCH_TIME_FOREVER);

		if (cacheUpdateError != nil)
		{
			// An error occured updating the cache, so don't update queries either, log the error and return here
			if ([cacheUpdateError isOCErrorWithCode:OCErrorOutdatedCache])
			{
				// Sync anchor value increased while fetching data from the server
				OCLogDebug(@"Sync anchor changed, refreshing from cache before merge..");
				[task forceUpdateCacheSet];
			}
			else
			{
				// Actual error
				OCLogError(@"Error updating metaData cache: %@", cacheUpdateError);
			}

			[self endActivity:@"item list task"];

			return;
		}
	}
	else
	{
		if (task.cachedSet.state == OCCoreItemListStateSuccess)
		{
			// Use cache
			queryResults = (task.cachedSet.items != nil) ? [[NSMutableArray alloc] initWithArray:task.cachedSet.items] : [NSMutableArray new];
		}
		else
		{
			// No result (yet)
		}
	}

	// Determine root item
	if ((taskPath != nil) && !targetRemoved)
	{
		OCItem *cacheRootItem = nil, *retrievedRootItem = nil;

		retrievedRootItem = task.retrievedSet.itemsByPath[taskPath];
		cacheRootItem = task.cachedSet.itemsByPath[taskPath];

		if ((taskRootItem==nil) && (cacheRootItem!=nil) && ([queryResults indexOfObjectIdenticalTo:cacheRootItem]!=NSNotFound))
		{
			taskRootItem = cacheRootItem;
		}

		if ((taskRootItem==nil) && (retrievedRootItem!=nil) && ([queryResults indexOfObjectIdenticalTo:retrievedRootItem]!=NSNotFound))
		{
			taskRootItem = retrievedRootItem;
		}
	}

	// Remove task
	if (removeTask)
	{
		if (task.path != nil)
		{
			if (_itemListTasksByPath[task.path] != nil)
			{
				[_itemListTasksByPath removeObjectForKey:task.path];
			}
		}
	}

	// Update queries
	NSMutableDictionary <OCPath, OCItem *> *queryResultItemsByPath = nil;
	NSMutableArray <OCItem *> *queryResultWithoutRootItem = nil;
	NSString *parentTaskPath = [taskPath stringByDeletingLastPathComponent];

	for (OCQuery *query in _queries)
	{
		NSMutableArray <OCItem *> *useQueryResults = nil;
		OCItem *queryRootItem = nil;

		// Queries targeting the path
		if ([query.queryPath isEqual:taskPath])
		{
			if ( (query.state != OCQueryStateIdle) ||	// Keep updating queries that have not gone through its complete, initial content update
			    ((query.state == OCQueryStateIdle) && (queryState == OCQueryStateIdle))) // Don't update queries that have previously gotten a complete, initial content update with content from the cache (as that cache content is prone to be identical with what we already have in it). Instead, update these queries only if we have an idle ("finished") queryResult again.
			{
				NSLog(@"Task root item: %@, include root item: %d", taskRootItem, query.includeRootItem);

				if (query.includeRootItem || (taskRootItem==nil))
				{
					useQueryResults = queryResults;
				}
				else
				{
					if (queryResultWithoutRootItem == nil)
					{
						queryResultWithoutRootItem = [[NSMutableArray alloc] initWithArray:queryResults];

						if (taskRootItem != nil)
						{
							[queryResultWithoutRootItem removeObjectIdenticalTo:taskRootItem];
						}
					}

					useQueryResults = queryResultWithoutRootItem;
				}

				queryRootItem = taskRootItem;
			}
		}
		else
		{
			OCPath queryItemPath;

			// Queries targeting the parent directory of taskPath
			if ([query.queryPath isEqual:parentTaskPath])
			{
				// Should contain taskRootItem
				if (taskRootItem != nil)
				{
					@synchronized(query) // Protect full query results against modification (-setFullQueryResults: is protected using @synchronized(query), too)
					{
						NSMutableArray <OCItem *> *fullQueryResults;

						if ((fullQueryResults = query.fullQueryResults) != nil)
						{
							OCPath taskRootItemPath;

							if ((taskRootItemPath = taskRootItem.path) != nil)
							{
								NSUInteger itemIndex = 0, replaceAtIndex = NSNotFound;

								// Find root item
								for (OCItem *item in fullQueryResults)
								{
									if ([item.path isEqual:taskRootItemPath])
									{
										replaceAtIndex = itemIndex;
										break;
									}

									itemIndex++;
								}

								// Replace if found
								if (replaceAtIndex != NSNotFound)
								{
									[fullQueryResults removeObjectAtIndex:replaceAtIndex];
									[fullQueryResults insertObject:taskRootItem atIndex:replaceAtIndex];

									[query setNeedsRecomputation];
								}
							}
						}
					}
				}
				else
				{
					if (targetRemoved)
					{
						// Task's root item was removed
						@synchronized(query) // Protect full query results against modification (-setFullQueryResults: is protected using @synchronized(query), too)
						{
							NSMutableArray <OCItem *> *fullQueryResults;

							if ((fullQueryResults = query.fullQueryResults) != nil)
							{
								NSUInteger itemIndex = 0, removeAtIndex = NSNotFound;

								// Find root item
								for (OCItem *item in fullQueryResults)
								{
									if ([item.path isEqual:taskPath])
									{
										removeAtIndex = itemIndex;
										break;
									}

									itemIndex++;
								}

								// Remove if found
								if (removeAtIndex != NSNotFound)
								{
									[fullQueryResults removeObjectAtIndex:removeAtIndex];

									[query setNeedsRecomputation];
								}
							}
						}

					}
				}
			}

			// Queries targeting a particular item
			if ((queryItemPath = query.queryItem.path) != nil)
			{
				OCItem *itemAtPath;

				if (queryResultItemsByPath == nil)
				{
					OCCoreItemList *queryResultSet = [OCCoreItemList new];
					[queryResultSet updateWithError:nil items:queryResults];

					queryResultItemsByPath = queryResultSet.itemsByPath;
				}

				if ((itemAtPath = queryResultItemsByPath[queryItemPath]) != nil)
				{
					// Item contained in queried directory, new info may be available
					useQueryResults = [[NSMutableArray alloc] initWithObjects:itemAtPath, nil];
				}
				else
				{
					if ([[queryItemPath stringByDeletingLastPathComponent] isEqual:task.path])
					{
						// Item was contained in queried directory, but is no longer there
						useQueryResults = [NSMutableArray new];
						queryState = OCQueryStateTargetRemoved;
					}
				}
			}
		}

		if (useQueryResults != nil)
		{
			query.state = queryState;
			query.rootItem = queryRootItem;
			query.fullQueryResults = useQueryResults;
		}
	}

	[self endActivity:@"item list task"];
}

#pragma mark - Tools
- (void)retrieveLatestDatabaseVersionOfItem:(OCItem *)item completionHandler:(void(^)(NSError *error, OCItem *requestedItem, OCItem *databaseItem))completionHandler
{
	if (item.type == OCItemTypeCollection)
	{
		// This method only supports files
		completionHandler(OCError(OCErrorFeatureNotSupportedForItem), item, nil);
		return;
	}

	[self.vault.database retrieveCacheItemsAtPath:item.path completionHandler:^(OCDatabase *db, NSError *error, NSArray<OCItem *> *items) {
		completionHandler(error, item, items.firstObject);
	}];
}

#pragma mark - ## Commands
- (NSProgress *)createFolderNamed:(NSString *)newFolderName atPath:(OCPath)path options:(NSDictionary *)options resultHandler:(OCCoreActionResultHandler)resultHandler
{
	return(nil); // Stub implementation
}

- (NSProgress *)createEmptyFileNamed:(NSString *)newFileName atPath:(OCPath)path options:(NSDictionary *)options resultHandler:(OCCoreActionResultHandler)resultHandler
{
	return(nil); // Stub implementation
}

- (NSProgress *)renameItem:(OCItem *)item to:(NSString *)newFileName resultHandler:(OCCoreActionResultHandler)resultHandler
{
	return(nil); // Stub implementation
}

- (NSProgress *)moveItem:(OCItem *)item to:(OCPath)newParentDirectoryPath resultHandler:(OCCoreActionResultHandler)resultHandler
{
	return(nil); // Stub implementation
}

- (NSProgress *)copyItem:(OCItem *)item to:(OCPath)newParentDirectoryPath options:(NSDictionary *)options resultHandler:(OCCoreActionResultHandler)resultHandler
{
	return(nil); // Stub implementation
}

- (NSProgress *)deleteItem:(OCItem *)item resultHandler:(OCCoreActionResultHandler)resultHandler
{
	return(nil); // Stub implementation
}

- (NSProgress *)uploadFileAtURL:(NSURL *)url to:(OCPath)newParentDirectoryPath resultHandler:(OCCoreActionResultHandler)resultHandler
{
	return(nil); // Stub implementation
}

- (NSProgress *)downloadItem:(OCItem *)item to:(OCPath)newParentDirectoryPath resultHandler:(OCCoreActionResultHandler)resultHandler
{
	return(nil); // Stub implementation
}

#pragma mark - Command: Retrieve Thumbnail
- (NSProgress *)retrieveThumbnailFor:(OCItem *)item maximumSize:(CGSize)requestedMaximumSizeInPoints scale:(CGFloat)scale retrieveHandler:(OCCoreThumbnailRetrieveHandler)retrieveHandler
{
	NSProgress *progress = [NSProgress indeterminateProgress];
	OCFileID fileID = item.fileID;
	OCItemVersionIdentifier *versionIdentifier = item.versionIdentifier;
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
				if ([thumbnail.versionIdentifier isEqual:item.versionIdentifier])
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
							cachedThumbnail.versionIdentifier = versionIdentifier;

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
										@"itemVersionIdentifier" : item.versionIdentifier,
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

- (NSProgress *)synchronizeWithServer
{
	return(nil); // Stub implementation
}

#pragma mark - OCEventHandler methods
- (void)handleEvent:(OCEvent *)event sender:(id)sender
{
	if (event.eventType == OCEventTypeRetrieveThumbnail)
	{
		[self _handleRetrieveThumbnailEvent:event sender:sender];
	}
}


#pragma mark - Busy count
- (void)beginActivity:(NSString *)description
{
	OCLogDebug(@"Beginning activity '%@' ..", description);
	dispatch_group_enter(_runningActivitiesGroup);
}

- (void)endActivity:(NSString *)description
{
	OCLogDebug(@"Ended activity '%@' ..", description);
	dispatch_group_leave(_runningActivitiesGroup);
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
