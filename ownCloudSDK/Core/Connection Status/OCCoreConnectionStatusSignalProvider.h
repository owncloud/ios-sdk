//
//  OCCoreConnectionStatusSignalProvider.h
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

#import <Foundation/Foundation.h>
#import "OCCore.h"

NS_ASSUME_NONNULL_BEGIN

typedef OCCoreConnectionStatusSignalState(^OCCoreConnectionStatusSignalStateProvider)(OCCoreConnectionStatusSignalProvider *provider);

@interface OCCoreConnectionStatusSignalProvider : NSObject
{
	__weak OCCore *_core;
	OCCoreConnectionStatusSignal _signal;
	OCCoreConnectionStatusSignalState _state;

	OCCoreConnectionStatusSignalStateProvider _stateProvider;
}

@property(nullable,weak) OCCore *core;
@property(readonly) OCCoreConnectionStatusSignal signal;
@property(assign,nonatomic) OCCoreConnectionStatusSignalState state;

#pragma mark - Init
- (instancetype)initWithSignal:(OCCoreConnectionStatusSignal)signal initialState:(OCCoreConnectionStatusSignalState)initialState stateProvider:(nullable OCCoreConnectionStatusSignalStateProvider)stateProvider;

#pragma mark - Events
- (void)providerWillBeAdded;
- (void)providerWasAdded;
- (void)providerWillBeRemoved;
- (void)providerWasRemoved;

@end

NS_ASSUME_NONNULL_END
