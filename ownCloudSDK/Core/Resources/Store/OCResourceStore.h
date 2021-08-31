//
//  OCResourceStore.h
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
#import "OCDatabase.h"
#import "OCResource.h"
#import "OCResourceRequest.h"

NS_ASSUME_NONNULL_BEGIN

@class OCResourceStore;

typedef void(^OCResourceStoreCompletionHandler)(OCResourceStore *store, NSError *error);
typedef void(^OCResourceRetrieveCompletionHandler)(OCResourceStore *store, NSError *error, OCResource *resource);

@interface OCResourceStore : NSObject

@property(weak,nullable) OCDatabase *database;

- (void)retrieveResourceForRequest:(OCResourceRequest *)request completionHandler:(OCResourceRetrieveCompletionHandler)completionHandler;
- (void)storeResource:(OCResource *)resource completionHandler:(OCResourceStoreCompletionHandler)completionHandler;

@end

NS_ASSUME_NONNULL_END
