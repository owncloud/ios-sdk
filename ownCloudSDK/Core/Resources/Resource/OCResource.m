//
//  OCResource.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 30.09.20.
//  Copyright © 2020 ownCloud GmbH. All rights reserved.
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

#import "OCResource.h"
#import "OCResourceRequest.h"

@implementation OCResource

- (instancetype)initWithRequest:(OCResourceRequest *)request
{
	if ((self = [super init]) != nil)
	{
		_type = request.type;
		_identifier = request.identifier;

		_version = request.version;
		_structureDescription = request.structureDescription;
	}

	return (self);
}

- (NSData *)data
{
	if ((_data == nil) && (_url != nil))
	{
		_data = [[NSData alloc] initWithContentsOfURL:_url];
	}

	return (_data);
}

#pragma mark - View Provider
- (UIView *)provideViewForSize:(CGSize)size
{
	return (nil);
}

#pragma mark - Secure Coding
+ (BOOL)supportsSecureCoding
{
	return (YES);
}

- (void)encodeWithCoder:(nonnull NSCoder *)coder
{
	[coder encodeObject:_type forKey:@"type"];
	[coder encodeObject:_identifier forKey:@"identifier"];
	[coder encodeObject:_version forKey:@"version"];
	[coder encodeObject:_structureDescription forKey:@"structureDescription"];

	[coder encodeInteger:_quality forKey:@"quality"];

	[coder encodeObject:_metaData forKey:@"metaData"];
	[coder encodeObject:_mimeType forKey:@"mimeType"];

	[coder encodeObject:_url forKey:@"url"];
	if (_url == nil)
	{
		[coder encodeObject:_data forKey:@"data"];
	}

	[coder encodeObject:_timestamp forKey:@"timestamp"];
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)coder
{
	if ((self = [self init]) != nil)
	{
		_type = [coder decodeObjectOfClass:NSString.class forKey:@"type"];
		_identifier = [coder decodeObjectOfClass:NSString.class forKey:@"identifier"];
		_version = [coder decodeObjectOfClass:NSString.class forKey:@"version"];
		_structureDescription = [coder decodeObjectOfClass:NSString.class forKey:@"structureDescription"];

		_quality = [coder decodeIntegerForKey:@"quality"];

		_metaData = [coder decodeObjectOfClass:NSString.class forKey:@"metaData"];
		_mimeType = [coder decodeObjectOfClass:NSString.class forKey:@"mimeType"];

		_url = [coder decodeObjectOfClass:NSURL.class forKey:@"url"];
		_data = [coder decodeObjectOfClass:NSData.class forKey:@"data"];

		_timestamp = [coder decodeObjectOfClass:NSDate.class forKey:@"timestamp"];
	}

	return (self);
}

@end

OCResourceType OCResourceTypeAny = @"*";
OCResourceType OCResourceTypeAvatar = @"image.avatar";
OCResourceType OCResourceTypeItemThumbnail = @"image.thumbnail";
OCResourceType OCResourceTypeDriveItem = @"drive.item";
