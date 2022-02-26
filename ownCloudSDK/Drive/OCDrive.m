//
//  OCDrive.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 31.01.22.
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

#import "OCDrive.h"
#import "GADrive.h"
#import "GADriveItem.h"
#import "OCMacros.h"

@implementation OCDrive

+ (instancetype)driveFromGADrive:(GADrive *)gDrive
{
	OCDrive *drive = nil;

	if (gDrive != nil)
	{
		drive = [OCDrive new];

		drive.identifier = gDrive.identifier;
		drive.type = gDrive.driveType;

		drive.name = gDrive.name;

		drive.davRootURL = gDrive.root.webDavUrl;

		drive.quota = (OCQuota *)gDrive.quota;

		drive.gaDrive = gDrive;
	}

	return (drive);
}

+ (instancetype)personalDrive
{
	return(nil);
}

#pragma mark - Secure coding
+ (BOOL)supportsSecureCoding
{
	return (YES);
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
	if ((self = [self init]) != nil)
	{
		_identifier = [decoder decodeObjectOfClass:NSString.class forKey:@"identifier"];
		_type = [decoder decodeObjectOfClass:NSString.class forKey:@"type"];

		_name = [decoder decodeObjectOfClass:NSString.class forKey:@"name"];

		_davRootURL = [decoder decodeObjectOfClass:NSURL.class forKey:@"davURL"];

		_quota = [decoder decodeObjectOfClass:GAQuota.class forKey:@"quota"];

		_gaDrive = [decoder decodeObjectOfClass:GADrive.class forKey:@"gaDrive"];
	}

	return (self);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:_identifier forKey:@"identifier"];
	[coder encodeObject:_type forKey:@"type"];

	[coder encodeObject:_name forKey:@"name"];

	[coder encodeObject:_davRootURL forKey:@"davURL"];

	[coder encodeObject:_quota forKey:@"quota"];

	[coder encodeObject:_gaDrive forKey:@"gaDrive"];
}

#pragma mark - Description
- (NSString *)description
{
	return ([NSString stringWithFormat:@"<%@: %p%@%@%@%@%@>", NSStringFromClass(self.class), self,
		OCExpandVar(identifier),
		OCExpandVar(type),
		OCExpandVar(name),
		OCExpandVar(quota),
		OCExpandVar(davRootURL)
	]);
}

@end

OCDriveType OCDriveTypePersonal = @"personal";
OCDriveType OCDriveTypeVirtual = @"virtual";
OCDriveType OCDriveTypeProject = @"project";
OCDriveType OCDriveTypeShare = @"share";
