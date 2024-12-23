//
// GADriveItemInvite.h
// Autogenerated / Managed by ocapigen
// Copyright (C) 2024 ownCloud GmbH. All rights reserved.
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

// occgen: includes {"locked":true}
#import <Foundation/Foundation.h>
#import "GAGraphObject.h"
#import "OCShareTypes.h"

// occgen: forward declarations
@class GADriveRecipient;

// occgen: type start
NS_ASSUME_NONNULL_BEGIN
@interface GADriveItemInvite : NSObject <GAGraphObject, NSSecureCoding>

// occgen: type properties { "customPropertyTypes" : { "roles" : "NSArray<OCShareRoleID> *", "libreGraphPermissionsActions" : "NSArray<OCShareActionID> *" }}
@property(strong, nullable) NSArray<GADriveRecipient *> *recipients; //!< A collection of recipients who will receive access and the sharing invitation. Currently, only internal users or groups are supported.
@property(strong, nullable) NSArray<OCShareRoleID> *roles; //!< Specifies the roles that are to be granted to the recipients of the sharing invitation.
@property(strong, nullable) NSArray<OCShareActionID> *libreGraphPermissionsActions; //!< Specifies the actions that are to be granted to the recipients of the sharing invitation, in effect creating a custom role.
@property(strong, nullable) NSDate *expirationDateTime; //!< [string:date-time] Specifies the dateTime after which the permission expires.

// occgen: type protected {"locked":true}


// occgen: type end
@end
NS_ASSUME_NONNULL_END

