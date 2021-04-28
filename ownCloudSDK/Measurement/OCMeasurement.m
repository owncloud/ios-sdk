//
//  OCMeasurement.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 22.04.21.
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

#import "OCMeasurement.h"
#import "OCLogger.h"
#import <os/log.h>
#import <os/signpost.h>
#import <objc/runtime.h>

@interface OCMeasurement ()
{
	NSMutableArray<OCMeasurementEvent *> *_events;
	NSTimeInterval _lastEmitTime;
	NSTimeInterval _lastLogTime;
}
@end

@implementation OCMeasurement

+ (OCClassSettingsIdentifier)classSettingsIdentifier
{
	return (OCClassSettingsIdentifierMeasurements);
}

+ (nullable NSDictionary<OCClassSettingsKey,id> *)defaultSettingsForIdentifier:(nonnull OCClassSettingsIdentifier)identifier
{
	return (@{
		OCClassSettingsKeyMeasurementsEnabled : @(YES)
	});
}

+ (OCClassSettingsMetadataCollection)classSettingsMetadata
{
	return (@{
		OCClassSettingsKeyMeasurementsEnabled : @{
			OCClassSettingsMetadataKeyType		: OCClassSettingsMetadataTypeBoolean,
			OCClassSettingsMetadataKeyDescription	: @"Turn measurements on or off",
			OCClassSettingsMetadataKeyCategory	: @"Logging",
			OCClassSettingsMetadataKeyFlags		: @(OCClassSettingsFlagAllowUserPreferences),
			OCClassSettingsMetadataKeyStatus	: OCClassSettingsKeyStatusDebugOnly
		}
	});
}

+ (BOOL)enabled
{
	static BOOL isEnabled;
	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		isEnabled = [[self classSettingForOCClassSettingsKey:OCClassSettingsKeyMeasurementsEnabled] boolValue];
	});

	return (isEnabled);
}

+ (nullable instancetype)measurementWithTitle:(nullable NSString *)title
{
	if (!self.enabled)
	{
		return (nil);
	}

	OCMeasurement *measurement = [[self alloc] init];

	measurement.title = title;

	return (measurement);
}

- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_identifier = NSUUID.UUID.UUIDString;
		_events = [NSMutableArray new];
	}

	return (self);
}

- (void)dealloc
{
	[self terminate];
	[self logIfNeeded:YES];
}

- (OCMeasurementEventReference)emitEvent:(OCMeasurementEvent *)event
{
	if (_state == OCMeasurementStateInitialized)
	{
		[self start];
		_startTimeSinceReferenceDate = event.timestamp;
	}

	@synchronized(self)
	{
		NSTimeInterval nowTime = NSDate.timeIntervalSinceReferenceDate;

		_lastEmitTime = nowTime;

		[_events addObject:event];
	}

	return (event.timestamp);
}

- (void)start
{
	if (_state == OCMeasurementStateInitialized)
	{
		_state = OCMeasurementStateStarted;
		_startTimeSinceReferenceDate = NSDate.timeIntervalSinceReferenceDate;
	}
}

- (void)terminate
{
	if (_state == OCMeasurementStateStarted)
	{
		_state = OCMeasurementStateTerminated;
		_endTimeSinceReferenceDate = NSDate.timeIntervalSinceReferenceDate;

		[self logIfNeeded:YES];
	}
}

- (void)logIfNeeded:(BOOL)ifNeeded
{
	BOOL doLog = !ifNeeded;

	@synchronized(self)
	{
		if (doLog || (_lastLogTime < _lastEmitTime))
		{
			_lastLogTime = _lastEmitTime;
			doLog = YES;
		}

		if (doLog)
		{
			NSMutableString *logMsg = [NSMutableString stringWithFormat:@"Measurement: %@\n", self.title];
			NSMutableDictionary<OCMeasurementEventIdentifier, NSNumber *> *_durationsByEvent = [NSMutableDictionary new];

			for (OCMeasurementEvent *event in _events)
			{
				if (event.progress == OCMeasurementEventProgressComplete)
				{
					_durationsByEvent[event.identifier] = @([_durationsByEvent[event.identifier] doubleValue] + (event.timestamp - event.relatedEventReference));
				}

				[logMsg appendFormat:@"- [%.02f] [%@%@] %@\n", (event.timestamp - _startTimeSinceReferenceDate), event.identifier, ((event.progress == OCMeasurementEventProgressUndetermined) ? @"" : [NSString stringWithFormat:@":%3ld", event.progress]), event.message];
			}

			[logMsg appendString:@"-------\n"];

			NSTimeInterval unattributedTime = ((_endTimeSinceReferenceDate != 0) ? _endTimeSinceReferenceDate : _lastEmitTime) - _startTimeSinceReferenceDate;

			for (OCMeasurementEventIdentifier eventID in _durationsByEvent)
			{
				NSTimeInterval duration = _durationsByEvent[eventID].doubleValue;
				unattributedTime -= duration;
				[logMsg appendFormat:@"= [%@] duration: %0.3f\n", eventID, duration];
			}

			if (unattributedTime > 0.01)
			{
				[logMsg appendFormat:@"? [unattributed] duration: %0.3f\n", unattributedTime];
			}

			if (_state == OCMeasurementStateTerminated)
			{
				[logMsg appendString:@"-- Terminated --\n"];
			}

			OCLog(@"%@", logMsg);
		}
	}
}

+ (NSArray<OCLogTagName> *)logTags
{
	return (@[@"Measure"]);
}

- (NSArray<OCLogTagName> *)logTags
{
	return (@[@"Measure", OCLogTagTypedID(@"Measurement", _identifier)]);
}

@end

static NSString *sOCMeasurementAssociatedObjectKey = @"assocObjKey";

@implementation NSObject (MeasurementExtractor)

- (nullable OCMeasurement *)extractedMeasurement
{
	if ([self isKindOfClass:OCMeasurement.class])
	{
		return ((OCMeasurement *)self);
	}

	if ([self conformsToProtocol:@protocol(OCMeasurementHost)])
	{
		return ([((NSObject<OCMeasurementHost>*)self) hostedMeasurement]);
	}

	return (objc_getAssociatedObject(self, (__bridge const void *)sOCMeasurementAssociatedObjectKey));
}

- (void)attachMeasurement:(nullable OCMeasurement *)measurement
{
	objc_setAssociatedObject(self, (__bridge const void *)sOCMeasurementAssociatedObjectKey, measurement, OBJC_ASSOCIATION_RETAIN);
}

- (void)detachMeasurement:(nullable OCMeasurement *)measurement
{
	if ((measurement == nil) || (objc_getAssociatedObject(self, (__bridge const void *)sOCMeasurementAssociatedObjectKey) == measurement))
	{
		[self attachMeasurement:nil];
	}
}

@end


OCClassSettingsIdentifier OCClassSettingsIdentifierMeasurements = @"measurements";
OCClassSettingsKey OCClassSettingsKeyMeasurementsEnabled = @"enabled";
