//
//  OCHTTPCookieStorage.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 14.08.19.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2019, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import <Foundation/Foundation.h>
#import "OCHTTPResponse.h"
#import "OCHTTPRequest.h"
#import "NSHTTPCookie+OCCookies.h"
#import "OCKeyValueStore.h"
#import "OCLogger.h"

NS_ASSUME_NONNULL_BEGIN

@class OCHTTPPipeline;

typedef BOOL(^OCHTTPCookieStorageCookieFilter)(NSHTTPCookie *cookie); //!< Cookie storage filter block: cookies for which YES is returned are used, a NO return value discards it.

@interface OCHTTPCookieStorage : NSObject <OCLogTagging>

@property(nullable,copy) OCHTTPCookieStorageCookieFilter cookieFilter;

//@property(nullable,readonly,strong) OCKeyValueStore *keyValueStore;
//@property(nullable,readonly,strong) OCKeyValueStoreKey storageKey;
//
//#pragma mark - Init
//- (instancetype)initWithKeyValueStore:(nullable OCKeyValueStore *)keyValueStore key:(nullable OCKeyValueStoreKey)storageKey;

#pragma mark - HTTP
- (void)addCookiesForPipeline:(nullable OCHTTPPipeline *)pipeline partitionID:(nullable OCHTTPPipelinePartitionID)partitionID toRequest:(OCHTTPRequest *)request;
- (void)extractCookiesForPipeline:(nullable OCHTTPPipeline *)pipeline partitionID:(nullable OCHTTPPipelinePartitionID)partitionID fromResponse:(OCHTTPResponse *)response;

#pragma mark - Storage
- (void)storeCookies:(NSArray<NSHTTPCookie *> *)cookies forPipeline:(nullable OCHTTPPipeline *)pipeline partitionID:(nullable OCHTTPPipelinePartitionID)partitionID;
- (nullable NSArray<NSHTTPCookie *> *)retrieveCookiesForPipeline:(OCHTTPPipeline *)pipeline partitionID:(OCHTTPPipelinePartitionID)partitionID url:(NSURL *)url;

@end

NS_ASSUME_NONNULL_END
