//
// GAImage.m
// Autogenerated / Managed by ocapigen
// Copyright (C) 2022 ownCloud GmbH. All rights reserved.
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

// occgen: includes
#import "GAImage.h"

// occgen: type start
@implementation GAImage

// occgen: type serialization
+ (nullable instancetype)decodeGraphData:(GAGraphData)structure context:(nullable GAGraphContext *)context error:(NSError * _Nullable * _Nullable)outError
{
	GAImage *instance = [self new];

	GA_SET(height, NSNumber, Nil);
	GA_SET(width, NSNumber, Nil);

	return (instance);
}

// occgen: type native deserialization
+ (BOOL)supportsSecureCoding
{
	return (YES);
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super init]) != nil)
	{
		_height = [decoder decodeObjectOfClass:NSNumber.class forKey:@"height"];
		_width = [decoder decodeObjectOfClass:NSNumber.class forKey:@"width"];
	}

	return (self);
}

// occgen: type native serialization
- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:_height forKey:@"height"];
	[coder encodeObject:_width forKey:@"width"];
}

// occgen: type debug description
- (NSString *)description
{
	return ([NSString stringWithFormat:@"<%@: %p%@%@>", NSStringFromClass(self.class), self, ((_height!=nil) ? [NSString stringWithFormat:@", height: %@", _height] : @""), ((_width!=nil) ? [NSString stringWithFormat:@", width: %@", _width] : @"")]);
}

// occgen: type protected {"locked":true}


// occgen: type end
@end

