//
//  OCCoreUpdateScheduleRecord.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 27.09.21.
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

#import "OCCoreUpdateScheduleRecord.h"

@implementation OCCoreUpdateScheduleRecord

+ (NSArray<OCAppComponentIdentifier> *)prioritizedComponents
{
	return @[
		OCAppComponentIdentifierApp,
		OCAppComponentIdentifierFileProviderExtension
	];
}

- (void)beginCheck
{
	self.lastCheckComponent = OCAppIdentity.sharedAppIdentity.componentIdentifier;
	self.lastCheckBegin = [NSDate new];
	self.lastCheckEnd = nil;

	[self updateComponentTimestamp];
}

- (void)endCheck
{
	if ([self.lastCheckComponent isEqual:OCAppIdentity.sharedAppIdentity.componentIdentifier])
	{
		self.lastCheckEnd = [NSDate new];
	}

	[self updateComponentTimestamp];
}

- (void)updateComponentTimestamp
{
	OCAppComponentIdentifier componentID;

	if ((componentID = OCAppIdentity.sharedAppIdentity.componentIdentifier) != nil)
	{
		if (_lastTimestampByComponents == nil)
		{
			_lastTimestampByComponents = [NSMutableDictionary new];
		}

		_lastTimestampByComponents[componentID] = [NSDate new];
	}
}

- (nullable NSDate *)nextDateByBeginAndEndDate
{
	// - check last time the last scan ended or, where not available, began
	// 	- otherwise schedule considerScan again in $secondsRemainigUntilPollInterval, update $lastComponentAttemptTimestamp
	// 	- if more than $pollInterval seconds ago, proceed \/

	NSDate *lastScan = (self.lastCheckEnd != nil) ? self.lastCheckEnd : self.lastCheckBegin;
	NSTimeInterval elapsedTime = -lastScan.timeIntervalSinceNow;

	if ((lastScan!=nil) && (elapsedTime < _pollInterval))
	{
		return ([NSDate dateWithTimeIntervalSinceNow:_pollInterval-elapsedTime]);
	}

	return (nil);
}

- (nullable NSDate *)nextDateByPrioritizedComponents:(NSString * _Nullable * _Nullable)outComponent
{
	// - priority: check the $lastComponentAttemptTimestamp of other components
	// 	- if a higher-ranking component (using OCAppIdentity.componentIdentifier: app, fileprovider, * (anything else))
	// 	  saved a timestamp less than ($pollInterval * 2) seconds ago, update own $lastComponentAttemptTimestamp and
	//	  reschedule considerScan in (($pollInterval * 2) + 2)
	// 	- otherwhise proceed \/

	OCAppComponentIdentifier currentComponent = OCAppIdentity.sharedAppIdentity.componentIdentifier;
	NSDate *nextDate = nil;

	for (OCAppComponentIdentifier checkComponent in OCCoreUpdateScheduleRecord.prioritizedComponents)
	{
		if ([checkComponent isEqual:currentComponent]) {
			// Timestamps of the current component and any components with lower priority
			// should be ignored
			break;
		}

		NSDate *componentTimestamp;

		if ((componentTimestamp = _lastTimestampByComponents[checkComponent]) != nil)
		{
			NSTimeInterval elapsedTime = -componentTimestamp.timeIntervalSinceNow;

			if (elapsedTime < (_pollInterval * 2.0))
			{
				// timestamp less than ($pollInterval * 2) seconds ago => reschedule in (($pollInterval * 2) + 2)
				nextDate = [NSDate dateWithTimeIntervalSinceNow:((_pollInterval * 2.0) + 2.0)];

				if (outComponent != NULL)
				{
					*outComponent = checkComponent;
				}
				break;
			}
		}
	}

	return (nextDate);
}

#pragma mark - Secure Coding
+ (BOOL)supportsSecureCoding
{
	return (YES);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeDouble:_pollInterval forKey:@"pollInterval"];

	[coder encodeObject:_lastCheckBegin forKey:@"lastCheckBegin"];
	[coder encodeObject:_lastCheckEnd forKey:@"lastCheckEnd"];
	[coder encodeObject:_lastCheckComponent forKey:@"lastCheckComponent"];
	[coder encodeObject:_lastTimestampByComponents forKey:@"lastTimestampByComponents"];
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super init]) != nil)
	{
		_pollInterval = [decoder decodeDoubleForKey:@"pollInterval"];

		_lastCheckBegin = [decoder decodeObjectOfClass:NSDate.class forKey:@"lastCheckBegin"];
		_lastCheckEnd = [decoder decodeObjectOfClass:NSDate.class forKey:@"lastCheckEnd"];
		_lastCheckComponent = [decoder decodeObjectOfClass:NSString.class forKey:@"lastCheckComponent"];
		_lastTimestampByComponents = [decoder decodeObjectOfClasses:[[NSSet alloc] initWithObjects:NSMutableDictionary.class, NSString.class, NSDate.class, nil] forKey:@"lastTimestampByComponents"];
	}

	return (self);
}

@end
