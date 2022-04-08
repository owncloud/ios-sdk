//
//  OCDataCellConfiguration.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 07.04.22.
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
#import "OCDataSource.h"
#import "OCDataItemRecord.h"
#import "OCDataRenderer.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCDataItemCellConfiguration : NSObject

@property(weak,nullable) OCDataSource *source;

@property(strong,nullable) OCDataItemReference reference;
@property(strong,nullable) OCDataItemRecord *record;

@property(strong,nullable) OCDataRenderer *renderer;
@property(strong,nullable) OCDataViewOptions viewOptions;

- (instancetype)initWithSource:(OCDataSource *)source;

@end

NS_ASSUME_NONNULL_END
