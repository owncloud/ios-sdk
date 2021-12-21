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

@class OCCore;

NS_ASSUME_NONNULL_BEGIN

typedef void(^OCResourceSourceResultHandler)(NSError * _Nullable error, OCResource * _Nullable resource);
typedef BOOL(^OCResourceSourceShouldProvideCheck)(void);

@interface OCResourceSource : NSObject

@property(strong,readonly) OCResourceSourceIdentifier identifier;
@property(strong,readonly) OCResourceType type;

@property(weak,nullable) OCCore *core;

#pragma mark - Routing
- (BOOL)canHandleRequest:(OCResourceRequest *)request; //!< Returns if the source can handle the request

#pragma mark - Main API
- (void)provideResourceForRequest:(OCResourceRequest *)request resultHandler:(OCResourceSourceResultHandler)resultHandler; //!< Returns the resource for a request

#pragma mark - Request grouping
- (OCResourceRequestGroupIdentifier)groupIdentifierForRequest:(OCResourceRequest *)request; //!< The group identifier returned here is used to group requests to reduce overhead and memory consumption when several identical requests are provided
- (void)startProvidingResourceForRequest:(OCResourceRequest *)request shouldProvideCheck:(OCResourceSourceShouldProvideCheck)shouldProvideCheck resultHandler:(OCResourceSourceResultHandler)resultHandler; // Subclass this

@end

NS_ASSUME_NONNULL_END
