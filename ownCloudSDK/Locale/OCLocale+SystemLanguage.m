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
	NSArray <NSString *> *preferredLocalizations = [NSBundle preferredLocalizationsFromArray:[[NSBundle mainBundle] localizations] forPreferences:nil];

	if (preferredLocalizations.count > 0)
	{
		NSString *acceptLanguage;

		if ((acceptLanguage = [[preferredLocalizations componentsJoinedByString:@", "] lowercaseString]) != nil)
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
