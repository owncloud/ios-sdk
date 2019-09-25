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

- (NSMutableDictionary<OCClassSettingsIdentifier, NSDictionary<OCClassSettingsKey, id> *> *)masterDictionary
{
	NSDictionary<OCClassSettingsIdentifier, NSDictionary<OCClassSettingsKey, id> *> *masterDictionaryReadOnly;

	if ((masterDictionaryReadOnly = [OCAppIdentity.sharedAppIdentity.userDefaults dictionaryForKey:@"org.owncloud.user-settings"]) != nil)
	{
		return ([masterDictionaryReadOnly mutableCopy]);
	}

	return ([NSMutableDictionary new]);
}

- (void)setMasterDictionary:(NSMutableDictionary<OCClassSettingsIdentifier, NSDictionary<OCClassSettingsKey, id> *> *)masterDictionary
{
	[OCAppIdentity.sharedAppIdentity.userDefaults setObject:masterDictionary forKey:@"org.owncloud.user-settings"];
}

- (nullable NSDictionary<OCClassSettingsKey, id> *)settingsForIdentifier:(OCClassSettingsIdentifier)classSettingsIdentifier
{
	return (self.masterDictionary[classSettingsIdentifier]);
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
	NSMutableDictionary<OCClassSettingsIdentifier, NSDictionary<OCClassSettingsKey, id> *> *masterDictionary = [self masterDictionary];
	NSMutableDictionary<OCClassSettingsKey, id> *classSettingsDictionary = nil;

	if ((classSettingsDictionary = [masterDictionary[classSettingsIdentifier] mutableCopy]) == nil)
	{
		classSettingsDictionary = [NSMutableDictionary new];
	}

	masterDictionary[classSettingsIdentifier] = classSettingsDictionary;

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
		[masterDictionary removeObjectForKey:classSettingsIdentifier];
	}

	self.masterDictionary = masterDictionary;
}

@end

@implementation NSObject (OCClassSettingsUserPreferences)

+ (BOOL)setUserPreferenceValue:(id<NSSecureCoding>)value forClassSettingsKey:(OCClassSettingsKey)key
{
	return ([OCClassSettingsUserPreferences.sharedUserPreferences setValue:value forClassSettingsKey:key ofClass:self]);
}

@end
