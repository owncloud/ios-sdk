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

typedef id<NSObject/*,NSCopying*/> OCDataItemReference; //!< Unique reference that uniquely identifies an item within a data source, typically a string or number
typedef NSString* OCDataItemType NS_TYPED_ENUM; //!< The item type, i.e. OCItem, OCDrive, ItemDescription, Section, TableCell, CollectionCell, View

typedef NSString* OCDataSourceType NS_TYPED_ENUM; //!< Optional data source type, i.e. List, SectionedList

typedef NSString* OCDataViewOption NS_TYPED_ENUM; //!< Options for view pipeline, i.e. reusable view
typedef NSDictionary<OCDataViewOption,id>* OCDataViewOptions;

typedef NSString* OCDataSourceSpecialItem NS_TYPED_ENUM;

NS_ASSUME_NONNULL_BEGIN

@class OCDataSource;

@protocol OCDataItem <NSObject>

@property(readonly) OCDataItemType dataItemType;
@property(readonly) OCDataItemReference dataItemReference;

@optional
- (BOOL)hasChildrenUsingSource:(OCDataSource *)source;

@end

NS_ASSUME_NONNULL_END
