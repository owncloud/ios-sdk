//
//  OCODataDecoder.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 16.12.24.
//  Copyright © 2024 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2024, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import <Foundation/Foundation.h>
#import "OCODataTypes.h"
#import "OCODataResponse.h"

NS_ASSUME_NONNULL_BEGIN

@class OCHTTPResponse;

typedef _Nonnull id(^OCODataCustomDecoder)(id value, NSError * _Nullable * _Nullable outError);

@interface OCODataDecoder : NSObject

@property(strong,readonly) OCODataLibreGraphID libreGraphID; //!< Libre graph ID to decode, f.ex. "@libre.graph.permissions.roles.allowedValues"
@property(strong,readonly,nullable) Class entityClass; //!< Class to decode objects to
@property(copy,readonly,nullable) OCODataCustomDecoder customDecoder; //!< Decodes the value for libreGraphID and returns the translation as a result

+ (nullable OCODataResponse *)decodeODataResponse:(NSDictionary<NSString *, id> *)jsonDictionary entityClass:(nullable Class)entityClass options:(nullable OCODataOptions)options;

- (instancetype)initWithLibreGraphID:(OCODataLibreGraphID)libreGraphID entityClass:(nullable Class)entityClass customDecoder:(nullable OCODataCustomDecoder)customDecoder;
- (nullable id)decodeValue:(id)value error:(NSError * _Nullable * _Nullable)outError;

@end

extern OCODataOptionKey OCODataOptionKeyLibreGraphDecoders; //!< Array of OCODataDecoder to decode additional Libre Graph elements

NS_ASSUME_NONNULL_END
