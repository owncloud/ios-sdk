//
//  OCResourceSource.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 27.02.21.
//  Copyright © 2021 ownCloud GmbH. All rights reserved.
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
#import "OCResource.h"
#import "OCResourceRequest.h"
#import "OCEvent.h"
#import "OCResourceManagerJob.h"

@class OCCore;
@class OCResourceManager;

NS_ASSUME_NONNULL_BEGIN

typedef void(^OCResourceSourceResultHandler)(NSError * _Nullable error, OCResource * _Nullable resource);

typedef NS_ENUM(NSInteger, OCResourceSourcePriority)
{
	OCResourceSourcePriorityNone = 0, //!< Do not use source
	OCResourceSourcePriorityRemote = 100, //!< Source fetches resource remotely
	OCResourceSourcePriorityLocalFallback = 200, //!< Source returns a locally generated fallback resource
	OCResourceSourcePriorityLocal = 300, //!< Source returns a locally generated resource
	OCResourceSourcePriorityLocalCache = 400, //!< Source returns resource from local cache
	OCResourceSourcePriorityInstant = 500 //!< Source makes a resource available instantly (for trivial fallback resources)
};

@interface OCResourceSource : NSObject <OCEventHandler>

@property(weak,nullable) OCResourceManager *manager;

@property(strong,readonly) OCResourceSourceIdentifier identifier;
@property(strong,readonly) OCResourceType type;

@property(weak,nullable) OCCore *core;
@property(readonly,strong) OCEventHandlerIdentifier eventHandlerIdentifier;

- (instancetype)initWithCore:(OCCore *)core;

- (OCResourceSourcePriority)priorityForType:(OCResourceType)type; //!< Returns the priority with which the source should be used, allowing to establish an ordering
- (OCResourceQuality)qualityForRequest:(OCResourceRequest *)request; //!< Returns which quality the source can deliver the requested resource in

- (void)provideResourceForRequest:(OCResourceRequest *)request resultHandler:(OCResourceSourceResultHandler)resultHandler; //!< Returns the resource for a request

#pragma mark - Event handler convenience integration
@property(readonly,nonatomic) BOOL shouldRegisterEventHandler;

- (void)registerEventHandler;
- (void)unregisterEventHandler;

@end

NS_ASSUME_NONNULL_END
