//
//  OCDataSourceArray.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 22.03.22.
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

#import "OCDataSource.h"
#import "OCDataTypes.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCDataSourceArray : OCDataSource
{
	NSMapTable<OCDataItemReference,id<OCDataItem>> *_itemsByReference;
	NSMapTable<OCDataItemReference,OCDataItemVersion> *_versionsByReference;
}

@property(copy,nullable) OCDataItemHasChildrenProvider dataItemHasChildrenProvider;
@property(assign) BOOL trackItemVersions; //!< If YES, tracks versions internally, allowing to detect/track changes to the same object

- (instancetype)initWithItems:(nullable NSArray<id<OCDataItem>> *)items;

- (void)setItems:(nullable NSArray<id<OCDataItem>> *)items updated:(nullable NSSet<id<OCDataItem>> *)updatedItems; //!< Uses item IDs to populate the data source
- (void)setVersionedItems:(nullable NSArray<id<OCDataItem,OCDataItemVersioning>> *)items; //!< Uses item versions and item IDs to populate the data source

@end

NS_ASSUME_NONNULL_END
