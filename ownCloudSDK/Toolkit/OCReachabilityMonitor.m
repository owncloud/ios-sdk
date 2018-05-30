//
//  OCReachabilityMonitor.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 05.04.18.
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

#import "OCReachabilityMonitor.h"

@implementation OCReachabilityMonitor

@synthesize hostname = _hostname;

@synthesize enabled = _enabled;
@synthesize available = _available;

- (instancetype)initWithHostname:(NSString *)hostname
{
	if ((self = [super init]) != nil)
	{
		self.hostname = hostname;
	}

	return (self);
}

- (void)dealloc
{
	self.enabled = NO;
}

- (void)setEnabled:(BOOL)enabled
{
	if ([NSThread isMainThread])
	{
		[self _setEnabled:enabled];
	}
	else
	{
		[self performSelectorOnMainThread:@selector(_setEnabled:) withObject:@(enabled) waitUntilDone:YES];
	}
}

static void OCReachabilityMonitorCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void *info)
{
	OCReachabilityMonitor *monitor = (__bridge OCReachabilityMonitor *)info;
	BOOL available;

	available = 	((flags & kSCNetworkReachabilityFlagsReachable) != 0)	// Reachable!
			&&
			(
			 ((flags & kSCNetworkReachabilityFlagsConnectionRequired) == 0) ||	// No connection required
			 (((flags & (kSCNetworkReachabilityFlagsConnectionOnTraffic|kSCNetworkReachabilityFlagsConnectionOnDemand)) != 0) && ((flags & kSCNetworkReachabilityFlagsInterventionRequired) == 0)) || // Connection on demand available without intervention
			 ((flags & kSCNetworkReachabilityFlagsIsLocalAddress) != 0) // Local address, reachable
			);
	if (available != monitor.available)
	{
		[monitor willChangeValueForKey:@"available"];
		monitor->_available = available;
		[monitor didChangeValueForKey:@"available"];

		[[NSNotificationCenter defaultCenter] postNotificationName:OCReachabilityMonitorAvailabilityChangedNotification object:monitor];
	}
}

- (void)_setEnabled:(BOOL)enabled
{
	if (_enabled != enabled)
	{
		_enabled = enabled;

		if (_reachabilityRef != NULL)
		{
			SCNetworkReachabilitySetCallback(_reachabilityRef, NULL, NULL);
			SCNetworkReachabilityUnscheduleFromRunLoop(_reachabilityRef, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);

			CFRelease(_reachabilityRef);
			_reachabilityRef = NULL;
		}

		if (_enabled && (_hostname!=nil))
		{
			if ((_reachabilityRef = SCNetworkReachabilityCreateWithName(kCFAllocatorDefault, _hostname.UTF8String)) != NULL)
			{
				SCNetworkReachabilityFlags flags = 0;
				SCNetworkReachabilityContext context = { 0, (__bridge void *)self, NULL, NULL, NULL };

				if (SCNetworkReachabilitySetCallback(_reachabilityRef, OCReachabilityMonitorCallback, &context))
				{
					SCNetworkReachabilityScheduleWithRunLoop(_reachabilityRef, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
				}

				if (SCNetworkReachabilityGetFlags(_reachabilityRef, &flags))
				{
					OCReachabilityMonitorCallback(_reachabilityRef, flags, (__bridge void *)self);
				}
			}
		}
	}
}

@end

NSNotificationName OCReachabilityMonitorAvailabilityChangedNotification = @"OCReachabilityMonitorAvailabilityChanged";
