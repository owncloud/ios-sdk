//
//  OCClassSettingsFlatSourceManagedConfiguration.m
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

#import "OCClassSettingsFlatSourceManagedConfiguration.h"

@implementation OCClassSettingsFlatSourceManagedConfiguration

- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		// As per https://developer.apple.com/business/documentation/MDM-Protocol-Reference.pdf (page 70), NSUserDefaultsDidChangeNotification is posted
		// when MDMs push new settings
		[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(_userDefaultsChanged:) name:NSUserDefaultsDidChangeNotification object:nil];
	}

	return (self);
}

- (void)dealloc
{
	[NSNotificationCenter.defaultCenter removeObserver:self name:NSUserDefaultsDidChangeNotification object:nil];
}

- (void)_userDefaultsChanged:(NSNotification *)notification
{
	[NSNotificationCenter.defaultCenter postNotificationName:OCClassSettingsChangedNotification object:nil];
}

- (OCClassSettingsSourceIdentifier)settingsSourceIdentifier
{
	return (OCClassSettingsSourceIdentifierManaged);
}

- (NSDictionary <OCClassSettingsFlatIdentifier, id> *)flatSettingsDictionary
{
	return ([[NSUserDefaults standardUserDefaults] dictionaryForKey:@"com.apple.configuration.managed"]);
}

@end

OCClassSettingsSourceIdentifier OCClassSettingsSourceIdentifierManaged = @"managed";
