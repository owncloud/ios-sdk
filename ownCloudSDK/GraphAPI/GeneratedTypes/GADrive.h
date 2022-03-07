//
// GADrive.h
// Autogenerated / Managed by ocapigen
// Copyright (C) 2022 ownCloud GmbH. All rights reserved.
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

// occgen: includes { "locked" : true }
#import <Foundation/Foundation.h>
#import "GAGraphObject.h"
#import "OCDrive.h"

// occgen: forward declarations { "locked" : true }
@class GAQuota;
@class GAUser;
@class GADriveItem;
@class GAIdentitySet;
@class GAItemReference;

// occgen: type start
NS_ASSUME_NONNULL_BEGIN
@interface GADrive : NSObject <GAGraphObject, NSSecureCoding>

// occgen: type properties { "customPropertyTypes" : { "driveType" : "OCDriveType", "eTag" : "OCFileETag" }}
@property(strong, nullable) NSString *identifier; //!< Read-only.
@property(strong, nullable) GAIdentitySet *createdBy; //!< Identity of the user, device, or application which created the item. Read-only.
@property(strong, nullable) NSDate *createdDateTime; //!< [string:date-time] Date and time of item creation. Read-only. | pattern: ^[0-9]{4,}-(0[1-9]|1[012])-(0[1-9]|[12][0-9]|3[01])[Tt]([01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9]([.][0-9]{1,12})?([Zz]|[+-][0-9][0-9]:[0-9][0-9])$
@property(strong, nullable) NSString *desc; //!< Provides a user-visible description of the item. Optional.
@property(strong, nullable) OCFileETag eTag; //!< ETag for the item. Read-only.
@property(strong, nullable) GAIdentitySet *lastModifiedBy; //!< Identity of the user, device, and application which last modified the item. Read-only.
@property(strong, nullable) NSDate *lastModifiedDateTime; //!< [string:date-time] Date and time the item was last modified. Read-only. | pattern: ^[0-9]{4,}-(0[1-9]|1[012])-(0[1-9]|[12][0-9]|3[01])[Tt]([01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9]([.][0-9]{1,12})?([Zz]|[+-][0-9][0-9]:[0-9][0-9])$
@property(strong, nullable) NSString *name; //!< The name of the item. Read-write.
@property(strong, nullable) GAItemReference *parentReference; //!< Parent information, if the item has a parent. Read-write.
@property(strong, nullable) NSURL *webUrl; //!< URL that displays the resource in the browser. Read-only.
@property(strong, nullable) GAUser *createdByUser; //!< Identity of the user who created the item. Read-only.
@property(strong, nullable) GAUser *lastModifiedByUser; //!< Identity of the user who last modified the item. Read-only.
@property(strong, nullable) OCDriveType driveType; //!< Describes the type of drive represented by this resource. Values are "personal" for users home spaces, "project", "virtual" or "share". Read-only.
@property(strong, nullable) NSString *driveAlias; //!< "The drive alias can be used in clients to make the urls user friendly. Example: 'personal/einstein'. This will be used to resolve to the correct driveID."
@property(strong, nullable) GAIdentitySet *owner;
@property(strong, nullable) GAQuota *quota;
@property(strong, nullable) NSArray<GADriveItem *> *items; //!< All items contained in the drive. Read-only. Nullable.
@property(strong, nullable) GADriveItem *root; //!< Drive item describing the drive's root. Read-only.
@property(strong, nullable) NSArray<GADriveItem *> *special; //!< A collection of special drive resources.

// occgen: type protected {"locked":true}


// occgen: type end
@end
NS_ASSUME_NONNULL_END

