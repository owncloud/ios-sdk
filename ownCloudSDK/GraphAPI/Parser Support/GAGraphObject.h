//
//  GAGraphObject.h
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
#import "GAGraphStruct+Encoder.h"
#import "GAGraphData+Decoder.h"

NS_ASSUME_NONNULL_BEGIN

@class GAGraphContext;

typedef NSMutableDictionary<NSString*,id>* GAGraphStruct; //!< A graph struct is a dictionary that can be encoded as JSON to send to the server

@protocol GAGraphObject <NSObject>

@required
+ (nullable instancetype)decodeGraphData:(GAGraphData)structure context:(nullable GAGraphContext *)context error:(NSError * _Nullable * _Nullable)outError;
- (nullable GAGraphStruct)encodeToGraphStructWithContext:(nullable GAGraphContext *)context error:(NSError * _Nullable * _Nullable)outError;

@optional
@property(readonly,strong,nonatomic) GAGraphType graphType;
@property(readonly,strong,nonatomic) GAGraphIdentifier graphIdentifier;

@end

NS_ASSUME_NONNULL_END
