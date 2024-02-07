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
#import "OCLocale.h"
#import "OCLocaleFilterVariables.h"

@implementation OCCapabilities (PasswordPolicy)

- (OCPasswordPolicy *)passwordPolicy
{
	NSMutableArray<OCPasswordPolicyRule *> *rules = [NSMutableArray new];

	if (!self.passwordPolicyEnabled)
	{
		// No password policy included, return nil
		return (nil);
	}

	// Minimum and maximum length
	if ((self.passwordPolicyMinCharacters != nil) ||
	    (self.passwordPolicyMaxCharacters != nil))
	{
		[rules addObject:[OCPasswordPolicyRule characterCountMinimum:self.passwordPolicyMinCharacters maximum:self.passwordPolicyMaxCharacters]];
	}

	// Minimum lower-case characters
	if (self.passwordPolicyMinLowerCaseCharacters != nil)
	{
		[rules addObject:[OCPasswordPolicyRule lowercaseCharactersMinimum:self.passwordPolicyMinLowerCaseCharacters maximum:nil]];
	}

	// Minimum upper-case characters
	if (self.passwordPolicyMinUpperCaseCharacters != nil)
	{
		[rules addObject:[OCPasswordPolicyRule uppercaseCharactersMinimum:self.passwordPolicyMinUpperCaseCharacters maximum:nil]];
	}

	// Minimum digits
	if (self.passwordPolicyMinDigits != nil)
	{
		[rules addObject:[OCPasswordPolicyRule digitsMinimum:self.passwordPolicyMinDigits maximum:nil]];
	}

	// Minimum special characters
	if ((self.passwordPolicyMinSpecialCharacters != nil) && (self.passwordPolicySpecialCharacters != nil))
	{
		[rules addObject:[OCPasswordPolicyRule specialCharacters:self.passwordPolicySpecialCharacters minimum:self.passwordPolicyMinSpecialCharacters]];
	}

	return ([[OCPasswordPolicy alloc] initWithRules:rules]);
}

@end
