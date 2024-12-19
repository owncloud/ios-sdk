//
//  OCIdentity+GraphAPI.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 16.12.24.
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

#import "OCIdentity.h"

@class GASharePointIdentitySet;
@class GAIdentitySet;
@class GAIdentity;

NS_ASSUME_NONNULL_BEGIN

@interface OCIdentity (GraphAPI)

+ (nullable instancetype)identityFromGAIdentitySet:(GAIdentitySet *)identitySet;
+ (nullable instancetype)identityFromGASharePointIdentitySet:(GASharePointIdentitySet *)identitySet;

@property(readonly,nullable,nonatomic) GAIdentitySet *gaIdentitySet;
@property(readonly,nullable,nonatomic) GAIdentity *gaIdentity;

@end

NS_ASSUME_NONNULL_END
