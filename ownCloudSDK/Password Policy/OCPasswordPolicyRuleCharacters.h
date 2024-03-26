//
//  OCPasswordPolicyRuleCharacters.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 14.02.24.
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

#import <ownCloudSDK/ownCloudSDK.h>

NS_ASSUME_NONNULL_BEGIN

@interface OCPasswordPolicyRuleCharacters : OCPasswordPolicyRule

@property(strong,nullable) NSString *localizedName; //!< A localized description of the matching characters. F.ex. "upper-case characters"

@property(strong,nullable) NSString *validCharacters; //!< A string with valid characters.
@property(strong,nullable) NSCharacterSet *validCharactersSet; //!< A character set with all valid characters. This can be wider than .validCharacters.

@property(strong,nullable) NSNumber *minimumCount; //!< The minimum number of matching characters required by this rule.
@property(strong,nullable) NSNumber *maximumCount; //!< The maximum number of matching characters allowed by this rule.

- (instancetype)initWithCharacters:(nullable NSString *)characters characterSet:(nullable NSCharacterSet *)characterSet minimumCount:(nullable NSNumber *)minimumCount maximumCount:(nullable NSNumber *)maximumCount localizedDescription:(nullable NSString *)localizedDescription localizedName:(NSString *)localizedName;

- (NSUInteger)charactersMatchCountIn:(NSString *)password; //!< Returns the number of characters matching the rule

@end

NS_ASSUME_NONNULL_END
