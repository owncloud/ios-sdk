//
//  OCUser.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 22.02.18.
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

#import <UIKit/UIKit.h>
#import "OCFeatureAvailability.h"
#import "OCGroup.h"
#import "OCUserPermissions.h"

@class GAUser;
@class GAIdentity;

NS_ASSUME_NONNULL_BEGIN

typedef NSString* OCUniqueUserIdentifier; //!< Internal SDK unique identifier for the user
typedef NSString* OCUserID; //!< Server-side user ID (f.ex. "534bb038-6f9d-4093-946f-133be61fa4e7"), typically from ocis servers

typedef NS_ENUM(NSInteger, OCUserType) {
	OCUserTypeUnknown,

	OCUserTypeMember,	// Regular user
	OCUserTypeGuest,	// Guest user
	OCUserTypeFederated	// Federated user
};

@interface OCUser : NSObject <NSSecureCoding, NSCopying>
{
	UIImage *_avatar;
	NSNumber *_forceIsRemote;
}

@property(nullable,strong) NSString *displayName; //!< Display name of the user (f.ex. "John Appleseed")

@property(nullable,strong) NSString *userName; //!< User name of the user (f.ex. "jappleseed")

@property(assign) OCUserType type; //!< Type of user
@property(nullable,strong) OCUserID identifier; //!< ID of the user (f.ex. "534bb038-6f9d-4093-946f-133be61fa4e7"), typically from ocis (not available on OC10)

@property(nullable,strong) NSString *emailAddress; //!< Email address of the user (f.ex. "jappleseed@owncloud.org")

@property(nonatomic,readonly) BOOL isRemote; //!< Returns YES if the userName contains an @ sign
@property(nullable,readonly) NSString *remoteUserName; //!< Returns the part before the @ sign for usernames containing an @ sign (nil otherwise)
@property(nullable,readonly) NSString *remoteHost; //!< Returns the part after the @ sign for usernames containing an @ sign (nil otherwise)

@property(nullable,readonly) OCUniqueUserIdentifier uniqueIdentifier; //!< Unique SDK internal identifier for the user
@property(nullable,readonly) NSString *localizedInitials; //!< Returns localized initials for user

@property(readonly,nonatomic,nullable) GAIdentity *gaIdentity;
@property(strong,nullable) NSArray<OCGroupID> *groupMemberships;

@property(strong,nullable) OCUserPermissions *permissions; //!< Permissions the user has on the server (to perform action)

+ (nullable NSString *)localizedInitialsForName:(NSString *)name;

+ (instancetype)userWithGraphUser:(GAUser *)user;
+ (instancetype)userWithGraphIdentity:(GAIdentity *)identity;

+ (instancetype)userWithUserName:(nullable NSString *)userName displayName:(nullable NSString *)displayName;
+ (instancetype)userWithUserName:(nullable NSString *)userName displayName:(nullable NSString *)displayName isRemote:(BOOL)isRemote;

@end

NS_ASSUME_NONNULL_END
