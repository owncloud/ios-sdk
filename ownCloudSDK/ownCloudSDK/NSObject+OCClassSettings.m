//
//  NSObject+OCClassSettings.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 25.02.18.
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

#import "NSObject+OCClassSettings.h"

@implementation NSObject (OCClassSettings)

- (id)classSettingForOCClassSettingsKey:(OCClassSettingsKey)key
{
	if (key==nil) { return(nil); }

	return ([[[OCClassSettings sharedSettings] settingsForClass:[self class]] objectForKey:key]);
}

@end
