//
//  OCVaultLocation.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 26.04.22.
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

#import "OCVaultLocation.h"
#import "OCVFSCore.h"

@implementation OCVaultLocation

#pragma mark - VFS item ID
- (instancetype)initWithVFSItemID:(OCVFSItemID)vfsItemID
{
	if ((self = [super init]) != nil)
	{
		BOOL recognized = NO;

		NSArray<NSString *> *segments = [vfsItemID componentsSeparatedByString:@"\\"];

		if (segments.count > 0)
		{
			if ([segments[0] isEqual:@"V"])
			{
				// Virtual items: V\[bookmarkUUID]\[driveID] or V\[vfsNodeID]
				if (segments.count > 1)
				{
					if (segments.count > 2)
					{
						OCBookmarkUUIDString uuidString = segments[1];
						self.bookmarkUUID = [[NSUUID alloc] initWithUUIDString:uuidString];
						self.driveID = segments[2];
						self.isVirtual = YES;
						recognized = YES;
					}
					else
					{
						self.vfsNodeID = segments[1];
						self.isVirtual = YES;
						recognized = YES;
					}
				}
			}

			if ([segments[0] isEqual:@"I"])
			{
				// Real items: 	 I\[bookmarkUUID]\[driveID]\[localID][\[fileName]]
				if (segments.count > 3)
				{
					OCBookmarkUUIDString uuidString = segments[1];
					self.bookmarkUUID = [[NSUUID alloc] initWithUUIDString:uuidString];
					self.driveID = segments[2];
					self.localID = segments[3];
					recognized = YES;
				}
				else if (segments.count > 2)
				{
					OCBookmarkUUIDString uuidString = segments[1];
					self.bookmarkUUID = [[NSUUID alloc] initWithUUIDString:uuidString];
					self.localID = segments[2];
					recognized = YES;
				}
			}
		}

		if (!recognized)
		{
			return (nil);
		}
	}

	return (self);
}

- (OCVFSItemID)vfsItemID
{
	if (_vfsNodeID != nil)
	{
		if ((_bookmarkUUID != nil) && (_driveID != nil))
		{
			return ([[NSString alloc] initWithFormat:@"V\\%@\\%@", _bookmarkUUID, _driveID]);
		}
		else
		{
			return ([[NSString alloc] initWithFormat:@"V\\%@", _vfsNodeID]);
		}
	}
	else if ((_bookmarkUUID != nil) && (_localID != nil))
	{
		return ([OCVFSCore composeVFSItemIDForOCItemWithBookmarkUUID:_bookmarkUUID.UUIDString driveID:_driveID localID:_localID]);
	}

	return (nil);
}

@end
