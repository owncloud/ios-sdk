//
//  OCVaultDriveList.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 16.05.22.
//  Copyright © 2022 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2022, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import <Foundation/Foundation.h>
#import "OCDrive.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCVaultDriveList : NSObject <NSSecureCoding>

@property(strong) NSArray<OCDrive *> *drives; //!< All (active) drives
@property(strong) NSMutableSet<OCDriveID> *subscribedDriveIDs; //!< List of all drives the user is subscribed to, may contain active and detached IDs

@property(strong,nullable) NSArray<OCDrive *> *detachedDrives; //!< All detached drives

@end

NS_ASSUME_NONNULL_END
