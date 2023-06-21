//
//  OCStatistic.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 14.10.22.
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

#import "OCStatistic.h"

@implementation OCStatistic

- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_uuid = NSUUID.UUID.UUIDString;
	}

	return (self);
}

- (NSString *)localizedSize
{
	if (_sizeInBytes != nil)
	{
		return ([NSByteCountFormatter stringFromByteCount:_sizeInBytes.longLongValue countStyle:NSByteCountFormatterCountStyleFile]);
	}

	return (nil);
}

- (OCDataItemType)dataItemType
{
	return (OCDataItemTypeStatistic);
}

- (OCDataItemReference)dataItemReference
{
	return (_uuid);
}

- (OCDataItemVersion)dataItemVersion
{
	return (@((_fileCount.unsignedIntegerValue * _folderCount.unsignedIntegerValue) + _fileCount.unsignedIntegerValue - _folderCount.unsignedIntegerValue + _sizeInBytes.unsignedIntegerValue));
}

@end
