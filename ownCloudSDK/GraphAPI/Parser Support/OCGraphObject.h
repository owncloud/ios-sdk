//
//  OCGraphObject.h
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
#import "OCGraph.h"
#import "OCGraphData+Decoder.h"

NS_ASSUME_NONNULL_BEGIN

@class OCGraphContext;

@protocol OCGraphObject <NSObject>

@required
+ (nullable instancetype)decodeGraphData:(OCGraphData)structure context:(nullable OCGraphContext *)context error:(NSError * _Nullable * _Nullable)outError;

@optional
@property(readonly,strong,nonatomic) OCGraphType graphType;
@property(readonly,strong,nonatomic) OCGraphIdentifier graphIdentifier;

@end

NS_ASSUME_NONNULL_END
