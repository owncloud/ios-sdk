//
//  OCVFSNode.m
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

#import "OCVFSNode.h"
#import "NSData+OCHash.h"
#import "NSString+OCPath.h"
#import "OCVFSCore.h"
#import "OCLocation.h"
#import "OCFeatureAvailability.h"

@interface OCVFSNode ()
{
	OCVFSNodeID _identifier;
	OCVFSItemID _itemID;
}
@end

@implementation OCVFSNode

- (OCVFSNode *)parentNode
{
	if (_path.isRootPath)
	{
		return (nil);
	}

	return ([_vfsCore nodeAtPath:_path.parentPath]);
}

- (void)setVfsCore:(OCVFSCore *)vfsCore
{
	_vfsCore = vfsCore;

//	[self locationItem];
}

- (OCVFSNodeID)identifier
{
	if (_identifier == nil)
	{
		NSString *hashBasis = ((_name != nil) ? [_path stringByAppendingPathComponent:_name] : _path);

		if (hashBasis != nil)
		{
			_identifier = [[[hashBasis dataUsingEncoding:NSUTF8StringEncoding] sha1Hash] asHexStringWithSeparator:nil];
		}
	}

	return (_identifier);
}

- (OCVFSItemID)itemID
{
	if (self.isRootNode)
	{
		return (OCVFSItemIDRoot);
	}

	if (_itemID == nil)
	{
		if ((_location != nil) && (_location.bookmarkUUID != nil) && (_location.driveID != nil) && (_location.path.isRootPath))
		{
			_itemID = [OCVFSNode rootFolderItemIDForBookmarkUUID:_location.bookmarkUUID.UUIDString driveID:_location.driveID];
		}
		else
		{
			_itemID = [@"V\\" stringByAppendingString:self.identifier];
		}
	}

	return (_itemID);
}

- (OCItem *)locationItem
{
	if ((_location != nil) && (_locationItem == nil))
	{
		_locationItem = [_vfsCore itemForLocation:_location error:NULL];
	}

	return (_locationItem);
}

- (void)setPath:(OCPath)path
{
	_path = path;

	_identifier = nil;
	_itemID = nil;
}

- (void)setName:(NSString *)name
{
	_name = name;
	_identifier = nil;
	_itemID = nil;
}

- (BOOL)isRootNode
{
	return ([_path isEqual:@"/"]);
}

+ (OCVFSNode *)virtualFolderAtPath:(OCPath)path location:(nullable OCLocation *)location
{
	OCVFSNode *node = [self new];

	node.type = (location != nil) ? OCVFSNodeTypeLocation : OCVFSNodeTypeVirtualFolder;

	node.path = path;
	node.name = path.lastPathComponent;

	node.location = location;

	return (node);
}

+ (OCVFSNode *)virtualFolderInPath:(OCPath)path withName:(NSString *)name location:(OCLocation *)location;
{
	OCVFSNode *node = [self new];

	node.type = (location != nil) ? OCVFSNodeTypeLocation : OCVFSNodeTypeVirtualFolder;

	node.path = [path stringByAppendingPathComponent:name].normalizedDirectoryPath;
	node.name = name;

	node.location = location;

	return (node);
}

+ (OCVFSItemID)rootFolderItemIDForBookmarkUUID:(OCBookmarkUUIDString)bookmarkUUIDString driveID:(nullable OCDriveID)driveID
{
	if (driveID != nil)
	{
		return ([[NSString alloc] initWithFormat:@"V\\%@\\%@", bookmarkUUIDString, driveID]);
	}

	return (OCVFSItemIDRoot);
}

#pragma mark - OCVFSItem
- (OCVFSItemID)vfsItemID
{
	OCVFSItemID vfsItemID = self.itemID;

	if ([vfsItemID isEqual:OCVFSItemIDRoot])
	{
		#if OC_FEATURE_AVAILABLE_FILEPROVIDER
		return (NSFileProviderRootContainerItemIdentifier);
		#else
		return (OCVFSItemIDRoot);
		#endif
	}

	return (vfsItemID);
}

- (OCVFSItemID)vfsParentItemID
{
	return (self.parentNode.vfsItemID);
}

- (NSString *)vfsItemName
{
	return (self.name);
}

@end
