//
//  OCClassSetting.m
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

#import "OCClassSetting.h"
#import "OCClassSettingsUserPreferences.h"
#import "NSString+OCClassSettings.h"

@interface OCClassSetting ()
{
	NSMapTable<id,NSMutableArray<OCClassSettingObserver> *> *_observersByOwner;
	id _lastValue;
	BOOL _lastIsUserConfigurable;
}
@end

@implementation OCClassSetting

#pragma mark - Initializers
+ (instancetype)settingForClass:(Class<OCClassSettingsSupport>)settingsClass key:(OCClassSettingsKey)key
{
	static dispatch_once_t onceToken;
	static NSMutableDictionary<OCClassSettingsFlatIdentifier, OCClassSetting *> *settingByFlatIdentifier;

	OCClassSettingsFlatIdentifier flatIdentifier = [NSString flatIdentifierFromIdentifier:[settingsClass classSettingsIdentifier] key:key];
	OCClassSetting *setting = nil;

	dispatch_once(&onceToken, ^{
		settingByFlatIdentifier = [NSMutableDictionary new];
	});

	if (flatIdentifier != nil)
	{
		@synchronized(settingByFlatIdentifier)
		{
			if ((setting = settingByFlatIdentifier[flatIdentifier]) == nil)
			{
				if ((setting = [[self alloc] initWithClass:settingsClass key:key]) != nil)
				{
					settingByFlatIdentifier[setting.identifier] = setting;
				}
			}
		}
	}

	return (setting);
}

- (instancetype)initWithClass:(Class<OCClassSettingsSupport>)settingsClass key:(OCClassSettingsKey)key
{
	if ((self = [super init]) != nil)
	{
		_settingsClass = settingsClass;
		_settingsKey = key;
		_settingsIdentifier = [_settingsClass classSettingsIdentifier];
		_identifier = [NSString flatIdentifierFromIdentifier:_settingsIdentifier key:key];

		[self _checkForNewValue]; // Set up _lastValue

		[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(_handleSettingsChangeNotification:) name:OCClassSettingsChangedNotification object:nil];
	}

	return (self);
}

- (void)dealloc
{
	[NSNotificationCenter.defaultCenter removeObserver:self name:OCClassSettingsChangedNotification object:nil];
}

#pragma mark - Observation
- (void)addObserver:(OCClassSettingObserver)observer withOwner:(id)owner
{
	NSMutableArray<OCClassSettingObserver> *observers = nil;

	observer = [observer copy];

	@synchronized(self)
	{
		if (_observersByOwner == nil)
		{
			_observersByOwner = [NSMapTable weakToStrongObjectsMapTable];
		}

		if ((observers = [_observersByOwner objectForKey:owner]) == nil)
		{
			observers = [NSMutableArray new];
			[_observersByOwner setObject:observers forKey:owner];
		}

		[observers addObject:observer];

		// Send initial value
		id value = nil;

		@synchronized(self)
		{
			value = _lastValue;
		}

		observer(owner, self, OCClassSettingChangeTypeInitial, nil, value);
	}
}

- (void)removeAllObserversForOwner:(id)owner
{
	@synchronized(self)
	{
		[_observersByOwner removeObjectForKey:owner];
	}
}

- (void)_handleSettingsChangeNotification:(NSNotification *)notification
{
	if ((notification.object == nil) || // Unspecific, global update
	    [notification.object isEqual:_identifier]) // Specific update
	{
		[self _checkForNewValue];
	}
}

- (void)_checkForNewValue
{
	id newValue = [_settingsClass classSettingForOCClassSettingsKey:_settingsKey];
	BOOL newIsUserConfigurable = [self isUserConfigurable];
	OCClassSettingChangeType changeType = OCClassSettingChangeTypeNone;

	if (newIsUserConfigurable != _lastIsUserConfigurable)
	{
		changeType |= OCClassSettingChangeTypeIsUserConfigurable;
		_lastIsUserConfigurable = newIsUserConfigurable;
	}

	if (![newValue isEqual:_lastValue])
	{
		changeType |= OCClassSettingChangeTypeValue;
	}

	if (changeType != OCClassSettingChangeTypeNone)
	{
		NSEnumerator *observerOwners = nil;
		id oldValue = nil;

		@synchronized(self)
		{
			oldValue = _lastValue;
			_lastValue = newValue;

			observerOwners = [_observersByOwner keyEnumerator];

			for (id owner in observerOwners)
			{
				NSMutableArray<OCClassSettingObserver> *observers = [_observersByOwner objectForKey:owner];

				for (OCClassSettingObserver observer in observers)
				{
					observer(owner, self, changeType, oldValue, newValue);
				}
			}
		}
	}
}

#pragma mark - Convenience accessors
- (BOOL)isUserConfigurable
{
	return ([[OCClassSettingsUserPreferences sharedUserPreferences] userAllowedToSetKey:_settingsKey ofClass:_settingsClass]);
}

@end

@implementation NSObject (OCClassSetting)

+ (OCClassSetting *)classSettingForKey:(OCClassSettingsKey)key
{
	return ([OCClassSetting settingForClass:self key:key]);
}

- (OCClassSetting *)classSettingForKey:(OCClassSettingsKey)key
{
	return ([OCClassSetting settingForClass:self.class key:key]);
}

@end

