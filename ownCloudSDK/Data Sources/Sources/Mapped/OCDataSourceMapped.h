//
//  OCDataSourceMapped.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 15.11.22.
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

@class OCDataSourceMapped;

typedef _Nullable id<OCDataItem>(^OCDataSourceMappedItemCreator)(OCDataSourceMapped *mappedSource, id<OCDataItem> fromItem);
typedef _Nonnull id<OCDataItem>(^OCDataSourceMappedItemUpdater)(OCDataSourceMapped *mappedSource, id<OCDataItem> fromItem, id<OCDataItem> mappedItem);
typedef void(^OCDataSourceMappedItemDestroyer)(OCDataSourceMapped *mappedSource, OCDataItemReference fromItemReference, id<OCDataItem> mappedItem);

@interface OCDataSourceMapped : OCDataSourceArray

@property(strong) OCDataSource *source;

- (instancetype)initWithItems:(nullable NSArray<id<OCDataItem>> *)items NS_UNAVAILABLE;

- (instancetype)initWithSource:(OCDataSource *)source creator:(OCDataSourceMappedItemCreator)itemCreator updater:(nullable OCDataSourceMappedItemUpdater)updater destroyer:(nullable OCDataSourceMappedItemDestroyer)destroyer queue:(nullable dispatch_queue_t)queue;

@end

NS_ASSUME_NONNULL_END
