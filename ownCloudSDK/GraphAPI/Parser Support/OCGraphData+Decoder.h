//
//  OCGraphData+Decoder.h
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

// Class property and JSON property names are identical
#define OCG_SET(prpName, clName, collectionCl) instance.prpName = [structure objectForKey:@#prpName ofClass:clName.class inCollection:collectionCl required:NO context:context error:outError]
#define OCG_SET_REQ(prpName, clName, collectionCl) instance.prpName = [structure objectForKey:@#prpName ofClass:clName.class inCollection:collectionCl required:YES context:context error:outError]

// Class property and JSON property names differ
#define OCG_MAP(prpName, jsonName, clName, collectionCl) instance.prpName = [structure objectForKey:@jsonName ofClass:clName.class inCollection:collectionCl required:NO context:context error:outError]
#define OCG_MAP_REQ(prpName, jsonName, clName, collectionCl) instance.prpName = [structure objectForKey:@jsonName ofClass:clName.class inCollection:collectionCl required:YES context:context error:outError]

NS_ASSUME_NONNULL_BEGIN

@class OCGraphContext;

@interface NSDictionary (OCGraphDataDecoder)

- (nullable id)objectForKey:(NSString *)key ofClass:(Class)class inCollection:(nullable Class)collectionClass required:(BOOL)required context:(nullable OCGraphContext *)context error:(NSError * _Nullable * _Nullable)outError;

+ (nullable id)object:(id)inObject key:(NSString *)key ofClass:(Class)class inCollection:(nullable Class)collectionClass required:(BOOL)required context:(nullable OCGraphContext *)context error:(NSError * _Nullable * _Nullable)outError;

@end

NS_ASSUME_NONNULL_END
