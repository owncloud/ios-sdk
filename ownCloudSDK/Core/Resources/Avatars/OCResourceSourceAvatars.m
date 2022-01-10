//
//  OCResourceSourceAvatars.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 27.02.21.
//  Copyright © 2021 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2021, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCResourceSourceAvatars.h"

@implementation OCResourceSourceAvatars

- (OCResourceType)type
{
	return (OCResourceTypeAvatar);
}

- (OCResourceSourceIdentifier)identifier
{
	return (OCResourceSourceIdentifierAvatar);
}

@end

OCResourceSourceIdentifier OCResourceSourceIdentifierAvatar = @"core.avatar";
