//
//  OCResourceImage.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 21.12.21.
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

#import "OCResourceImage.h"
#import "OCItemThumbnail.h"
#import "OCMacros.h"

@implementation OCResourceImage

- (OCImage *)image
{
	if (_image == nil)
	{
		_image = [OCImage new];

		_image.mimeType = self.mimeType;
		_image.maximumSizeInPixels = self.maxPixelSize;

		_image.url = self.url;
		if (self.url == nil)
		{
			_image.data = self.data;
		}
	}

	return (_image);
}

- (OCItemThumbnail *)thumbnail
{
	if (_image == nil)
	{
		OCItemThumbnail *thumbnail = [OCItemThumbnail new];

		thumbnail.mimeType = self.mimeType;
		thumbnail.maximumSizeInPixels = self.maxPixelSize;

		thumbnail.data = self.data;
		thumbnail.itemVersionIdentifier = [[OCItemVersionIdentifier alloc] initWithFileID:self.identifier eTag:self.version];
		thumbnail.specID = self.structureDescription;

		_image = thumbnail;

		return (thumbnail);
	}

	return (OCTypedCast(_image, OCItemThumbnail));
}

#pragma mark - Secure Coding
+ (BOOL)supportsSecureCoding
{
	return (YES);
}

- (void)encodeWithCoder:(nonnull NSCoder *)coder
{
	[super encodeWithCoder:coder];

	[coder encodeCGSize:_maxPixelSize forKey:@"maxPixelSize"];
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)coder
{
	if ((self = [super initWithCoder:coder]) != nil)
	{
		_maxPixelSize = [coder decodeCGSizeForKey:@"maxPixelSize"];
	}

	return (self);
}

@end
