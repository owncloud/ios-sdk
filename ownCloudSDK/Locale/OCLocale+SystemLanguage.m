//
//  OCLocale+SystemLanguage.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 20.10.22.
//  Copyright © 2022 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2022, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCLocale+SystemLanguage.h"

@implementation OCLocale (SystemLanguage)

#pragma mark - Locale
- (NSString *)acceptLanguageString
{
	NSArray <NSString *> *preferredLocalizations = [NSBundle preferredLocalizationsFromArray:NSBundle.mainBundle.localizations forPreferences:nil];

	if (preferredLocalizations.count > 0)
	{
		NSString *acceptLanguage;
		NSMutableArray<NSString *> *iso6391Languages = [NSMutableArray new];

		for (NSString *preferredLocalization in preferredLocalizations)
		{
			if (preferredLocalization.length > 2)
			{
				// Ensure that codes are formatted correctly (f.ex. en-US rather than en_US)
				[iso6391Languages addObject:[preferredLocalization stringByReplacingOccurrencesOfString:@"_" withString:@"-"]];
			}
			else
			{
				[iso6391Languages addObject:preferredLocalization];
			}
		}

		if ((acceptLanguage = [iso6391Languages componentsJoinedByString:@","].lowercaseString) != nil)
		{
			return (acceptLanguage);
		}
	}

	return (nil);
}

- (NSString *)primaryUserLanguage
{
	return ([NSBundle preferredLocalizationsFromArray:[[NSBundle mainBundle] localizations] forPreferences:nil].firstObject.lowercaseString);
}

@end
