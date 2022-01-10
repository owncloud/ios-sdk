//
//  OCResourceRequest.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 30.09.20.
//  Copyright © 2020 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2021, ownCloud GmbH.
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

typedef void(^OCResourceRequestChangeHandler)(OCResourceRequest *request, NSError * _Nullable error, OCResource * _Nullable previousResource, OCResource * _Nullable newResource);
typedef NSString* OCResourceRequestGroupIdentifier;

@interface OCResourceRequest : NSObject

@property(weak,nullable) OCCore *core;

@property(assign) OCResourceRequestLifetime lifetime; //!< Determines how long a request is considered / served.

@property(strong) OCResourceType type;
@property(strong) OCResourceIdentifier identifier;
@property(strong,nullable) id reference; //!< Depending on resource, instance of a reference, i.e. OCItem, OCUser, ...

@property(strong,nullable) OCResourceVersion version;
@property(strong,nullable) OCResourceStructureDescription structureDescription;

@property(assign) BOOL cancelled;

@property(assign) CGSize maxPointSize; 	//!< Maximum size in points on screen
@property(assign) CGFloat scale;	//!< Number of pixels per point
@property(readonly) CGSize maxPixelSize; //!< Computed from maxPointSize and scale

@property(assign) BOOL waitForConnectivity; //!< Sources that send requests to servers should wait for connectivity

@property(strong,nullable,nonatomic) OCResource *resource;

@property(copy,nullable) OCResourceRequestChangeHandler changeHandler;

- (instancetype)initWithType:(OCResourceType)type identifier:(OCResourceIdentifier)identifier;

- (OCResourceRequestRelation)relationWithRequest:(OCResourceRequest *)otherRequest; //!< return how this request is related with otherRequest

//- (void)start;
//- (void)stop;

@end

NS_ASSUME_NONNULL_END
