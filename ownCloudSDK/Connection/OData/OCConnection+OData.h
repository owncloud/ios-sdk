//
//  OCConnection+OData.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 10.02.22.
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

#import "OCConnection.h"
#import "OCODataTypes.h"

NS_ASSUME_NONNULL_BEGIN

typedef void(^OCConnectionODataRequestCompletionHandler)(NSError * _Nullable error, id _Nullable response);

@interface OCConnection (OData)

- (void)decodeODataResponse:(OCHTTPResponse *)response error:(nullable NSError *)error entityClass:(nullable Class)entityClass options:(nullable OCODataOptions)options completionHandler:(OCConnectionODataRequestCompletionHandler)completionHandler;

- (NSProgress *)requestODataAtURL:(NSURL *)url requireSignals:(nullable NSSet<OCConnectionSignalID> *)requiredSignals selectEntityID:(nullable OCODataEntityID)selectEntityID selectProperties:(nullable NSArray<OCODataProperty> *)selectProperties filterString:(nullable OCODataFilterString)filterString parameters:(nullable NSDictionary<NSString *,NSString *> *)parameters entityClass:(Class)entityClass options:(nullable OCODataOptions)options completionHandler:(OCConnectionODataRequestCompletionHandler)completionHandler;

- (nullable NSProgress *)createODataObject:(id<GAGraphObject>)object atURL:(NSURL *)url requireSignals:(nullable NSSet<OCConnectionSignalID> *)requiredSignals parameters:(nullable NSDictionary<NSString *,NSString *> *)additionalParameters responseEntityClass:(nullable Class)responseEntityClass completionHandler:(OCConnectionODataRequestCompletionHandler)completionHandler;

- (nullable NSProgress *)updateODataObject:(id<GAGraphObject>)object atURL:(NSURL *)url requireSignals:(nullable NSSet<OCConnectionSignalID> *)requiredSignals parameters:(nullable NSDictionary<NSString *,NSString *> *)additionalParameters responseEntityClass:(nullable Class)responseEntityClass completionHandler:(OCConnectionODataRequestCompletionHandler)completionHandler;

//- (NSProgress *)removeOData;

@end

extern OCODataOptionKey OCODataOptionKeyReturnODataResponse; //!< Return the complete OCODataResponse object as response object
extern OCODataOptionKey OCODataOptionKeyValueKey; //!< Require that the entity(s) are stored under the provided key in the response. Returns nil if the key does not exist.

NS_ASSUME_NONNULL_END
