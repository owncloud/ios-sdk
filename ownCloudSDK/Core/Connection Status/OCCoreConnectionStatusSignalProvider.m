//
//  OCCoreConnectionStatusSignalProvider.m
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

#import "OCCoreConnectionStatusSignalProvider.h"
#import "OCCore+ConnectionStatus.h"

@implementation OCCoreConnectionStatusSignalProvider

@synthesize core = _core;
@synthesize signal = _signal;
@synthesize state = _state;

#pragma mark - Init
- (instancetype)initWithSignal:(OCCoreConnectionStatusSignal)signal initialState:(OCCoreConnectionStatusSignalState)initialState stateProvider:(nullable OCCoreConnectionStatusSignalStateProvider)stateProvider
{
	if ((self = [super init]) != nil)
	{
		_signal = signal;
		_state = initialState;

		_stateProvider = [stateProvider copy];
	}

	return (self);
}

#pragma mark - State accessors
- (OCCoreConnectionStatusSignalState)state
{
	if (_stateProvider != nil)
	{
		return (_stateProvider(self));
	}

	return (_state);
}

- (void)setState:(OCCoreConnectionStatusSignalState)state
{
	if (_state != state)
	{
		_state = state;
		[self.core recomputeConnectionStatus];
	}
}

#pragma mark - Events
- (void)providerWillBeAdded
{
}

- (void)providerWasAdded
{
}

- (void)providerWillBeRemoved
{
}

- (void)providerWasRemoved
{
}

@end
