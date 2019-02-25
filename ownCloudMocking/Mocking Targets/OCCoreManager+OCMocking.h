//
//  OCCoreManager+OCMocking.h
//  ownCloudMocking
//
//  Created by Javier Gonzalez on 09/11/2018.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2018, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import <ownCloudSDK/ownCloudSDK.h>
#import "OCMockManager.h"

@interface OCCoreManager (OCMocking)

- (void)ocm_requestCoreForBookmark:(OCBookmark *)bookmark setup:(void(^)(OCCore *core, NSError *))setupHandler completionHandler:(void (^)(OCCore *core, NSError *error))completionHandler;

@end

typedef void(^OCMockOCCoreManagerRequestCoreForBookmarkBlock)(OCBookmark *bookmark, void(^setupHandler)(OCCore *core, NSError *), void(^completionHandler)(OCCore *core, NSError *error));
extern OCMockLocation OCMockLocationOCCoreManagerRequestCoreForBookmark;
