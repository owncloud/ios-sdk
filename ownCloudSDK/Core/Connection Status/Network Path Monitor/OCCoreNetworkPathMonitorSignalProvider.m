//
//  OCCoreNetworkPathMonitorSignalProvider.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 10.01.19.
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

#import <Network/Network.h>

#import "OCCoreNetworkPathMonitorSignalProvider.h"
#import "OCMacros.h"
#import "OCConnection.h"

@interface OCCoreNetworkPathMonitorSignalProvider ()
{
	nw_path_monitor_t _pathMonitor;
	dispatch_queue_t _monitorQueue;
}

@property(assign) BOOL isSatisfied;
@property(assign) BOOL isExpensive;

@end

@implementation OCCoreNetworkPathMonitorSignalProvider

- (instancetype)initWithHostname:(NSString *)hostname
{
	if ((self = [super initWithSignal:OCCoreConnectionStatusSignalReachable initialState:OCCoreConnectionStatusSignalStateFalse stateProvider:nil]) != nil)
	{
		_hostname = hostname;
	}

	return (self);
}

#pragma mark - Update state
- (void)_updateState
{
	NSString *shortDescription = nil;

	if (_isSatisfied)
	{
		if (_isExpensive)
		{
			if (_isExpensive && !OCConnection.allowCellular)
			{
				shortDescription = OCLocalized(@"Offline (no WiFi connection)");
				self.shortDescription = shortDescription;
			}

			self.state = OCConnection.allowCellular ? OCCoreConnectionStatusSignalStateTrue : OCCoreConnectionStatusSignalStateFalse;
		}
		else
		{
			self.state = OCCoreConnectionStatusSignalStateTrue;
		}
	}
	else
	{
		self.state = OCCoreConnectionStatusSignalStateFalse;
	}

	self.shortDescription = shortDescription;
}

#pragma mark - Events
- (void)providerWillBeAdded
{
	if (_pathMonitor == nil)
	{
		if (@available(iOS 12,*))
		{
			// Create path monitor for all interfaces
			_pathMonitor = nw_path_monitor_create();

			// Create and set queue to deliver events to
			_monitorQueue = dispatch_queue_create("OCCoreNetworkPathMonitorSignalProvider", DISPATCH_QUEUE_SERIAL);
			nw_path_monitor_set_queue(_pathMonitor, _monitorQueue);

			// Set update handler
			__weak OCCoreNetworkPathMonitorSignalProvider *weakSelf = self;

			nw_path_monitor_set_update_handler(_pathMonitor, ^(nw_path_t _Nonnull path) {
				switch (nw_path_get_status(path))
				{
					case nw_path_status_satisfied:
					case nw_path_status_satisfiable:
						weakSelf.isSatisfied = YES;
					break;

					case nw_path_status_invalid:
					case nw_path_status_unsatisfied:
						weakSelf.isSatisfied = NO;
					break;
				}

				weakSelf.isExpensive = nw_path_is_expensive(path); // Cellular data or tethered connection

				[weakSelf _updateState];
			});

			// Start
			nw_path_monitor_start(_pathMonitor);

			// Listen for connection settings changes
			[OCIPNotificationCenter.sharedNotificationCenter addObserver:self forName:OCIPCNotificationNameConnectionSettingsChanged withHandler:^(OCIPNotificationCenter * _Nonnull notificationCenter, OCCoreNetworkPathMonitorSignalProvider * _Nonnull signalProvider, OCIPCNotificationName  _Nonnull notificationName) {
				[signalProvider _updateState];
			}];
		}
	}
}

- (void)providerWasRemoved
{
	if (_pathMonitor != nil)
	{
		if (@available(iOS 12,*))
		{
			// Stop listening for connection settings changes
			[OCIPNotificationCenter.sharedNotificationCenter removeObserver:self forName:OCIPCNotificationNameConnectionSettingsChanged];

			// Wait for path monitor to complete cancellation
			OCSyncExec(waitForPathMonitorCancelCompletion, {
				nw_path_monitor_set_cancel_handler(_pathMonitor, ^{
					OCSyncExecDone(waitForPathMonitorCancelCompletion);
				});

				nw_path_monitor_cancel(_pathMonitor);
			});
		}

		_pathMonitor = nil;
		_monitorQueue = nil;
	}
}

@end
