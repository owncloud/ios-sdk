//
//  OCCellularManager.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 20.05.20.
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
#import "OCCellularSwitch.h"
#import "OCIPNotificationCenter.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCCellularManager : NSObject

@property(strong,nonatomic,readonly,class) OCCellularManager *sharedManager;

@property(strong,readonly) NSArray<OCCellularSwitch *> *switches;

- (void)registerSwitch:(OCCellularSwitch *)cellularSwitch;
- (void)unregisterSwitch:(OCCellularSwitch *)cellularSwitch;

- (nullable OCCellularSwitch *)switchWithIdentifier:(OCCellularSwitchIdentifier)identifier;

- (BOOL)cellularAccessAllowedFor:(nullable OCCellularSwitchIdentifier)identifier transferSize:(NSUInteger)transferSize; //!< Convenience method merging results for the referenced and global main switches. If you pass nil as identifier, the main switch is used.

- (BOOL)networkAccessAvailableFor:(nullable OCCellularSwitchIdentifier)switchID transferSize:(NSUInteger)transferSize onWifiOnly:(BOOL * _Nullable)outOnWifiOnly; //!< Returns if network access is _currently_ allowed for the respective cellular switch - and (optionally) - if only WiFi should be used. Only pass signals prefixed with OCConnectionSignalCellularSwitchPrefix here!

@end

extern OCIPCNotificationName OCIPCNotificationNameOCCellularSwitchChangedNotification;

NS_ASSUME_NONNULL_END
