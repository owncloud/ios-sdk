//
//  OCServerInstance.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 07.03.23.
//  Copyright © 2023 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2023, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCServerInstance.h"

@implementation OCServerInstance

@dynamic localizedTitle;

- (instancetype)initWithURL:(NSURL *)url
{
	if ((self = [super init]) != nil)
	{
		_url = url;
	}

	return (self);
}

- (NSString *)localizedTitle
{
	if (_titlesByLanguageCode != nil)
	{
		NSString *preferredLanguage;

		if ((preferredLanguage = [NSBundle preferredLocalizationsFromArray:_titlesByLanguageCode.allKeys].firstObject) != nil) {
			return (_titlesByLanguageCode[preferredLanguage]);
		};

		return (_titlesByLanguageCode.allValues.firstObject);
	}

	return (nil);
}

@end
