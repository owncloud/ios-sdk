//
//  OCIdentity.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 01.03.19.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2019, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import <Foundation/Foundation.h>
#import "OCUser.h"
#import "OCGroup.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, OCIdentityType) {
	OCIdentityTypeUser,
	OCIdentityTypeGroup
};

typedef NS_ENUM(NSUInteger, OCIdentityMatchType) {
	OCIdentityMatchTypeUnknown,	//!< No match type available for the recipient
	OCIdentityMatchTypeExact,	//!< Exact match from search
	OCIdentityMatchTypeAdditional	//!< Additional match from search
};

@interface OCIdentity : NSObject <NSSecureCoding, NSCopying>

@property(assign) OCIdentityType type;

@property(nullable,strong) OCGroup *group;
@property(nullable,strong) OCUser *user;

@property(nullable,strong,nonatomic) NSString *identifier; //!< Depending on type, returns user.userName/user.identifier or group.identifier
@property(nullable,strong,nonatomic) NSString *displayName; //!< Depending on type, returns user.displayName or group.name. Adds " (shareWithAdditionalInfo)" if shareWithAdditionalInfo is available.

@property(nullable,strong) NSString *searchResultName; //!< For recipient search results, the name provided from the server via "shareWithAdditionalInfo" where available

@property(assign) OCIdentityMatchType matchType;

+ (instancetype)identityWithUser:(OCUser *)user;
+ (instancetype)identityWithGroup:(OCGroup *)group;

- (instancetype)withSearchResultName:(nullable NSString *)searchResultName;

@end

// NSCoding compatibility shim following OCRecipient -> OCIdentity refactoring
@interface OCRecipient : OCIdentity
@end

NS_ASSUME_NONNULL_END
