//
//  OCCoreReachabilityConnectionStatusSignalProvider.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 06.12.18.
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

#import "OCMacros.h"
#import "OCCoreReachabilityConnectionStatusSignalProvider.h"

@implementation OCCoreReachabilityConnectionStatusSignalProvider

- (instancetype)initWithHostname:(NSString *)hostname
{
	if ((self = [super initWithSignal:OCCoreConnectionStatusSignalReachable initialState:OCCoreConnectionStatusSignalStateFalse stateProvider:nil]) != nil)
	{
		_hostname = hostname;
	}

	return (self);
}

#pragma mark - Reachability
- (void)_reachabilityChanged:(NSNotification *)notification
{
	self.state = _reachabilityMonitor.available ? OCCoreConnectionStatusSignalStateTrue : OCCoreConnectionStatusSignalStateFalse;
}

#pragma mark - Events
- (void)providerWillBeAdded
{
	if (_reachabilityMonitor == nil)
	{
		_reachabilityMonitor = [[OCReachabilityMonitor alloc] initWithHostname:_hostname];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_reachabilityChanged:) name:OCReachabilityMonitorAvailabilityChangedNotification object:_reachabilityMonitor];

		OCSyncExec(waitForReachabilityMonitorStartupCompletion, {
			[_reachabilityMonitor setEnabled:YES withCompletionHandler:^{
				OCSyncExecDone(waitForReachabilityMonitorStartupCompletion);
			}];
		});
	}
}

- (void)providerWasRemoved
{
	if (_reachabilityMonitor != nil)
	{
		[[NSNotificationCenter defaultCenter] removeObserver:self name:OCReachabilityMonitorAvailabilityChangedNotification object:_reachabilityMonitor];

		OCSyncExec(waitForReachabilityMonitorShutdownCompletion, {
			[_reachabilityMonitor setEnabled:NO withCompletionHandler:^{
				OCSyncExecDone(waitForReachabilityMonitorShutdownCompletion);
			}];
		});

		_reachabilityMonitor = nil;
	}
}

@end
