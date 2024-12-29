//
//  OCShare.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 05.02.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2018, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import <Foundation/Foundation.h>
#import "OCUser.h"
#import "OCIdentity.h"
#import "OCShareTypes.h"

#import "OCItem.h"
#import "GAPermission.h"

@class OCSharePermission;
@class OCShareRole;
@class GAPermission;

NS_ASSUME_NONNULL_BEGIN

@interface OCShare : NSObject <NSSecureCoding, NSCopying>
{
	GAPermission *_originGAPermission;
}

@property(nullable,strong) OCShareID identifier; //!< Server-issued unique identifier of the share (server-provided instances are guaranteed to have an ID, locally created ones do typically NOT have an ID)

@property(assign) OCShareType type; //!< The type of share (i.e. public or user)
@property(assign) OCShareCategory category; //!< Category of share (with me/by me)

@property(strong,nonatomic) OCLocation *itemLocation; //!< Location of the shared item
@property(strong,nullable) OCFileID itemFileID; //!< File ID of item
@property(assign) OCLocationType itemType; //!< Type of the shared item
@property(nullable,strong) OCUser *itemOwner; //!< Owner of the item
@property(nullable,strong) NSString *itemMIMEType; //!< MIME-Type of the shared item

@property(nullable,strong) NSString *name; //!< Name of the share (maximum length: 64 characters)
@property(nullable,strong) NSString *token; //!< share token
@property(nullable,strong) NSURL *url; //!< URL of the share (i.e. public link)

@property(assign,nonatomic) OCSharePermissionsMask permissions; //!< Mask of permissions set on the share
@property(strong,nullable) NSArray<OCSharePermission *> *sharePermissions;
@property(readonly,nullable,strong) OCShareRoleID firstRoleID; //!< Convenience accessor to return the first roleID from .sharePermissions
@property(readonly,nullable,strong) OCShareRole *firstRole; //!< Convenience accessor to return the first role from .sharePermissions

@property(nullable,strong) NSDate *creationDate; //!< Creation date of the share
@property(nullable,strong) NSDate *expirationDate; //!< Expiration date of the share

@property(assign,nonatomic) BOOL protectedByPassword; //!< YES if the share is password protected (not always available)
@property(nullable,strong) NSString *password; //!< Password of the share (not always available)

@property(nullable,strong) OCUser *owner; //!< Owner of the share
@property(nullable,strong) OCIdentity *recipient; //!< Recipient of the share

@property(nullable,strong) NSString *mountPoint; //!< Mount point of federated share (if accepted, itemPath contains a sanitized path to the location inside the user's account)
@property(nullable,strong) OCShareState state; //!< Local share is pending, accepted or rejected
@property(nullable,strong) NSNumber *accepted; //!< Federated share has been accepted

@property(nullable,readonly,nonatomic) OCShareState effectiveState; //!< Unified state information for both remote and local shares

@property(nullable,strong) NSArray<OCShare *> *otherItemShares; //!< Other shares targeting the same item (! not serialized !)

@property(readonly,nullable,strong) GAPermission *originGAPermission; //!< The GAPermission this OCShare instance was created from. For debugging only.

#pragma mark - Convenience constructors
/**
 Creates an object that can be used to create a share on the server.

 @param recipient The recipient representing the user or group to share with.
 @param location The location of the item to share. Can be retrieved from OCItem.location.
 @param permissions Array of OCSharePermissions.
 @param expirationDate Optional expiration date.
 @return An OCShare instance configured with the respective options.
 */
+ (instancetype)shareWithRecipient:(OCIdentity *)recipient location:(OCLocation *)location permissions:(NSArray<OCSharePermission *> *)permissions expiration:(nullable NSDate *)expirationDate;

/**
 Creates an object that can be used to create a public link.

 @param location The location of the item to share. Can be retrieved from OCItem.location.
 @param name Optional name for the public link.
 @param permissions Array of OCSharePermissions (previously: Bitmask of permissions: OCSharePermissionsMaskRead for "Download + View". OCSharePermissionsMaskCreate for "Upload" (specify only this for a folder to create a file drop). OCSharePermissionsMaskUpdate|OCSharePermissionsMaskDelete to also allow changes / deletion of items.)
 @param password Optional password to control access.
 @param expirationDate Optional expiration date.
 @return An OCShare instance configured with the respective options.
 */
+ (instancetype)shareWithPublicLinkToLocation:(OCLocation *)location linkName:(nullable NSString *)name permissions:(NSArray<OCSharePermission *> *)permissions password:(nullable NSString *)password expiration:(nullable NSDate *)expirationDate;

#pragma mark - Conversions
+ (OCShareTypesMask)maskForType:(OCShareType)type; //!< Converts share types into mask values.
+ (OCShareType)typeForMask:(OCShareTypesMask)mask; //!< Converts single-type mask values into types. Multi-type masks are returned as OCShareTypeUnknown

@end

extern OCShareState OCShareStateAccepted;
extern OCShareState OCShareStatePending;
extern OCShareState OCShareStateDeclined;

NS_ASSUME_NONNULL_END
