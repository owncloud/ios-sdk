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

@class OCCore;
@class OCItem;
@class OCCoreSyncRoute;

typedef NS_ENUM(NSUInteger, OCCoreState)
{
	OCCoreStateStopped,
	OCCoreStateStopping,

	OCCoreStateStarting,
	OCCoreStateRunning
};

typedef void(^OCCoreActionResultHandler)(NSError *error, OCCore *core, OCItem *item, id parameter);
typedef void(^OCCoreDownloadResultHandler)(NSError *error, OCCore *core, OCItem *item, OCFile *file);
typedef void(^OCCoreRetrieveHandler)(NSError *error, OCCore *core, OCItem *item, id retrievedObject, BOOL isOngoing, NSProgress *progress);
typedef void(^OCCoreThumbnailRetrieveHandler)(NSError *error, OCCore *core, OCItem *item, OCItemThumbnail *thumbnail, BOOL isOngoing, NSProgress *progress);
typedef void(^OCCoreCompletionHandler)(NSError *error);

@protocol OCCoreDelegate <NSObject>

- (void)core:(OCCore *)core handleError:(NSError *)error issue:(OCConnectionIssue *)issue;

@end

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

	dispatch_group_t _runningActivitiesGroup;
	NSInteger _runningActivities;
	dispatch_block_t _runningActivitiesCompleteBlock;

	OCCache<OCFileID,OCItemThumbnail *> *_thumbnailCache;
	NSMutableDictionary <NSString *, NSMutableArray<OCCoreThumbnailRetrieveHandler> *> *_pendingThumbnailRequests;

	OCCoreState _state;

	OCEventHandlerIdentifier _eventHandlerIdentifier;

	NSMutableDictionary <OCSyncAction, OCCoreSyncRoute *> *_syncRoutesByAction;
	BOOL _needsToProcessSyncRecords;

	OCSyncAnchor _latestSyncAnchor;

	__weak id <OCCoreDelegate> _delegate;
}

@property(readonly) OCBookmark *bookmark; //!< Bookmark identifying the server this core manages.

@property(readonly) OCVault *vault; //!< Vault managing storage and database access for this core.
@property(readonly) OCConnection *connection; //!< Connection used by the core to make requests to the server.
@property(readonly) OCReachabilityMonitor *reachabilityMonitor; //!< ReachabilityMonitor observing the reachability of the bookmark.url.host.

@property(readonly,nonatomic) OCCoreState state;

@property(readonly,strong) OCEventHandlerIdentifier eventHandlerIdentifier;

@property(weak) id <OCCoreDelegate> delegate;

@property(readonly, strong) OCSyncAnchor latestSyncAnchor;

#pragma mark - Init
- (instancetype)init NS_UNAVAILABLE; //!< Always returns nil. Please use the designated initializer instead.
- (instancetype)initWithBookmark:(OCBookmark *)bookmark NS_DESIGNATED_INITIALIZER;

- (void)unregisterEventHandler; //!< Unregisters the core as an event handler. Should only be called after the core has been stopped and called the completionHandler. This call is needed to clear the last reference to the core and remove it from memory.

#pragma mark - Start / Stop Core
- (void)startWithCompletionHandler:(OCCompletionHandler)completionHandler;
- (void)stopWithCompletionHandler:(OCCompletionHandler)completionHandler;

#pragma mark - Query
- (void)startQuery:(OCQuery *)query;	//!< Starts a query
- (void)reloadQuery:(OCQuery *)query;	//!< Asks the core to reach out to the server and request a new list of items for the query
- (void)stopQuery:(OCQuery *)query;	//!< Stops a query

#pragma mark - Commands
- (NSProgress *)createEmptyFileNamed:(NSString *)newFileName atPath:(OCPath)path options:(NSDictionary *)options resultHandler:(OCCoreActionResultHandler)resultHandler;

- (NSProgress *)uploadFileAtURL:(NSURL *)url to:(OCPath)newParentDirectoryPath resultHandler:(OCCoreActionResultHandler)resultHandler;

- (NSProgress *)retrieveThumbnailFor:(OCItem *)item maximumSize:(CGSize)size scale:(CGFloat)scale retrieveHandler:(OCCoreThumbnailRetrieveHandler)retrieveHandler;
+ (BOOL)thumbnailSupportedForMIMEType:(NSString *)mimeType;

- (NSProgress *)shareItem:(OCItem *)item options:(OCShareOptions)options resultHandler:(OCCoreActionResultHandler)resultHandler;

- (NSProgress *)requestAvailableOfflineCapabilityForItem:(OCItem *)item completionHandler:(OCCoreCompletionHandler)completionHandler;
- (NSProgress *)terminateAvailableOfflineCapabilityForItem:(OCItem *)item completionHandler:(OCCoreCompletionHandler)completionHandler;

@end

@interface OCCore (Download)
- (NSProgress *)downloadItem:(OCItem *)item options:(NSDictionary *)options resultHandler:(OCCoreDownloadResultHandler)resultHandler;
@end

@interface OCCore (FileManagement)
- (void)performFile:(OCFile *)file retainerOperation:(void(^)(OCCore *core, OCFile *file, OCRetainerCollection *retainers))retainerOperation;
//
//- (BOOL)retainFile:(OCFile *)file with:(OCRetainer *)retainer;
//- (BOOL)releaseFile:(OCFile *)file from:(OCRetainer *)retainer;
//
//- (OCRetainer *)retainFile:(OCFile *)file withExplicitIdentifier:(NSString *)explicitIdentifier;
//- (BOOL)releaseFile:(OCFile *)file fromExplicitIdentifier:(NSString *)explicitIdentifier;
@end

@interface OCCore (CommandCreateFolder)
- (NSProgress *)createFolder:(NSString *)folderName inside:(OCItem *)parentItem options:(NSDictionary *)options resultHandler:(OCCoreActionResultHandler)resultHandler;
@end

@interface OCCore (CommandDelete)
- (NSProgress *)deleteItem:(OCItem *)item requireMatch:(BOOL)requireMatch resultHandler:(OCCoreActionResultHandler)resultHandler;
@end

@interface OCCore (CommandCopyMove)
- (NSProgress *)copyItem:(OCItem *)item to:(OCItem *)parentItem withName:(NSString *)name options:(NSDictionary *)options resultHandler:(OCCoreActionResultHandler)resultHandler;
- (NSProgress *)moveItem:(OCItem *)item to:(OCItem *)parentItem withName:(NSString *)name options:(NSDictionary *)options resultHandler:(OCCoreActionResultHandler)resultHandler;
- (NSProgress *)renameItem:(OCItem *)item to:(NSString *)newFileName options:(NSDictionary *)options resultHandler:(OCCoreActionResultHandler)resultHandler;
@end

extern OCClassSettingsKey OCCoreThumbnailAvailableForMIMETypePrefixes;

extern OCDatabaseCounterIdentifier OCCoreSyncAnchorCounter;
extern OCDatabaseCounterIdentifier OCCoreSyncJournalCounter;
