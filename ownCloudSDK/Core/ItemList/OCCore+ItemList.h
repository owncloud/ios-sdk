//
//  OCCore+ItemList.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 23.07.18.
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
#import "OCLockManager.h"
#import "OCLockRequest.h"

NS_ASSUME_NONNULL_BEGIN

@class OCMeasurement;

@interface OCCore (ItemList)

#pragma mark - Item List Tasks
- (void)scheduleItemListTaskForPath:(OCPath)path forDirectoryUpdateJob:(nullable OCCoreDirectoryUpdateJob *)directoryUpdateJob withMeasurement:(nullable OCMeasurement *)measurement;
- (void)handleUpdatedTask:(OCCoreItemListTask *)task;

- (void)queueRequestJob:(OCAsyncSequentialQueueJob)requestJob;

#pragma mark - Check for updates
- (void)startCheckingForUpdates; //!< Checks the root directory for a changed ETag and recursively traverses the entire tree for all updated and new items.
- (void)fetchUpdatesWithCompletionHandler:(nullable OCCoreItemListFetchUpdatesCompletionHandler)completionHandler; //!< Checks the root directory for a changed ETag and recursively traverses the entire tree for all updated and new items. Calls a completionHandler when done.

- (void)_handleRetrieveItemListEvent:(OCEvent *)event sender:(id)sender;

#pragma mark - Update Scans
- (void)scheduleUpdateScanForPath:(OCPath)path waitForNextQueueCycle:(BOOL)waitForNextQueueCycle;
- (void)recoverPendingUpdateJobs;

- (void)coordinatedScanForChanges;
- (void)shutdownCoordinatedScanForChanges;

@end

@interface OCCore (ItemListInternal)
- (void)scheduleNextItemListTask;
@end

extern OCActivityIdentifier OCActivityIdentifierPendingServerScanJobsSummary; //!< The activity reporting the progress of background checks for updates

extern OCKeyValueStoreKey OCKeyValueStoreKeyCoreUpdateScheduleRecord;
extern OCLockResourceIdentifier OCLockResourceIdentifierCoreUpdateScan;

NS_ASSUME_NONNULL_END
