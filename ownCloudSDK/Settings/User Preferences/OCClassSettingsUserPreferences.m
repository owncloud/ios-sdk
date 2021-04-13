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
#import "OCClassSettings+Metadata.h"
#import "OCAppIdentity.h"
#import "OCKeyValueStore.h"
#import "OCMacros.h"
#import "NSString+OCClassSettings.h"

static OCIPCNotificationName OCIPCNotificationNameClassSettingsUserPreferencesChanged = @"com.owncloud.class-settings.user-preferences.changed";

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

- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		[OCIPNotificationCenter.sharedNotificationCenter addObserver:self forName:OCIPCNotificationNameClassSettingsUserPreferencesChanged withHandler:^(OCIPNotificationCenter * _Nonnull notificationCenter, id  _Nonnull observer, OCIPCNotificationName  _Nonnull notificationName) {
			[OCClassSettings.sharedSettings clearSourceCache];
			[NSNotificationCenter.defaultCenter postNotificationName:OCClassSettingsChangedNotification object:nil];
		}];
	}

	return (self);
}

- (void)dealloc
{
	[OCIPNotificationCenter.sharedNotificationCenter removeObserver:self forName:OCIPCNotificationNameClassSettingsUserPreferencesChanged];
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
	BOOL changeAllowed = NO;

	if ((changeAllowed = [self userAllowedToSetKey:key ofClass:theClass]) == YES)
	{
		OCClassSettingsIdentifier classSettingsIdentifier;

		if ((classSettingsIdentifier = [theClass classSettingsIdentifier]) != nil)
		{
			[self _setValue:value forClassSettingsKey:key classSettingsIdentifier:classSettingsIdentifier];
		}

		[OCClassSettings.sharedSettings clearSourceCache];

		[NSNotificationCenter.defaultCenter postNotificationName:OCClassSettingsChangedNotification object:[NSString flatIdentifierFromIdentifier:classSettingsIdentifier key:key]];
		[OCIPNotificationCenter.sharedNotificationCenter postNotificationForName:OCIPCNotificationNameClassSettingsUserPreferencesChanged ignoreSelf:YES];
	}

	return (changeAllowed);
}

- (BOOL)userAllowedToSetKey:(OCClassSettingsKey)key ofClass:(Class<OCClassSettingsSupport>)theClass
{
	OCClassSettingsIdentifier classSettingsIdentifier = [theClass classSettingsIdentifier];
	BOOL changeAllowed = NO;

	if ([theClass conformsToProtocol:@protocol(OCClassSettingsUserPreferencesSupport)] && [theClass conformsToProtocol:@protocol(OCClassSettingsSupport)])
	{
		if ([theClass respondsToSelector:@selector(allowUserPreferenceForClassSettingsKey:)])
		{
			changeAllowed = [(Class<OCClassSettingsUserPreferencesSupport>)theClass allowUserPreferenceForClassSettingsKey:key];
		}
		else
		{
			OCClassSettingsFlag flags = [OCClassSettings.sharedSettings flagsForClass:theClass key:key];

			if (((flags & OCClassSettingsFlagAllowUserPreferences) == OCClassSettingsFlagAllowUserPreferences) || // User preferences explicitely allowed
			    ((flags & OCClassSettingsFlagDenyUserPreferences) == 0)) // User preferences not explicitely denied
			{
				changeAllowed = YES;
			}
		}
	}

	if (changeAllowed)
	{
		NSArray<OCClassSettingsFlatIdentifier> *settingsIdentifiers;
		OCClassSettingsFlatIdentifier flatIdentifier = [NSString flatIdentifierFromIdentifier:classSettingsIdentifier key:key];

		if ((settingsIdentifiers = [self classSettingForOCClassSettingsKey:OCClassSettingsKeyUserPreferencesAllow]) != nil)
		{
			if (![settingsIdentifiers containsObject:flatIdentifier])
			{
				changeAllowed = NO;
			}
		}

		if ((settingsIdentifiers = [self classSettingForOCClassSettingsKey:OCClassSettingsKeyUserPreferencesDisallow]) != nil)
		{
			if ([settingsIdentifiers containsObject:flatIdentifier])
			{
				changeAllowed = NO;
			}
		}
	}

	return (changeAllowed);
}

- (void)_setValue:(id<NSSecureCoding>)value forClassSettingsKey:(OCClassSettingsKey)key classSettingsIdentifier:(OCClassSettingsIdentifier)classSettingsIdentifier
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

#pragma mark - Class settings support
+ (OCClassSettingsIdentifier)classSettingsIdentifier
{
	return (OCClassSettingsIdentifierUserPreferences);
}

+ (NSDictionary<OCClassSettingsKey,id> *)defaultSettingsForIdentifier:(OCClassSettingsIdentifier)identifier
{
	return (@{

	});
}

+ (OCClassSettingsMetadataCollection)classSettingsMetadata
{
	return (@{
		// Allow User Preferences
		OCClassSettingsKeyUserPreferencesAllow : @{
			OCClassSettingsMetadataKeyType 		: OCClassSettingsMetadataTypeStringArray,
			OCClassSettingsMetadataKeyDescription 	: @"List of settings (as flat identifiers) users are allowed to change. If this list is specified, only these settings can be changed by the user.",
			OCClassSettingsMetadataKeyStatus	: OCClassSettingsKeyStatusAdvanced,
			OCClassSettingsMetadataKeyCategory	: @"Security"
		},

		// Disallow User Preferences
		OCClassSettingsKeyUserPreferencesDisallow : @{
			OCClassSettingsMetadataKeyType 		: OCClassSettingsMetadataTypeStringArray,
			OCClassSettingsMetadataKeyDescription 	: @"List of settings (as flat identifiers) users are not allowed to change. If this list is specified, all settings not on the list can be changed by the user.",
			OCClassSettingsMetadataKeyStatus	: OCClassSettingsKeyStatusAdvanced,
			OCClassSettingsMetadataKeyCategory	: @"Security"
		}
	});
}

@end

@implementation NSObject (OCClassSettingsUserPreferences)

+ (BOOL)userAllowedToSetPreferenceValueForClassSettingsKey:(OCClassSettingsKey)key
{
	return ([OCClassSettingsUserPreferences.sharedUserPreferences userAllowedToSetKey:key ofClass:self]);
}

- (BOOL)userAllowedToSetPreferenceValueForClassSettingsKey:(OCClassSettingsKey)key
{
	return ([OCClassSettingsUserPreferences.sharedUserPreferences userAllowedToSetKey:key ofClass:self.class]);
}

+ (BOOL)setUserPreferenceValue:(id<NSSecureCoding>)value forClassSettingsKey:(OCClassSettingsKey)key
{
	return ([OCClassSettingsUserPreferences.sharedUserPreferences setValue:value forClassSettingsKey:key ofClass:self]);
}

- (BOOL)setUserPreferenceValue:(id<NSSecureCoding>)value forClassSettingsKey:(OCClassSettingsKey)key
{
	return ([OCClassSettingsUserPreferences.sharedUserPreferences setValue:value forClassSettingsKey:key ofClass:self.class]);
}

@end

OCClassSettingsKey OCClassSettingsKeyUserPreferencesAllow = @"allow";
OCClassSettingsKey OCClassSettingsKeyUserPreferencesDisallow = @"disallow";
OCClassSettingsIdentifier OCClassSettingsIdentifierUserPreferences = @"user-settings";

OCClassSettingsSourceIdentifier OCClassSettingsSourceIdentifierUserPreferences = @"user-prefs";
