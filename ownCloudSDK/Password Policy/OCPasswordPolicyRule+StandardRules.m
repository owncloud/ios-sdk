//
//  OCPasswordPolicyRule+StandardRules.m
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

#import "OCPasswordPolicyRule+StandardRules.h"
#import "OCPasswordPolicyRuleCharacters.h"
#import "OCMacros.h"
#import "OCLocale.h"
#import "OCLocaleFilterVariables.h"

@implementation OCPasswordPolicyRule (StandardRules)

+ (nullable OCPasswordPolicyRule *)characterCountMinimum:(nullable NSNumber *)minimum maximum:(nullable NSNumber *)maximum
{
	if ((minimum != nil) || (maximum != nil))
	{
		return ([[OCPasswordPolicyRuleCharacters alloc] initWithCharacters:nil characterSet:nil minimumCount:minimum maximumCount:maximum localizedDescription:nil localizedName:OCLocalized(@"characters")]);
	}

	return (nil);
}

+ (nullable OCPasswordPolicyRule *)lowercaseCharactersMinimum:(nullable NSNumber *)minimum maximum:(nullable NSNumber *)maximum
{
	if ((minimum != nil) || (maximum != nil))
	{
		return ([[OCPasswordPolicyRuleCharacters alloc] initWithCharacters:@"abcdefghijklmnopqrstuvwxyz" characterSet:NSCharacterSet.lowercaseLetterCharacterSet minimumCount:minimum maximumCount:maximum localizedDescription:nil localizedName:OCLocalized(@"lower-case characters")]);
	}

	return (nil);
}

+ (nullable OCPasswordPolicyRule *)uppercaseCharactersMinimum:(nullable NSNumber *)minimum maximum:(nullable NSNumber *)maximum
{
	if ((minimum != nil) || (maximum != nil))
	{
		return ([[OCPasswordPolicyRuleCharacters alloc] initWithCharacters:@"ABCDEFGHIJKLMNOPQRSTUVWXYZ" characterSet:NSCharacterSet.uppercaseLetterCharacterSet minimumCount:minimum maximumCount:maximum localizedDescription:nil localizedName:OCLocalized(@"upper-case characters")]);
	}

	return (nil);
}

+ (nullable OCPasswordPolicyRule *)digitsMinimum:(nullable NSNumber *)minimum maximum:(nullable NSNumber *)maximum
{
	if ((minimum != nil) || (maximum != nil))
	{
		return ([[OCPasswordPolicyRuleCharacters alloc] initWithCharacters:@"1234567890" characterSet:NSCharacterSet.decimalDigitCharacterSet minimumCount:minimum maximumCount:maximum localizedDescription:nil localizedName:OCLocalized(@"digits")]);
	}

	return (nil);
}

+ (nullable OCPasswordPolicyRule *)specialCharacters:(NSString *)specialCharacters minimum:(NSNumber *)minimum
{
	if ((minimum != nil) && (specialCharacters != nil))
	{
		return ([[OCPasswordPolicyRuleCharacters alloc] initWithCharacters:specialCharacters characterSet:nil minimumCount:minimum maximumCount:nil localizedDescription:OCLocalizedFormat(@"At least {{min}} special characters: {{specialCharacters}}", (@{
			@"min" : minimum.stringValue,
			@"specialCharacters" : specialCharacters
		})) localizedName:OCLocalized(@"special characters")]);
	}

	return (nil);
}

@end
