//
//  OCDataSourceKVO.h
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

#import "OCDataSourceArray.h"

NS_ASSUME_NONNULL_BEGIN

typedef NSArray<id<OCDataItem>> * _Nullable (^OCDataSourceKVOItemUpdateHandler)(NSObject *object, NSString *keyPath, id _Nullable newValue, NSSet<id<OCDataItem>> * _Nullable * _Nullable outUpdatedItems);
typedef NSArray<id<OCDataItem,OCDataItemVersion>> * _Nullable (^OCDataSourceKVOVersionedItemUpdateHandler)(NSObject *object, NSString *keyPath, id _Nullable newValue);

@interface OCDataSourceKVO : OCDataSourceArray

- (instancetype)initWithObject:(NSObject *)object keyPath:(NSString *)keyPath itemUpdateHandler:(OCDataSourceKVOItemUpdateHandler)itemUpdateHandler; //!< Create a data source based on the key-value observation of an object. The itemUpdateHandler returns an array of OCDataItems and a set of updated items via outUpdatedItems.

- (instancetype)initWithObject:(NSObject *)object keyPath:(NSString *)keyPath versionedItemUpdateHandler:(nullable OCDataSourceKVOVersionedItemUpdateHandler)versionedItemUpdateHandler; //!< Create a data source based on the key-value observation of an object. The versionedItemUpdateHandler returns an array of OCDataItems that also conform to OCDataItemVersion. Passing nil will use the observation value as that array.

@end

NS_ASSUME_NONNULL_END
