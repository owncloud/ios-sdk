//
//  OCCore.h
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

#import <Foundation/Foundation.h>
#import "OCBookmark.h"
#import "OCVault.h"
#import "OCQuery.h"
#import "OCShareQuery.h"
#import "OCItem.h"
#import "NSProgress+OCEvent.h"
#import "OCConnection.h"
#import "OCShare.h"
#import "OCCache.h"
#import "OCDatabase.h"
#import "OCIPNotificationCenter.h"
#import "OCLogTag.h"
#import "OCAsyncSequentialQueue.h"
#import "OCActivityManager.h"
#import "OCActivityUpdate.h"
#import "OCRecipientSearchController.h"
#import "OCSyncIssue.h"
#import "OCMessageQueue.h"
#import "OCScanJobActivity.h"
#import "OCMeasurement.h"
#import "OCLock.h"
#import "OCLockRequest.h"
#import "OCDataSourceArray.h"
#import "OCDataSourceComposition.h"
#import "OCDataItemPresentable.h"
#import "OCShareRole.h"
#import "OCPlatform.h"

@class OCCore;
@class OCItem;
@class OCCoreItemListTask;
@class OCSyncAction;
@class OCIPNotificationCenter;
@class OCRecipientSearchController;
@class OCCoreQuery;
@class OCItemPolicyProcessor;
@class OCSignalManager;

@class OCCoreConnectionStatusSignalProvider;
@class OCCoreServerStatusSignalProvider;

#pragma mark - Types
typedef NS_ENUM(NSUInteger, OCCoreState)
{
	OCCoreStateStopped,	//!< The core is stopped and can't be used. (if you do, expect things to break)
 	OCCoreStateStopping,	//!< The core is in the process of being stopped.

	OCCoreStateStarting,	//!< The core is being started
	OCCoreStateReady,	//!< The core is started and ready, awaiting connecting to complete

	OCCoreStateRunning	//!< The core is fully operational - and now running
} __attribute__((enum_extensibility(closed)));

typedef NS_ENUM(NSUInteger, OCCoreConnectionStatus)
{
	OCCoreConnectionStatusOffline,		//!< The server or client device is currently offline
	OCCoreConnectionStatusUnavailable,	//!< The server is in maintenance mode and returns with 503 Service Unavailable or /status.php returns "maintenance"=true
	OCCoreConnectionStatusConnecting,	//!< The connection is available and the client is actively trying to connect to the server
	OCCoreConnectionStatusOnline		//!< The server and client device are online
} __attribute__((enum_extensibility(closed)));

typedef NS_OPTIONS(NSUInteger, OCCoreConnectionStatusSignal)
{
	OCCoreConnectionStatusSignalReachable	= (1 << 0),	//!< The server is reachable
	OCCoreConnectionStatusSignalAvailable	= (1 << 1), 	//!< The server is available (not in maintenance mode, not responding with unexpected responses)
	OCCoreConnectionStatusSignalConnecting	= (1 << 2),	//!< The OCCore is in the process of connecting
	OCCoreConnectionStatusSignalConnected	= (1 << 3), 	//!< The OCConnection has connected successfully

	OCCoreConnectionStatusSignalBitCount	= 4		//!< Number of bits used for status signal
} __attribute__((enum_extensibility(closed)));

typedef NS_ENUM(NSUInteger, OCCoreConnectionStatusSignalState)
{
	OCCoreConnectionStatusSignalStateFalse,		//!< Signal state is false
	OCCoreConnectionStatusSignalStateTrue,  	//!< Signal state is true
	OCCoreConnectionStatusSignalStateForceFalse,	//!< Signal state is force false (overriding any true + force true states)
	OCCoreConnectionStatusSignalStateForceTrue   	//!< Signal state is force true (overriding any false states)
} __attribute__((enum_extensibility(closed)));

typedef NS_ENUM(NSUInteger,OCCoreAvailableOfflineCoverage)
{
	OCCoreAvailableOfflineCoverageNone,	//!< Item is not targeted by available offline item policy
	OCCoreAvailableOfflineCoverageIndirect,	//!< Item is indirectly targeted by available offline item policy (f.ex. returned for /Photos/Paris.jpg if /Photos/ is available offline
	OCCoreAvailableOfflineCoverageDirect	//!< Item is directly targeted by available offline item policy
} __attribute__((enum_extensibility(closed)));

NS_ASSUME_NONNULL_BEGIN

typedef void(^OCCoreActionResultHandler)(NSError * _Nullable error, OCCore *core, OCItem * _Nullable item, id _Nullable parameter);
typedef void(^OCCoreUploadResultHandler)(NSError * _Nullable error, OCCore *core, OCItem * _Nullable item, id _Nullable parameter);
typedef void(^OCCoreDownloadResultHandler)(NSError * _Nullable error, OCCore *core, OCItem * _Nullable item, OCFile * _Nullable file);
typedef void(^OCCoreRetrieveHandler)(NSError * _Nullable error, OCCore *core, OCItem * _Nullable item, id _Nullable retrievedObject, BOOL isOngoing, NSProgress * _Nullable progress);
typedef void(^OCCoreThumbnailRetrieveHandler)(NSError * _Nullable error, OCCore *core, OCItem * _Nullable item, OCItemThumbnail * _Nullable thumbnail, BOOL isOngoing, NSProgress * _Nullable progress);
typedef void(^OCCorePlaceholderCompletionHandler)(NSError * _Nullable error, OCItem * _Nullable item);
typedef void(^OCCoreFavoritesResultHandler)(NSError * _Nullable error, NSArray<OCItem *> * _Nullable favoritedItems);
typedef void(^OCCoreItemPolicyCompletionHandler)(NSError * _Nullable error, OCItemPolicy * _Nullable itemPolicy);
typedef void(^OCCoreItemPoliciesCompletionHandler)(NSError * _Nullable error, NSArray <OCItemPolicy *> * _Nullable itemPolicies);
typedef void(^OCCoreClaimCompletionHandler)(NSError * _Nullable error, OCItem * _Nullable item);
typedef void(^OCCoreCompletionHandler)(NSError * _Nullable error);
typedef void(^OCCoreStateChangedHandler)(OCCore *core);
typedef void(^OCCoreSyncReasonCountChangeObserver)(OCCore *core, BOOL initial, NSDictionary<OCSyncReason, NSNumber *> * _Nullable countBySyncReason);
typedef void(^OCCoreDriveCompletionHandler)(NSError * _Nullable error, OCDrive * _Nullable drive);
typedef void(^OCCoreItemCompletionHandler)(NSError * _Nullable error, OCItem * _Nullable item);


typedef void(^OCCoreBusyStatusHandler)(NSProgress * _Nullable progress);

typedef void(^OCCoreSyncIssueResolutionResultHandler)(OCSyncIssueChoice *choice);

typedef void(^OCCoreItemListFetchUpdatesCompletionHandler)(NSError * _Nullable error, BOOL didFindChanges);

typedef void(^OCCoreShareJailQueryCustomizer)(OCQuery *query); // Used by OCCore+DataSources.shareJailQueryCustomizer

typedef NSError * _Nullable (^OCCoreImportTransformation)(NSURL *sourceURL);

typedef NSString* OCCoreOption NS_TYPED_ENUM;
typedef id<NSObject> OCCoreItemTracking;

#pragma mark - Delegate
@protocol OCCoreDelegate <NSObject>

- (void)core:(OCCore *)core handleError:(nullable NSError *)error issue:(nullable OCIssue *)issue;

@optional
- (BOOL)core:(OCCore *)core handleSyncIssue:(nullable OCSyncIssue *)syncIssue; //!< Implement this method if you want to get a chance to handle sync issues before they are submitted to the core's OCMessageQueue. Return YES if you handled it, NO if it should still be submitted to the OCMessageQueue. Use [OCIssue issueFromSyncIssue:syncIssue forCore:core] to convert sync issues received this way to OCIssue instances.

@end

#pragma mark - Class
@interface OCCore : NSObject <OCEventHandler, OCClassSettingsSupport, OCLogTagging, OCProgressResolver>
{
	OCBookmark *_bookmark;

	OCVault *_vault;
	OCConnection *_connection;
	BOOL _attemptConnect;

	OCPlatformMemoryConfiguration _memoryConfiguration;

	NSMutableArray <OCQuery *> *_queries;

	NSMutableArray <OCShareQuery *> *_shareQueries;
	OCShareQuery *_pollingQuery;

	pthread_key_t _queueKey;
	dispatch_queue_t _queue;
	dispatch_queue_t _connectivityQueue;

	OCCoreState _state;
	OCCoreStateChangedHandler _stateChangedHandler;

	BOOL _connectionStatusInitialUpdate;
	OCCoreConnectionStatus _connectionStatus;
	OCCoreConnectionStatusSignal _connectionStatusSignals;
	NSString *_connectionStatusShortDescription;
	NSMutableArray <OCCoreConnectionStatusSignalProvider *> *_connectionStatusSignalProviders;

	OCCoreConnectionStatusSignalProvider *_reachabilityStatusSignalProvider; // Wrapping OCReachabilityMonitor or nw_path_monitor
	OCCoreServerStatusSignalProvider *_serverStatusSignalProvider; // Processes reports of connection refused and maintenance mode responses and performs status.php polls to detect the resolution of the issue
	OCCoreConnectionStatusSignalProvider *_connectingStatusSignalProvider; // Glue to include the OCCore state (connecting) into connection status (signal)
	OCCoreConnectionStatusSignalProvider *_connectionStatusSignalProvider; // Glue to include the OCConnection state (connected) into connection status (signal)
	OCCoreConnectionStatusSignalProvider *_rejectedIssueSignalProvider; // Glue to include rejectedIssueSignatures into reachability
	OCCoreConnectionStatusSignalProvider *_pauseConnectionSignalProvider; // Allows pausing all connectivity via reachability signal

	NSMutableSet<OCIssueSignature> *_unsolvedIssueSignatures;
	NSMutableSet<OCIssueSignature> *_rejectedIssueSignatures;

	NSDate *_nextSchedulingDate;

	NSTimeInterval _effectivePollForChangesInterval;

	OCActivityManager *_activityManager;
	NSMutableSet <OCSyncRecordID> *_publishedActivitySyncRecordIDs;
	BOOL _needsToBroadcastSyncRecordActivityUpdates;

	OCEventHandlerIdentifier _eventHandlerIdentifier;

	BOOL _needsToProcessSyncRecords;

	OCSyncAnchor _latestSyncAnchor;

	OCRateLimiter *_syncResetRateLimiter;

	NSMutableDictionary <OCLocationString, OCCoreItemListTask *> *_itemListTasksByLocationString;
	NSMutableArray <OCCoreDirectoryUpdateJob *> *_queuedItemListTaskUpdateJobs;
	NSMutableArray <OCCoreItemListTask *> *_scheduledItemListTasks;
	NSMutableSet <OCCoreDirectoryUpdateJobID> *_scheduledDirectoryUpdateJobIDs;
	OCScanJobActivity *_scheduledDirectoryUpdateJobActivity;
	NSUInteger _totalScheduledDirectoryUpdateJobs;
	NSUInteger _pendingScheduledDirectoryUpdateJobs;
	OCAsyncSequentialQueue *_itemListTasksRequestQueue;
	BOOL _itemListTaskRunning;
	NSTimeInterval _directoryUpdateStartTime;
	NSMutableArray<OCCoreItemListFetchUpdatesCompletionHandler> *_fetchUpdatesCompletionHandlers;
	OCLock *_scanForChangesLock;
	OCLockRequest *_scanForChangesLockRequest;
	NSTimeInterval _nextCoordinatedScanRetryTime;

	NSMutableArray <OCItemPolicy *> *_itemPolicies;
	NSMutableArray <OCItemPolicyProcessor *> *_itemPolicyProcessors;
	BOOL _itemPoliciesAppliedInitially;
	BOOL _itemPoliciesValid;

	NSMutableSet <OCLocation *> *_availableOfflineFolderLocations;
	NSMutableSet <OCLocalID> *_availableOfflineIDs;
	BOOL _availableOfflineCacheValid;
	NSMapTable <OCClaimIdentifier, NSObject *> *_claimTokensByClaimIdentifier;

	OCSignalManager *_signalManager;

	NSMutableDictionary <NSString *, NSMutableArray<OCCoreThumbnailRetrieveHandler> *> *_pendingThumbnailRequests;

	NSMutableDictionary <OCIPCNotificationName, id> *_remoteSyncEngineTriggerAcknowledgements;
	NSMutableSet<OCSyncRecordID> *_remoteSyncEngineTimedOutSyncRecordIDs;

	OCChecksumAlgorithmIdentifier _preferredChecksumAlgorithm;

	BOOL _automaticItemListUpdatesEnabled;
	NSDate *_lastScheduledItemListUpdateDate;

	NSUInteger _maximumSyncLanes;

	NSMutableDictionary <OCLocalID, NSMutableArray<NSProgress *> *> *_progressByLocalID;

	NSMutableArray <OCCertificate *> *_warnedCertificates;

	NSMutableArray<OCDrive *> *_drives;
	NSMutableDictionary<OCDriveID, OCFileETag> *_lastRootETagsByDriveID;

	OCDataSourceArray *_drivesDataSource;
	OCDataSourceArray *_subscribedDrivesDataSource;
	OCDataSourceArray *_disabledDrivesDataSource;
	OCDataSourceArray *_personalDriveDataSource;
	OCDataSourceArray *_shareJailDriveDataSource;
	OCDataSourceArray *_projectDrivesDataSource;

	dispatch_source_t _pollingDataSourcesTimer;
	NSUInteger _pollingDataSourcesSubscribers;
	NSUInteger _pollingDataSourcesOutstandingRequests;

	OCShareQuery *_acceptedCloudSharesQuery;
	OCShareQuery *_pendingCloudSharesQuery;

	OCShareQuery *_sharedWithMeQuery;
	OCDataSourceComposition *_sharedWithMeDataSource;
	NSInteger _sharedWithMeSubscribingDataSources;
	OCQuery *_sharesJailQuery;
	OCCoreShareJailQueryCustomizer _shareJailQueryCustomizer;
	OCDataSourceComposition *_sharedWithMePendingDataSource;
	OCDataSourceComposition *_sharedWithMeAcceptedDataSource;
	OCDataSourceComposition *_sharedWithMeDeclinedDataSource;

	OCShareQuery *_allSharedByMeQuery;
	OCDataSourceArray *_allSharedByMeDataSource;
	NSInteger _allSharedByMeSubscribingDataSources;
	OCDataSourceArray *_sharedByMeDataSource;
	OCDataSourceArray *_sharedByMeGroupedDataSource;
	OCDataSourceArray *_sharedByLinkDataSource;

	OCQuery *_favoritesQuery; // provides content for .favoritesDataSource
	BOOL _favoritesDataSourceHasSubscribers;
	OCDataSourceComposition *_favoritesDataSource;

	BOOL _availableOfflineItemPoliciesDataSourceHasSubscribers;
	BOOL _observesOfflineItemPolicies;
	OCDataSourceArray *_availableOfflineItemPoliciesDataSource;

	OCQuery *_availableOfflineFilesQuery;
	BOOL _availableOfflineFilesDataSourceHasSubscribers;
	OCDataSourceComposition *_availableOfflineFilesDataSource;

	NSMutableArray<OCCoreSyncReasonCountChangeObserver> *_syncReasonCountChangeObservers;
	NSDictionary<OCSyncReason, NSNumber *> *_lastSyncReasonCounts;

	__weak id <OCCoreDelegate> _delegate;

	NSMutableArray<OCShareRole *> *_legacyShareRoles;

	NSNumber *_rootQuotaBytesRemaining;
	NSNumber *_rootQuotaBytesUsed;
	NSNumber *_rootQuotaBytesTotal;
}

@property(readonly) OCCoreRunIdentifier runIdentifier; //!< UUID that's unique for every OCCore instance (also differs between two cores for the same bookmarks)
@property(readonly,nonatomic) BOOL isManaged; //!< YES if this OCCore is managed by OCCoreManager.

@property(readonly) OCBookmark *bookmark; //!< Bookmark identifying the server this core manages.

@property(readonly) OCVault *vault; //!< Vault managing storage and database access for this core.
@property(readonly) OCConnection *connection; //!< Connection used by the core to make requests to the server.

@property(assign,nonatomic) OCPlatformMemoryConfiguration memoryConfiguration;

@property(readonly,nonatomic) OCCoreState state;
@property(copy) OCCoreStateChangedHandler stateChangedHandler;

@property(copy,nullable,nonatomic) OCCoreBusyStatusHandler busyStatusHandler;

@property(readonly,nonatomic) OCCoreConnectionStatus connectionStatus; //!< Combined connection status computed from different available signals like OCReachabilityMonitor and server responses
@property(readonly,nonatomic) OCCoreConnectionStatusSignal connectionStatusSignals; //!< Mask of current connection status signals
@property(readonly,strong,nullable) NSString *connectionStatusShortDescription; //!< Short description of the current connection status.

@property(readonly,strong) OCSignalManager *signalManager;

@property(readonly,strong) OCActivityManager *activityManager;

@property(readonly,strong) OCEventHandlerIdentifier eventHandlerIdentifier;

@property(weak) id <OCCoreDelegate> delegate;

@property(assign) BOOL postFileProviderNotifications; //!< YES if the core should post file provider notifications and integrate with file provider APIs.

@property(readonly, strong) OCSyncAnchor latestSyncAnchor;

@property(strong) OCChecksumAlgorithmIdentifier preferredChecksumAlgorithm; //!< Identifier of the preferred checksum algorithm

@property(assign) BOOL automaticItemListUpdatesEnabled; //!< Whether OCCore should scan for item list updates automatically.

@property(assign,nonatomic) NSUInteger maximumSyncLanes; //!< The maximum number of sync lanes, which limit how many sync actions can be executed at the same time. A value of 0 equals no limits (default: 0).

@property(readonly,strong,nullable) NSNumber *rootQuotaBytesRemaining; //!< The remaining number of bytes available to the user.
@property(readonly,strong,nullable) NSNumber *rootQuotaBytesUsed; //!< The number of bytes used by the user's content.
@property(readonly,strong,nullable) NSNumber *rootQuotaBytesTotal; //!< The total amount of space assigned/available to the user.

@property(readonly,strong,nonatomic) OCMessageQueue *messageQueue;

#pragma mark - Init
- (instancetype)init NS_UNAVAILABLE; //!< Always returns nil. Please use the designated initializer instead.
- (instancetype)initWithBookmark:(OCBookmark *)bookmark NS_DESIGNATED_INITIALIZER;

- (void)unregisterEventHandler; //!< Unregisters the core as an event handler. Should only be called after the core has been stopped and called the completionHandler. This call is needed to clear the last reference to the core and remove it from memory.

#pragma mark - Start / Stop Core
- (void)startWithCompletionHandler:(nullable OCCompletionHandler)completionHandler;
- (void)stopWithCompletionHandler:(nullable OCCompletionHandler)completionHandler;

#pragma mark - Query
- (void)startQuery:(OCCoreQuery *)query;	//!< Starts a query
- (void)reloadQuery:(OCCoreQuery *)query;	//!< Asks the core to reach out to the server and request a new list of items for the query
- (void)stopQuery:(OCCoreQuery *)query;		//!< Stops a query

#pragma mark - Progress tracking
- (void)registerProgress:(NSProgress *)progress forItem:(OCItem *)item;   //!< Registers a progress object for an item. Once the progress is finished, it's unregistered automatically.
- (void)unregisterProgress:(NSProgress *)progress forItem:(OCItem *)item; //!< Unregisters a progress object for an item

- (nullable NSArray<NSProgress *> *)progressForItemWithLocalID:(nullable OCLocalID)localID matchingEventType:(OCEventType)eventType; //!< Returns the registered progress objects for a specific eventType for an item. Specifying eventType OCEventTypeNone will return all registered progress objects for the item.

#pragma mark - Error handling
- (BOOL)sendError:(nullable NSError *)error issue:(nullable OCIssue *)issue; //!< If YES is returned, the error was sent to the OCCoreDelegate. If NO is returned, the error was not sent to the OCCoreDelegate.

#pragma mark - Item lookup and information
- (nullable OCCoreItemTracking)trackItemAtLocation:(OCLocation *)location trackingHandler:(void(^)(NSError * _Nullable error, OCItem * _Nullable item, BOOL isInitial))trackingHandler; //!< Retrieve an item at the specified path from cache and receive updates via the trackingHandler. The returned OCCoreItemTracking object needs to be retained by the caller. Releasing it will end the tracking. This method is a convenience method wrapping cache retrieval, regular and custom queries under the hood.
- (nullable OCCoreItemTracking)trackItemWithCondition:(OCQueryCondition *)queryCondition trackingHandler:(void(^)(NSError * _Nullable error, OCItem * _Nullable item, BOOL isInitial))trackingHandler; //!< Like -trackItemAtLocation:trackingHandler:, but backed by a query condition. The returned OCCoreItemTracking object needs to be retained by the caller. Releasing it will end the tracking.

- (nullable OCItem *)cachedItemAtLocation:(OCLocation *)location error:(__autoreleasing NSError * _Nullable * _Nullable)outError; //!< If one exists, returns the item at the specified location from the cache.
- (void)cachedItemAtLocation:(OCLocation *)location resultHandler:(void(^)(NSError * _Nullable error, OCItem * _Nullable item))resultHandler; //!< If one exists, returns the item at the specified location from the cache.
- (nullable OCItem *)cachedItemInParentLocation:(OCLocation *)parentLocation withName:(NSString *)name isDirectory:(BOOL)isDirectory error:(__autoreleasing NSError * _Nullable * _Nullable)outError; //!< If one exists, returns the item with the provided name in the specified parent directory.
- (nullable OCItem *)cachedItemInParent:(OCItem *)parentItem withName:(NSString *)name isDirectory:(BOOL)isDirectory error:(__autoreleasing NSError * _Nullable * _Nullable)outError; //!< If one exists, returns the item with the provided name in the parent directory represented by parentItem.
- (nullable NSURL *)localCopyOfItem:(OCItem *)item;		//!< Returns the local URL of the item if a local copy exists.

#pragma mark - Item location & directory lifecycle
- (NSURL *)localURLForItem:(OCItem *)item;			//!< Returns the local URL of the item, including the file itself. Also returns a URL for items that don't have a local copy. Please use -localCopyOfItem: if you'd like to check for a local copy and retrieve its URL in one go.
- (NSURL *)localParentDirectoryURLForItem:(OCItem *)item;	//!< Returns the local URL of the parent directory of the item.

- (nullable NSURL *)availableTemporaryURLAlongsideItem:(OCItem *)item fileName:(__autoreleasing NSString * _Nullable * _Nullable)returnFileName; //!< Returns a free local URL for a temporary file inside an item's directory. Returns the filename seperately if wanted.
- (BOOL)isURL:(NSURL *)url temporaryAlongsideItem:(OCItem *)item; //!< Returns YES if url is a temporary URL pointing to a file alongside the item's file.

- (nullable NSError *)createDirectoryForItem:(OCItem *)item; 		//!< Creates the directory for the item
- (nullable NSError *)deleteDirectoryForItem:(OCItem *)item; 		//!< Deletes the directory for the item
- (nullable NSError *)renameDirectoryFromItem:(OCItem *)fromItem forItem:(OCItem *)toItem adjustLocalMetadata:(BOOL)adjustLocalMetadata; //!< Renames the directory of a (placeholder) item to be usable by another item

#pragma mark - Drives
@property(readonly,nonatomic) BOOL useDrives; //!< Returns YES if this account is drive-based (oCIS) rather than driven by a single WebDAV endpoint (OC10)

- (void)subscribeToDrive:(OCDrive *)drive; //!< Subscribes to a drive. The metadata for subscribed drives are actively kept up-to-date. [TBD]
- (void)unsubscribeFromDrive:(OCDrive *)drive; //!< Unsubscribe from a drive. Metadata + files may be kept around, but are not kept up-to-date. [TBD]

@property(strong,readonly,nonatomic) NSArray<OCDrive *> *drives; //!< Returns all known drives.
@property(strong,readonly,nonatomic) NSArray<OCDrive *> *subscribedDrives; //!< Returns all subscribed drives.
- (nullable OCDrive *)driveWithIdentifier:(OCDriveID)driveID attachedOnly:(BOOL)attachedOnly; //!< Returns the OCDrive* instance for an OCDriveID - or nil, if it wasn't found.

@property(strong,readonly,nullable,nonatomic) OCDrive *personalDrive;

#pragma mark - App Providers
@property(readonly,nullable,nonatomic) OCAppProvider *appProvider;

#pragma mark - Item usage
- (void)registerUsageOfItem:(OCItem *)item completionHandler:(nullable OCCompletionHandler)completionHandler; //!< Registers that the item has been used by the user, updating the locally tracked OCItem.lastUsed date with the current date and time.

#pragma mark - Indicating activity requiring the core
- (void)performInRunningCore:(void(^)(dispatch_block_t completionHandler))activityBlock withDescription:(NSString *)description; //!< Runs a block in the current thread while making sure OCCore will not stop before the completionHandler has been called.

#pragma mark - Schedule work in the core's queue
- (void)scheduleInCoreQueue:(dispatch_block_t)block; //!< Performs a block on the core's internal queue, effectively pausing the core for the duration the block runs. Use this only if you know what you're doing.

@end

@interface OCCore (Favorites)

- (nullable NSProgress *)refreshFavoritesWithCompletionHandler:(OCCoreFavoritesResultHandler)completionHandler; //!< Performs a search for favorites on the server and uses the results to update the favorite status of items in the meta data cache. This is a (hopefully temporary) band-aid for a wider issue (see https://github.com/owncloud/core/issues/16589#issuecomment-492577219 for details). The returned array of OCItems may be incomplete as it only contains OCItems already known by the database.

@end

@interface OCCore (Thumbnails)
+ (BOOL)thumbnailSupportedForMIMEType:(NSString *)mimeType;
@end

typedef void(^OCCoreShareRoleRetrievalHandler)(NSError * _Nullable error, NSArray<OCShareRole *> * _Nullable roles);

@interface OCCore (Sharing)
/**
 Creates a new share on the server.

 @param share The OCShare object with the share to create. Use the OCShare convenience constructors for this object.
 @param options Options (pass nil for now).
 @param completionHandler Completion handler to receive the result upon completion.
 @return A progress object tracking the underlying HTTP request.
 */
- (nullable NSProgress *)createShare:(OCShare *)share options:(nullable OCShareOptions)options completionHandler:(void(^)(NSError * _Nullable error, OCShare * _Nullable newShare))completionHandler;

/**
 Updates an existing share with changes.

 @param share The share to update (without changes).
 @param performChanges A block within which the changes to the share need to be performed (will be called immediately) so the method can detect what changed and perform updates on the server as needed.
 @param completionHandler Completion handler to receive the result upon completion.
 @return A progress object tracking the underlying HTTP request(s).
 */
- (nullable NSProgress *)updateShare:(OCShare *)share afterPerformingChanges:(void(^)(OCShare *share))performChanges completionHandler:(void(^)(NSError * _Nullable error, OCShare * _Nullable updatedShare))completionHandler;

/**
 Deletes an existing share.

 @param share The share to delete.
 @param completionHandler Completion handler to receive the result upon completion.
 @return A progress object tracking the underlying HTTP request(s).
 */
- (nullable NSProgress *)deleteShare:(OCShare *)share completionHandler:(void(^)(NSError * _Nullable error))completionHandler;

/**
 Make a decision on whether to allow or reject a request for federated sharing.

 @param share The share to make the decision on.
 @param accept YES to allow the request for sharing. NO to decline it.
 @param completionHandler Completion handler to receive the result upon completion.
 @return A progress object tracking the underlying HTTP request(s).
 */
- (nullable NSProgress *)makeDecisionOnShare:(OCShare *)share accept:(BOOL)accept completionHandler:(void(^)(NSError * _Nullable error))completionHandler;

- (OCRecipientSearchController *)recipientSearchControllerForItem:(OCItem *)item; //!< Returns a recipient search controller for the provided item

- (nullable NSProgress *)retrievePrivateLinkForItem:(OCItem *)item completionHandler:(void(^)(NSError * _Nullable error, NSURL * _Nullable privateLink))completionHandler; //!< Returns the private link for the item
- (nullable NSProgress *)retrieveItemForPrivateLink:(NSURL *)privateLink completionHandler:(void(^)(NSError * _Nullable error, OCItem * _Nullable item))completionHandler; //!< Returns the item for the private link

- (void)availableShareRolesForType:(OCShareType)shareType location:(OCLocation *)location completionHandler:(OCCoreShareRoleRetrievalHandler)completionHandler; //!< Returns the share roles available for this location and type. Returns nil if none are available.
- (nullable OCShareRole *)matchingForShare:(OCShare *)share fromShareRoles:(nullable NSArray<OCShareRole *> *)roles; //!< Returns the share role matching the provided item and share's permissions and location. Returns nil if none matches.

@end

@interface OCCore (AvailableOffline)
- (void)makeAvailableOffline:(OCItem *)item options:(nullable NSDictionary <OCCoreOption, id> *)options completionHandler:(nullable OCCoreItemPolicyCompletionHandler)completionHandler; //!< Request offline availablity for an item. Pass OCCoreOptionSkipRedundancyChecks in options to skip redundancy tests.
- (nullable NSArray <OCItemPolicy *> *)retrieveAvailableOfflinePoliciesCoveringItem:(nullable OCItem *)item completionHandler:(nullable OCCoreItemPoliciesCompletionHandler)completionHandler; //!< Retrieves an array of item policies that request offline availability for this item. Passing nil for completionHandler makes this call return results synchronously. Passing nil for item returns all available offline policies.
- (void)removeAvailableOfflinePolicy:(OCItemPolicy *)itemPolicy completionHandler:(nullable OCCoreCompletionHandler)completionHandler; //!< Removes the provided available offline item policy.
- (OCCoreAvailableOfflineCoverage)availableOfflinePolicyCoverageOfItem:(OCItem *)item; //!< Determines the available offline coverage for an item. Meant to be used for displaying coverage status.
@end

@interface OCCore (CommandDownload)
- (nullable NSProgress *)downloadItem:(OCItem *)item options:(nullable NSDictionary<OCCoreOption,id> *)options resultHandler:(nullable OCCoreDownloadResultHandler)resultHandler;
@end

@interface OCCore (CommandLocalImport)
- (nullable NSProgress *)importFileNamed:(nullable NSString *)newFileName at:(OCItem *)parentItem fromURL:(NSURL *)inputFileURL isSecurityScoped:(BOOL)isSecurityScoped options:(nullable NSDictionary<OCCoreOption,id> *)options placeholderCompletionHandler:(nullable OCCorePlaceholderCompletionHandler)placeholderCompletionHandler resultHandler:(nullable OCCoreUploadResultHandler)resultHandler;
@end

@interface OCCore (CommandLocalModification)
- (nullable NSProgress *)reportLocalModificationOfItem:(OCItem *)item parentItem:(OCItem *)parentItem withContentsOfFileAtURL:(nullable NSURL *)inputFileURL isSecurityScoped:(BOOL)isSecurityScoped options:(nullable NSDictionary<OCCoreOption,id> *)options placeholderCompletionHandler:(nullable OCCorePlaceholderCompletionHandler)placeholderCompletionHandler resultHandler:(nullable OCCoreUploadResultHandler)resultHandler;
@end

@interface OCCore (CommandCreateFolder)
- (nullable NSProgress *)createFolder:(NSString *)folderName inside:(OCItem *)parentItem options:(nullable NSDictionary<OCCoreOption,id> *)options resultHandler:(nullable OCCoreActionResultHandler)resultHandler;
- (nullable NSProgress *)createFolder:(NSString *)folderName inside:(OCItem *)parentItem options:(nullable NSDictionary<OCCoreOption,id> *)options placeholderCompletionHandler:(nullable OCCorePlaceholderCompletionHandler)placeholderCompletionHandler resultHandler:(nullable OCCoreActionResultHandler)resultHandler;
@end

@interface OCCore (CommandDelete)
- (nullable NSProgress *)deleteItem:(OCItem *)item requireMatch:(BOOL)requireMatch resultHandler:(nullable OCCoreActionResultHandler)resultHandler;
- (nullable NSProgress *)deleteLocalCopyOfItem:(OCItem *)item resultHandler:(nullable OCCoreActionResultHandler)resultHandler;
@end

@interface OCCore (CommandCopyMove)
- (nullable NSProgress *)copyItem:(OCItem *)item to:(OCItem *)parentItem withName:(NSString *)name options:(nullable NSDictionary<OCCoreOption,id> *)options resultHandler:(nullable OCCoreActionResultHandler)resultHandler;
- (nullable NSProgress *)moveItem:(OCItem *)item to:(OCItem *)parentItem withName:(NSString *)name options:(nullable NSDictionary<OCCoreOption,id> *)options resultHandler:(nullable OCCoreActionResultHandler)resultHandler;
- (nullable NSProgress *)renameItem:(OCItem *)item to:(NSString *)newFileName options:(nullable NSDictionary<OCCoreOption,id> *)options resultHandler:(nullable OCCoreActionResultHandler)resultHandler;
@end

@interface OCCore (CommandUpdate)
- (nullable NSProgress *)updateItem:(OCItem *)item properties:(NSArray <OCItemPropertyName> *)properties options:(nullable NSDictionary<OCCoreOption,id> *)options resultHandler:(nullable OCCoreActionResultHandler)resultHandler; //!< resultHandler.parameter returns the OCConnectionPropertyUpdateResult
@end

@interface OCCore (DriveManagement)

// Creation
- (nullable NSProgress *)createDriveWithName:(NSString *)name description:(nullable NSString *)description quota:(nullable NSNumber *)quotaBytes template:(nullable OCDriveTemplate)templateName completionHandler:(OCCoreDriveCompletionHandler)completionHandler;

// Disable/Restore/Delete
- (nullable NSProgress *)disableDrive:(OCDrive *)drive completionHandler:(OCCoreCompletionHandler)completionHandler;
- (nullable NSProgress *)restoreDrive:(OCDrive *)drive completionHandler:(OCCoreCompletionHandler)completionHandler;
- (nullable NSProgress *)deleteDrive:(OCDrive *)drive completionHandler:(OCCoreCompletionHandler)completionHandler;

// Change attributes
- (nullable NSProgress *)updateDrive:(OCDrive *)drive properties:(NSDictionary<OCDriveProperty, id> *)updateProperties completionHandler:(nullable OCCoreDriveCompletionHandler)completionHandler;

- (void)retrieveDrive:(OCDrive *)drive itemForResource:(OCDriveResource)resource completionHandler:(OCCoreItemCompletionHandler)completionHandler;
- (nullable NSProgress *)updateDrive:(OCDrive *)drive resourceFor:(OCDriveResource)resource withItem:(nullable OCItem *)item completionHandler:(nullable OCCoreDriveCompletionHandler)completionHandler;

@end

extern OCClassSettingsKey OCCoreAddAcceptLanguageHeader;
extern OCClassSettingsKey OCCoreThumbnailAvailableForMIMETypePrefixes;
extern OCClassSettingsKey OCCoreOverrideReachabilitySignal;
extern OCClassSettingsKey OCCoreOverrideAvailabilitySignal;
extern OCClassSettingsKey OCCoreActionConcurrencyBudgets;
extern OCClassSettingsKey OCCoreCookieSupportEnabled;
extern OCClassSettingsKey OCCoreScanForChangesInterval;
extern OCClassSettingsKey OCCoreSpaceResourceFolderPath;

extern OCDatabaseCounterIdentifier OCCoreSyncAnchorCounter;
extern OCDatabaseCounterIdentifier OCCoreSyncJournalCounter;

extern OCConnectionSignalID OCConnectionSignalIDCoreOnline; //!< This signal is set if the core is fully online and operational. Don't use this as a general network availability indicator - as the network may be reachable, but this signal still not set because of a server-side issue.
extern OCConnectionSignalID OCConnectionSignalIDNetworkAvailable; //!< This signal is set if the network is generally available.

extern OCCoreOption OCCoreOptionImportByCopying; //!< [BOOL] Determines whether -[OCCore importFileNamed:..] should make a copy of the provided file, or move it (default).
extern OCCoreOption OCCoreOptionImportTransformation; //!< [OCCoreImportTransformation] Transformation to be applied on local item before upload
extern OCCoreOption OCCoreOptionReturnImmediatelyIfOfflineOrUnavailable; //!< [BOOL] Determines whether -[OCCore downloadItem:..] should return immediately if the core is currently offline or unavailable.
extern OCCoreOption OCCoreOptionPlaceholderCompletionHandler; //!< [OCCorePlaceholderCompletionHandler] For actions that support it: optional block that's invoked with the placeholder item if one is created by the action.
extern OCCoreOption OCCoreOptionAutomaticConflictResolutionNameStyle; //!< [OCCoreDuplicateNameStyleNone] Automatically resolves conflicts while performing the action. For import, that means automatic rename of the file to upload if a file with the same name already exists, using the provided naming style.
extern OCCoreOption OCCoreOptionDownloadTriggerID; //!< [OCItemDownloadTriggerID] An ID of what triggered the download (f.ex. "AvailableOffline" or "User")
extern OCCoreOption OCCoreOptionSyncReason; //!< [OCCoreOptionSyncReason] The reason the sync action was triggered. Becomes available on the OCSyncRecord.syncReason level.
extern OCCoreOption OCCoreOptionAddFileClaim; //!< [OCClaim] A claim to add to an item as part of an action (typically upload/download)
extern OCCoreOption OCCoreOptionAddTemporaryClaimForPurpose; //!< [OCCoreClaimPurpose] Adds a temporary claim to the returned OCFile object (download) generated for the provided purpose. Makes sure the claim is automatically removed if the OCCore is still running when the object is deallocated. (default is OCCoreClaimPurposeNone)
extern OCCoreOption OCCoreOptionSkipRedundancyChecks; //!< [BOOL] Determines whether AvailableOffline should skip redundancy checks.
extern OCCoreOption OCCoreOptionConvertExistingLocalDownloads; //!< [BOOL] Determines whether AvailableOffline should convert existing local copies to Available Offline managed items if they fall under a new Available Offline rule
extern OCCoreOption OCCoreOptionLastModifiedDate; //!< [NSDate] For uploads, the date that should be used as last modified date for the uploaded file.
extern OCCoreOption OCCoreOptionDependsOnCellularSwitch; //!< [OCCellularSwitchIdentifier] Tells the core to set the permission for cellular access according to the status of the provided OCCellularSwitchIdentifier (currently only supported for up- and downloads).
extern OCCoreOption OCCoreOptionWaitConditions; //!< [OCWaitCondition] Wait conditions that must be met before the sync record should be scheduled.

extern OCKeyValueStoreKey OCCoreSkipAvailableOfflineKey; //!< Vault.KVS-key with a NSNumber Boolean value. If the value is YES, available offline item policies are skipped.

extern OCSyncReason OCSyncReasonUserInteraction; //!< Sync Action was triggered by a user interaction;

extern NSNotificationName OCCoreItemBeginsHavingProgress; //!< Notification sent when an item starts having progress. The object is the localID of the item.
extern NSNotificationName OCCoreItemChangedProgress; //!< Notification sent when an item's progress changed. The object is the localID of the item.
extern NSNotificationName OCCoreItemStopsHavingProgress; //!< Notification sent when an item no longer has any progress. The object is the localID of the item.

NS_ASSUME_NONNULL_END
