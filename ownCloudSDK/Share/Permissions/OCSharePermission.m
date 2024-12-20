//
//  OCSharePermission.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 17.12.24.
//  Copyright © 2024 ownCloud GmbH. All rights reserved.
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

#import "OCSharePermission.h"
#import "OCShareAction.h"
#import "OCShareRole.h"
#import "OCLocale.h"

#import "GAUnifiedRoleDefinition.h"

@implementation OCSharePermission

// MARK: - Initializers
- (instancetype)initWithRole:(OCShareRole *)role
{
	if ((self = [super init]) != nil)
	{
		_role = role;
		_roleID = role.identifier;
	}

	return (self);
}

- (instancetype)initWithRoleID:(OCShareRoleID)roleID
{
	if ((self = [super init]) != nil)
	{
		_roleID = roleID;
	}

	return (self);
}

- (instancetype)initWithActions:(NSArray<OCShareActionID> *)actions
{
	if ((self = [super init]) != nil)
	{
		_actions = actions;
	}

	return (self);
}

#if OC_LEGACY_SUPPORT
- (instancetype)initWithPermissionsMask:(OCSharePermissionsMask)permissionMask
{
	if ((self = [super init]) != nil)
	{
		_mask = permissionMask;
	}

	return (self);
}

- (instancetype)initWithPermissionsMask:(OCSharePermissionsMask)permissionMask actions:(NSArray<OCShareActionID> *)actions
{
	if ((self = [super init]) != nil)
	{
		_mask = permissionMask;
		_actions = actions;
	}

	return (self);
}

// MARK: - ocis space properties
- (OCSharePermissionDriveRole)driveRole
{
	if (_roleID != nil) {
		if ([_roleID isEqualToString:OCShareRoleIDManager] || [_roleID isEqualToString:OCShareRoleIDManagerV1]) {
			return (OCSharePermissionDriveRoleManager);
		}
		if ([_roleID isEqualToString:OCShareRoleIDEditor] || [_roleID isEqualToString:OCShareRoleIDEditorV1]) {
			return (OCSharePermissionDriveRoleEditor);
		}
		if ([_roleID isEqualToString:OCShareRoleIDViewer] || [_roleID isEqualToString:OCShareRoleIDViewerV1]) {
			return (OCSharePermissionDriveRoleViewer);
		}
	}
	return (OCSharePermissionDriveRoleNone);
}

- (nullable NSString *)localizedDriveRoleName
{
	switch (self.driveRole)
	{
		case OCSharePermissionDriveRoleManager:
			return (OCLocalizedString(@"Manager", nil));
		break;

		case OCSharePermissionDriveRoleEditor:
			return (OCLocalizedString(@"Editor", nil));
		break;

		case OCSharePermissionDriveRoleViewer:
			return (OCLocalizedString(@"Viewer", nil));
		break;

		case OCSharePermissionDriveRoleNone:
		default:
			return (nil);
		break;
	}
}

- (nullable NSString *)localizedRoleNameWithRoles:(nullable NSArray<GAUnifiedRoleDefinition *> *)roleDefinitions
{
	for (GAUnifiedRoleDefinition *roleDefinition in roleDefinitions)
	{
		if ([roleDefinition.identifier isEqual:_roleID] && (roleDefinition.displayName != nil)) {
			return (roleDefinition.displayName);
		}
	}

	if ([self.role.identifier isEqual:self.roleID])
	{
		return (self.role.localizedName);
	}

	return (self.localizedDriveRoleName);
}

// MARK: - permission -> Legacy mask conversion
+ (OCSharePermissionsMask)permissionMaskForPermissions:(NSArray<OCSharePermission *> *)permissions
{
	OCSharePermissionsMask mask = 0;

	for (OCSharePermission *permission in permissions)
	{
		mask |= permission.mask;
	}

	return (mask);
}

#endif /* OC_LEGACY_SUPPORT */

//// MARK: - Convenience initializers
+ (OCSharePermission *)createPermission
{
	return ([[self alloc] initWithPermissionsMask:OCSharePermissionsMaskCreate actions:@[
		OCShareActionIDCreateUpload,
		OCShareActionIDCreateChildren,
	]]);
}

+ (OCSharePermission *)readPermission
{
	return ([[self alloc] initWithPermissionsMask:OCSharePermissionsMaskRead actions:@[
		OCShareActionIDReadPath,
		OCShareActionIDReadBasic,
		OCShareActionIDReadContent,
		OCShareActionIDReadChildren,
	]]);
}

+ (OCSharePermission *)updatePermission
{
	return ([[self alloc] initWithPermissionsMask:OCSharePermissionsMaskUpdate actions:@[
		OCShareActionIDUpdatePath,
		OCShareActionIDUpdateDeleted,
		OCShareActionIDUpdatePermissions,
	]]);
}

+ (OCSharePermission *)deletePermission
{
	return ([[self alloc] initWithPermissionsMask:OCSharePermissionsMaskDelete actions:@[
		OCShareActionIDDeleteStandard,
	]]);
}

+ (OCSharePermission *)sharePermission
{
	#if OC_LEGACY_SUPPORT
	return ([[self alloc] initWithPermissionsMask:OCSharePermissionsMaskShare actions:nil]);
	#else
	return (nil);
	#endif /* OC_LEGACY_SUPPORT */
}

@end
