//
//  OCVault+Internal.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 07.05.19.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2019, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCVault.h"
#import "OCFeatureAvailability.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCVault (Internal) <NSFileManagerDelegate>

#pragma mark - Compacting
- (void)compactInContext:(nullable void(^)(void(^blockToRunInContext)(OCSyncAnchor syncAnchor, void(^updateHandler)(NSSet<OCLocalID> *updateDirectoryLocalIDs))))runInContext withSelector:(OCVaultCompactSelector)selector completionHandler:(nullable OCCompletionHandler)completionHandler; //!< Compacts the vault's contents using the selector to determine which items' files to delete. If the vault is used by an online core, make sure to pass a block for runInContext that runs the passed block inside -[OCCore performProtectedSyncBlock:..] to guarantee integrity.

#pragma mark - File Provider
- (void)signalChangesForItems:(NSArray <OCItem *> *)changedItems;
- (void)signalChangesInDirectoriesWithLocalIDs:(NSSet <OCLocalID> *)changedDirectoriesLocalIDs;
#if OC_FEATURE_AVAILABLE_FILEPROVIDER
- (void)signalEnumeratorForContainerItemIdentifier:(NSFileProviderItemIdentifier)changedDirectoryLocalID;
#endif /* OC_FEATURE_AVAILABLE_FILEPROVIDER */

@end

NS_ASSUME_NONNULL_END
