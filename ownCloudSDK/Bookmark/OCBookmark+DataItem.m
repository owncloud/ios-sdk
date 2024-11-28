//
//  OCBookmark+DataItem.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 15.11.22.
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

#import "OCBookmark+DataItem.h"
#import "OCDataTypes.h"
#import "OCResource.h"
#import "OCMacros.h"
#import "OCPlatform.h"

@implementation OCBookmark (DataItem)

- (OCDataItemType)dataItemType
{
	return (OCDataItemTypeBookmark);
}

- (OCDataItemReference)dataItemReference
{
	return (self.uuid.UUIDString);
}

- (OCDataItemVersion)dataItemVersion
{
	if (OCPlatform.current.memoryConfiguration != OCPlatformMemoryConfigurationMinimum)
	{
		OCResource *avatarResource = OCTypedCast(self.avatar, OCResource);
		NSString *avatarVersion = ((avatarResource != nil) ? avatarResource.version : @"");

		return ([NSString stringWithFormat:@"%@%@%@%@%@%@%@", self.name, self.url, self.originURL, self.userName, self.userDisplayName, self.authenticationDataID, avatarVersion]);
	}
	else
	{
		return ([NSString stringWithFormat:@"%@%@%@%@%@%@", self.name, self.url, self.originURL, self.userName, self.userDisplayName, self.authenticationDataID]);
	}
}

@end
