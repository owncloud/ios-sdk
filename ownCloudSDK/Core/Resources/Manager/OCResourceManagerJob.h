//
//  OCResourceManagerJob.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 04.01.22.
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
#import "OCResourceRequest.h"

NS_ASSUME_NONNULL_BEGIN

@class OCResourceManager;
@class OCResourceSource;
@class OCResource;

typedef NS_ENUM(NSInteger, OCResourceManagerJobState)
{
	OCResourceManagerJobStateNew,
	OCResourceManagerJobStateInProgress,
	OCResourceManagerJobStateComplete
};

typedef NSUInteger OCResourceManagerJobSeed;

typedef void(^OCResourceManagerJobCancellationHandler)(void);

@interface OCResourceManagerJob : NSObject

@property(weak,nullable) OCResourceManager *manager;

@property(assign) OCResourceManagerJobState state;
@property(assign) OCResourceManagerJobSeed seed;

@property(strong) NSHashTable<OCResourceRequest *> *requests;
@property(strong) NSMutableArray<OCResourceRequest *> *managedRequests;
@property(weak,nullable,nonatomic) OCResourceRequest *primaryRequest;

@property(assign) OCResourceQuality minimumQuality;

@property(strong,nullable) NSMutableArray<OCResourceSource *> *sources;
@property(strong,nullable) NSNumber *sourcesCursorPosition;

@property(strong,nullable) OCResource *latestResource;
@property(weak,nullable) OCResource *lastStoredResource;

@property(assign,nonatomic) BOOL cancelled;
@property(copy,nullable) OCResourceManagerJobCancellationHandler cancellationHandler;

- (instancetype)initWithPrimaryRequest:(OCResourceRequest *)primaryRequest forManager:(OCResourceManager *)manager;

- (void)addRequest:(OCResourceRequest *)request; //!< Adds an additional request
- (void)replacePrimaryRequestWith:(OCResourceRequest *)request; //!< Replace primary request with this request and start anew
- (void)removeRequest:(OCResourceRequest *)request; //!< Removes a request

- (void)removeRequestsWithLifetime:(OCResourceRequestLifetime)lifetime; //!< For removal of (managed) requests with a lifetime other than OCResourceRequestLifetimeUntilDeallocation

@end

NS_ASSUME_NONNULL_END
