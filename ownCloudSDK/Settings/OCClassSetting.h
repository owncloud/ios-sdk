//
//  OCClassSetting.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 19.11.20.
//  Copyright © 2020 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2020, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import <Foundation/Foundation.h>
#import "OCClassSettings.h"

NS_ASSUME_NONNULL_BEGIN

@class OCClassSetting;

typedef NS_OPTIONS(NSInteger, OCClassSettingChangeType)
{
	OCClassSettingChangeTypeNone = 0,

	OCClassSettingChangeTypeInitial = (1<<0),
	OCClassSettingChangeTypeValue = (1<<1),
	OCClassSettingChangeTypeIsUserConfigurable = (1<<2)
};

typedef void(^OCClassSettingObserver)(id owner, OCClassSetting *setting, OCClassSettingChangeType type, id _Nullable oldValue, id _Nullable newValue);

@interface OCClassSetting : NSObject

@property(strong,readonly) OCClassSettingsFlatIdentifier identifier;

@property(strong,readonly) Class settingsClass;
@property(strong,readonly) OCClassSettingsIdentifier settingsIdentifier;
@property(strong,readonly) OCClassSettingsKey settingsKey;

#pragma mark - Convenience
@property(nonatomic,readonly) BOOL isUserConfigurable;

#pragma mark - Initializers
+ (nullable instancetype)settingForClass:(Class<OCClassSettingsSupport>)settingsClass key:(OCClassSettingsKey)key;

#pragma mark - Observation
- (void)addObserver:(OCClassSettingObserver)observer withOwner:(id)owner;
- (void)removeAllObserversForOwner:(id)owner;

@end

@interface NSObject (OCClassSetting)

+ (nullable OCClassSetting *)classSettingForKey:(OCClassSettingsKey)key;
- (nullable OCClassSetting *)classSettingForKey:(OCClassSettingsKey)key;

@end

NS_ASSUME_NONNULL_END
