//
//  OCConnection+GraphAPI.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 26.01.22.
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

#import "OCConnection.h"

NS_ASSUME_NONNULL_BEGIN

@class OCDrive;

typedef void(^OCRetrieveDriveListCompletionHandler)(NSError * _Nullable error, NSArray<OCDrive *> * _Nullable drives);

@interface OCConnection (GraphAPI)

#pragma mark - Drives
@property(strong,nullable) NSArray<OCDrive *> *drives; //!< Current list of known drives

- (nullable OCDrive *)driveWithID:(OCDriveID)driveID; //!< Returns the OCDrive instance for the provided ID if it is already known locally
- (void)driveWithID:(OCDriveID)driveID completionHandler:(void(^)(OCDrive * _Nullable drive))completionHandler; //!< Returns the OCDrive instance for the provided ID. Will attempt to retrieve it from the server if not known locally.

- (nullable NSProgress *)retrieveDriveListWithCompletionHandler:(OCRetrieveDriveListCompletionHandler)completionHandler; //!< Retrieves a list of drives and updates .drives

@end

extern OCConnectionEndpointID OCConnectionEndpointIDGraphMeDrives;
extern OCConnectionEndpointID OCConnectionEndpointIDGraphDrives;

NS_ASSUME_NONNULL_END
