//
//  OCShare+GraphAPI.m
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

#import "OCShare+GraphAPI.h"
#import "OCShareRole+GraphAPI.h"
#import "OCIdentity+GraphAPI.h"
#import "OCSharePermission.h"
#import "GASharingLink.h"

@implementation OCShare (GraphAPI)

+ (nonnull instancetype)shareFromGAPermission:(nonnull GAPermission *)gaPermission roleDefinitions:(NSArray<GAUnifiedRoleDefinition *> *)gaRoleDefinitions forLocation:(nonnull OCLocation *)location item:(nullable OCItem *)item category:(OCShareCategory)category
{
	OCShare *share = [OCShare new];

	share.category = (category != OCShareCategoryUnknown) ? category : ((gaPermission.invitation != nil) ? OCShareCategoryWithMe : OCShareCategoryByMe);

	share.identifier = gaPermission.identifier;
	share.itemLocation = (location != nil) ? location : item.location;
	share.itemType = share.itemLocation.type;
	share.itemFileID = (share.itemType == OCLocationTypeDrive) ? nil : ((location.fileID != nil) ? location.fileID : item.fileID);
	share.itemMIMEType = (share.itemType == OCLocationTypeDrive) ? nil : item.mimeType;

	share.recipient = [OCIdentity identityFromGASharePointIdentitySet:gaPermission.grantedToV2];
	share.sharePermissions = [gaPermission sharePermissionsUsingRoleDefinitions:gaRoleDefinitions];

	if (gaPermission.link != nil)
	{
		share.url = gaPermission.link.webUrl;
		share.name = gaPermission.link.libreGraphDisplayName;
		share.type = OCShareTypeLink;
		if (gaPermission.link.type != nil)
		{
			// Find role among ocis link share roles
			for (OCShareRole *linkRole in OCShareRole.linkShareRoles)
			{
				if ([linkRole.identifier isEqual:gaPermission.link.type])
				{
					share.sharePermissions = @[ [[OCSharePermission alloc] initWithRole:linkRole] ];
					break;
				}
			}

			if (share.sharePermissions.count == 0)
			{
				// Fallback in case none of the standard link share roles fits
				share.sharePermissions = @[ [[OCSharePermission alloc] initWithRoleID:gaPermission.link.type] ];
			}
		}
	}

	share.creationDate = gaPermission.createdDateTime;
	share.expirationDate = gaPermission.expirationDateTime;

	share.protectedByPassword = gaPermission.hasPassword.boolValue;

	share->_originGAPermission = gaPermission;

	if (share.recipient != nil) {
		switch (share.recipient.type) {
			case OCIdentityTypeUser:
				share.type = OCShareTypeUserShare;
			break;

			case OCIdentityTypeGroup:
				share.type = OCShareTypeGroupShare;
			break;
		}
	}

	return (share);
}

@end
