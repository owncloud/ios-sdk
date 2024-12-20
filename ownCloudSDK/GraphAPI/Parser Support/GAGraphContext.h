//
//  GAGraphContext.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 26.01.22.
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
#import "GAGraph.h"
#import "GAGraphObject.h"

NS_ASSUME_NONNULL_BEGIN

@interface GAGraphContext : NSObject

@property(class,nonatomic,strong,nullable,readonly) GAGraphContext *defaultContext; //!< Context that WILL return an error during encoding if a required value is missing
@property(class,nonatomic,strong,nullable,readonly) GAGraphContext *relaxedContext; //!< Context that will NOT return an error during encoding if a required value is missing

@property(assign) BOOL ignoreRequirements;
@property(assign) BOOL ignoreConversionErrors;

@end

NS_ASSUME_NONNULL_END
