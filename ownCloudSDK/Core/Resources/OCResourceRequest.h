//
//  OCResourceRequest.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 30.09.20.
//  Copyright © 2020 ownCloud GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OCItem.h"
#import "OCUser.h"

NS_ASSUME_NONNULL_BEGIN

@class OCResourceRequest;

typedef void(^OCResourceRequestChangeHandler)(OCResourceRequest *request);

@interface OCResourceRequest<ResClass> : NSObject

@property(assign) CGSize maximumSizeInPoints;
@property(assign) CGFloat scale;

@property(assign) BOOL waitForConnectivity;

@property(strong,nullable) ResClass resource;

+ (instancetype)thumbnailRequestFor:(OCItem *)item maximumSize:(CGSize)requestedMaximumSizeInPoints scale:(CGFloat)scale waitForConnectivity:(BOOL)waitForConnectivity;
+ (instancetype)avatarRequestFor:(OCUser *)user maximumSize:(CGSize)requestedMaximumSizeInPoints scale:(CGFloat)scale waitForConnectivity:(BOOL)waitForConnectivity;

- (void)start;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
