//
//  NSString+OCClassSettings.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 23.10.20.
//  Copyright © 2020 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2020, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "NSString+OCClassSettings.h"

@implementation NSString (OCClassSettings)

+ (instancetype)flatIdentifierFromIdentifier:(OCClassSettingsIdentifier)identifier key:(OCClassSettingsKey)key
{
	return ([NSString stringWithFormat:@"%@.%@", identifier, key]);
}

- (OCClassSettingsIdentifier)classSettingsIdentifier
{
	NSRange dotRange = [self rangeOfString:@"."];

	if (dotRange.location != NSNotFound)
	{
		return ([self substringToIndex:dotRange.location]);
	}

	return (nil);
}

- (OCClassSettingsKey)classSettingsKey
{
	NSRange dotRange = [self rangeOfString:@"."];

	if (dotRange.location != NSNotFound)
	{
		return ([self substringFromIndex:dotRange.location+1]);
	}

	return (nil);
}

@end
