//
//  OCClassSettingsFlatSource.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 22.03.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2018, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCClassSettingsFlatSource.h"

@implementation OCClassSettingsFlatSource

- (OCClassSettingsSourceIdentifier)settingsSourceIdentifier
{
	return (@"flat");
}

- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		[self parseFlatSettingsDictionary];
	}

	return (self);
}

- (void)parseFlatSettingsDictionary
{
	NSDictionary<NSString *, id> *flatSettingsDict;

	_settingsByKeyByIdentifier = nil;

	if ((flatSettingsDict = [self flatSettingsDictionary]) != nil)
	{
		[flatSettingsDict enumerateKeysAndObjectsUsingBlock:^(NSString *combinedKey, id value, BOOL * _Nonnull stop) {
			NSRange dotRange = [combinedKey rangeOfString:@"."];

			if (dotRange.location != NSNotFound)
			{
				NSString *identifier = [combinedKey substringToIndex:dotRange.location];
				NSString *key = [combinedKey substringFromIndex:dotRange.location+1];

				if ((identifier != nil) && (key != nil))
				{
					if (self->_settingsByKeyByIdentifier == nil) { self->_settingsByKeyByIdentifier = [NSMutableDictionary new]; }
					if (self->_settingsByKeyByIdentifier[identifier] == nil) { self->_settingsByKeyByIdentifier[identifier] = [NSMutableDictionary new]; }

					self->_settingsByKeyByIdentifier[identifier][key] = value;
				}
			}
		}];
	}
}

- (nullable NSDictionary<NSString *, id> *)flatSettingsDictionary
{
	return(@{});
}

- (NSDictionary<NSString *,id> *)settingsForIdentifier:(OCClassSettingsIdentifier)identifier
{
	if (identifier != nil)
	{
		return (_settingsByKeyByIdentifier[identifier]);
	}

	return (nil);
}

@end
