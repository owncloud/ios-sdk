//
//  OCAsyncSequentialQueue.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 16.01.19.
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

#import "OCAsyncSequentialQueue.h"
#import "OCLogger.h"

@interface OCAsyncSequentialQueue ()
{
	OCAsyncSequentialQueueExecutor _executor;

	BOOL _busy;
	NSMutableArray<OCAsyncSequentialQueueJob> *_queuedJobs;
}

@end

@implementation OCAsyncSequentialQueue

@synthesize executor = _executor;

#pragma mark - Init
- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		self.executor = ^(OCAsyncSequentialQueueJob  _Nonnull job, dispatch_block_t  _Nonnull completionHandler) {
			dispatch_async(dispatch_get_main_queue(), ^{
				job(completionHandler);
			});
		};

		_queuedJobs = [NSMutableArray new];
	}

	return(self);
}

#pragma mark - Job execution
- (void)async:(OCAsyncSequentialQueueJob)job
{
	BOOL runNextJob = NO;

	@synchronized (self)
	{
		[_queuedJobs addObject:[job copy]];

		if (!_busy)
		{
			runNextJob = YES;
			_busy = YES;
		}
	}

	if (runNextJob)
	{
		[self runNextJob];
	}
}

- (void)runNextJob
{
	OCAsyncSequentialQueueJob nextJob = nil;

	@synchronized (self)
	{
		if (_queuedJobs.count > 0)
		{
			if ((nextJob = _queuedJobs.firstObject) != nil)
			{
				[_queuedJobs removeObjectAtIndex:0];
			}
		}
		else
		{
			_busy = NO;
		}
	}

	if (nextJob != nil)
	{
		__block BOOL didRunNext = NO;

		self.executor(nextJob, ^{
			if (!didRunNext)
			{
				didRunNext = YES;
				[self runNextJob];
			}
			else
			{
				OCLogError(@"OCAsyncSequentialQueueJob completionHandler called multiple times. Backtrace: %@", NSThread.callStackSymbols);
			}
		});
	}
}

@end
