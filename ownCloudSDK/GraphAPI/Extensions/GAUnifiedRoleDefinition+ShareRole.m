//
//  GAUnifiedRoleDefinition+ShareRole.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 18.12.24.
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

#import "GAUnifiedRoleDefinition+ShareRole.h"
#import "GAUnifiedRolePermission.h"
#import "OCShareRole.h"

@implementation GAUnifiedRoleDefinition (ShareRole)

- (OCShareRole *)role
{
	if (_role == nil) {
		OCShareRole *role = [OCShareRole new];

		role.identifier = self.identifier;

		role.localizedName = self.displayName;
		role.localizedDescription = self.desc;

		role.weight = self.libreGraphWeight;

		role.locations = OCLocationTypeUnknown;

		NSMutableSet<OCShareActionID> *allowedActions = nil;

		for (GAUnifiedRolePermission *rolePermission in self.rolePermissions)
		{
			if ([rolePermission.condition isEqual:@"exists @Resource.Root"]) {
				role.locations |= OCLocationTypeDrive;
			}

			if ([rolePermission.condition isEqual:@"exists @Resource.Folder"]) {
				role.locations |= OCLocationTypeFolder;
			}

			if ([rolePermission.condition isEqual:@"exists @Resource.File"]) {
				role.locations |= OCLocationTypeFile;
			}

			if (rolePermission.allowedResourceActions != nil) {
				if (allowedActions == nil) { allowedActions = [NSMutableSet new]; }
				[allowedActions addObjectsFromArray:rolePermission.allowedResourceActions];
			}
		}

		role.allowedActions = (allowedActions.count > 0) ? allowedActions.allObjects : nil;

		_role = role;
	}
	return (_role);
}

@end
