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

@class OCCore;
@class OCResourceRequest;

NS_ASSUME_NONNULL_BEGIN

@interface OCResourceSource : NSObject

@property(strong,readonly) OCResourceSourceIdentifier identifier;
@property(strong,readonly) OCResourceType type;

@property(weak,nullable) OCCore *core;

- (OCResourceSourcePriority)priorityForRequest:(OCResourceRequest *)request; //!< Returns the priority with which the source can respond to a request
- (void)provideResourceForRequest:(OCResourceRequest *)request completionHandler:(void(^)(NSError * _Nullable error, OCResource * _Nullable resource))completionHandler; //!< Returns the resource for a request

@end

NS_ASSUME_NONNULL_END
