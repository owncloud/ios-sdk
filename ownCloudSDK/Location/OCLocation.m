//
//  OCLocation.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 04.02.22.
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

#import "OCLocation.h"
#import "OCMacros.h"

@implementation OCLocation

- (instancetype)initWithDriveID:(nullable OCDriveID)driveID path:(nullable OCPath)path
{
	if ((self = [super init]) != nil)
	{
		_driveID = driveID;
		_path = path;
	}

	return (self);
}

#pragma mark - String composition / decomposition
- (OCLocationString)string
{
	// Format: BOOKMARKUUID;DRIVEID:PATH
	//	- ";" is the devider between BOOKMARKUUID and DRIVEID
	//	- ":" is the devider between DRIVEID and PATH
	//	- missing elements are encoded as empty string ("")
	return ([NSString stringWithFormat:@";%@:%@", ((_driveID != nil) ? _driveID : @""), ((_path != nil) ? _path : @"")]);
}

+ (instancetype)fromString:(OCLocationString)string
{
	NSRange semicolonRange = [string rangeOfString:@";"];

	if (semicolonRange.location != NSNotFound)
	{
		NSRange colonDividerRange = [string rangeOfString:@":"];

		if (colonDividerRange.location != NSNotFound)
		{
			NSString *bookmarkUUIDString = (semicolonRange.location > 0) ? [string substringWithRange:NSMakeRange(1, semicolonRange.location)] : nil;
			NSString *driveID = (colonDividerRange.location > (semicolonRange.location+semicolonRange.length)) ? [string substringWithRange:NSMakeRange((semicolonRange.location+semicolonRange.length), colonDividerRange.location-(semicolonRange.location+semicolonRange.length))] : nil;
			NSString *path = ((colonDividerRange.location+colonDividerRange.length) < string.length) ? [string substringFromIndex:colonDividerRange.location+colonDividerRange.length] : nil;

			OCLocation *location;

			location = [[self alloc] initWithDriveID:driveID path:path];
			location.bookmarkUUID = [[NSUUID alloc] initWithUUIDString:bookmarkUUIDString];

			return (location);
		}
	}

	return (nil);
}

#pragma mark - Secure coding
+ (BOOL)supportsSecureCoding
{
	return (YES);
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super init]) != nil)
	{
		_bookmarkUUID = [decoder decodeObjectOfClass:NSUUID.class forKey:@"bookmarkUUID"];
		_driveID = [decoder decodeObjectOfClass:NSString.class forKey:@"driveID"];
		_path = [decoder decodeObjectOfClass:NSString.class forKey:@"path"];
	}

	return (self);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:_bookmarkUUID forKey:@"bookmarkUUID"];
	[coder encodeObject:_driveID forKey:@"driveID"];
	[coder encodeObject:_path forKey:@"path"];
}

#pragma mark - Copying
- (id)copyWithZone:(NSZone *)zone
{
	OCLocation *location = [OCLocation new];

	location->_driveID = _driveID;
	location->_path = _path;

	return (location);
}

#pragma mark - Description
- (NSString *)description
{
	return ([NSString stringWithFormat:@"<%@: %p%@%@>", NSStringFromClass(self.class), self,
		OCExpandVar(driveID),
		OCExpandVar(path)
	]);
}

@end
