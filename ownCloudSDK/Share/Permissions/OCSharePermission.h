//
//  OCSharePermission.h
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

#import <Foundation/Foundation.h>
#import "OCShareTypes.h"
#import "OCShareRole.h"
#import "OCFeatureAvailability.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, OCSharePermissionDriveRole) {
	OCSharePermissionDriveRoleNone,

	// Order allows numeric sorting by driveRole from most to least permissive
	OCSharePermissionDriveRoleViewer,
	OCSharePermissionDriveRoleEditor,
	OCSharePermissionDriveRoleManager
};

@class GAPermission;
@class GAUnifiedRoleDefinition;

@interface OCSharePermission : NSObject

// MARK: - Convenience initializers
@property(class,readonly,nonatomic) OCSharePermission *createPermission;
@property(class,readonly,nonatomic) OCSharePermission *readPermission;
@property(class,readonly,nonatomic) OCSharePermission *updatePermission;
@property(class,readonly,nonatomic) OCSharePermission *deletePermission;

@property(class,readonly,nonatomic,nullable) OCSharePermission *sharePermission; //!< oc10 legacy share permission

// MARK: - ocis properties
@property(readonly,nullable,strong) OCShareRole *role; //!< ocis graph role
@property(readonly,nullable,strong) OCShareRoleID roleID; //!< ocis graph role ID
@property(readonly,nullable,strong) NSArray<OCShareActionID> *actions; //!< ocis graph share action IDs

// MARK: - ocis space properties
@property(readonly,nonatomic) OCSharePermissionDriveRole driveRole; //!< For ocis spaces, returns the role - or OCSharePermissionDriveRoleNone if no role is provided
@property(readonly,strong,nullable,nonatomic) NSString *localizedDriveRoleName; //!< For ocis spaces, returns a localized name for the drive role, ignoring actual roles. Returns nil for non-driverole roles
- (nullable NSString *)localizedRoleNameWithRoles:(nullable NSArray<GAUnifiedRoleDefinition *> *)roleDefinitions; //!< For ocis spaces, returns a textual representation of .driveRole - or the name of the matching role definition

// MARK: - OC10 properties
@property(readonly) OCSharePermissionsMask mask; //!< OC10-style permission mask

// MARK: - Initializers
- (instancetype)initWithRole:(OCShareRole *)role; //!< ocis graph role
- (instancetype)initWithRoleID:(OCShareRoleID)roleID; //!< ocis graph role ID
- (instancetype)initWithActions:(NSArray<OCShareActionID> *)actions; //!< ocis graph "permission actions"
#if OC_LEGACY_SUPPORT
- (instancetype)initWithPermissionsMask:(OCSharePermissionsMask)permissionMask;  //!< oc10 legacy permission mask

// MARK: - permission -> Legacy mask conversion
+ (OCSharePermissionsMask)permissionMaskForPermissions:(NSArray<OCSharePermission *> *)permissions;
#endif /* OC_LEGACY_SUPPORT */

@end

NS_ASSUME_NONNULL_END
