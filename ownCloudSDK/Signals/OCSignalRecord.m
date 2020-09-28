//
//  OCSignalRecord.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 28.09.20.
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

#import "OCSignalRecord.h"
#import "OCEvent.h"

@implementation OCSignalRecord

- (instancetype)initWithSignalUUID:(OCSignalUUID)signalUUID
{
	if ((self = [super init]) != nil)
	{
		_signalUUID = signalUUID;
		_consumers = [NSMutableArray new];
	}

	return (self);
}

- (void)addConsumer:(OCSignalConsumer *)consumer
{
	if (_consumers == nil)
	{
		_consumers = [NSMutableArray new];
	}
	else
	{
		if (![_consumers isKindOfClass:NSMutableArray.class])
		{
			_consumers = [[NSMutableArray alloc] initWithArray:_consumers];
		}
	}

	[(NSMutableArray *)_consumers addObject:consumer];
}

- (void)removeConsumer:(OCSignalConsumer *)consumer
{
	if (_consumers != nil)
	{
		if (![_consumers isKindOfClass:NSMutableArray.class])
		{
			_consumers = [[NSMutableArray alloc] initWithArray:_consumers];
		}

		[(NSMutableArray *)_consumers removeObject:consumer];
	}
}

- (BOOL)removeConsumersMatching:(BOOL(^)(OCSignalConsumer *storedConsumer))matcher onlyFirstMatch:(BOOL)onlyFirstMatch
{
	if (_consumers != nil)
	{
		NSMutableArray<OCSignalConsumer *> *modifiedConsumers = nil;

		for (OCSignalConsumer *storedConsumer in _consumers)
		{
			if (matcher(storedConsumer))
			{
				if (modifiedConsumers == nil)
				{
					modifiedConsumers = [[NSMutableArray alloc] initWithArray:_consumers];
				}

				[modifiedConsumers removeObject:storedConsumer];

				if (onlyFirstMatch)
				{
					break;
				}
			}
		}

		if (modifiedConsumers != nil)
		{
			_consumers = modifiedConsumers;

			return (YES);
		}
	}

	return (NO);
}

#pragma mark - Secure Coding
+ (BOOL)supportsSecureCoding
{
	return (YES);
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
	if ((self = [super init]) != nil)
	{
		_signalUUID = [coder decodeObjectOfClass:NSString.class forKey:@"signalUUID"];

		_signal = [coder decodeObjectOfClass:OCSignal.class forKey:@"signal"];
		_consumers = [coder decodeObjectOfClasses:OCEvent.safeClasses forKey:@"consumers"];
	}

	return (self);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:_signalUUID forKey:@"signalUUID"];

	[coder encodeObject:_signal forKey:@"signal"];
	[coder encodeObject:_consumers forKey:@"consumers"];
}

@end
