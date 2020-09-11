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
#import "OCClassSettingsFlatSourceEnvironment.h"
#import "OCClassSettingsUserPreferences.h"

@interface OCClassSettings ()
{
	NSMutableArray <id <OCClassSettingsSource>> *_sources;
	NSMutableDictionary<OCClassSettingsIdentifier,NSMutableDictionary<OCClassSettingsKey,id> *> *_overrideValuesByKeyByIdentifier;

	NSMutableDictionary<OCClassSettingsIdentifier,NSMutableDictionary<OCClassSettingsKey,id> *> *_registeredDefaultValuesByKeyByIdentifier;
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
		[sharedClassSettings addSource:[OCClassSettingsUserPreferences sharedUserPreferences]];
		[sharedClassSettings addSource:[[OCClassSettingsFlatSourceEnvironment alloc] initWithPrefix:@"oc:"]];
	});
	
	return(sharedClassSettings);
}

- (void)registerDefaults:(NSDictionary<OCClassSettingsKey, id> *)defaults forClass:(Class<OCClassSettingsSupport>)theClass
{
	OCClassSettingsIdentifier identifier;

	if ((identifier = [theClass classSettingsIdentifier]) != nil)
	{
		@synchronized(self)
		{
			NSMutableDictionary<OCClassSettingsKey,id> *registeredDefaultValuesByKey = nil;

			if (_registeredDefaultValuesByKeyByIdentifier == nil)
			{
				_registeredDefaultValuesByKeyByIdentifier = [NSMutableDictionary new];
			}

			if ((registeredDefaultValuesByKey = _registeredDefaultValuesByKeyByIdentifier[identifier]) == nil)
			{
				registeredDefaultValuesByKey = [NSMutableDictionary new];
				_registeredDefaultValuesByKeyByIdentifier[identifier] = registeredDefaultValuesByKey;
			}

			[registeredDefaultValuesByKey addEntriesFromDictionary:defaults];
		}
	}
}

- (nullable NSDictionary<OCClassSettingsKey, id> *)registeredDefaultsForClass:(Class<OCClassSettingsSupport>)theClass
{
	@synchronized(self)
	{
		OCClassSettingsIdentifier identifier;

		if ((identifier = [theClass classSettingsIdentifier]) != nil)
		{
			return (_registeredDefaultValuesByKeyByIdentifier[identifier]);
		}
	}

	return (nil);
}

- (void)addSource:(id <OCClassSettingsSource>)source
{
	if (source == nil) { return; }

	@synchronized(self)
	{
		if (_sources == nil)
		{
			_sources = [NSMutableArray new];
		}

		[_sources addObject:source];

		[self clearSourceCache];
	}
}

- (void)insertSource:(id <OCClassSettingsSource>)source before:(nullable OCClassSettingsSourceIdentifier)beforeSourceID after:(nullable OCClassSettingsSourceIdentifier)afterSourceID
{
	if (source == nil) { return; }

	@synchronized(self)
	{
		if (_sources == nil)
		{
			_sources = [NSMutableArray new];
			[_sources addObject:source];
		}
		else
		{
			__block NSInteger insertIndex = NSNotFound;

			[_sources enumerateObjectsUsingBlock:^(id<OCClassSettingsSource>  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
				if ([obj.settingsSourceIdentifier isEqual:beforeSourceID])
				{
					insertIndex = idx;
					*stop = YES;
				}

				if ([obj.settingsSourceIdentifier isEqual:afterSourceID])
				{
					insertIndex = idx+1;
					*stop = YES;
				}
			}];

			if (insertIndex != NSNotFound)
			{
				[_sources insertObject:source atIndex:insertIndex];
			}
			else
			{
				[_sources addObject:source];
			}
		}

		[self clearSourceCache];
	}
}

- (void)removeSource:(id <OCClassSettingsSource>)source
{
	if (source == nil) { return; }

	@synchronized(self)
	{
		if (_sources != nil)
		{
			[_sources removeObjectIdenticalTo:source];

			[self clearSourceCache];
		}
	}
}

- (void)clearSourceCache
{
	@synchronized(self)
	{
		[_overrideValuesByKeyByIdentifier removeAllObjects];
	}
}

- (NSDictionary<OCClassSettingsKey,id> *)_overrideDictionaryForSettingsIdentifier:(OCClassSettingsIdentifier)settingsIdentifier
{
	NSMutableDictionary<OCClassSettingsKey,id> *overrideDict = nil;

	@synchronized(self)
	{
		if (_sources != nil)
		{
			if ((overrideDict = _overrideValuesByKeyByIdentifier[settingsIdentifier]) == nil)
			{
				if (_overrideValuesByKeyByIdentifier == nil)
				{
					_overrideValuesByKeyByIdentifier = [NSMutableDictionary new];
				}

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
	}

	return (overrideDict);
}

- (nullable NSDictionary<OCClassSettingsKey, id> *)settingsForClass:(Class<OCClassSettingsSupport>)settingsClass
{
	NSDictionary<OCClassSettingsKey, id> *classSettings = nil;
	NSDictionary<OCClassSettingsKey, id> *registeredDefaults = nil;
	OCClassSettingsIdentifier classSettingsIdentifier;

	if ((classSettingsIdentifier = [settingsClass classSettingsIdentifier]) != nil)
	{
		NSDictionary<NSString *, id> *overrideSettings = nil;

		// Use defaults provided by class
		classSettings = [settingsClass defaultSettingsForIdentifier:classSettingsIdentifier];

		// Merge with registered defaults (f.ex. added by subclasses)
		if (((registeredDefaults = [self registeredDefaultsForClass:settingsClass]) != nil) && (registeredDefaults.count > 0))
		{
			NSMutableDictionary<OCClassSettingsKey, id> *mergedSettings = [classSettings mutableCopy];
			[mergedSettings addEntriesFromDictionary:registeredDefaults];

			classSettings = mergedSettings;
		}

		// Merge override values from sources (if any)
		if ((overrideSettings = [self _overrideDictionaryForSettingsIdentifier:classSettingsIdentifier]) != nil)
		{
			if (classSettings != nil)
			{
				NSMutableDictionary<OCClassSettingsKey,id> *mergedClassSettings = nil;

				mergedClassSettings = [[NSMutableDictionary alloc] initWithDictionary:classSettings];

				[mergedClassSettings addEntriesFromDictionary:overrideSettings];

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

- (NSDictionary<OCClassSettingsIdentifier, NSDictionary<OCClassSettingsKey, NSArray<NSDictionary<OCClassSettingsSourceIdentifier, id> *> *> *> *)settingsSnapshotForClasses:(nullable NSArray<Class> *)classes onlyPublic:(BOOL)onlyPublic
{
	NSMutableDictionary<OCClassSettingsIdentifier, NSMutableDictionary<OCClassSettingsKey, NSMutableArray<NSDictionary<OCClassSettingsSourceIdentifier, id> *> *> *> *settingsSnapshot = [NSMutableDictionary new];

	for (Class inspectClass in classes)
	{
		// Check conformity
		if ([inspectClass conformsToProtocol:@protocol(OCClassSettingsSupport)])
		{
			OCClassSettingsIdentifier settingsIdentifier;

			// Determine identifier
			if ((settingsIdentifier = [inspectClass classSettingsIdentifier]) != nil)
			{
				NSDictionary<OCClassSettingsKey, id> *classSettingDefaults = [inspectClass defaultSettingsForIdentifier:settingsIdentifier];
				NSMutableSet<OCClassSettingsKey> *keys = [NSMutableSet new];

				// Determine relevant keys
				if ([inspectClass respondsToSelector:@selector(publicClassSettingsIdentifiers)])
				{
					[keys addObjectsFromArray:[inspectClass publicClassSettingsIdentifiers]];
				}
				else
				{
					if (classSettingDefaults != nil)
					{
						[keys addObjectsFromArray:classSettingDefaults.allKeys];
					}

					if (_registeredDefaultValuesByKeyByIdentifier[settingsIdentifier] != nil)
					{
						[keys addObjectsFromArray:_registeredDefaultValuesByKeyByIdentifier[settingsIdentifier].allKeys];
					}
				}

				// Capture snapshot
				NSMutableDictionary<OCClassSettingsKey, NSMutableArray<NSDictionary<OCClassSettingsSourceIdentifier, id> *> *> *classSnapshot;

				if ((classSnapshot = settingsSnapshot[settingsIdentifier]) == nil)
				{
					classSnapshot = [NSMutableDictionary new];
					settingsSnapshot[settingsIdentifier] = classSnapshot;
				}

				for (OCClassSettingsKey key in keys)
				{
					NSMutableArray<NSDictionary<OCClassSettingsSourceIdentifier, id> *> *keySnapshot;

					if ((keySnapshot = classSnapshot[key]) == nil)
					{
						keySnapshot = [NSMutableArray new];
						classSnapshot[key] = keySnapshot;
					}

					// Add default value
					if (classSettingDefaults[key] != nil)
					{
						[keySnapshot addObject:@{ @"default" : classSettingDefaults[key] }];
					}

					// Add registered default value
					if (_registeredDefaultValuesByKeyByIdentifier[settingsIdentifier][key] != nil)
					{
						[keySnapshot addObject:@{ @"reg-default" : _registeredDefaultValuesByKeyByIdentifier[settingsIdentifier][key] }];
					}

					// Add defaults from sources
					for (id <OCClassSettingsSource> source in _sources)
					{
						NSDictionary<OCClassSettingsKey,id> *settingsDict;

						if ((settingsDict = [source settingsForIdentifier:settingsIdentifier]) != nil)
						{
							if (settingsDict[key] != nil)
							{
								[keySnapshot addObject:@{ source.settingsSourceIdentifier : settingsDict[key] }];
							}
						}
					}

					// Add computed value
					id computedValue = [inspectClass classSettingForOCClassSettingsKey:key];

					[keySnapshot addObject:@{ @"computed" : (computedValue != nil) ? computedValue : NSNull.null }];
				}
			}
		}
	}

	return (settingsSnapshot);
}

- (nullable NSString *)settingsSummaryForClasses:(nullable NSArray<Class> *)classes onlyPublic:(BOOL)onlyPublic
{
	NSMutableString *overview = [NSMutableString new];
	NSDictionary<OCClassSettingsIdentifier, NSDictionary<OCClassSettingsKey, NSArray<NSDictionary<OCClassSettingsSourceIdentifier, id> *> *> *> *snapshot = [self settingsSnapshotForClasses:classes onlyPublic:onlyPublic];

	for (OCClassSettingsIdentifier settingsIdentifier in snapshot)
	{
		for (OCClassSettingsKey key in snapshot[settingsIdentifier])
		{
			[overview appendFormat:@"%@.%@: ", settingsIdentifier, key];

			NSArray<NSDictionary<OCClassSettingsSourceIdentifier, id> *> *valueTuples = snapshot[settingsIdentifier][key];
			BOOL firstTuple = YES;

			for (NSDictionary<OCClassSettingsSourceIdentifier, id> *tuple in valueTuples)
			{
				[overview appendFormat:(firstTuple ? @"%@: `%@`" : @" -> %@: `%@`"), tuple.allKeys.firstObject, [[tuple.allValues.firstObject description] stringByReplacingOccurrencesOfString:@"\n" withString:@" "]];

				firstTuple = NO;
			}

			[overview appendFormat:@"\n"];
		}
	}

	return (overview);
}

@end
