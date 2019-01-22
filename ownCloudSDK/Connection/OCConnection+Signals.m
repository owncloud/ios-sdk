//
//  OCConnection+Signals.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 09.01.19.
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

#import "OCConnection.h"
#import "OCConnectionQueue.h"

@implementation OCConnection (Signals)

- (void)setSignal:(OCConnectionSignalID)signal on:(BOOL)on
{
	BOOL scheduleRequests = NO;

	@synchronized(_signals)
	{
		if ([_signals containsObject:signal] != on)
		{
			if (on)
			{
				[_signals addObject:signal];
			}
			else
			{
				[_signals removeObject:signal];
			}

			scheduleRequests = YES;
		}
	}

	if (scheduleRequests)
	{
		[self _scheduleRequestsOnQueues];
	}
}

- (void)updateSignalsWith:(NSSet <OCConnectionSignalID> *)allSignals
{
	BOOL scheduleRequests = NO;

	@synchronized(_signals)
	{
		if (![allSignals isEqualToSet:_signals])
		{
			[_signals removeAllObjects];
			[_signals unionSet:allSignals];

			scheduleRequests = YES;
		}
	}

	if (scheduleRequests)
	{
		[self _scheduleRequestsOnQueues];
	}
}

- (BOOL)isSignalOn:(OCConnectionSignalID)signal
{
	@synchronized(_signals)
	{
		return ([_signals containsObject:signal]);
	}
}

- (BOOL)meetsSignalRequirements:(NSSet<OCConnectionSignalID> *)requiredSignals
{
	if (requiredSignals == nil)
	{
		return (YES);
	}

	@synchronized(_signals)
	{
		return ([requiredSignals isSubsetOfSet:_signals]);
	}
}

- (void)_scheduleRequestsOnQueues
{
	[[self allQueues] makeObjectsPerformSelector:@selector(scheduleQueuedRequests)];
}

@end
