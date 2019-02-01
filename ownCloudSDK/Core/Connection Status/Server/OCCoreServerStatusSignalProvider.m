//
//  OCCoreServerStatusSignalProvider.m
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

#import "OCCoreServerStatusSignalProvider.h"
#import "OCMacros.h"

@implementation OCCoreServerStatusSignalProvider

- (instancetype)init
{
	return ([super initWithSignal:OCCoreConnectionStatusSignalAvailable initialState:OCCoreConnectionStatusSignalStateTrue stateProvider:nil]);
}

- (void)dealloc
{
	[_statusPollTimer invalidate];
	_statusPollTimer = nil;
}

#pragma mark - Status poll timer
- (void)setStatusPollTimerActive:(BOOL)statusPollTimerActive
{
	dispatch_async(dispatch_get_main_queue(), ^{
		if (statusPollTimerActive != (self->_statusPollTimer != NULL))
		{
			if (statusPollTimerActive)
			{
				self->_statusPollTimer = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:10] interval:10 target:self selector:@selector(_sendStatusPollRequest:) userInfo:nil repeats:YES];
				[[NSRunLoop currentRunLoop] addTimer:self->_statusPollTimer forMode:NSRunLoopCommonModes];
			}
			else
			{
				[self->_statusPollTimer invalidate];
				self->_statusPollTimer = nil;
			}
		}
	});
}

- (void)_sendStatusPollRequest:(NSTimer *)timer
{
	[self.core.connection requestServerStatusWithCompletionHandler:^(NSError *error, OCConnectionRequest *request, NSDictionary<NSString *,id> *statusInfo) {
		if ((error == nil) && (statusInfo != nil))
		{
			NSNumber *maintenanceMode;

			if ((maintenanceMode = statusInfo[@"maintenance"]) != nil)
			{
				if (!maintenanceMode.boolValue)
				{
					self.shortDescription = nil;
					self.state = OCCoreConnectionStatusSignalStateTrue;
					[self setStatusPollTimerActive:NO];
				}
			}
		}
	}];
}

- (void)reportResponseIndicatingMaintenanceMode
{
	@synchronized(self)
	{
		self.state = OCCoreConnectionStatusSignalStateFalse;

		[self setStatusPollTimerActive:YES];
	}
}

- (void)reportConnectionRefusedError
{
	@synchronized(self)
	{
		self.state = OCCoreConnectionStatusSignalStateFalse;
		self.shortDescription = OCLocalized(@"Connection refused");

		[self setStatusPollTimerActive:YES];
	}
}

@end
