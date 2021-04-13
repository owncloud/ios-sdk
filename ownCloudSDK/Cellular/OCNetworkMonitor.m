//
//  OCNetworkMonitor.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 28.06.20.
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

#import <Network/Network.h>
#import "OCLogger.h"

#import "OCNetworkMonitor.h"
#import "OCMacros.h"

@interface OCNetworkMonitor ()
{
	nw_path_monitor_t _pathMonitor;
	dispatch_queue_t _monitorQueue;

	NSInteger _observerCount;
}

@end

@implementation OCNetworkMonitor

+ (OCNetworkMonitor *)sharedNetworkMonitor
{
	static OCNetworkMonitor *sharedNetworkMonitor;
	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		sharedNetworkMonitor = [OCNetworkMonitor new];
	});

	return (sharedNetworkMonitor);
}

- (void)setActive:(BOOL)active
{
	if (_active != active)
	{
		_active = active;

		if (_active)
		{
			if (_pathMonitor == nil)
			{
				// Create path monitor for all interfaces
				_pathMonitor = nw_path_monitor_create();

				// Create and set queue to deliver events to
				_monitorQueue = dispatch_queue_create("OCNetworkMonitor", DISPATCH_QUEUE_SERIAL);
				nw_path_monitor_set_queue(_pathMonitor, _monitorQueue);

				// Set update handler
				__weak OCNetworkMonitor *weakSelf = self;

				nw_path_monitor_set_update_handler(_pathMonitor, ^(nw_path_t _Nonnull path) {
					switch (nw_path_get_status(path))
					{
						case nw_path_status_satisfied:
						case nw_path_status_satisfiable:
							weakSelf.networkAvailable = YES;
						break;

						case nw_path_status_invalid:
						case nw_path_status_unsatisfied:
							weakSelf.networkAvailable = NO;
						break;
					}

					weakSelf.isExpensive = nw_path_is_expensive(path); // Cellular data or tethered connection

					// Post local notification
					[NSNotificationCenter.defaultCenter postNotificationName:OCNetworkMonitorStatusChangedNotification object:self];
				});

				// Start
				nw_path_monitor_start(_pathMonitor);
			}
		}
		else
		{
			if (_pathMonitor != nil)
			{
				// Wait for path monitor to complete cancellation
				OCSyncExec(waitForPathMonitorCancelCompletion, {
					nw_path_monitor_set_cancel_handler(_pathMonitor, ^{
						OCSyncExecDone(waitForPathMonitorCancelCompletion);
					});

					nw_path_monitor_cancel(_pathMonitor);
				});

				_pathMonitor = nil;
				_monitorQueue = nil;
			}
		}
	}
}

- (void)addNetworkObserver:(id)observer selector:(SEL)aSelector
{
	BOOL activate = NO;

	@synchronized(self)
	{
		if (_observerCount == 0)
		{
			activate = YES;
		}

		_observerCount++;
	}

	[NSNotificationCenter.defaultCenter addObserver:observer selector:aSelector name:OCNetworkMonitorStatusChangedNotification object:self];

	if (activate)
	{
		self.active = YES;
	}
}

- (void)removeNetworkObserver:(id)observer
{
	BOOL deactivate = NO;

	@synchronized(self)
	{
		_observerCount--;

		if (_observerCount == 0)
		{
			deactivate = YES;
		}

		if (_observerCount < 0)
		{
			OCLogError(@"More observers removed than added to %@ - could impact correct functioning until process termination!", self);
		}
	}

	[NSNotificationCenter.defaultCenter removeObserver:observer name:OCNetworkMonitorStatusChangedNotification object:self];

	if (deactivate)
	{
		self.active = NO;
	}
}

- (BOOL)isCellularConnection
{
	return (_isExpensive);
}

- (BOOL)isWifiOrEthernetConnection
{
	return (_networkAvailable && !_isExpensive);
}

@end

NSNotificationName OCNetworkMonitorStatusChangedNotification = @"OCNetworkMonitorStatusChangedNotification";
