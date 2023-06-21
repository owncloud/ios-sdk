//
//  OCDataItemRecord.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 15.03.22.
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
#import "OCDataTypes.h"

NS_ASSUME_NONNULL_BEGIN

@class OCDataSource;

@interface OCDataItemRecord : NSObject

@property(weak,nullable) OCDataSource *source;

@property(strong) OCDataItemReference reference;
@property(strong) OCDataItemType type;

@property(assign) BOOL hasChildren;

@property(strong,nullable) id<OCDataItem> item;

- (instancetype)initWithSource:(nullable OCDataSource *)source itemType:(OCDataItemType)type itemReference:(OCDataItemReference)itemRef hasChildren:(BOOL)hasChildren item:(nullable id<OCDataItem>)item;

- (instancetype)initWithSource:(nullable OCDataSource *)source item:(nullable id<OCDataItem>)item hasChildren:(BOOL)hasChildren;

- (void)retrieveItemWithCompletionHandler:(void(^)(NSError * _Nullable error, OCDataItemRecord * _Nullable record))completionHandler;

@end

NS_ASSUME_NONNULL_END
