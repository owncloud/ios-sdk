//
//  OCShareRole.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 13.10.22.
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

#import "OCShareRole.h"
#import "OCMacros.h"

@implementation OCShareRole

- (instancetype)initWithIdentifier:(OCShareRoleID)identifier type:(OCShareRoleType)type shareTypes:(OCShareTypesMask)shareTypes permissions:(OCSharePermissionsMask)permissions customizablePermissions:(OCSharePermissionsMask)customizablePermissions locations:(OCLocationType)locations symbolName:(OCSymbolName)symbolName localizedName:(NSString *)localizedName localizedDescription:(NSString *)localizedDescription
{
	if ((self = [super init]) != nil)
	{
		_identifier = identifier;

		_type = type;
		_shareTypes = shareTypes;

		_permissions = permissions;
		_customizablePermissions = customizablePermissions;

		_locations = locations;

		_symbolName = symbolName;
		_localizedName = localizedName;
		_localizedDescription = localizedDescription;
	}

	return (self);
}

- (BOOL)isEqual:(id)object
{
	OCShareRole *otherRole;

	if ((otherRole = OCTypedCast(object, OCShareRole)) == nil)
	{
		return (NO);
	}

	if (OCNANotEqual(_identifier, otherRole.identifier) ||
	    OCNANotEqual(_type, otherRole.type) ||
	    (_shareTypes != otherRole.shareTypes) ||
	    (_permissions != otherRole.permissions) ||
	    (_customizablePermissions != otherRole.customizablePermissions) ||
	    (_locations != otherRole.locations))
	{
		return (NO);
	}

	return (YES);
}

- (NSUInteger)hash
{
	return (_identifier.hash ^ _type.hash ^ ((NSUInteger)_shareTypes << 8) ^ ((NSUInteger)_permissions << 16) ^ ((NSUInteger)_customizablePermissions << 24) ^ ((NSUInteger)_locations << 32) ^ _symbolName.hash ^ _localizedName.hash ^ _localizedDescription.hash);
}

@end

OCShareRoleType OCShareRoleTypeInternal = @"internal";
OCShareRoleType OCShareRoleTypeViewer = @"viewer";
OCShareRoleType OCShareRoleTypeUploader = @"uploader";
OCShareRoleType OCShareRoleTypeEditor = @"editor";
OCShareRoleType OCShareRoleTypeContributor = @"contributor";
OCShareRoleType OCShareRoleTypeManager = @"manager";
OCShareRoleType OCShareRoleTypeCustom = @"custom";

// as per https://github.com/owncloud/web/blob/6983ef727ea25430d57c7625ec53f0b249132246/packages/web-client/src/graph/drives/drives.ts#L9
OCShareRoleID OCShareRoleIDManagerV1 = @"manager"; // v1 role id
OCShareRoleID OCShareRoleIDViewerV1 = @"viewer"; // v1 role id
OCShareRoleID OCShareRoleIDEditorV1 = @"editor"; // v1 role id

OCShareRoleID OCShareRoleIDManager = @"312c0871-5ef7-4b3a-85b6-0e4074c64049"; // v2 role id
OCShareRoleID OCShareRoleIDViewer = @"a8d5fe5e-96e3-418d-825b-534dbdf22b99"; // v2 role id
OCShareRoleID OCShareRoleIDEditor = @"58c63c02-1d89-4572-916a-870abc5a1b7d"; // v2 role id
