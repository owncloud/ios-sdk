//
//  OCResourceManager.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 21.12.21.
//  Copyright © 2021 ownCloud GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OCResourceTypes.h"
#import "OCResourceRequest.h"
#import "OCResourceSource.h"
#import "OCResource.h"
#import "OCCache.h"
#import "OCCore.h"

NS_ASSUME_NONNULL_BEGIN

typedef void(^OCResourceStoreCompletionHandler)(NSError * _Nullable error);
typedef void(^OCResourceRetrieveCompletionHandler)(NSError * _Nullable error, OCResource * _Nullable resource);

@protocol OCResourceStorage <NSObject>
- (void)retrieveResourceForRequest:(OCResourceRequest *)request completionHandler:(OCResourceRetrieveCompletionHandler)completionHandler;
- (void)storeResource:(OCResource *)resource completionHandler:(OCResourceStoreCompletionHandler)completionHandler;
@end

@interface OCResourceManager : NSObject <OCResourceStorage>

@property(weak,nullable) id<OCResourceStorage> storage;
@property(weak,nullable) OCCore *core;

@property(assign,nonatomic) OCCoreMemoryConfiguration memoryConfiguration;

// @property(assign) NSUInteger maximumConcurrentJobs; //!< Maximum number of jobs to work on in parallel. A value of 0 indicates no limit.

- (instancetype)initWithStorage:(nullable id<OCResourceStorage>)storage;

#pragma mark - Sources
- (void)addSource:(OCResourceSource *)source;
- (void)removeSource:(OCResourceSource *)source;

#pragma mark - Requests
- (void)startRequest:(OCResourceRequest *)request;
- (void)stopRequest:(OCResourceRequest *)request;

@end

NS_ASSUME_NONNULL_END
