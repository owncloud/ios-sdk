//
//  OCUserPermissions.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 04.02.25.
//  Copyright © 2025 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2025, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCUserPermissions.h"

@implementation OCUserPermissions

- (instancetype)initWith:(NSArray<OCUserPermissionIdentifier> *)permissionIDs
{
	if ((self = [super init]) != nil)
	{
		_identifiers = permissionIDs;

		// Extract permissions
		_canCreateSpaces = [_identifiers containsObject:@"Drives.Create.all"];
		_canEditSpaces = [_identifiers containsObject:@"Drives.ReadWrite.all"];
		_canDisableSpaces = [_identifiers containsObject:@"Drives.DeleteProject.all"];
	}

	return (self);
}

@end
