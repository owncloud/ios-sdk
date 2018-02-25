//
//  NSObject+OCClassSettings.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 25.02.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import "NSObject+OCClassSettings.h"

@implementation NSObject (OCClassSettings)

- (id)classSettingForOCClassSettingsKey:(OCClassSettingsKey)key
{
	if (key==nil) { return(nil); }

	return ([[[OCClassSettings sharedSettings] settingsForClass:[self class]] objectForKey:key]);
}

@end
