//
//  OCDataRenderer.h
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
#import "OCDataTypes.h"

NS_ASSUME_NONNULL_BEGIN

@class OCDataSource;
@class OCDataConverter;

@interface OCDataRenderer : NSObject

@property(readonly,class,nonatomic,strong) OCDataRenderer *defaultRenderer; //!< Globally shared default renderer

- (instancetype)initWithConverters:(nullable NSArray<OCDataConverter *> *)converters; //!< Initialize a new renderer with an array of converters

- (void)addConverters:(NSArray<OCDataConverter *> *)converters; //!< Add one or more converter(s)

- (nullable OCDataConverter *)assembledConverterFrom:(OCDataItemType)inputType to:(OCDataItemType)outputType; //!< Returns existing converters from inputType to outputType. If none is found, attempts to assemble a new pipeline from existing converters. Returns nil if none was found or could be assembled.

- (nullable id)renderObject:(id)object ofType:(OCDataItemType)inputType asType:(OCDataItemType)outputType error:(NSError * _Nullable * _Nullable)outError withOptions:(nullable OCDataViewOptions)options; //!< Render an input object (of inputType) as an object of type outputType using the renderer's converters

- (nullable id)renderItem:(id<OCDataItem>)item asType:(OCDataItemType)outputType error:(NSError * _Nullable * _Nullable)outError withOptions:(nullable OCDataViewOptions)options; //!< Render an item (of item.dataItemType) as an object of type outputType using the renderer's converters. Calls -renderObject: internally.

@end

NS_ASSUME_NONNULL_END
