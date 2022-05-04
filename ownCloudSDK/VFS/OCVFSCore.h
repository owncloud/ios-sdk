//
//  OCVFSCore.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 28.04.22.
//  Copyright © 2022 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2022, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import <Foundation/Foundation.h>
#import "OCVFSTypes.h"
#import "OCVFSNode.h"
#import "OCQuery.h"
#import "OCVFSContent.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCVFSCore : NSObject

#pragma mark - Public interface
- (void)addNodes:(NSArray<OCVFSNode *> *)nodes; //!< Adds nodes
- (void)removeNodes:(NSArray<OCVFSNode *> *)nodes; //!< Removes nodes

- (nullable NSURL *)urlForItemIdentifier:(OCVFSItemID)identifier;
- (nullable OCVFSItemID)itemIdentifierForURL:(NSURL *)url;
- (nullable id<OCVFSItem>)itemForIdentifier:(OCVFSItemID)identifier error:(NSError * _Nullable * _Nullable)outError;

- (void)provideContentForContainerItemID:(nullable OCVFSItemID)containerItemID changesFromSyncAnchor:(nullable OCSyncAnchor)sinceSyncAnchor completionHandler:(void(^)(NSError * _Nullable error, OCVFSContent * _Nullable content))completionHandler;

#pragma mark - Internals
//- (nullable OCVFSNode *)nodeForID:(OCVFSNodeID)nodeID;
//- (nullable OCVFSNode *)retrieveNodeAt:(OCLocation *)location; //!< returns the VFS node for the given location. For virtual paths, use just OCLocation.path, for server-based paths, use OCLocation.bookmarkUUID, OCLocation.driveID (where applicable) and OCLocation.path
//- (nullable NSArray<OCVFSNode *> *)retrieveChildNodesAt:(OCLocation *)location; //!< returns the VFS childnodes at the given location. For virtual paths, use just OCLocation.path, for server-based paths, use OCLocation.bookmarkUUID, OCLocation.driveID (where applicable) and OCLocation.path

@end

NS_ASSUME_NONNULL_END
