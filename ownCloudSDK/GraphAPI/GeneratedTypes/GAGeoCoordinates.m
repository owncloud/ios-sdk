//
// GAGeoCoordinates.m
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
#import "GAGeoCoordinates.h"

// occgen: type start
@implementation GAGeoCoordinates

// occgen: type serialization
+ (nullable instancetype)decodeGraphData:(GAGraphData)structure context:(nullable GAGraphContext *)context error:(NSError * _Nullable * _Nullable)outError
{
	GAGeoCoordinates *instance = [self new];

	GA_SET(altitude, NSNumber, Nil);
	GA_SET(latitude, NSNumber, Nil);
	GA_SET(longitude, NSNumber, Nil);

	return (instance);
}

// occgen: struct serialization
- (nullable GAGraphStruct)encodeToGraphStructWithContext:(nullable GAGraphContext *)context error:(NSError * _Nullable * _Nullable)outError
{
	GA_ENC_INIT
	GA_ENC_ADD(_altitude, "altitude", NO);
	GA_ENC_ADD(_latitude, "latitude", NO);
	GA_ENC_ADD(_longitude, "longitude", NO);
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
		_altitude = [decoder decodeObjectOfClass:NSNumber.class forKey:@"altitude"];
		_latitude = [decoder decodeObjectOfClass:NSNumber.class forKey:@"latitude"];
		_longitude = [decoder decodeObjectOfClass:NSNumber.class forKey:@"longitude"];
	}

	return (self);
}

// occgen: type native serialization
- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:_altitude forKey:@"altitude"];
	[coder encodeObject:_latitude forKey:@"latitude"];
	[coder encodeObject:_longitude forKey:@"longitude"];
}

// occgen: type debug description
- (NSString *)description
{
	return ([NSString stringWithFormat:@"<%@: %p%@%@%@>", NSStringFromClass(self.class), self, ((_altitude!=nil) ? [NSString stringWithFormat:@", altitude: %@", _altitude] : @""), ((_latitude!=nil) ? [NSString stringWithFormat:@", latitude: %@", _latitude] : @""), ((_longitude!=nil) ? [NSString stringWithFormat:@", longitude: %@", _longitude] : @"")]);
}

// occgen: type protected {"locked":true}


// occgen: type end
@end
