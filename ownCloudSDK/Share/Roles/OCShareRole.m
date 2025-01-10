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

- (OCSymbolName)symbolName
{
	if ((_symbolName == nil) && (_identifier != nil)) {
		NSDictionary<OCShareRoleID, OCSymbolName> *roleIDToSymbolMap = @{
			// Based on https://github.com/owncloud/web/blob/master/packages/web-runtime/themes/owncloud/theme.json
			@"b1e2218d-eef8-4d4c-b82d-0f1a1b48f3b5" : @"eye.fill", 			// UnifiedRoleViewer
			@"a8d5fe5e-96e3-418d-825b-534dbdf22b99" : @"eye.fill",			// UnifiedRoleSpaceViewer
			@"2d00ce52-1fc2-4dbc-8b95-a73b73395f5a" : @"pencil",			// UnifiedRoleFileEditor
			@"fb6c3e19-e378-47e5-b277-9732f9de6e21" : @"pencil",			// UnifiedRoleEditor
			@"58c63c02-1d89-4572-916a-870abc5a1b7d" : @"pencil",			// UnifiedRoleSpaceEditor
			@"312c0871-5ef7-4b3a-85b6-0e4074c64049" : @"person.fill", 		// UnifiedRoleManager
			@"1c996275-f1c9-4e71-abdf-a42f6495e960" : @"arrow.up.circle.fill",	// UnifiedRoleUploader
			@"aa97fe03-7980-45ac-9e50-b325749fd7e6" : @"shield"			// UnifiedRoleSecureView
		};

		return roleIDToSymbolMap[_identifier];
	}

	return (_symbolName);
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

+ (BOOL)isRoleID:(OCShareRoleID)identifier equalTo:(OCShareRoleID)otherIdentifier
{
	if ([identifier isEqual:otherIdentifier])
	{
		return(YES);
	}

	if (([identifier      isEqualToString:OCShareRoleIDManager] || [identifier      isEqualToString:OCShareRoleIDManagerV1]) &&
	    ([otherIdentifier isEqualToString:OCShareRoleIDManager] || [otherIdentifier isEqualToString:OCShareRoleIDManagerV1]))
	{
		return (YES);
	}

	if (([identifier      isEqualToString:OCShareRoleIDEditor] || [identifier      isEqualToString:OCShareRoleIDEditorV1]) &&
	    ([otherIdentifier isEqualToString:OCShareRoleIDEditor] || [otherIdentifier isEqualToString:OCShareRoleIDEditorV1]))
	{
		return (YES);
	}

	if (([identifier      isEqualToString:OCShareRoleIDViewer] || [identifier      isEqualToString:OCShareRoleIDViewerV1]) &&
	    ([otherIdentifier isEqualToString:OCShareRoleIDViewer] || [otherIdentifier isEqualToString:OCShareRoleIDViewerV1]))
	{
		return (YES);
	}

	return (NO);
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
