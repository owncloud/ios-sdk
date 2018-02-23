//
//  OCClassSettings.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 23.02.18.
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

#import "OCClassSettings.h"

@implementation OCClassSettings

+ (instancetype)sharedSettings
{
	static dispatch_once_t onceToken;
	static OCClassSettings *sharedClassSettings = nil;
	
	dispatch_once(&onceToken, ^{
		sharedClassSettings = [OCClassSettings new];
	});
	
	return(sharedClassSettings);
}

- (NSDictionary<NSString *, id> *)settingsForClass:(Class<OCClassSettingsSupport>)settingsClass
{
	NSDictionary<NSString *, id> *classSettings = nil;
	OCClassSettingsIdentifier classSettingsIdentifier;
	
	if ((classSettingsIdentifier = [settingsClass classSettingsIdentifier]) != nil)
	{
		classSettings = [settingsClass defaultSettingsForIdentifier:classSettingsIdentifier];
	}
	
	return (classSettings);
}

@end
