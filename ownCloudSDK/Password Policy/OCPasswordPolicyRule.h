//
//  OCPasswordPolicyRule.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 06.02.24.
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

NS_ASSUME_NONNULL_BEGIN

@interface OCPasswordPolicyRule : NSObject

@property(strong,nullable) NSString *validCharacters; //!< A string with valid characters.
@property(strong,nullable) NSCharacterSet *validCharactersSet; //!< A character set with all valid characters. This can be wider than .validCharacters.

@property(strong,nullable) NSNumber *minimumCount; //!< The minimum number of matching characters required by this rule.
@property(strong,nullable) NSNumber *maximumCount; //!< The maximum number of matching characters allowed by this rule.

@property(strong,nullable) NSString *localizedDescription; //!< A localized description of the rule. F.ex. "At least %@ upper-case characters"
@property(strong,nullable) NSString *localizedName; //!< A localized description of the matching characters. F.ex. "upper-case characters"

- (instancetype)initWithCharacters:(nullable NSString *)characters characterSet:(nullable NSCharacterSet *)characterSet minimumCount:(nullable NSNumber *)minimumCount maximumCount:(nullable NSNumber *)maximumCount localizedDescription:(nullable NSString *)localizedDescription localizedName:(NSString *)localizedName;

- (NSUInteger)charactersMatchCountIn:(NSString *)password; //!< Returns the number of characters matching the rule
- (nullable NSString *)validate:(NSString *)password; //!< Validates the password against the rule. If the password satisfies the rule, nil is returned, otherwise a localized description of the error that can be presented to the user as a hint.

@end

NS_ASSUME_NONNULL_END
