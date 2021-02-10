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

typedef NSString* OCClassSettingsUserPreferencesMigrationIdentifier;
typedef NSNumber* OCClassSettingsUserPreferencesMigrationVersion;

@protocol OCClassSettingsUserPreferencesSupport

@optional
+ (BOOL)allowUserPreferenceForClassSettingsKey:(OCClassSettingsKey)key; //!< If implemented, preferences for the provided key are only allowed to be changed by the user if this method returns YES. If this method is not implemented, the decision hinges on the flags provided in metadata.

@end

@interface OCClassSettingsUserPreferences : NSObject <OCClassSettingsSource, OCClassSettingsSupport>

@property(class,readonly,nonatomic,strong) OCClassSettingsUserPreferences *sharedUserPreferences;

- (BOOL)setValue:(nullable id<NSSecureCoding>)value forClassSettingsKey:(OCClassSettingsKey)key ofClass:(Class<OCClassSettingsSupport>)theClass;
- (BOOL)userAllowedToSetKey:(OCClassSettingsKey)key ofClass:(Class<OCClassSettingsSupport>)theClass;

#pragma mark - Versioned migration of settings
+ (void)migrateWithIdentifier:(OCClassSettingsUserPreferencesMigrationIdentifier)identifier version:(OCClassSettingsUserPreferencesMigrationVersion)version silent:(BOOL)silent perform:(NSError * _Nullable (^)(OCClassSettingsUserPreferencesMigrationVersion _Nullable lastMigrationVersion))migration;

@end

@interface NSObject (OCClassSettingsUserPreferences)

+ (BOOL)userAllowedToSetPreferenceValueForClassSettingsKey:(OCClassSettingsKey)key;
- (BOOL)userAllowedToSetPreferenceValueForClassSettingsKey:(OCClassSettingsKey)key;

+ (BOOL)setUserPreferenceValue:(nullable id<NSSecureCoding>)value forClassSettingsKey:(OCClassSettingsKey)key;
- (BOOL)setUserPreferenceValue:(nullable id<NSSecureCoding>)value forClassSettingsKey:(OCClassSettingsKey)key;

@end

extern OCClassSettingsSourceIdentifier OCClassSettingsSourceIdentifierUserPreferences;

extern OCClassSettingsKey OCClassSettingsKeyUserPreferencesAllow;
extern OCClassSettingsKey OCClassSettingsKeyUserPreferencesDisallow;
extern OCClassSettingsIdentifier OCClassSettingsIdentifierUserPreferences;

NS_ASSUME_NONNULL_END
