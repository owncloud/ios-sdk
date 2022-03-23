//
//  OCDataConverter.h
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

@class OCDataRenderer;
@class OCDataConverter;

NS_ASSUME_NONNULL_BEGIN

typedef id _Nullable(^OCDataConversion)(OCDataConverter *converter, id _Nullable input, OCDataRenderer * _Nullable renderer, NSError * _Nullable * _Nullable outError, OCDataViewOptions _Nullable options);

@interface OCDataConverter : NSObject
{
	OCDataConversion _conversion;
}

@property(readonly,nonatomic) OCDataItemType inputType; //!< type this converter converts from
@property(readonly,nonatomic) OCDataItemType outputType; //!< type this converter converts to

- (instancetype)initWithInputType:(OCDataItemType)inputType outputType:(OCDataItemType)outputType conversion:(OCDataConversion)conversion; //!< Create a new converter using a conversion-block.

- (nullable id)convert:(nullable id)input renderer:(nullable OCDataRenderer *)renderer error:(NSError * _Nullable * _Nullable)outError withOptions:(nullable OCDataViewOptions)options; //!< Converts the input object (of .inputType) to an object of .outputType.

@end

NS_ASSUME_NONNULL_END
