//
//  OCVaultDriveList.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 16.05.22.
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

#import "OCVaultDriveList.h"
#import "OCEvent.h"

@implementation OCVaultDriveList

- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_subscribedDriveIDs = [NSMutableSet new];
		_drives = @[ ];
	}

	return (self);
}

+ (BOOL)supportsSecureCoding
{
	return (YES);
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)decoder
{
	if ((self = [super init]) != nil)
	{
		_drives = [decoder decodeObjectOfClasses:OCEvent.safeClasses forKey:@"drives"];
		_subscribedDriveIDs = [decoder decodeObjectOfClasses:OCEvent.safeClasses forKey:@"subscribedDriveIDs"];

		_detachedDrives = [decoder decodeObjectOfClasses:OCEvent.safeClasses forKey:@"detachedDrives"];
	}

	return (self);
}

- (void)encodeWithCoder:(nonnull NSCoder *)coder
{
	[coder encodeObject:_drives forKey:@"drives"];
	[coder encodeObject:_subscribedDriveIDs forKey:@"subscribedDriveIDs"];

	[coder encodeObject:_detachedDrives forKey:@"detachedDrives"];
}

@end
