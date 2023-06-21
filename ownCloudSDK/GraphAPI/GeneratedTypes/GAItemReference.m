//
// GAItemReference.m
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
#import "GAItemReference.h"

// occgen: type start
@implementation GAItemReference

// occgen: type serialization
+ (nullable instancetype)decodeGraphData:(GAGraphData)structure context:(nullable GAGraphContext *)context error:(NSError * _Nullable * _Nullable)outError
{
	GAItemReference *instance = [self new];

	GA_SET(driveId, NSString, Nil);
	GA_SET(driveType, NSString, Nil);
	GA_MAP(identifier, "id", NSString, Nil);
	GA_SET(name, NSString, Nil);
	GA_SET(path, NSString, Nil);
	GA_SET(shareId, NSString, Nil);

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
		_driveId = [decoder decodeObjectOfClass:NSString.class forKey:@"driveId"];
		_driveType = [decoder decodeObjectOfClass:NSString.class forKey:@"driveType"];
		_identifier = [decoder decodeObjectOfClass:NSString.class forKey:@"identifier"];
		_name = [decoder decodeObjectOfClass:NSString.class forKey:@"name"];
		_path = [decoder decodeObjectOfClass:NSString.class forKey:@"path"];
		_shareId = [decoder decodeObjectOfClass:NSString.class forKey:@"shareId"];
	}

	return (self);
}

// occgen: type native serialization
- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:_driveId forKey:@"driveId"];
	[coder encodeObject:_driveType forKey:@"driveType"];
	[coder encodeObject:_identifier forKey:@"identifier"];
	[coder encodeObject:_name forKey:@"name"];
	[coder encodeObject:_path forKey:@"path"];
	[coder encodeObject:_shareId forKey:@"shareId"];
}

// occgen: type debug description
- (NSString *)description
{
	return ([NSString stringWithFormat:@"<%@: %p%@%@%@%@%@%@>", NSStringFromClass(self.class), self, ((_driveId!=nil) ? [NSString stringWithFormat:@", driveId: %@", _driveId] : @""), ((_driveType!=nil) ? [NSString stringWithFormat:@", driveType: %@", _driveType] : @""), ((_identifier!=nil) ? [NSString stringWithFormat:@", identifier: %@", _identifier] : @""), ((_name!=nil) ? [NSString stringWithFormat:@", name: %@", _name] : @""), ((_path!=nil) ? [NSString stringWithFormat:@", path: %@", _path] : @""), ((_shareId!=nil) ? [NSString stringWithFormat:@", shareId: %@", _shareId] : @"")]);
}

// occgen: type protected {"locked":true}


// occgen: type end
@end

