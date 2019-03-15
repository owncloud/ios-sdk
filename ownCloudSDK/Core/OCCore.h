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

@class OCCore;
@class OCItem;
@class OCCoreItemListTask;
@class OCSyncAction;
@class OCIPNotificationCenter;
@class OCRecipientSearchController;
@class OCCoreQuery;

@class OCCoreConnectionStatusSignalProvider;
@class OCCoreServerStatusSignalProvider;

#pragma mark - Types
typedef NS_ENUM(NSUInteger, OCCoreState)
{
	OCCoreStateStopped,
	OCCoreStateStopping,

	OCCoreStateStarting,
	OCCoreStateRunning
};

typedef NS_ENUM(NSUInteger, OCCoreConnectionStatus)
{
	OCCoreConnectionStatusOffline,		//!< The server or client device is currently offline
	OCCoreConnectionStatusUnavailable,	//!< The server is in maintenance mode and returns with 503 Service Unavailable or /status.php returns "maintenance"=true
	OCCoreConnectionStatusOnline,		//!< The server and client device are online
};

typedef NS_OPTIONS(NSUInteger, OCCoreConnectionStatusSignal)
{
	OCCoreConnectionStatusSignalReachable = (1 << 0), //!< The server is reachable
	OCCoreConnectionStatusSignalAvailable = (1 << 1), //!< The server is available (not in maintenance mode, not responding with unexpected responses)
	OCCoreConnectionStatusSignalConnected = (1 << 2), //!< The OCConnection has connected successfully

	OCCoreConnectionStatusSignalBitCount  = 3	  //!< Number of bits used for status signal
};

typedef NS_ENUM(NSUInteger, OCCoreConnectionStatusSignalState)
{
	OCCoreConnectionStatusSignalStateFalse,		//!< Signal state is false
	OCCoreConnectionStatusSignalStateTrue,  	//!< Signal state is true
	OCCoreConnectionStatusSignalStateForceFalse,	//!< Signal state is force false (overriding any true + force true states)
	OCCoreConnectionStatusSignalStateForceTrue   	//!< Signal state is force true (overriding any false states)
};

typedef NS_ENUM(NSUInteger, OCCoreMemoryConfiguration)
{
	OCCoreMemoryConfigurationDefault,	//!< Default memory configuration
	OCCoreMemoryConfigurationMinimum	//!< Try using only the minimum amount of memory needed
};

typedef void(^OCCoreActionResultHandler)(NSError *error, OCCore *core, OCItem *item, id parameter);
typedef void(^OCCoreUploadResultHandler)(NSError *error, OCCore *core, OCItem *item, id parameter);
typedef void(^OCCoreDownloadResultHandler)(NSError *error, OCCore *core, OCItem *item, OCFile *file);
typedef void(^OCCoreRetrieveHandler)(NSError *error, OCCore *core, OCItem *item, id retrievedObject, BOOL isOngoing, NSProgress *progress);
typedef void(^OCCoreThumbnailRetrieveHandler)(NSError *error, OCCore *core, OCItem *item, OCItemThumbnail *thumbnail, BOOL isOngoing, NSProgress *progress);
typedef void(^OCCorePlaceholderCompletionHandler)(NSError *error, OCItem *item);
typedef void(^OCCoreCompletionHandler)(NSError *error);
typedef void(^OCCoreStateChangedHandler)(OCCore *core);

typedef NSError *(^OCCoreImportTransformation)(NSURL *sourceURL);

typedef NSString* OCCoreOption NS_TYPED_ENUM;

#pragma mark - Delegate
@protocol OCCoreDelegate <NSObject>

- (void)core:(OCCore *)core handleError:(NSError *)error issue:(OCIssue *)issue;

@end

#pragma mark - Class
NS_ASSUME_NONNULL_BEGIN

@interface OCCore : NSObject <OCEventHandler, OCClassSettingsSupport, OCLogTagging, OCProgressResolver>
{
	OCBookmark *_bookmark;

	OCVault *_vault;
	OCConnection *_connection;
	BOOL _attemptConnect;

	OCCoreMemoryConfiguration _memoryConfiguration;

	NSMutableArray <OCQuery *> *_queries;

	NSMutableArray <OCShareQuery *> *_shareQueries;
	OCShareQuery *_pollingQuery;

	dispatch_queue_t _queue;
	dispatch_queue_t _connectivityQueue;

	OCCoreState _state;
	OCCoreStateChangedHandler _stateChangedHandler;

	OCCoreConnectionStatus _connectionStatus;
	OCCoreConnectionStatusSignal _connectionStatusSignals;
	NSString *_connectionStatusShortDescription;
	NSMutableArray <OCCoreConnectionStatusSignalProvider *> *_connectionStatusSignalProviders;

	OCCoreConnectionStatusSignalProvider *_reachabilityStatusSignalProvider; // Wrapping OCReachabilityMonitor or nw_path_monitor
	OCCoreServerStatusSignalProvider *_serverStatusSignalProvider; // Processes reports of connection refused and maintenance mode responses and performs status.php polls to detect the resolution of the issue
	OCCoreConnectionStatusSignalProvider *_connectionStatusSignalProvider; // Glue to include the OCConnection state into connection status (signal)

	OCActivityManager *_activityManager;
	NSMutableSet <OCSyncRecordID> *_publishedActivitySyncRecordIDs;
	BOOL _needsToBroadcastSyncRecordActivityUpdates;

	OCEventHandlerIdentifier _eventHandlerIdentifier;

	BOOL _needsToProcessSyncRecords;

	OCSyncAnchor _latestSyncAnchor;

	NSMutableDictionary <OCPath,OCCoreItemListTask*> *_itemListTasksByPath;
	NSMutableArray <OCPath> *_queuedItemListTaskPaths;
	NSMutableArray <OCCoreItemListTask*> *_scheduledItemListTasks;
	OCAsyncSequentialQueue *_itemListTasksRequestQueue;
	BOOL _itemListTaskRunning;

	OCCache<OCFileID,OCItemThumbnail *> *_thumbnailCache;
	NSMutableDictionary <NSString *, NSMutableArray<OCCoreThumbnailRetrieveHandler> *> *_pendingThumbnailRequests;

	id _fileProviderManager;
	NSMutableDictionary <NSFileProviderItemIdentifier, NSNumber *> *_fileProviderSignalCountByContainerItemIdentifiers;
	id _fileProviderSignalCountByContainerItemIdentifiersLock;
	BOOL _postFileProviderNotifications;

	OCChecksumAlgorithmIdentifier _preferredChecksumAlgorithm;

	BOOL _automaticItemListUpdatesEnabled;
	NSDate *_lastScheduledItemListUpdateDate;

	NSMutableDictionary <OCLocalID, NSMutableArray<NSProgress *> *> *_progressByLocalID;

	__weak id <OCCoreDelegate> _delegate;
}

@property(readonly) OCBookmark *bookmark; //!< Bookmark identifying the server this core manages.

@property(readonly) OCVault *vault; //!< Vault managing storage and database access for this core.
@property(readonly) OCConnection *connection; //!< Connection used by the core to make requests to the server.

@property(assign,nonatomic) OCCoreMemoryConfiguration memoryConfiguration;

@property(readonly,nonatomic) OCCoreState state;
@property(copy) OCCoreStateChangedHandler stateChangedHandler;

@property(readonly,nonatomic) OCCoreConnectionStatus connectionStatus; //!< Combined connection status computed from different available signals like OCReachabilityMonitor and server responses
@property(readonly,nonatomic) OCCoreConnectionStatusSignal connectionStatusSignals; //!< Mask of current connection status signals
@property(readonly,strong,nullable) NSString *connectionStatusShortDescription; //!< Short description of the current connection status.

@property(readonly,strong) OCActivityManager *activityManager;

@property(readonly,strong) OCEventHandlerIdentifier eventHandlerIdentifier;

@property(weak) id <OCCoreDelegate> delegate;

@property(assign) BOOL postFileProviderNotifications; //!< YES if the core should post file provider notifications and integrate with file provider APIs.

@property(readonly, strong) OCSyncAnchor latestSyncAnchor;

@property(strong) OCChecksumAlgorithmIdentifier preferredChecksumAlgorithm; //!< Identifier of the preferred checksum algorithm

@property(assign) BOOL automaticItemListUpdatesEnabled; //!< Whether OCCore should scan for item list updates automatically.

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
- (void)stopQuery:(OCCoreQuery *)query;	//!< Stops a query

#pragma mark - Commands
- (nullable NSProgress *)requestAvailableOfflineCapabilityForItem:(OCItem *)item completionHandler:(nullable OCCoreCompletionHandler)completionHandler;
- (nullable NSProgress *)terminateAvailableOfflineCapabilityForItem:(OCItem *)item completionHandler:(nullable OCCoreCompletionHandler)completionHandler;

#pragma mark - Progress tracking
- (void)registerProgress:(NSProgress *)progress forItem:(OCItem *)item;   //!< Registers a progress object for an item. Once the progress is finished, it's unregistered automatically.
- (void)unregisterProgress:(NSProgress *)progress forItem:(OCItem *)item; //!< Unregisters a progress object for an item

- (nullable NSArray <NSProgress *> *)progressForItem:(OCItem *)item matchingEventType:(OCEventType)eventType; //!< Returns the registered progress objects for a specific eventType for an item. Specifying eventType OCEventTypeNone will return all registered progress objects for the item.

#pragma mark - Item location & directory lifecycle
- (NSURL *)localURLForItem:(OCItem *)item;			//!< Returns the local URL of the item, including the file itself. Also returns a URL for items that don't have a local copy. Please use -localCopyOfItem: if you'd like to check for a local copy and retrive its URL in one go.
- (NSURL *)localParentDirectoryURLForItem:(OCItem *)item;	//!< Returns the local URL of the parent directory of the item.

- (nullable NSURL *)localCopyOfItem:(OCItem *)item;		//!< Returns the local URL of the item if a local copy exists.

- (nullable NSURL *)availableTemporaryURLAlongsideItem:(OCItem *)item fileName:(__autoreleasing NSString **)returnFileName; //!< Returns a free local URL for a temporary file inside an item's directory. Returns the filename seperately if wanted.
- (BOOL)isURL:(NSURL *)url temporaryAlongsideItem:(OCItem *)item; //!< Returns YES if url is a temporary URL pointing to a file alongside the item's file.

- (nullable NSError *)createDirectoryForItem:(OCItem *)item; 		//!< Creates the directory for the item
- (nullable NSError *)deleteDirectoryForItem:(OCItem *)item; 		//!< Deletes the directory for the item
- (nullable NSError *)renameDirectoryFromItem:(OCItem *)fromItem forItem:(OCItem *)toItem adjustLocalMetadata:(BOOL)adjustLocalMetadata; //!< Renames the directory of a (placeholder) item to be usable by another item

@end

//@interface OCCore (FileManagement)
//- (void)performFile:(OCFile *)file retainerOperation:(void(^)(OCCore *core, OCFile *file, OCRetainerCollection *retainers))retainerOperation;
//
//- (BOOL)retainFile:(OCFile *)file with:(OCRetainer *)retainer;
//- (BOOL)releaseFile:(OCFile *)file from:(OCRetainer *)retainer;
//
//- (OCRetainer *)retainFile:(OCFile *)file withExplicitIdentifier:(NSString *)explicitIdentifier;
//- (BOOL)releaseFile:(OCFile *)file fromExplicitIdentifier:(NSString *)explicitIdentifier;
//@end

@interface OCCore (Thumbnails)
+ (BOOL)thumbnailSupportedForMIMEType:(NSString *)mimeType;
- (nullable NSProgress *)retrieveThumbnailFor:(OCItem *)item maximumSize:(CGSize)size scale:(CGFloat)scale retrieveHandler:(OCCoreThumbnailRetrieveHandler)retrieveHandler;
@end

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
@end

@interface OCCore (CommandDelete)
- (nullable NSProgress *)deleteItem:(OCItem *)item requireMatch:(BOOL)requireMatch resultHandler:(nullable OCCoreActionResultHandler)resultHandler;
@end

@interface OCCore (CommandCopyMove)
- (nullable NSProgress *)copyItem:(OCItem *)item to:(OCItem *)parentItem withName:(NSString *)name options:(nullable NSDictionary<OCCoreOption,id> *)options resultHandler:(nullable OCCoreActionResultHandler)resultHandler;
- (nullable NSProgress *)moveItem:(OCItem *)item to:(OCItem *)parentItem withName:(NSString *)name options:(nullable NSDictionary<OCCoreOption,id> *)options resultHandler:(nullable OCCoreActionResultHandler)resultHandler;
- (nullable NSProgress *)renameItem:(OCItem *)item to:(NSString *)newFileName options:(nullable NSDictionary<OCCoreOption,id> *)options resultHandler:(nullable OCCoreActionResultHandler)resultHandler;
@end

@interface OCCore (CommandUpdate)
- (nullable NSProgress *)updateItem:(OCItem *)item properties:(NSArray <OCItemPropertyName> *)properties options:(nullable NSDictionary<OCCoreOption,id> *)options resultHandler:(nullable OCCoreActionResultHandler)resultHandler; //!< resultHandler.parameter returns the OCConnectionPropertyUpdateResult
@end

NS_ASSUME_NONNULL_END

extern OCClassSettingsKey OCCoreAddAcceptLanguageHeader;
extern OCClassSettingsKey OCCoreThumbnailAvailableForMIMETypePrefixes;

extern OCDatabaseCounterIdentifier OCCoreSyncAnchorCounter;
extern OCDatabaseCounterIdentifier OCCoreSyncJournalCounter;

extern OCConnectionSignalID OCConnectionSignalIDCoreOnline;

extern OCCoreOption OCCoreOptionImportByCopying; //!< [BOOL] Determines whether -[OCCore importFileNamed:..] should make a copy of the provided file, or move it (default).
extern OCCoreOption OCCoreOptionImportTransformation; //!< [OCCoreImportTransformation] Transformation to be applied on local item before upload
extern OCCoreOption OCCoreOptionReturnImmediatelyIfOfflineOrUnavailable; //!< [BOOL] Determines whether -[OCCore downloadItem:..] should return immediately if the core is currently offline or unavailable.

extern NSNotificationName OCCoreItemBeginsHavingProgress; //!< Notification sent when an item starts having progress. The object is the localID of the item.
extern NSNotificationName OCCoreItemChangedProgress; //!< Notification sent when an item's progress changed. The object is the localID of the item.
extern NSNotificationName OCCoreItemStopsHavingProgress; //!< Notification sent when an item no longer has any progress. The object is the localID of the item.
