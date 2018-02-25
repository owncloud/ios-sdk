//
//  NSObject+OCClassSettings.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 25.02.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OCClassSettings.h"

@interface NSObject (OCClassSettings)

- (id)classSettingForOCClassSettingsKey:(OCClassSettingsKey)key;

@end
