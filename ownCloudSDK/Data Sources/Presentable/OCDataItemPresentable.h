//
//  OCDataItemPresentable.h
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

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "OCDataTypes.h"

NS_ASSUME_NONNULL_BEGIN

@class OCDataItemPresentable;
@class OCResourceRequest;

typedef NSString* OCDataItemPresentableResource NS_TYPED_ENUM;
typedef OCResourceRequest * _Nullable(^OCDataItemPresentableResourceRequestProvider)(OCDataItemPresentable *presentable, OCDataItemPresentableResource presentableResource, OCDataViewOptions _Nullable options, NSError * _Nullable * _Nullable outError);

@interface OCDataItemPresentable : NSObject <OCDataItem, OCDataItemVersioning>

#pragma mark - OCDataItem conformance
@property(strong) OCDataItemReference dataItemReference;
@property(nullable,strong) OCDataItemType originalDataItemType;

#pragma mark - OCDataItemVersion conformance
@property(nullable,strong) OCDataItemVersion dataItemVersion;

#pragma mark - Presentable properties
@property(strong,nullable) UIImage *image;
@property(strong,nullable) NSString *title;
@property(strong,nullable) NSString *subtitle;

#pragma mark - Initialization
- (instancetype)init NS_UNAVAILABLE; //!< Always returns nil. Please use the designated initializer instead.
- (instancetype)initWithReference:(OCDataItemReference)reference originalDataItemType:(nullable OCDataItemType)originalDataItemType version:(nullable OCDataItemVersion)dataItemVersion NS_DESIGNATED_INITIALIZER; //!< Initialize with reference of item from which the presentable representation is derived
- (instancetype)initWithItem:(id<OCDataItem>)item NS_DESIGNATED_INITIALIZER; //!< Initialize with reference, originalDataItemType and (where available) dataItemVersion of item from which the presentable representation is derived

#pragma mark - Asynchronous resource retrieval
@property(strong,nullable) NSArray<OCDataItemPresentableResource> *availableResources; //!< Set of available resources that can be requested
@property(copy,nullable) OCDataItemPresentableResourceRequestProvider resourceRequestProvider; //!< Resource request provider, used by - provideResourceRequest:withOptions:completionHandler:

- (nullable OCResourceRequest *)provideResourceRequest:(OCDataItemPresentableResource)presentableResource withOptions:(nullable OCDataViewOptions)options error:(NSError * _Nullable * _Nullable)outError; //!< Returns an OCResourceRequest for a particular resource associated with the presentable, i.e. a thumbnail, using the presentable's resourceRequestProvider

#pragma mark - Children data source provider
@property(copy,nullable) OCDataItemHasChildrenProvider hasChildrenProvider;
@property(copy,nullable) OCDataItemChildrenDataSourceProvider childrenDataSourceProvider;

@end

extern OCDataItemPresentableResource OCDataItemPresentableResourceCoverImage;
extern OCDataItemPresentableResource OCDataItemPresentableResourceCoverDescription;

NS_ASSUME_NONNULL_END
