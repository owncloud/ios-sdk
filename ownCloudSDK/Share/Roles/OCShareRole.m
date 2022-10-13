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

@implementation OCShareRole

- (instancetype)initWithType:(OCShareRoleType)type shareTypes:(OCShareTypesMask)shareTypes permissions:(OCSharePermissionsMask)permissions customizablePermissions:(OCSharePermissionsMask)customizablePermissions locations:(OCLocationType)locations symbolName:(OCSymbolName)symbolName localizedName:(NSString *)localizedName localizedDescription:(NSString *)localizedDescription
{
	if ((self = [super init]) != nil)
	{
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

@end

OCShareRoleType OCShareRoleTypeViewer = @"viewer";
OCShareRoleType OCShareRoleTypeUploader = @"uploader";
OCShareRoleType OCShareRoleTypeEditor = @"editor";
OCShareRoleType OCShareRoleTypeContributor = @"contributor";
OCShareRoleType OCShareRoleTypeManager = @"manager";
OCShareRoleType OCShareRoleTypeCustom = @"custom";
