//
//  OCShareRole+GraphAPI.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 29.12.24.
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

#import "OCShareRole+GraphAPI.h"
#import "GASharingLinkType.h"

@implementation OCShareRole (GraphAPI)

+ (NSArray<OCShareRole *> *)linkShareRoles
{
	static NSArray<OCShareRole *> *linkShareRoles;
	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		linkShareRoles = @[
			// Roles for links (per https://github.com/owncloud/web/blob/a8bac47148bf8beb1367bfd70a8d37b113be57e2/packages/web-pkg/src/composables/links/useLinkTypes.ts#L45)

			// # LINKS
			// ## Internal
			// - files, folders
			[[OCShareRole alloc]  initWithIdentifier:GASharingLinkTypeInternal
							    type:OCShareRoleTypeInternal
						      shareTypes:OCShareTypesMaskLink
						     permissions:OCSharePermissionsMaskNone
					 customizablePermissions:OCSharePermissionsMaskNone
						       locations:0 // Role is no longer offered, so make it unavailable for choosing (was OCLocationTypeFile|OCLocationTypeFolder)
						      symbolName:@"person.fill"
						   localizedName:OCLocalizedString(@"Invited people", nil)
					    localizedDescription:OCLocalizedString(@"Link works only for invited people. Login is required.", nil)],

			// ## Viewer
			// - files, folders
			[[OCShareRole alloc]  initWithIdentifier:GASharingLinkTypeView
							    type:OCShareRoleTypeViewer
						      shareTypes:OCShareTypesMaskLink
						     permissions:OCSharePermissionsMaskNone
					 customizablePermissions:OCSharePermissionsMaskNone
						       locations:OCLocationTypeFile|OCLocationTypeFolder|OCLocationTypeDrive
						      symbolName:@"eye.fill"
						   localizedName:OCLocalizedString(@"Can view", nil)
					    localizedDescription:OCLocalizedString(@"View, download", nil)],

			// ## Uploader
			// - folders
			[[OCShareRole alloc]  initWithIdentifier:GASharingLinkTypeUpload
							    type:OCShareRoleTypeUploader
						      shareTypes:OCShareTypesMaskLink
						     permissions:OCSharePermissionsMaskNone
					 customizablePermissions:OCSharePermissionsMaskNone
						       locations:0 // Role is no longer offered, so make it unavailable for choosing (was OCLocationTypeFolder)
						      symbolName:@"arrow.up.circle.fill"
						   localizedName:OCLocalizedString(@"Can upload", nil)
					    localizedDescription:OCLocalizedString(@"View, upload, download", nil)],

			// ## Editor
			// - files
			[[OCShareRole alloc]  initWithIdentifier:GASharingLinkTypeEdit
							    type:OCShareRoleTypeEditor
						      shareTypes:OCShareTypesMaskLink
						     permissions:OCSharePermissionsMaskNone
					 customizablePermissions:OCSharePermissionsMaskNone
						       locations:OCLocationTypeFile|OCLocationTypeFolder|OCLocationTypeDrive
						      symbolName:@"pencil"
						   localizedName:OCLocalizedString(@"Can edit", nil)
					    localizedDescription:OCLocalizedString(@"View, upload, edit, download, delete", nil)],

			// - folders
			[[OCShareRole alloc]  initWithIdentifier:GASharingLinkTypeCreateOnly
							    type:OCShareRoleTypeUploader
						      shareTypes:OCShareTypesMaskLink
						     permissions:OCSharePermissionsMaskNone
					 customizablePermissions:OCSharePermissionsMaskNone
						       locations:OCLocationTypeFolder|OCLocationTypeDrive
						      symbolName:@"tray.and.arrow.down.fill"
						   localizedName:OCLocalizedString(@"Secret File Drop", nil)
					    localizedDescription:OCLocalizedString(@"Upload only, existing content is not revealed", nil)]
		];
	});

	return (linkShareRoles);
}

@end
