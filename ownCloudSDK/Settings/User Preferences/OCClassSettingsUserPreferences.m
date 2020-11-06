//
//  OCClassSettingsUserPreferences.m
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

#import "OCClassSettingsUserPreferences.h"
#import "OCAppIdentity.h"
#import "OCKeyValueStore.h"
#import "OCMacros.h"

@implementation OCClassSettingsUserPreferences

+ (instancetype)sharedUserPreferences
{
	static dispatch_once_t onceToken;
	static OCClassSettingsUserPreferences *sharedClassSettingsUserPreferences;
	dispatch_once(&onceToken, ^{
		sharedClassSettingsUserPreferences = [OCClassSettingsUserPreferences new];
	});

	return (sharedClassSettingsUserPreferences);
}

- (NSMutableDictionary<OCClassSettingsIdentifier, NSDictionary<OCClassSettingsKey, id> *> *)mainDictionary
{
	NSDictionary<OCClassSettingsIdentifier, NSDictionary<OCClassSettingsKey, id> *> *mainDictionaryReadOnly;

	if ((mainDictionaryReadOnly = [OCAppIdentity.sharedAppIdentity.userDefaults dictionaryForKey:@"org.owncloud.user-settings"]) != nil)
	{
		return ([mainDictionaryReadOnly mutableCopy]);
	}

	return ([NSMutableDictionary new]);
}

- (void)setMainDictionary:(NSMutableDictionary<OCClassSettingsIdentifier, NSDictionary<OCClassSettingsKey, id> *> *)mainDictionary
{
	[OCAppIdentity.sharedAppIdentity.userDefaults setObject:mainDictionary forKey:@"org.owncloud.user-settings"];
}

- (nullable NSDictionary<OCClassSettingsKey, id> *)settingsForIdentifier:(OCClassSettingsIdentifier)classSettingsIdentifier
{
	return (self.mainDictionary[classSettingsIdentifier]);
}

- (nonnull OCClassSettingsSourceIdentifier)settingsSourceIdentifier
{
	return (OCClassSettingsSourceIdentifierUserPreferences);
}

- (BOOL)setValue:(id<NSSecureCoding>)value forClassSettingsKey:(OCClassSettingsKey)key ofClass:(Class<OCClassSettingsSupport>)theClass
{
	OCClassSettingsIdentifier classSettingsIdentifier;
	BOOL changeAllowed = NO;

	if ([theClass conformsToProtocol:@protocol(OCClassSettingsUserPreferencesSupport)] && [theClass conformsToProtocol:@protocol(OCClassSettingsSupport)])
	{
		if ([theClass respondsToSelector:@selector(allowUserPreferenceForClassSettingsKey:)])
		{
			changeAllowed = [(Class<OCClassSettingsUserPreferencesSupport>)theClass allowUserPreferenceForClassSettingsKey:key];
		}
		else
		{
			changeAllowed = YES;
		}

		if (changeAllowed)
		{
			if ((classSettingsIdentifier = [theClass classSettingsIdentifier]) != nil)
			{
				[self setValue:value forClassSettingsKey:key classSettingsIdentifier:classSettingsIdentifier];
			}

			[OCClassSettings.sharedSettings clearSourceCache];
		}
	}

	return (changeAllowed);
}

- (void)setValue:(id<NSSecureCoding>)value forClassSettingsKey:(OCClassSettingsKey)key classSettingsIdentifier:(OCClassSettingsIdentifier)classSettingsIdentifier
{
	NSMutableDictionary<OCClassSettingsIdentifier, NSDictionary<OCClassSettingsKey, id> *> *mainDictionary = [self mainDictionary];
	NSMutableDictionary<OCClassSettingsKey, id> *classSettingsDictionary = nil;

	if ((classSettingsDictionary = [mainDictionary[classSettingsIdentifier] mutableCopy]) == nil)
	{
		classSettingsDictionary = [NSMutableDictionary new];
	}

	mainDictionary[classSettingsIdentifier] = classSettingsDictionary;

	if (value != nil)
	{
		classSettingsDictionary[key] = value;
	}
	else
	{
		[classSettingsDictionary removeObjectForKey:key];
	}

	if (classSettingsDictionary.count == 0)
	{
		[mainDictionary removeObjectForKey:classSettingsIdentifier];
	}

	self.mainDictionary = mainDictionary;
}

#pragma mark - Versioned migration of settings
+ (void)migrateWithIdentifier:(OCClassSettingsUserPreferencesMigrationIdentifier)identifier version:(OCClassSettingsUserPreferencesMigrationVersion)version silent:(BOOL)silent perform:(NSError * _Nullable (^)(OCClassSettingsUserPreferencesMigrationVersion _Nullable lastMigrationVersion))migration
{
	static OCKeyValueStore *migrationsStorage = nil;
	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		NSURL *migrationsKVSURL;

		if ((migrationsKVSURL = [OCAppIdentity.sharedAppIdentity.appGroupContainerURL URLByAppendingPathComponent:@"migrations.dat"]) != nil)
		{
			migrationsStorage = [[OCKeyValueStore alloc] initWithURL:migrationsKVSURL identifier:@"migrations.global"];
		}
	});

	[migrationsStorage updateObjectForKey:identifier usingModifier:^id _Nullable(id  _Nullable existingObject, BOOL * _Nonnull outDidModify) {
		NSNumber *lastMigrationVersion = OCTypedCast(existingObject, NSNumber);

		if (![lastMigrationVersion isEqual:version] && (lastMigrationVersion.integerValue < version.integerValue))
		{
			NSError *error;

			if ((error = migration(lastMigrationVersion)) == nil)
			{
				*outDidModify = YES;
				if (!silent)
				{
					OCLog(@"Migration %@ from version %@ to %@ succeeded", identifier, lastMigrationVersion, version);
				}
				return(version);
			}

			if (!silent)
			{
				OCLogError(@"Migration %@ from version %@ to %@ failed with error=%@", identifier, lastMigrationVersion, version, error);
			}
		}

		*outDidModify = NO;
		return (existingObject);
	}];
}

@end

@implementation NSObject (OCClassSettingsUserPreferences)

+ (BOOL)setUserPreferenceValue:(id<NSSecureCoding>)value forClassSettingsKey:(OCClassSettingsKey)key
{
	return ([OCClassSettingsUserPreferences.sharedUserPreferences setValue:value forClassSettingsKey:key ofClass:self]);
}

@end

OCClassSettingsSourceIdentifier OCClassSettingsSourceIdentifierUserPreferences = @"user-prefs";
