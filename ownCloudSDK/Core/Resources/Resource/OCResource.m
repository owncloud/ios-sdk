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

@implementation OCResource

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
	[coder encodeObject:_data forKey:@"data"];
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
		_data = [coder decodeObjectOfClass:NSData.class forKey:@"data"];
	}

	return (self);
}

@end

OCResourceType OCResourceTypeAny = @"any";
