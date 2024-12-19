//
//  GAPermission+SharePermission.m
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

#import "GAPermission+SharePermission.h"
#import "GAUnifiedRoleDefinition.h"

@implementation GAPermission (SharePermission)

- (nullable NSArray<OCSharePermission *> *)sharePermissionsUsingRoleDefinitions:(nullable NSArray<GAUnifiedRoleDefinition *> *)roleDefinitions
{
	NSMutableArray<OCSharePermission *> *permissions = [NSMutableArray new];

	if (self.roles.count > 0) {
		for (OCShareRoleID roleID in self.roles) {
			OCShareRole *role = nil;
			for (GAUnifiedRoleDefinition *roleDefinition in roleDefinitions) {
				if ([roleDefinition.identifier isEqual:roleID]) {
					role = roleDefinition.role;
				}
			}

			if (role != nil)
			{
				[permissions addObject:[[OCSharePermission alloc] initWithRole:role]];
			}
			else
			{
				[permissions addObject:[[OCSharePermission alloc] initWithRoleID:roleID]];
			}
		}
	}

	if (self.libreGraphPermissionsActions.count > 0) {
		[permissions addObject:[[OCSharePermission alloc] initWithActions:self.libreGraphPermissionsActions]];
	}

	return (permissions);
}

@end
