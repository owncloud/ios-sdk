//
//  OCClassSettings.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 23.02.18.
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

#import "OCClassSettings.h"
#import "OCClassSettingsFlatSourceManagedConfiguration.h"

@interface OCClassSettings ()
{
	NSMutableArray <id <OCClassSettingsSource>> *_sources;
	NSMutableDictionary<OCClassSettingsIdentifier,NSMutableDictionary<OCClassSettingsKey,id> *> *_overrideValuesByKeyByIdentifier;
}

@end

@implementation OCClassSettings

+ (instancetype)sharedSettings
{
	static dispatch_once_t onceToken;
	static OCClassSettings *sharedClassSettings = nil;
	
	dispatch_once(&onceToken, ^{
		sharedClassSettings = [OCClassSettings new];

		[sharedClassSettings addSource:[OCClassSettingsFlatSourceManagedConfiguration new]];
	});
	
	return(sharedClassSettings);
}

- (void)addSource:(id <OCClassSettingsSource>)source
{
	if (source == nil) { return; }

	if (_sources == nil)
	{
		_sources = [NSMutableArray new];
	}

	[_sources addObject:source];

	[_overrideValuesByKeyByIdentifier removeAllObjects];
}

- (NSDictionary<OCClassSettingsKey,id> *)_overrideDictionaryForSettingsIdentifier:(OCClassSettingsIdentifier)settingsIdentifier
{
	NSMutableDictionary<OCClassSettingsKey,id> *overrideDict = nil;

	if (_sources != nil)
	{
		if ((overrideDict = _overrideValuesByKeyByIdentifier[settingsIdentifier]) == nil)
		{
			for (id <OCClassSettingsSource> source in _sources)
			{
				NSDictionary<OCClassSettingsKey,id> *sourceOverrideDict;

				if ((sourceOverrideDict = [source settingsForIdentifier:settingsIdentifier]) != nil)
				{
					if (overrideDict==nil) { overrideDict = [NSMutableDictionary new]; }

					[overrideDict setValuesForKeysWithDictionary:sourceOverrideDict];
				}
			}

			if (overrideDict != nil)
			{
				if (_overrideValuesByKeyByIdentifier == nil) { _overrideValuesByKeyByIdentifier = [NSMutableDictionary new]; }

				_overrideValuesByKeyByIdentifier[settingsIdentifier] = overrideDict;
			}
		}
	}

	return (overrideDict);
}

- (NSDictionary<OCClassSettingsKey,id> *)settingsForClass:(Class<OCClassSettingsSupport>)settingsClass
{
	NSDictionary<NSString *, id> *classSettings = nil;
	OCClassSettingsIdentifier classSettingsIdentifier;

	if ((classSettingsIdentifier = [settingsClass classSettingsIdentifier]) != nil)
	{
		NSDictionary<NSString *, id> *overrideSettings = nil;

		// Use defaults provided by class
		classSettings = [settingsClass defaultSettingsForIdentifier:classSettingsIdentifier];

		// Merge override values from sources (if any)
		if ((overrideSettings = [self _overrideDictionaryForSettingsIdentifier:classSettingsIdentifier]) != nil)
		{
			if (classSettings != nil)
			{
				NSMutableDictionary<OCClassSettingsKey,id> *mergedClassSettings = nil;

				mergedClassSettings = [[NSMutableDictionary alloc] initWithDictionary:classSettings];

				[mergedClassSettings setDictionary:overrideSettings];

				classSettings = mergedClassSettings;
			}
			else
			{
				classSettings = overrideSettings;
			}
		}
	}

	return (classSettings);
}

@end
