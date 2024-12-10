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
#import "OCResourceRequest.h"
#import "OCResourceRequestImage.h"

@implementation OCResourceImage

- (instancetype)initWithRequest:(OCResourceRequest *)request
{
	if ((self = [super initWithRequest:request]) != nil)
	{
		self.maxPixelSize = request.maxPixelSize;
		self.fillMode = OCTypedCast(request, OCResourceRequestImage).fillMode;
	}

	return (self);
}

- (id)_createImageWithClass:(Class)imageClass
{
	OCImage *image = [imageClass new];

	image.mimeType = self.mimeType;
	image.maxPixelSize = self.maxPixelSize;
	image.fillMode = self.fillMode;

	image.url = self.url;
	if (self.url == nil)
	{
		image.data = self.data;
	}

	return (image);
}

- (OCImage *)image
{
	if (_image == nil)
	{
		if ([self.type isEqual:OCResourceTypeAvatar]) 		{ return ([self avatar]);	}
		if ([self.type isEqual:OCResourceTypeItemThumbnail]) 	{ return ([self thumbnail]);	}

		_image = [self _createImageWithClass:OCImage.class];
	}

	return (_image);
}

- (OCItemThumbnail *)thumbnail
{
	if (_image == nil)
	{
		OCItemThumbnail *thumbnail = [self _createImageWithClass:OCItemThumbnail.class];

		thumbnail.itemVersionIdentifier = [[OCItemVersionIdentifier alloc] initWithFileID:self.identifier eTag:self.version];
		thumbnail.specID = self.structureDescription;

		_image = thumbnail;

		return (thumbnail);
	}

	return (OCTypedCast(_image, OCItemThumbnail));
}

- (OCAvatar *)avatar
{
	if (_image == nil)
	{
		OCAvatar *avatar = [self _createImageWithClass:OCAvatar.class];

		avatar.uniqueUserIdentifier = self.identifier;
		avatar.eTag = self.version;

		avatar.timestamp = self.timestamp;

		_image = avatar;

		return (avatar);
	}

	return (OCTypedCast(_image, OCAvatar));
}

#pragma mark - View provider
- (void)provideViewForSize:(CGSize)size inContext:(OCViewProviderContext *)context completion:(void (^)(UIView * _Nullable))completionHandler
{
	if ([self.image conformsToProtocol:@protocol(OCViewProvider)])
	{
		[(id<OCViewProvider>)self.image provideViewForSize:size inContext:context completion:completionHandler];
		
		return;
	}

	completionHandler(nil);
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
	[coder encodeInteger:_fillMode forKey:@"fillMode"];
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)coder
{
	if ((self = [super initWithCoder:coder]) != nil)
	{
		_maxPixelSize = [coder decodeCGSizeForKey:@"maxPixelSize"];
		_fillMode = [coder decodeIntegerForKey:@"fillMode"];
	}

	return (self);
}

@end
