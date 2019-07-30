//
//  OCClassSettingsUserPreferences.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 30.07.19.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2019, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCClassSettings.h"

NS_ASSUME_NONNULL_BEGIN

@protocol OCClassSettingsUserPreferencesSupport

@optional
+ (BOOL)allowUserPreferenceForClassSettingsKey:(OCClassSettingsKey)key;

@end

@interface OCClassSettingsUserPreferences : NSObject <OCClassSettingsSource>

@property(class,readonly,nonatomic,strong) OCClassSettingsUserPreferences *sharedUserPreferences;

- (BOOL)setValue:(nullable id<NSSecureCoding>)value forClassSettingsKey:(OCClassSettingsKey)key ofClass:(Class<OCClassSettingsSupport>)theClass;

@end

@interface NSObject (OCClassSettingsUserPreferences)

+ (BOOL)setUserPreferenceValue:(nullable id<NSSecureCoding>)value forClassSettingsKey:(OCClassSettingsKey)key;

@end

NS_ASSUME_NONNULL_END
