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

NS_ASSUME_NONNULL_BEGIN

@interface OCCellularManager : NSObject

@property(strong,nonatomic,readonly,class) OCCellularManager *sharedManager;

@property(strong,readonly) NSArray<OCCellularSwitch *> *switches;

- (void)registerSwitch:(OCCellularSwitch *)cellularSwitch;
- (void)unregisterSwitch:(OCCellularSwitch *)cellularSwitch;

- (nullable OCCellularSwitch *)switchWithIdentifier:(OCCellularSwitchIdentifier)identifier;

- (BOOL)cellularAccessAllowedFor:(OCCellularSwitchIdentifier)identifier transferSize:(NSUInteger)transferSize; //!< Convenience method merging results for the referenced and global master switches

@end

NS_ASSUME_NONNULL_END
