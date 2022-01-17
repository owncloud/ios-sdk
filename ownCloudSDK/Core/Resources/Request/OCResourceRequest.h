//
//  OCResourceRequest.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 30.09.20.
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
#import "OCResourceTypes.h"
#import "OCItem.h"
#import "OCUser.h"

NS_ASSUME_NONNULL_BEGIN

@class OCResourceManagerJob;
@class OCResourceRequest;
@class OCResource;

typedef NS_ENUM(NSInteger, OCResourceRequestRelation)
{
	OCResourceRequestRelationDistinct,	//!< Distinct requests, no relation (f.ex. for different request types, different resources, etc.)
	OCResourceRequestRelationGroupWith,	//!< Request points to same resource, should/can be linked with other request
	OCResourceRequestRelationReplace	//!< Request points to a newer/better version of same resource, should/can replace the other request
};

typedef NS_ENUM(NSInteger, OCResourceRequestLifetime)
{
	OCResourceRequestLifetimeUntilDeallocation,
	OCResourceRequestLifetimeSingleRun,
	OCResourceRequestLifetimeUntilStopped
};

typedef void(^OCResourceRequestChangeHandler)(OCResourceRequest *request, NSError * _Nullable error, BOOL isOngoing, OCResource * _Nullable previousResource, OCResource * _Nullable newResource);
typedef NSString* OCResourceRequestGroupIdentifier;

@protocol OCResourceRequestDelegate <NSObject>
- (void)resourceRequest:(OCResourceRequest *)request didChangeWithError:(nullable NSError *)error isOngoing:(BOOL)isOngoing previousResource:(nullable OCResource *)previousResource newResource:(nullable OCResource *)newResource;
@end

@interface OCResourceRequest : NSObject

@property(weak,nullable) OCCore *core;

@property(weak,nullable,nonatomic) OCResourceManagerJob *job;

@property(assign) OCResourceRequestLifetime lifetime; //!< Determines how long a request is considered / served.

@property(strong) OCResourceType type;
@property(strong) OCResourceIdentifier identifier;
@property(strong,nullable) id reference; //!< Depending on resource, instance of a reference, i.e. OCItem, OCUser, ...
@property(assign) OCResourceQuality minimumQuality; //!< Require minimum quality for requested resource. Allows to f.ex. exclude placeholders from being returned. This filtering could also take place via resource.quality, but memory + CPU cycles would be wasted that way. Defaults to OCResourceQualityFallback.

@property(strong,nullable) OCResourceVersion version;
@property(strong,nullable) OCResourceStructureDescription structureDescription;

@property(assign) CGSize maxPointSize; 	//!< Maximum size in points on screen
@property(assign) CGFloat scale;	//!< Number of pixels per point
@property(readonly) CGSize maxPixelSize; //!< Computed from maxPointSize and scale

@property(assign) BOOL waitForConnectivity; //!< Sources that send requests to servers should wait for connectivity

@property(assign,nonatomic) BOOL cancelled;
@property(readonly) BOOL ended;

@property(strong,nullable,nonatomic) OCResource *resource;

@property(copy,nullable) OCResourceRequestChangeHandler changeHandler;
@property(weak,nullable) id<OCResourceRequestDelegate> delegate;

- (instancetype)initWithType:(OCResourceType)type identifier:(OCResourceIdentifier)identifier;

- (OCResourceRequestRelation)relationWithRequest:(OCResourceRequest *)otherRequest; //!< return how this request is related with otherRequest

- (BOOL)satisfiedByResource:(OCResource *)resource; //!< Return YES if the resource satisfies the request requirements. Used to determine if a cached resource is meeting the request's requirement and can be served.

- (void)endRequest;

@end

NS_ASSUME_NONNULL_END
