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
#import "OCLogger.h"

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
		[sharedClassSettings addSource:[OCClassSettingsUserPreferences sharedUserPreferences]];
		[sharedClassSettings addSource:[[OCClassSettingsFlatSourceEnvironment alloc] initWithPrefix:@"oc:"]];
	});
	
	return(sharedClassSettings);
}

-(instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_validatedValuesByKeyByIdentifier = [NSMutableDictionary new];
		_actualValuesByKeyByIdentifier = [NSMutableDictionary new];

		_flagsByKeyByIdentifier = [NSMutableDictionary new];
	}

	return (self);
}

- (void)registerDefaults:(NSDictionary<OCClassSettingsKey, id> *)defaults metadata:(nullable OCClassSettingsMetadataCollection)metaData forClass:(Class<OCClassSettingsSupport>)theClass
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

			if (metaData != nil)
			{
				NSMutableArray<OCClassSettingsMetadataCollection> *registeredMetaDataCollections = nil;

				if (_registeredMetaDataCollectionsByIdentifier == nil)
				{
					_registeredMetaDataCollectionsByIdentifier = [NSMutableDictionary new];
				}

				if ((registeredMetaDataCollections = _registeredMetaDataCollectionsByIdentifier[identifier]) == nil)
				{
					registeredMetaDataCollections = [NSMutableArray new];
					_registeredMetaDataCollectionsByIdentifier[identifier] = registeredMetaDataCollections;
				}

				[registeredMetaDataCollections addObject:metaData];
			}

			[self clearSourceCache];
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
		[NSNotificationCenter.defaultCenter postNotificationName:OCClassSettingsChangedNotification object:nil];
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
		[NSNotificationCenter.defaultCenter postNotificationName:OCClassSettingsChangedNotification object:nil];
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
			[NSNotificationCenter.defaultCenter postNotificationName:OCClassSettingsChangedNotification object:nil];
		}
	}
}

- (void)clearSourceCache
{
	@synchronized(self)
	{
		[_overrideValuesByKeyByIdentifier removeAllObjects];
		[_flagsByKeyByIdentifier removeAllObjects];
	}
}

- (NSMutableDictionary<OCClassSettingsKey,id> *)_overrideDictionaryForSettingsIdentifier:(OCClassSettingsIdentifier)settingsIdentifier managedByClass:(Class<OCClassSettingsSupport>)settingsClass
{
	NSMutableDictionary<OCClassSettingsKey,id> *overrideDict = nil;
	dispatch_block_t completeLogErrors = nil;

	@synchronized(self)
	{
		if (_sources != nil)
		{
			if ((overrideDict = _overrideValuesByKeyByIdentifier[settingsIdentifier]) == nil)
			{
				OCClassSettingsIdentifier classSettingsIdentifier = [settingsClass classSettingsIdentifier];

				if (_overrideValuesByKeyByIdentifier == nil)
				{
					_overrideValuesByKeyByIdentifier = [NSMutableDictionary new];
				}

				for (id <OCClassSettingsSource> source in _sources)
				{
					NSDictionary<OCClassSettingsKey,id> *originalOverrideDict;

					if ((originalOverrideDict = [source settingsForIdentifier:settingsIdentifier]) != nil)
					{
						NSDictionary<OCClassSettingsKey, NSError *> *validationErrorsByKey;
						NSMutableDictionary<OCClassSettingsKey,id> *sourceOverrideDict;

						if (overrideDict==nil) { overrideDict = [NSMutableDictionary new]; }
						sourceOverrideDict = [originalOverrideDict mutableCopy];

						validationErrorsByKey = [self validateDictionary:sourceOverrideDict forClass:settingsClass updateCache:NO];

						if (validationErrorsByKey.count > 0)
						{
							dispatch_block_t logErrors = ^{
								for (OCClassSettingsKey key in validationErrorsByKey)
								{
									OCLogError(@"Rejecting value %@ [%@] for %@.%@ setting: %@", originalOverrideDict[key], NSStringFromClass([originalOverrideDict[key] class]), classSettingsIdentifier, key, validationErrorsByKey[key].localizedDescription);
								}
							};

							if ([classSettingsIdentifier isEqual:OCClassSettingsIdentifierLog])
							{
								// Log log settings errors asyncronously to avoid a dead-lock
								dispatch_async(dispatch_get_main_queue(), logErrors);
							}
							else
							{
								// Log errors from this method, but do it only later, to avoid being inside @synchronized(self) when doing so (deadlock due to logging settings could loom otherwise)
								if (completeLogErrors == nil) {
									completeLogErrors = logErrors;
								} else {
									dispatch_block_t previousLogErrors = completeLogErrors;
									completeLogErrors = ^{
										previousLogErrors();
										logErrors();
									};
								}
							}
						}

						for (OCClassSettingsKey srcKey in sourceOverrideDict)
						{
							if (validationErrorsByKey[srcKey] == nil)
							{
								overrideDict[srcKey] = sourceOverrideDict[srcKey];
							}
						}
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

	if (completeLogErrors != nil)
	{
		completeLogErrors();
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
		NSMutableDictionary<NSString *, id> *overrideSettings = nil;

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
		if ((overrideSettings = [self _overrideDictionaryForSettingsIdentifier:classSettingsIdentifier managedByClass:settingsClass]) != nil)
		{
			NSDictionary<OCClassSettingsKey, NSError *> *errorsByKey;

			@synchronized(self) // guard to protect in case overrideSettings was returned from the cached _overrideValuesByKeyByIdentifier
			{
				errorsByKey = [self validateDictionary:overrideSettings forClass:settingsClass updateCache:YES];
			}

			if (errorsByKey != nil)
			{
				dispatch_block_t logErrors = ^{
					for (OCClassSettingsKey key in errorsByKey)
					{
						OCLogError(@"Rejecting value for %@.%@ setting: %@", classSettingsIdentifier, key, errorsByKey[key].localizedDescription);
					}
				};

				if ([classSettingsIdentifier isEqual:OCClassSettingsIdentifierLog])
				{
					// Log log settings errors asyncronously to avoid a dead-lock
					dispatch_async(dispatch_get_main_queue(), logErrors);
				}
				else
				{
					logErrors();
				}
			}

			if (classSettings != nil)
			{
				NSMutableDictionary<OCClassSettingsKey,id> *mergedClassSettings = nil;

				mergedClassSettings = [[NSMutableDictionary alloc] initWithDictionary:classSettings];

				@synchronized(self) // guard to protect in case overrideSettings was returned from the cached _overrideValuesByKeyByIdentifier
				{
					[mergedClassSettings addEntriesFromDictionary:overrideSettings];
				}

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
		if ([inspectClass conformsToProtocol:@protocol(OCClassSettingsSupport)] &&
		    [inspectClass respondsToSelector:@selector(classSettingsIdentifier)]) // Avoid proxy classes
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
						for (OCClassSettingsKey key in classSettingDefaults.allKeys)
						{
							if (([self flagsForClass:inspectClass key:key] & OCClassSettingsFlagIsPrivate) == 0)
							{
								[keys addObject:key];
							}
						}
					}

					if (_registeredDefaultValuesByKeyByIdentifier[settingsIdentifier] != nil)
					{
						for (OCClassSettingsKey key in _registeredDefaultValuesByKeyByIdentifier[settingsIdentifier].allKeys)
						{
							if (([self flagsForClass:inspectClass key:key] & OCClassSettingsFlagIsPrivate) == 0)
							{
								[keys addObject:key];
							}
						}
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

#pragma mark - Log tagging
+ (NSArray<OCLogTagName> *)logTags
{
	return (@[ @"Settings" ]);
}

- (NSArray<OCLogTagName> *)logTags
{
	return (@[ @"Settings" ]);
}

@end

NSNotificationName OCClassSettingsChangedNotification = @"OCClassSettingsChanged";
