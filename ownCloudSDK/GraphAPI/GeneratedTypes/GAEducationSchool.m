//
// GAEducationSchool.m
// Autogenerated / Managed by ocapigen
// Copyright (C) 2024 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2024, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

// occgen: includes
#import "GAEducationSchool.h"

// occgen: type start
@implementation GAEducationSchool

// occgen: type serialization
+ (nullable instancetype)decodeGraphData:(GAGraphData)structure context:(nullable GAGraphContext *)context error:(NSError * _Nullable * _Nullable)outError
{
	GAEducationSchool *instance = [self new];

	GA_MAP(identifier, "id", NSString, Nil);
	GA_SET(displayName, NSString, Nil);
	GA_SET(schoolNumber, NSString, Nil);
	GA_SET(terminationDate, NSDate, Nil);

	return (instance);
}

// occgen: struct serialization
- (nullable GAGraphStruct)encodeToGraphStructWithContext:(nullable GAGraphContext *)context error:(NSError * _Nullable * _Nullable)outError
{
	GA_ENC_INIT
	GA_ENC_ADD(_identifier, "id", NO);
	GA_ENC_ADD(_displayName, "displayName", NO);
	GA_ENC_ADD(_schoolNumber, "schoolNumber", NO);
	GA_ENC_ADD(_terminationDate, "terminationDate", NO);
	GA_ENC_RETURN
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
		_identifier = [decoder decodeObjectOfClass:NSString.class forKey:@"identifier"];
		_displayName = [decoder decodeObjectOfClass:NSString.class forKey:@"displayName"];
		_schoolNumber = [decoder decodeObjectOfClass:NSString.class forKey:@"schoolNumber"];
		_terminationDate = [decoder decodeObjectOfClass:NSDate.class forKey:@"terminationDate"];
	}

	return (self);
}

// occgen: type native serialization
- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:_identifier forKey:@"identifier"];
	[coder encodeObject:_displayName forKey:@"displayName"];
	[coder encodeObject:_schoolNumber forKey:@"schoolNumber"];
	[coder encodeObject:_terminationDate forKey:@"terminationDate"];
}

// occgen: type debug description
- (NSString *)description
{
	return ([NSString stringWithFormat:@"<%@: %p%@%@%@%@>", NSStringFromClass(self.class), self, ((_identifier!=nil) ? [NSString stringWithFormat:@", identifier: %@", _identifier] : @""), ((_displayName!=nil) ? [NSString stringWithFormat:@", displayName: %@", _displayName] : @""), ((_schoolNumber!=nil) ? [NSString stringWithFormat:@", schoolNumber: %@", _schoolNumber] : @""), ((_terminationDate!=nil) ? [NSString stringWithFormat:@", terminationDate: %@", _terminationDate] : @"")]);
}

// occgen: type protected {"locked":true}


// occgen: type end
@end

