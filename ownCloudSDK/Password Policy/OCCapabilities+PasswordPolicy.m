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
		[rules addObject:[[OCPasswordPolicyRule alloc] initWithCharacters:nil characterSet:nil minimumCount:self.passwordPolicyMinCharacters maximumCount:self.passwordPolicyMaxCharacters localizedDescription:nil localizedName:OCLocalized(@"characters")]];
	}

	// Minimum lower-case characters
	if (self.passwordPolicyMinLowerCaseCharacters != nil)
	{
		[rules addObject:[[OCPasswordPolicyRule alloc] initWithCharacters:@"abcdefghijklmnopqrstuvwxyz" characterSet:NSCharacterSet.lowercaseLetterCharacterSet minimumCount:self.passwordPolicyMinLowerCaseCharacters maximumCount:nil localizedDescription:nil localizedName:OCLocalized(@"lower-case characters")]];
	}

	// Minimum upper-case characters
	if (self.passwordPolicyMinUpperCaseCharacters != nil)
	{
		[rules addObject:[[OCPasswordPolicyRule alloc] initWithCharacters:@"ABCDEFGHIJKLMNOPQRSTUVWXYZ" characterSet:NSCharacterSet.uppercaseLetterCharacterSet minimumCount:self.passwordPolicyMinUpperCaseCharacters maximumCount:nil localizedDescription:nil localizedName:OCLocalized(@"upper-case characters")]];
	}

	// Minimum digits
	if (self.passwordPolicyMinDigits != nil)
	{
		[rules addObject:[[OCPasswordPolicyRule alloc] initWithCharacters:@"1234567890" characterSet:NSCharacterSet.decimalDigitCharacterSet minimumCount:self.passwordPolicyMinDigits maximumCount:nil localizedDescription:nil localizedName:@"digits"]];
	}

	// Minimum special characters
	if ((self.passwordPolicyMinSpecialCharacters != nil) && (self.passwordPolicySpecialCharacters != nil))
	{
		[rules addObject:[[OCPasswordPolicyRule alloc] initWithCharacters:self.passwordPolicySpecialCharacters characterSet:nil minimumCount:self.passwordPolicyMinSpecialCharacters maximumCount:nil localizedDescription:OCLocalizedFormat(@"At least {{min}} special characters: {{specialCharacters}}", (@{
			@"min" : self.passwordPolicyMinSpecialCharacters.stringValue,
			@"specialCharacters" : self.passwordPolicySpecialCharacters
		})) localizedName:@"special characters"]];
	}

	return ([[OCPasswordPolicy alloc] initWithRules:rules]);
}

@end
