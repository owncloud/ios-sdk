//
//  OCCore+ConnectionStatus.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 05.12.18.
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

#import "OCCore.h"
#import "OCCoreConnectionStatusSignalProvider.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCCore (ConnectionStatus) <OCConnectionDelegate>

#pragma mark - Signal providers
- (void)addSignalProvider:(OCCoreConnectionStatusSignalProvider *)provider;
- (void)removeSignalProviders;

#pragma mark - Connection status updates
- (void)recomputeConnectionStatus;

#pragma mark - Reporting
- (void)reportReponseIndicatingMaintenanceMode;

@end

NS_ASSUME_NONNULL_END
