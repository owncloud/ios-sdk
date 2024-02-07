//
//  OCPasswordPolicyRule+StandardRules.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 07.02.24.
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

#import <Foundation/Foundation.h>
#import "OCPasswordPolicyRule.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCPasswordPolicyRule (StandardRules)

+ (nullable OCPasswordPolicyRule *)characterCountMinimum:(nullable NSNumber *)minimum maximum:(nullable NSNumber *)maximum;
+ (nullable OCPasswordPolicyRule *)lowercaseCharactersMinimum:(nullable NSNumber *)minimum maximum:(nullable NSNumber *)maximum;
+ (nullable OCPasswordPolicyRule *)uppercaseCharactersMinimum:(nullable NSNumber *)minimum maximum:(nullable NSNumber *)maximum;
+ (nullable OCPasswordPolicyRule *)digitsMinimum:(nullable NSNumber *)minimum maximum:(nullable NSNumber *)maximum;
+ (nullable OCPasswordPolicyRule *)specialCharacters:(NSString *)specialCharacters minimum:(NSNumber *)minimum;

@end

NS_ASSUME_NONNULL_END
