//
//  OCAppProviderApp.m
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

#import "OCAppProviderApp.h"
#import "OCAppProviderFileType.h"
#import "OCMacros.h"
#import "OCResourceRequestURLItem.h"

@interface OCAppProviderApp ()
{
	OCResourceRequest *_iconResourceRequest;
}
@end

@implementation OCAppProviderApp

- (void)addSupportedType:(OCAppProviderFileType *)type
{
	if (_supportedTypes == nil)
	{
		_supportedTypes = [NSMutableArray new];
	}

	NSMutableArray<OCAppProviderFileType *> *types = nil;

	if ((types = OCTypedCast(_supportedTypes, NSMutableArray)) == nil)
	{
		NSMutableArray<OCAppProviderFileType *> *mutableTypes = (_supportedTypes != nil) ? [[NSMutableArray alloc] initWithArray:_supportedTypes] : [NSMutableArray new];

		types = mutableTypes;
		_supportedTypes = mutableTypes;
	}

	[types addObject:type];
}

- (BOOL)supportsItem:(OCItem *)item
{
	OCMIMEType itemMimeType = item.mimeType.lowercaseString;
	OCFileExtension itemFileExtension = item.name.pathExtension.lowercaseString;

	if (itemFileExtension.length == 0)
	{
		itemFileExtension = nil;
	}

	for (OCAppProviderFileType *fileType in _supportedTypes)
	{
		if ([fileType.mimeType.lowercaseString isEqual:itemMimeType] ||
		    [fileType.extension.lowercaseString isEqual:itemFileExtension])
		{
			return (YES);
		}
	}

	return (NO);
}

- (OCResourceRequest *)iconResourceRequest
{
	if ((_iconResourceRequest == nil) && (_iconURL != nil))
	{
		_iconResourceRequest = [OCResourceRequestURLItem requestURLItem:_iconURL identifier:nil version:OCResourceRequestURLItem.daySpecificVersion structureDescription:@"icon" waitForConnectivity:YES changeHandler:nil];
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
	return ([NSString stringWithFormat:@"<%@: %p%@%@%@>", NSStringFromClass(self.class), self,
		OCExpandVar(name),
		OCExpandVar(iconURL),
		OCExpandVar(supportedTypes)
	]);
}

@end

OCAppProviderViewMode OCAppProviderViewModeView = @"view";
OCAppProviderViewMode OCAppProviderViewModeRead = @"read";
OCAppProviderViewMode OCAppProviderViewModeWrite = @"write";
