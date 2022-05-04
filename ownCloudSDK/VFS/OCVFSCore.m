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
#import "OCBookmarkManager.h"
#import "OCCoreManager.h"

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
	[_nodes addObjectsFromArray:nodes];

	for (OCVFSNode *node in nodes)
	{
		[_nodesByID setObject:node forKey:node.identifier];
	}

	[self _recreateVirtualFillNodes];
}

- (void)removeNodes:(NSArray<OCVFSNode *> *)nodes
{
	[_nodes removeObjectsInArray:nodes];
	[self _recreateVirtualFillNodes];
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
		return ([OCVault urlForLocation:location]);
	}

	return (nil);
}

- (nullable OCVFSItemID)itemIdentifierForURL:(NSURL *)url
{
	return ([OCVault locationForURL:url].vfsItemID);
}

- (nullable id<OCVFSItem>)itemForIdentifier:(OCVFSItemID)identifier error:(NSError * _Nullable * _Nullable)outError
{
	OCVaultLocation *location;

	if ((location = [[OCVaultLocation alloc] initWithVFSItemID:identifier]) != nil)
	{

	}

	return (nil);
}

- (void)provideContentForContainerItemID:(nullable OCVFSItemID)containerItemID changesFromSyncAnchor:(nullable OCSyncAnchor)sinceSyncAnchor completionHandler:(void(^)(NSError * _Nullable error, OCVFSContent * _Nullable content))completionHandler
{
	OCVFSNode *containerNode = nil;
	OCQuery *query = nil;
	NSArray<OCVFSNode *> *vfsChildNodes = nil;
	OCLocation *vfsLocation = nil;

	if (containerItemID == nil)
	{
		vfsLocation = [OCLocation withVFSPath:@"/"];
		containerNode = [self retrieveNodeAt:vfsLocation];
	}
	else
	{
		OCVaultLocation *vaultLocation;

		if ((vaultLocation = [[OCVaultLocation alloc] initWithVFSItemID:containerItemID]) != nil)
		{
			if (vaultLocation.vfsNodeID != nil)
			{
				containerNode = [self nodeForID:vaultLocation.vfsNodeID];

				vfsLocation = [OCLocation withVFSPath:containerNode.path];
			}
		}
	}

	if (vfsLocation != nil)
	{
		vfsChildNodes = [self childNodesAt:vfsLocation];
	}

	if (containerNode.location != nil)
	{
		if (sinceSyncAnchor != nil)
		{
			query = [OCQuery queryForChangesSinceSyncAnchor:sinceSyncAnchor];
		}
		else
		{
			query = [OCQuery queryForLocation:containerNode.location];
		}

		OCBookmarkUUID bookmarkUUID;
		OCBookmark *bookmark = nil;

		if ((bookmarkUUID = containerNode.location.bookmarkUUID) != nil)
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
					content.query = query;

					completionHandler(nil, content);
				}
			}];

			return;
		}
	}

	OCVFSContent *content = [[OCVFSContent alloc] init];

	content.vfsChildNodes = vfsChildNodes;
	content.query = query;

	completionHandler(nil, content);
}

- (OCVFSNode *)retrieveNodeAt:(OCLocation *)location
{
	if (location.bookmarkUUID == nil)
	{
		for (OCVFSNode *node in _nodes)
		{
			if ([node.path isEqual:location.path])
			{
				return (node);
			}
		}
	}

	return (nil);
}

- (NSArray<OCVFSNode *> *)childNodesAt:(OCLocation *)location
{
	OCVFSNode *closestNode = nil;
	return (nil);
}

- (nullable OCVFSNode *)nodeForID:(OCVFSNodeID)nodeID
{
	return ([_nodesByID objectForKey:nodeID]);
}

@end

OCVFSItemID OCVFSItemIDRoot = @"_root_";
