//
//  OCAppProviderFileType.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 05.09.22.
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

#import "OCAppProviderFileType.h"
#import "OCMacros.h"
#import "OCResourceRequestURLItem.h"

@interface OCAppProviderFileType ()
{
	OCResourceRequest *_iconResourceRequest;
}
@end

@implementation OCAppProviderFileType

- (OCResourceRequest *)iconResourceRequest
{
	if ((_iconResourceRequest == nil) && (_iconURL != nil))
	{
		_iconResourceRequest = [OCResourceRequestURLItem requestURLItem:_iconURL identifier:nil version:OCResourceRequestURLItem.weekSpecificVersion structureDescription:@"icon" waitForConnectivity:YES changeHandler:nil];
	}

	return (_iconResourceRequest);
}

- (UIImage *)icon
{
	return (OCTypedCast(self.iconResourceRequest.resource, OCResourceImage).image.image);
}

#pragma mark - Description
- (NSString *)description
{
	return ([NSString stringWithFormat:@"<%@: %p%@%@%@%@%@%@, allowCreation: %d>", NSStringFromClass(self.class), self,
		OCExpandVar(mimeType),
		OCExpandVar(extension),
		OCExpandVar(name),
		OCExpandVar(iconURL),
		OCExpandVar(typeDescription),
		OCExpandVar(defaultAppName),
		_allowCreation
	]);
}

@end
