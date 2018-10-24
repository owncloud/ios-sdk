//
//  OCCore+ItemUpdates.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 24.10.18.
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
#import "OCCoreItemList.h"

NS_ASSUME_NONNULL_BEGIN

typedef void(^OCCoreItemUpdateQueryPostProcessor)(OCCore *core, OCQuery *query, OCCoreItemList *addedItemsList, OCCoreItemList *removedItemsList, OCCoreItemList *updatedItemsList);

@interface OCCore (ItemUpdates)

#pragma mark - Perform updates
- (void)performUpdatesForAddedItems:(nullable NSArray<OCItem *> *)addedItems
			removedItems:(nullable NSArray<OCItem *> *)removedItems
			updatedItems:(nullable NSArray<OCItem *> *)updatedItems
			refreshPaths:(nullable NSArray <OCPath> *)refreshPaths
		       newSyncAnchor:(nullable OCSyncAnchor)newSyncAnchor
		     preflightAction:(nullable void(^)(dispatch_block_t completionHandler))preflightAction
		    postflightAction:(nullable void(^)(dispatch_block_t completionHandler))postflightAction
		  queryPostProcessor:(nullable OCCoreItemUpdateQueryPostProcessor)queryPostProcessor;

@end

NS_ASSUME_NONNULL_END
