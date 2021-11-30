//
//  OCLocaleFilterClassSettings.m
//  OCLocaleFilterClassSettings
//
//  Created by Felix Schwarz on 16.10.21.
//  Copyright © 2021 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2021, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCLocaleFilterClassSettings.h"

@interface OCLocaleFilterClassSettings ()
{
	NSDictionary<NSString *, NSString *> *_overrides;
}
@end

@implementation OCLocaleFilterClassSettings

#pragma mark - Class settings
+ (OCClassSettingsIdentifier)classSettingsIdentifier
{
	return (@"locale");
}

+ (NSDictionary<OCClassSettingsKey, id> *)defaultSettingsForIdentifier:(OCClassSettingsIdentifier)identifier
{
	return (@{
		OCClassSettingsKeyLocaleOverrides : @{ }
	});
}

+ (OCClassSettingsMetadataCollection)classSettingsMetadata
{
	return (@{
		OCClassSettingsKeyLocaleOverrides : @{
			OCClassSettingsMetadataKeyType 		: OCClassSettingsMetadataTypeDictionary,
			OCClassSettingsMetadataKeyLabel 	: @"Localization Overrides",
			OCClassSettingsMetadataKeyDescription 	: @"Dictionary with localization overrides where the key is the English string whose localization should be overridden, and the value is a dictionary where the keys are the language codes (f.ex. \"en\", \"de\") and the values the translations to use.",
			OCClassSettingsMetadataKeyStatus	: OCClassSettingsKeyStatusAdvanced,
			OCClassSettingsMetadataKeyCategory	: @"Localization"
		},
	});
}

#pragma mark - Shared
+ (OCLocaleFilterClassSettings *)shared
{
	static dispatch_once_t onceToken;
	static OCLocaleFilterClassSettings *sharedInstance = nil;

	dispatch_once(&onceToken, ^{
		sharedInstance = [OCLocaleFilterClassSettings new];
		[sharedInstance pullFromClassSettings];
	});

	return (sharedInstance);
}

- (void)pullFromClassSettings
{
	NSDictionary<NSString *,NSDictionary<NSString *, NSString *> *> *overrides = [self classSettingForOCClassSettingsKey:OCClassSettingsKeyLocaleOverrides];
	NSMutableDictionary<NSString *, NSString *> *computedOverrides = [NSMutableDictionary new];

	[overrides enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull localizeString, NSDictionary<NSString *,NSString *> * _Nonnull translations, BOOL * _Nonnull stop) {
		NSString *preferredLanguage;
		NSString *translation = nil;

		if ((preferredLanguage = [NSBundle preferredLocalizationsFromArray:translations.allKeys].firstObject) != nil) {
			translation = translations[preferredLanguage];
		};

		if (translation == nil) {
			translation = localizeString;
		}

		computedOverrides[localizeString] = translation;
	}];

	_overrides = computedOverrides;
}

- (NSString *)applyToLocalizedString:(NSString *)localizedString withOriginalString:(NSString *)originalString options:(OCLocaleOptions)options
{
	if (originalString != nil)
	{
		NSString *returnString = nil;

		if ((returnString = _overrides[originalString]) != nil)
		{
			return (returnString);
		}
	}

	return (localizedString);
}

@end

OCClassSettingsKey OCClassSettingsKeyLocaleOverrides = @"overrides";
