//
//  OCCapabilities+PasswordPolicy.m
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

#import "OCCapabilities+PasswordPolicy.h"

#import "OCPasswordPolicy.h"
#import "OCPasswordPolicyRule.h"
#import "OCPasswordPolicyRule+StandardRules.h"

#import "OCMacros.h"
#import "OCPasswordPolicyRuleByteLength.h"

@implementation OCCapabilities (PasswordPolicy)

- (OCPasswordPolicy *)passwordPolicy
{
	NSMutableArray<OCPasswordPolicyRule *> *rules = [NSMutableArray new];
	BOOL hasCharacterBasedRule = NO;

	if (!self.passwordPolicyEnabled)
	{
		// No password policy included, return nil
		return (nil);
	}

	// Minimum and maximum length
	if (((self.passwordPolicyMinCharacters != nil) && (self.passwordPolicyMinCharacters.intValue > 0)) ||
	    (self.passwordPolicyMaxCharacters != nil))
	{
		[rules addObject:[OCPasswordPolicyRule characterCountMinimum:self.passwordPolicyMinCharacters maximum:self.passwordPolicyMaxCharacters]];
	}

	// Minimum lower-case characters
	if ((self.passwordPolicyMinLowerCaseCharacters != nil) && (self.passwordPolicyMinLowerCaseCharacters.intValue > 0))
	{
		[rules addObject:[OCPasswordPolicyRule lowercaseCharactersMinimum:self.passwordPolicyMinLowerCaseCharacters maximum:nil]];
		hasCharacterBasedRule = YES;
	}

	// Minimum upper-case characters
	if ((self.passwordPolicyMinUpperCaseCharacters != nil) && (self.passwordPolicyMinUpperCaseCharacters.intValue > 0))
	{
		[rules addObject:[OCPasswordPolicyRule uppercaseCharactersMinimum:self.passwordPolicyMinUpperCaseCharacters maximum:nil]];
		hasCharacterBasedRule = YES;
	}

	// Minimum digits
	if ((self.passwordPolicyMinDigits != nil) && (self.passwordPolicyMinDigits.intValue > 0))
	{
		[rules addObject:[OCPasswordPolicyRule digitsMinimum:self.passwordPolicyMinDigits maximum:nil]];
		hasCharacterBasedRule = YES;
	}

	// Minimum special characters
	if ((self.passwordPolicyMinSpecialCharacters != nil) && (self.passwordPolicyMinSpecialCharacters.intValue > 0) && (self.passwordPolicySpecialCharacters != nil))
	{
		[rules addObject:[OCPasswordPolicyRule specialCharacters:self.passwordPolicySpecialCharacters minimum:self.passwordPolicyMinSpecialCharacters]];
		hasCharacterBasedRule = YES;
	}

	// Add character-based rules for generation if missing
	if (!hasCharacterBasedRule)
	{
		// Only lengths provided, no character based rules so far - add rules for generator
		[rules addObjectsFromArray:@[
			[OCPasswordPolicyRule lowercaseCharactersMinimum:@(0) maximum:nil],
			[OCPasswordPolicyRule uppercaseCharactersMinimum:@(0) maximum:nil],
			[OCPasswordPolicyRule digitsMinimum:@(0) maximum:nil],
		]];

		if (self.passwordPolicySpecialCharacters.length > 0)
		{
			[rules addObject:[OCPasswordPolicyRule specialCharacters:self.passwordPolicySpecialCharacters minimum:@(0)]];
		}
	}

	// Limit number of bytes
	[rules addObject:OCPasswordPolicyRuleByteLength.defaultRule];

	return ([[OCPasswordPolicy alloc] initWithRules:rules]);
}

@end
