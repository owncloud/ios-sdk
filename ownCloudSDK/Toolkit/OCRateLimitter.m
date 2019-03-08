//
//  OCRateLimitter.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 07.03.19.
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

#import "OCRateLimitter.h"

@interface OCRateLimitter ()
{
	NSTimeInterval _lastTime;
	BOOL _nextInvocationScheduled;
	dispatch_block_t _invocationBlock;
}

@end

@implementation OCRateLimitter

- (instancetype)initWithMinimumTime:(NSTimeInterval)minimumTime
{
	if ((self = [super init]) != nil)
	{
		_minimumTime = minimumTime;
	}

	return (self);
}

- (void)runRateLimitedBlock:(dispatch_block_t)block
{
	NSTimeInterval nowTimeInterval = [NSDate timeIntervalSinceReferenceDate];
	BOOL perform = NO, schedule = NO;
	NSTimeInterval timeSinceLast, timeUntilNext;

	@synchronized(self)
	{
		timeSinceLast = nowTimeInterval - _lastTime;
		timeUntilNext = _minimumTime - timeSinceLast;

		if (((_lastTime == 0) || (timeSinceLast >= _minimumTime)) && !_nextInvocationScheduled)
		{
			_lastTime = nowTimeInterval;
			perform = YES;
		}
		else
		{
			_invocationBlock = [block copy];

			if (!_nextInvocationScheduled)
			{
				_nextInvocationScheduled = YES;

				schedule = YES;
			}
		}
	}

	if (perform)
	{
		if (block != nil)
		{
			block();
		}
	}
	else if (schedule)
	{
		NSTimeInterval timeUntil = timeUntilNext * ((NSTimeInterval) NSEC_PER_SEC);

		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)timeUntil), dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
			dispatch_block_t block = nil;

			@synchronized(self)
			{
				block = self->_invocationBlock;
				self->_invocationBlock = nil;

				self->_lastTime = [NSDate timeIntervalSinceReferenceDate];
				self->_nextInvocationScheduled = NO;
			}

			if (block != nil)
			{
				block();
			}
		});
	}
}

@end
