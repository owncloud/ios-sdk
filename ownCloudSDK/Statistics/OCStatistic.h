//
//  OCStatistic.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 14.10.22.
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

typedef NSString* OCStatisticUUID;

@interface OCStatistic : NSObject <OCDataItem, OCDataItemVersioning>

@property(readonly,strong) OCStatisticUUID uuid; //!< UUID of the statistic, random

@property(nullable,strong) NSString *label; //!< Label describing the statistic

@property(nullable,strong) NSNumber *itemCount;	//!< Number of items

@property(nullable,strong) NSNumber *fileCount; //!< Number of files
@property(nullable,strong) NSNumber *folderCount; //!< Number of folders

@property(nullable,strong) NSNumber *sizeInBytes; //!< Size in bytes
@property(nullable,readonly,nonatomic) NSString *localizedSize; //!< Localized string built from .sizeInBytes

@end

NS_ASSUME_NONNULL_END
