//
//  OCCoreNetworkMonitorSignalProvider.m
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

#import "OCCoreNetworkMonitorSignalProvider.h"
#import "OCMacros.h"
#import "OCConnection.h"
#import "OCNetworkMonitor.h"
#import "OCCellularManager.h"

@interface OCCoreNetworkMonitorSignalProvider ()
{
	BOOL _listeningForChangesAndUpdates;
}

@end

@implementation OCCoreNetworkMonitorSignalProvider

- (instancetype)init
{
	return ([super initWithSignal:OCCoreConnectionStatusSignalReachable initialState:OCCoreConnectionStatusSignalStateFalse stateProvider:nil]);
}

#pragma mark - Update state
- (void)_updateState:(nullable NSNotification *)notification
{
	OCNetworkMonitor *networkMonitor = notification.object;

	if (networkMonitor == nil)
	{
		networkMonitor = OCNetworkMonitor.sharedNetworkMonitor;
	}

	if (networkMonitor != nil)
	{
		NSString *shortDescription = nil;
		OCCoreConnectionStatusSignalState state;

		if (networkMonitor.networkAvailable)
		{
			// Network is available
			if (networkMonitor.isExpensive)
			{
				// Network is expensive (f.ex. cellular)
				if (!OCConnection.allowCellular || // MDM setting
				    ![[OCCellularManager.sharedManager switchWithIdentifier:OCCellularSwitchIdentifierMain] allowsTransferOfSize:1]) // Main cellular switch
				{
					// Cellular is not allowed -> indicate network is unavailable
					shortDescription = OCLocalized(@"Offline (no WiFi connection)");
					state = OCCoreConnectionStatusSignalStateFalse;
				}
				else
				{
					// Cellular is allowed -> indicate network is available
					state = OCCoreConnectionStatusSignalStateTrue;
				}
			}
			else
			{
				// WiFi network available
				state = OCCoreConnectionStatusSignalStateTrue;
			}
		}
		else
		{
			// No network available
			state = OCCoreConnectionStatusSignalStateFalse;
		}

		self.shortDescription = shortDescription;
		self.state = state;

		OCTLogDebug(@[@"NetworkAvailability"], @"Reachable signal changed to %lu (%@)", (unsigned long)state, shortDescription);
	}
}

#pragma mark - Events
- (void)providerWillBeAdded
{
	if (!_listeningForChangesAndUpdates)
	{
		_listeningForChangesAndUpdates = YES;

		// Listen for network monitor updates
		[OCNetworkMonitor.sharedNetworkMonitor addNetworkObserver:self selector:@selector(_updateState:)];

		// Listen for cellular settings changes
		[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(_updateState:) name:OCCellularSwitchUpdatedNotification object:nil];

		// Initialize state
		[self _updateState:nil];
	}
}

- (void)providerWasRemoved
{
	if (_listeningForChangesAndUpdates)
	{
		_listeningForChangesAndUpdates = NO;

		// Stop listening for cellular settings changes
		[NSNotificationCenter.defaultCenter removeObserver:self name:OCCellularSwitchUpdatedNotification object:nil];

		// Stop listening for network monitor updates
		[OCNetworkMonitor.sharedNetworkMonitor removeNetworkObserver:self];
	}
}

@end
