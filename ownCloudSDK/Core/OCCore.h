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

@class OCCore;
@class OCItem;

typedef void(^OCCoreActionResultHandler)(NSError *error, OCCore *core, OCItem *item);
typedef void(^OCCoreActionShareHandler)(NSError *error, OCCore *core, OCItem *item, OCShare *share);
typedef void(^OCCoreCompletionHandler)(NSError *error);

@protocol OCCoreDelegate <NSObject>

- (void)core:(OCCore *)core handleError:(NSError *)error;

@end

@interface OCCore : NSObject <OCEventHandler>
{
	OCBookmark *_bookmark;

	OCVault *_vault;
	OCConnection *_connection;
	
	__weak id <OCCoreDelegate> _delegate;
}

@property(readonly) OCBookmark *bookmark; //!< Bookmark identifying the server this core manages.

@property(readonly) OCVault *vault; //!< Vault managing storage and database access for this core.
@property(readonly) OCConnection *connection; //!< Connection used by the core to make requests to the server.

@property(weak) id <OCCoreDelegate> delegate;

#pragma mark - Init
- (instancetype)init NS_UNAVAILABLE; //!< Always returns nil. Please use the designated initializer instead.
- (instancetype)initWithBookmark:(OCBookmark *)bookmark NS_DESIGNATED_INITIALIZER;

#pragma mark - Query
- (void)startQuery:(OCQuery *)query;
- (void)stopQuery:(OCQuery *)query;

#pragma mark - Commands
- (NSProgress *)createFolderNamed:(NSString *)newFolderName atPath:(OCPath)path options:(NSDictionary *)options resultHandler:(OCCoreActionResultHandler)resultHandler;
- (NSProgress *)createEmptyFileNamed:(NSString *)newFileName atPath:(OCPath)path options:(NSDictionary *)options resultHandler:(OCCoreActionResultHandler)resultHandler;

- (NSProgress *)renameItem:(OCItem *)item to:(NSString *)newFileName resultHandler:(OCCoreActionResultHandler)resultHandler;
- (NSProgress *)moveItem:(OCItem *)item to:(OCPath)newParentDirectoryPath resultHandler:(OCCoreActionResultHandler)resultHandler;
- (NSProgress *)copyItem:(OCItem *)item to:(OCPath)newParentDirectoryPath options:(NSDictionary *)options resultHandler:(OCCoreActionResultHandler)resultHandler;

- (NSProgress *)deleteItem:(OCItem *)item resultHandler:(OCCoreActionResultHandler)resultHandler;

- (NSProgress *)uploadFileAtURL:(NSURL *)url to:(OCPath)newParentDirectoryPath resultHandler:(OCCoreActionResultHandler)resultHandler;
- (NSProgress *)downloadItem:(OCItem *)item to:(OCPath)newParentDirectoryPath resultHandler:(OCCoreActionResultHandler)resultHandler;

- (NSProgress *)retrieveThumbnailFor:(OCItem *)item resultHandler:(OCCoreActionResultHandler)resultHandler;

- (NSProgress *)shareItem:(OCItem *)item options:(OCShareOptions)options resultHandler:(OCCoreActionShareHandler)resultHandler;

- (NSProgress *)requestAvailableOfflineCapabilityForItem:(OCItem *)item completionHandler:(OCCoreCompletionHandler)completionHandler;
- (NSProgress *)terminateAvailableOfflineCapabilityForItem:(OCItem *)item completionHandler:(OCCoreCompletionHandler)completionHandler;

- (NSProgress *)synchronizeWithServer;

@end
