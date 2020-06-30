//
//  OCNetworkMonitor.h
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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface OCNetworkMonitor : NSObject

@property(class,strong,nonatomic,readonly) OCNetworkMonitor *sharedNetworkMonitor;

@property(assign,nonatomic) BOOL active;

@property(assign) BOOL networkAvailable; //!< Network connectivity is available
@property(assign) BOOL isExpensive;	 //!< YES if connectivity is using Cellular (on device or via Personal Hotspot)

@property(assign,nonatomic,readonly) BOOL isCellularConnection; //!< Convenience method wrapping .isExpensive and .networkAvailable. No KVO support for now.
@property(assign,nonatomic,readonly) BOOL isWifiOrEthernetConnection; //! Convenience method wrapping .isExpensive and .networkAvailable. No KVO support for now.

- (void)addNetworkObserver:(id)observer selector:(SEL)aSelector; //!< Convenience method to add an OCNetworkMonitorStatusChangedNotification observer and activate OCNetworkMonitor if the first observer is added and the monitor is not yet active
- (void)removeNetworkObserver:(id)observer; //!< Convenience method to remove an OCNetworkMonitorStatusChangedNotification observer and deactivate OCNetworkMonitor when the last observer was removed and the monitor is active

@end

extern NSNotificationName OCNetworkMonitorStatusChangedNotification;

NS_ASSUME_NONNULL_END
