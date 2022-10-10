//
//  OCVFSCore.m
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

#import "OCVFSCore.h"
#import "OCVault.h"
#import "OCVaultLocation.h"
#import "OCBookmarkManager.h"
#import "OCCoreManager.h"
#import "NSArray+OCFiltering.h"
#import "NSString+OCPath.h"
#import "OCMacros.h"
#import "OCCore+FileProvider.h"

@interface OCVFSCore ()
{
	NSMutableArray<OCVFSNode *> *_nodes;
	NSMapTable<OCVFSNodeID, OCVFSNode *> *_nodesByID;
}
@end

@implementation OCVFSCore

- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_nodes = [NSMutableArray new];
		_nodesByID = [NSMapTable weakToWeakObjectsMapTable];
	}

	return (self);
}

- (void)addNodes:(NSArray<OCVFSNode *> *)nodes
{
	@synchronized(_nodes)
	{
		[_nodes addObjectsFromArray:nodes];

		for (OCVFSNode *node in nodes)
		{
			node.vfsCore = self;
			[_nodesByID setObject:node forKey:node.identifier];
		}
	}

	[self _recreateVirtualFillNodes];
}

- (void)removeNodes:(NSArray<OCVFSNode *> *)nodes
{
	@synchronized(_nodes)
	{
		for (OCVFSNode *node in nodes)
		{
			[_nodesByID removeObjectForKey:node.identifier];
			node.vfsCore = nil;
		}
		[_nodes removeObjectsInArray:nodes];
	}
	[self _recreateVirtualFillNodes];
}

- (void)setNodes:(NSArray<OCVFSNode *> *)nodes
{
	@synchronized(_nodes)
	{
		[self removeNodes:_nodes];
	}
	[self addNodes:nodes];
}

- (void)_recreateVirtualFillNodes
{
	// Create virtual "fill" nodes to fill the gaps between
	// virtual paths
}

- (nullable NSURL *)urlForItemIdentifier:(OCVFSItemID)identifier
{
	OCVaultLocation *location;

	if ((location = [[OCVaultLocation alloc] initWithVFSItemID:identifier]) != nil)
	{
		if (!location.isVirtual)
		{
			OCItem *item;

			if ((item = (OCItem *)[self itemForIdentifier:identifier error:NULL]) != nil)
			{
				if (item.name != nil)
				{
					location.additionalPathElements = @[ item.name ];
				}
			}
		}

		return ([OCVault urlForLocation:location]);
	}

	return (nil);
}

- (nullable OCVFSItemID)itemIdentifierForURL:(NSURL *)url
{
	return ([OCVault locationForURL:url].vfsItemID);
}

- (OCCore *)_acquireCoreForVaultLocation:(OCVaultLocation *)location error:(NSError **)outError
{
	__block OCCore *returnCore = nil;
	__block NSError *returnError = nil;

	if (location.bookmarkUUID != nil)
	{
		OCBookmark *bookmark;

		if ((bookmark = [OCBookmarkManager.sharedBookmarkManager bookmarkForUUID:location.bookmarkUUID]) != nil)
		{
			if (_delegate != nil)
			{
				OCSyncExec(acquireCore, {
					[_delegate acquireCoreForBookmark:bookmark completionHandler:^(NSError * _Nullable error, OCCore * _Nullable core) {
						returnCore = core;
						returnError = error;

						OCSyncExecDone(acquireCore);
					}];
				});
			}
		}
	}

	if (outError != NULL)
	{
		*outError = returnError;
	}

	return (returnCore);
}

- (void)_relinquishCore:(OCCore *)core
{
	if (_delegate != nil)
	{
		[_delegate relinquishCoreForBookmark:core.bookmark completionHandler:^(NSError * _Nullable error) {
			if (error != nil)
			{
				OCLogError(@"Error returning core: %@", error);
			}
		}];
	}
}

- (nullable id<OCVFSItem>)itemForIdentifier:(OCVFSItemID)identifier error:(NSError * _Nullable * _Nullable)outError
{
	OCVaultLocation *location;
	__block NSError *returnError = nil;
	__block id<OCVFSItem> item = nil;

	if ([identifier isEqual:OCVFSItemIDRoot])
	{
		return (self.rootNode);
	}

	if ((location = [[OCVaultLocation alloc] initWithVFSItemID:identifier]) != nil)
	{
		if (location.vfsNodeID != nil)
		{
			// Virtual item
			@synchronized(_nodes)
			{
				item = (id<OCVFSItem>)[_nodesByID objectForKey:location.vfsNodeID];
			}
		}
		else if (location.isVirtual)
		{
			// Virtual item not identified by node ID
			if ((location.driveID != nil) && (location.bookmarkUUID != nil))
			{
				item = (id<OCVFSItem>)[self driveRootNodeForLocation:[[OCLocation alloc] initWithBookmarkUUID:location.bookmarkUUID driveID:location.driveID path:@"/"]];
			}
		}
		else
		{
			// Other item
			if ((location.bookmarkUUID != nil) && (location.localID != nil))
			{
				NSError *coreError = nil;
				OCCore *core = [self _acquireCoreForVaultLocation:location error:&coreError];

				if (core != nil)
				{
					if (coreError != nil)
					{
						returnError = coreError;
					}
					else
					{
						OCSyncExec(itemRetrieval, {
							[core retrieveItemFromDatabaseForLocalID:location.localID completionHandler:^(NSError *error, OCSyncAnchor syncAnchor, OCItem *itemFromDatabase) {
								itemFromDatabase.bookmarkUUID = location.bookmarkUUID.UUIDString;
								item = (id<OCVFSItem>)itemFromDatabase;
								returnError = error;

								OCSyncExecDone(itemRetrieval);
							}];
						});

						[self _relinquishCore:core];
					}

				}
			}
		}
	}

	if (outError != NULL)
	{
		*outError = returnError;
	}

	return (item);
}

- (nullable OCItem *)itemForLocation:(OCLocation *)location error:(NSError * _Nullable * _Nullable)outError
{
	NSError *returnError = nil;
	OCItem *item = nil;

	if (location != nil)
	{
		// Other item
		if ((location.bookmarkUUID != nil) && (location.path != nil))
		{
			NSError *coreError = nil;
			OCVaultLocation *vaultLocation = [[OCVaultLocation alloc] init];
			OCCore *core;

			vaultLocation.bookmarkUUID = location.bookmarkUUID;
			vaultLocation.driveID = location.driveID;

			if ((core = [self _acquireCoreForVaultLocation:vaultLocation error:&coreError]) != nil)
			{
				if (coreError != nil)
				{
					returnError = coreError;
				}
				else
				{
					item = [core cachedItemAtLocation:location error:&returnError];

					[self _relinquishCore:core];
				}
			}
		}
	}

	if (outError != NULL)
	{
		*outError = returnError;
	}

	return (item);
}

- (void)provideContentForContainerItemID:(nullable OCVFSItemID)containerItemID changesFromSyncAnchor:(nullable OCSyncAnchor)sinceSyncAnchor completionHandler:(void(^)(NSError * _Nullable error, OCVFSContent * _Nullable content))completionHandler
{
	OCVFSNode *containerNode = nil;
	OCQuery *query = nil;
	NSArray<OCVFSNode *> *vfsChildNodes = nil;
	OCPath vfsContainerPath = nil;
	OCLocation *queryLocation = nil;

	if ((containerItemID == nil) || [containerItemID isEqual:OCVFSItemIDRoot])
	{
		vfsContainerPath = @"/";
		containerNode = self.rootNode;
	}
	else
	{
		OCVaultLocation *vaultLocation;

		if ((vaultLocation = [[OCVaultLocation alloc] initWithVFSItemID:containerItemID]) != nil)
		{
			if (vaultLocation.isVirtual)
			{
				if (vaultLocation.vfsNodeID != nil)
				{
					containerNode = [self nodeForID:vaultLocation.vfsNodeID];
				}
				else if ((vaultLocation.bookmarkUUID != nil) && (vaultLocation.driveID != nil))
				{
					containerNode = [self driveRootNodeForLocation:[[OCLocation alloc] initWithBookmarkUUID:vaultLocation.bookmarkUUID driveID:vaultLocation.driveID path:@"/"]];
				}

				if (containerNode != nil)
				{
					queryLocation = containerNode.location;
					vfsContainerPath = containerNode.path;
				}
			}
			else
			{
				NSError *error = nil;
				OCItem *item = (OCItem *)[self itemForIdentifier:containerItemID error:&error];

				if ([item isKindOfClass:OCItem.class])
				{
					queryLocation = [[OCLocation alloc] init];

					queryLocation.bookmarkUUID = vaultLocation.bookmarkUUID;
					queryLocation.driveID = vaultLocation.driveID;
					queryLocation.path = item.path;
				}
			}
		}
	}

	if (vfsContainerPath != nil)
	{
		vfsChildNodes = [self childNodesOf:vfsContainerPath];
	}

	if (queryLocation != nil)
	{
		if (sinceSyncAnchor != nil)
		{
			query = [OCQuery queryForChangesSinceSyncAnchor:sinceSyncAnchor];
		}
		else
		{
			query = [OCQuery queryForLocation:queryLocation];
		}

		OCBookmarkUUID bookmarkUUID;
		OCBookmark *bookmark = nil;

		if ((bookmarkUUID = queryLocation.bookmarkUUID) != nil)
		{
			bookmark = [OCBookmarkManager.sharedBookmarkManager bookmarkForUUID:bookmarkUUID];
		}

		if (bookmark != nil)
		{
			[OCCoreManager.sharedCoreManager requestCoreForBookmark:bookmark setup:nil completionHandler:^(OCCore * _Nullable core, NSError * _Nullable error) {
				if (error != nil)
				{
					completionHandler(error, nil);
				}
				else
				{
					OCVFSContent *content = [[OCVFSContent alloc] init];

					content.bookmark = bookmark;
					content.core = core;

					content.vfsChildNodes = vfsChildNodes;
					content.isSnapshot = (vfsChildNodes.count > 0);
					content.containerNode = containerNode;
					content.query = query;

					completionHandler(nil, content);
				}
			}];

			return;
		}
	}

	OCVFSContent *content = [[OCVFSContent alloc] init];

	content.vfsChildNodes = vfsChildNodes;
	content.isSnapshot = (vfsChildNodes.count > 0);
	content.containerNode = containerNode;
	content.query = query;

	completionHandler(nil, content);
}

- (OCVFSNode *)rootNode
{
	return ([self nodeAtPath:@"/"]);
}

- (OCVFSNode *)driveRootNodeForLocation:(OCLocation *)location
{
	if (location == nil) { return (nil); }

	@synchronized(_nodes)
	{
		return ([_nodes firstObjectMatching:^BOOL(OCVFSNode * _Nonnull node) {
			return ([node.location.bookmarkUUID isEqual:location.bookmarkUUID] && OCNAIsEqual(node.location.driveID, location.driveID) && node.location.path.isRootPath);
		}]);
	}
}

- (OCVFSNode *)nodeAtPath:(OCPath)vfsPath
{
	if (vfsPath == nil) { return (nil); }

	@synchronized(_nodes)
	{
		return ([_nodes firstObjectMatching:^BOOL(OCVFSNode * _Nonnull node) {
			return ([node.path isEqual:vfsPath]);
		}]);
	}
}

- (NSArray<OCVFSNode *> *)childNodesOf:(OCPath)path
{
	@synchronized(_nodes)
	{
		return ([_nodes filteredArrayUsingBlock:^BOOL(OCVFSNode * _Nonnull node, BOOL * _Nonnull stop) {
			return ([node.path.parentPath isEqual:path] && ![node.path isEqual:path]);
		}]);
	}
}

- (nullable OCVFSNode *)nodeForID:(OCVFSNodeID)nodeID
{
	@synchronized(_nodes)
	{
		return ([_nodesByID objectForKey:nodeID]);
	}
}

+ (OCVFSItemID)composeVFSItemIDForOCItemWithBookmarkUUID:(OCBookmarkUUIDString)bookmarkUUIDString driveID:(OCDriveID)driveID localID:(OCLocalID)localID
{
	if ((bookmarkUUIDString == nil) || (localID == nil))
	{
		return (nil);
	}

	if (driveID != nil)
	{
		return ([[NSString alloc] initWithFormat:@"I\\%@\\%@\\%@", bookmarkUUIDString, driveID, localID]);
	}

	return ([[NSString alloc] initWithFormat:@"I\\%@\\%@", bookmarkUUIDString, localID]);
}

@end

OCVFSItemID OCVFSItemIDRoot = @"R";
