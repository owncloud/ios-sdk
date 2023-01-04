//
//  OCCore+DataSources.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 28.03.22.
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

#import <ownCloudSDK/ownCloudSDK.h>

NS_ASSUME_NONNULL_BEGIN

@interface OCCore (DataSources)

#pragma mark - Drives data sources (event-driven)
@property(readonly,strong,nonatomic) OCDataSource *drivesDataSource; //!< ALL drives
@property(readonly,strong,nonatomic) OCDataSource *subscribedDrivesDataSource; //!< Drives the user is subscribed to
@property(readonly,strong,nonatomic) OCDataSource *personalDriveDataSource; //!< Personal drive
@property(readonly,strong,nonatomic) OCDataSource *shareJailDriveDataSource; //!< Shares Jail drive
@property(readonly,strong,nonatomic) OCDataSource *projectDrivesDataSource; //!< Spaces the user is subscribed to (applies filter on .subscribedDrivesDataSource)

#pragma mark - Sharing data sources (on-demand)
// On-demand data sources require constant polling or other additional overhead - they are only updated when they have subscribers
// Therefore subscriptions should not be "hoarded" on on-demand data sources, but only be kept around for as long as needed - and then terminated.
@property(readonly,strong,nonatomic) OCDataSource *sharedWithMePendingDataSource;
@property(readonly,strong,nonatomic) OCDataSource *sharedWithMeAcceptedDataSource;  //!< Contents same as the Shared Jail drive
@property(readonly,strong,nonatomic) OCDataSource *sharedWithMeDeclinedDataSource;

@property(readonly,strong,nonatomic) OCDataSource *sharedByMeDataSource;
@property(readonly,strong,nonatomic) OCDataSource *sharedByLinkDataSource;

#pragma mark - Special datasources (on-demand)
// On-demand data sources require constant polling or other additional overhead - they are only updated when they have subscribers
// Therefore subscriptions should not be "hoarded" on on-demand data sources, but only be kept around for as long as needed - and then terminated.
@property(readonly,strong,nonatomic) OCDataSource *favoritesDataSource;
@property(readonly,strong,nonatomic) OCDataSource *availableOfflineItemPoliciesDataSource;
@property(readonly,strong,nonatomic) OCDataSource *availableOfflineFilesDataSource;

@end

NS_ASSUME_NONNULL_END
