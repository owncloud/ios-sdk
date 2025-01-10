//
//  OCAvatar.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 29.09.20.
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

#import <Foundation/Foundation.h>
#import "OCImage.h"
#import "OCTypes.h"
#import "OCUser.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCAvatar : OCImage <NSSecureCoding>

@property(class,nonatomic,readonly) CGSize defaultSize;

@property(strong,nullable) OCUniqueUserIdentifier uniqueUserIdentifier;
@property(strong,nullable) OCFileETag eTag;

@property(strong,nullable) NSDate *timestamp;

@end

NS_ASSUME_NONNULL_END
