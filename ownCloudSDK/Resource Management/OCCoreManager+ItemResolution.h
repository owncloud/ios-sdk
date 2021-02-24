//
//  OCCoreManager+ItemResolution.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 24.02.21.
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

#import "OCCoreManager.h"
#import "OCBookmarkManager+ItemResolution.h"
#import "OCTypes.h"
#import "OCBookmark.h"
#import "OCItem.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCCoreManager (ItemResolution)

- (void)requestCoreForBookmarkWithItemWithLocalID:(OCLocalID)localID setup:(nullable void(^)(OCCore * _Nullable core, NSError * _Nullable error))setupHandler completionHandler:(void(^)(NSError * _Nullable error, OCCore * _Nullable core, OCItem * _Nullable item))completionHandler;

@end

NS_ASSUME_NONNULL_END
