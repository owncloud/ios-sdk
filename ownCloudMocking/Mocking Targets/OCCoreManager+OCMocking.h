//
//  OCCoreManager+OCMocking.h
//  ownCloudMocking
//
//  Created by Javier Gonzalez on 09/11/2018.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import <ownCloudSDK/ownCloudSDK.h>
#import "OCMockManager.h"

@interface OCCoreManager (OCMocking)

- (OCCore *)ocm_requestCoreForBookmark:(OCBookmark *)bookmark completionHandler:(void (^)(OCCore *core, NSError *error))completionHandler;

@end

typedef OCCore *(^OCMockOCCoreManagerRequestCoreForBookmarkBlock)(OCBookmark *bookmark, void(^completionHandler)(OCCore *core, NSError *error));
extern OCMockLocation OCMockLocationOCCoreManagerRequestCoreForBookmark;
