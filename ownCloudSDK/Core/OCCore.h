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
#import "OCItem.h"
#import "NSProgress+OCEvent.h"
#import "OCConnection.h"
#import "OCShare.h"
#import "OCReachabilityMonitor.h"
#import "OCCache.h"
#import "OCDatabase.h"
#import "OCRetainerCollection.h"
#import "OCIPNotificationCenter.h"

@class OCCore;
@class OCItem;
@class OCCoreItemListTask;
@class OCSyncAction;
@class OCIPNotificationCenter;

typedef NS_ENUM(NSUInteger, OCCoreState)
{
	OCCoreStateStopped,
	OCCoreStateStopping,

	OCCoreStateStarting,
	OCCoreStateRunning
};

typedef void(^OCCoreActionResultHandler)(NSError *error, OCCore *core, OCItem *item, id parameter);
typedef void(^OCCoreUploadResultHandler)(NSError *error, OCCore *core, OCItem *item, id parameter);
typedef void(^OCCoreDownloadResultHandler)(NSError *error, OCCore *core, OCItem *item, OCFile *file);
typedef void(^OCCoreRetrieveHandler)(NSError *error, OCCore *core, OCItem *item, id retrievedObject, BOOL isOngoing, NSProgress *progress);
typedef void(^OCCoreThumbnailRetrieveHandler)(NSError *error, OCCore *core, OCItem *item, OCItemThumbnail *thumbnail, BOOL isOngoing, NSProgress *progress);
typedef void(^OCCorePlaceholderCompletionHandler)(NSError *error, OCItem *item);
typedef void(^OCCoreCompletionHandler)(NSError *error);
typedef void(^OCCoreStateChangedHandler)(OCCore *core);

typedef NSString* OCCoreOption;

@protocol OCCoreDelegate <NSObject>

- (void)core:(OCCore *)core handleError:(NSError *)error issue:(OCConnectionIssue *)issue;

@end

NS_ASSUME_NONNULL_BEGIN

@interface OCCore : NSObject <OCEventHandler, OCClassSettingsSupport>
{
	OCBookmark *_bookmark;

	OCVault *_vault;
	OCConnection *_connection;
	OCReachabilityMonitor *_reachabilityMonitor;
	BOOL _attemptConnect;

	NSMutableArray <OCQuery *> *_queries;

	dispatch_queue_t _queue;
	dispatch_queue_t _connectivityQueue;

	OCCoreState _state;
	OCCoreStateChangedHandler _stateChangedHandler;

	OCEventHandlerIdentifier _eventHandlerIdentifier;

	BOOL _needsToProcessSyncRecords;

	OCSyncAnchor _latestSyncAnchor;

	NSMutableDictionary <OCPath,OCCoreItemListTask*> *_itemListTasksByPath;

	OCCache<OCFileID,OCItemThumbnail *> *_thumbnailCache;
	NSMutableDictionary <NSString *, NSMutableArray<OCCoreThumbnailRetrieveHandler> *> *_pendingThumbnailRequests;

	id _fileProviderManager;
	NSMutableDictionary <NSFileProviderItemIdentifier, NSNumber *> *_fileProviderSignalCountByContainerItemIdentifiers;
	id _fileProviderSignalCountByContainerItemIdentifiersLock;
	BOOL _postFileProviderNotifications;

	OCIPCNotificationName _ipNotificationName;
	OCIPNotificationCenter *_ipNotificationCenter;

	OCChecksumAlgorithmIdentifier _preferredChecksumAlgorithm;

	BOOL _automaticItemListUpdatesEnabled;
	NSDate *_lastScheduledItemListUpdateDate;

	__weak id <OCCoreDelegate> _delegate;
}

@property(readonly) OCBookmark *bookmark; //!< Bookmark identifying the server this core manages.

@property(readonly) OCVault *vault; //!< Vault managing storage and database access for this core.
@property(readonly) OCConnection *connection; //!< Connection used by the core to make requests to the server.
@property(readonly) OCReachabilityMonitor *reachabilityMonitor; //!< ReachabilityMonitor observing the reachability of the bookmark.url.host.

@property(readonly,nonatomic) OCCoreState state;
@property(copy) OCCoreStateChangedHandler stateChangedHandler;

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
- (void)startQuery:(OCQuery *)query;	//!< Starts a query
- (void)reloadQuery:(OCQuery *)query;	//!< Asks the core to reach out to the server and request a new list of items for the query
- (void)stopQuery:(OCQuery *)query;	//!< Stops a query

#pragma mark - Commands
- (nullable NSProgress *)retrieveThumbnailFor:(OCItem *)item maximumSize:(CGSize)size scale:(CGFloat)scale retrieveHandler:(OCCoreThumbnailRetrieveHandler)retrieveHandler;
+ (BOOL)thumbnailSupportedForMIMEType:(NSString *)mimeType;

- (nullable NSProgress *)shareItem:(OCItem *)item options:(nullable OCShareOptions)options resultHandler:(nullable OCCoreActionResultHandler)resultHandler;

- (nullable NSProgress *)requestAvailableOfflineCapabilityForItem:(OCItem *)item completionHandler:(nullable OCCoreCompletionHandler)completionHandler;
- (nullable NSProgress *)terminateAvailableOfflineCapabilityForItem:(OCItem *)item completionHandler:(nullable OCCoreCompletionHandler)completionHandler;

#pragma mark - Item location & directory lifecycle
- (NSURL *)localURLForItem:(OCItem *)item;			//!< Returns the local URL of the item, including the file itself.
- (NSURL *)localParentDirectoryURLForItem:(OCItem *)item;	//!< Returns the local URL of the parent directory of the item.

- (nullable NSURL *)availableTemporaryURLAlongsideItem:(OCItem *)item fileName:(__autoreleasing NSString **)returnFileName; //!< Returns a free local URL for a temporary file inside an item's directory. Returns the filename seperately if wanted.
- (BOOL)isURL:(NSURL *)url temporaryAlongsideItem:(OCItem *)item; //!< Returns YES if url is a temporary URL pointing to a file alongside the item's file.

- (nullable NSError *)createDirectoryForItem:(OCItem *)item; 		//!< Creates the directory for the item
- (nullable NSError *)deleteDirectoryForItem:(OCItem *)item; 		//!< Deletes the directory for the item

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

extern OCClassSettingsKey OCCoreThumbnailAvailableForMIMETypePrefixes;

extern OCDatabaseCounterIdentifier OCCoreSyncAnchorCounter;
extern OCDatabaseCounterIdentifier OCCoreSyncJournalCounter;

extern OCCoreOption OCCoreOptionImportByCopying; //!< [BOOL] Determines whether -[OCCore importFileNamed:..] should make a copy of the provided file, or move it (default).
