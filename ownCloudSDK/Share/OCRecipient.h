//
//  OCRecipient.h
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

typedef NS_ENUM(NSUInteger, OCRecipientType) {
	OCRecipientTypeUser,
	OCRecipientTypeGroup
};

@interface OCRecipient : NSObject

@property(assign) OCRecipientType type;

@property(nullable,strong) OCGroup *group;
@property(nullable,strong) OCUser *user;

+ (instancetype)recipientWithUser:(OCUser *)user;
+ (instancetype)recipientWithGroup:(OCGroup *)group;

@end

NS_ASSUME_NONNULL_END
