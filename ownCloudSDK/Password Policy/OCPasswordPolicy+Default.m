//
//  OCPasswordPolicy+Default.m
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

#import "OCPasswordPolicy+Default.h"
#import "OCPasswordPolicyRule+StandardRules.h"

@implementation OCPasswordPolicy (Default)

+ (OCPasswordPolicy *)defaultPolicy
{
	return ([[OCPasswordPolicy alloc] initWithRules:@[
		// Defaults as per https://github.com/owncloud/web/blob/master/packages/web-pkg/src/services/passwordPolicy/passwordPolicy.ts#L51
		[OCPasswordPolicyRule characterCountMinimum:@(12) maximum:nil],
		[OCPasswordPolicyRule lowercaseCharactersMinimum:@(2) maximum:nil],
		[OCPasswordPolicyRule uppercaseCharactersMinimum:@(2) maximum:nil],
		[OCPasswordPolicyRule digitsMinimum:@(2) maximum:nil],
		[OCPasswordPolicyRule specialCharacters:@" !\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~" minimum:@(2)] // special characters as per https://owasp.org/www-community/password-special-characters
	]]);
}

@end
