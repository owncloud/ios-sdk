//
//  OCMeasurementEvent.m
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

#import "OCMeasurementEvent.h"

@implementation OCMeasurementEvent

+ (instancetype)eventWithIdentifier:(OCMeasurementEventIdentifier)eventIdentifier message:(nullable NSString *)message
{
	return ([[self alloc] initWithIdentifier:eventIdentifier message:message progress:OCMeasurementEventProgressUndetermined relatedEventTimestamp:0]);
}

+ (instancetype)eventWithIdentifier:(OCMeasurementEventIdentifier)eventIdentifier message:(nullable NSString *)message progress:(OCMeasurementEventProgress)progress
{
	return ([[self alloc] initWithIdentifier:eventIdentifier message:message progress:progress relatedEventTimestamp:0]);
}

+ (instancetype)eventWithIdentifier:(OCMeasurementEventIdentifier)eventIdentifier message:(nullable NSString *)message progress:(OCMeasurementEventProgress)progress relatedEventReference:(OCMeasurementEventReference)relatedEventReference
{
	return ([[self alloc] initWithIdentifier:eventIdentifier message:message progress:progress relatedEventTimestamp:relatedEventReference]);
}

- (instancetype)initWithIdentifier:(OCMeasurementEventIdentifier)eventIdentifier message:(nullable NSString *)message progress:(OCMeasurementEventProgress)progress relatedEventTimestamp:(OCMeasurementEventReference)relatedEventReference
{
	if ((self = [super init]) != nil)
	{
		_timestamp = NSDate.timeIntervalSinceReferenceDate;

		_identifier = eventIdentifier;
		_message = message;
		_progress = progress;
		_relatedEventReference = relatedEventReference;
	}

	return (self);
}

@end
