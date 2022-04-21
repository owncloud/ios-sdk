//
//  OCDataTypes.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 08.03.22.
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

typedef NSObject* OCDataItemReference; //!< Unique reference that uniquely identifies an item within a data source, typically a string or number
typedef NSString* OCDataItemType NS_TYPED_ENUM; //!< The item type, i.e. OCItem, OCDrive, ItemDescription, Section, TableCell, CollectionCell, View
typedef id<NSObject> OCDataItemVersion; //!< The version of the item, i.e. a string or a number. Can be used by data sources to find changed items in small data sets.

typedef NSString* OCDataSourceUUID; //!< Unique data source UUID
typedef NSString* OCDataSourceType NS_TYPED_ENUM; //!< Optional data source type, i.e. List, SectionedList

typedef NSString* OCDataViewOption NS_TYPED_ENUM; //!< Options for view pipeline, i.e. reusable view
typedef NSDictionary<OCDataViewOption,id>* OCDataViewOptions;

typedef NSString* OCDataSourceSpecialItem NS_TYPED_ENUM;

NS_ASSUME_NONNULL_BEGIN

@class OCDataSource;
@class OCDataItemRecord;

@protocol OCDataItem <NSObject>

@property(readonly) OCDataItemType dataItemType;
@property(readonly) OCDataItemReference dataItemReference;

@optional
- (BOOL)hasChildrenUsingSource:(OCDataSource *)source; //!< Indiciates if the item has children
- (nullable OCDataSource *)dataSourceForChildrenUsingSource:(OCDataSource *)source; //!< Provides a datasource containing the children of the item. The parent item's data source is provided as parameter.

@end

@protocol OCDataItemVersion
@property(readonly) OCDataItemVersion dataItemVersion;
@end

typedef BOOL(^OCDataItemHasChildrenProvider)(OCDataSource *dataSource, id<OCDataItem> item);
typedef OCDataSource * _Nullable(^OCDataItemChildrenDataSourceProvider)(OCDataSource *parentItemDataSource, id<OCDataItem> parentItem);

typedef BOOL(^OCDataSourceItemFilter)(OCDataSource *source, OCDataItemReference itemRef);
typedef NSComparisonResult(^OCDataSourceItemComparator)(OCDataSource *source1, OCDataItemReference itemRef1, OCDataSource *source2, OCDataItemReference itemRef2);

typedef BOOL(^OCDataSourceItemRecordFilter)(OCDataItemRecord * _Nullable itemRecord);
typedef NSComparisonResult(^OCDataSourceItemRecordComparator)(OCDataItemRecord * _Nullable itemRecord1, OCDataItemRecord * _Nullable itemRecord2);

extern OCDataItemType OCDataItemTypeItem;  //!< Item of type OCItem
extern OCDataItemType OCDataItemTypeDrive; //!< Item of type OCDrive
extern OCDataItemType OCDataItemTypePresentable; //!< Item of type OCDataItemPresentable
extern OCDataItemType OCDataItemTypeTextResource; //!< Item of type OCResourceText

extern OCDataViewOption OCDataViewOptionCore; //!< OCCore instance
extern OCDataViewOption OCDataViewOptionListContentConfiguration; //!< UIListContentConfiguration instance to fill

NS_ASSUME_NONNULL_END
