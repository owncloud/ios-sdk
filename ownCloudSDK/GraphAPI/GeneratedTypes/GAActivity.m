//
// GAActivity.m
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
#import "GAActivity.h"

// occgen: type start
@implementation GAActivity

// occgen: type serialization
+ (nullable instancetype)decodeGraphData:(GAGraphData)structure context:(nullable GAGraphContext *)context error:(NSError * _Nullable * _Nullable)outError
{
	GAActivity *instance = [self new];

	GA_MAP_REQ(identifier, "id", NSString, Nil);
	GA_SET_REQ(times, NSDictionary, Nil);
	GA_SET_REQ(template, NSDictionary, Nil);

	return (instance);
}

// occgen: struct serialization
- (nullable GAGraphStruct)encodeToGraphStructWithContext:(nullable GAGraphContext *)context error:(NSError * _Nullable * _Nullable)outError
{
	GA_ENC_INIT
	GA_ENC_ADD(_identifier, "id", YES);
	GA_ENC_ADD(_times, "times", YES);
	GA_ENC_ADD(_template, "template", YES);
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
		_times = [decoder decodeObjectOfClass:NSDictionary.class forKey:@"times"];
		_template = [decoder decodeObjectOfClass:NSDictionary.class forKey:@"template"];
	}

	return (self);
}

// occgen: type native serialization
- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:_identifier forKey:@"identifier"];
	[coder encodeObject:_times forKey:@"times"];
	[coder encodeObject:_template forKey:@"template"];
}

// occgen: type debug description
- (NSString *)description
{
	return ([NSString stringWithFormat:@"<%@: %p%@%@%@>", NSStringFromClass(self.class), self, ((_identifier!=nil) ? [NSString stringWithFormat:@", identifier: %@", _identifier] : @""), ((_times!=nil) ? [NSString stringWithFormat:@", times: %@", _times] : @""), ((_template!=nil) ? [NSString stringWithFormat:@", template: %@", _template] : @"")]);
}

// occgen: type protected {"locked":true}


// occgen: type end
@end
