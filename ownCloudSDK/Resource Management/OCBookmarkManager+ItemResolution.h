//
//  OCBookmarkManager+ItemResolution.h
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

#import "OCBookmarkManager.h"
#import "OCTypes.h"
#import "OCBookmark.h"
#import "OCItem.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCBookmarkManager (ItemResolution)

- (void)locateBookmarkForItemWithLocalID:(OCLocalID)localID completionHandler:(void(^)(NSError * _Nullable error, OCBookmark * _Nullable bookmark, OCItem * _Nullable item))completionHandler;

@end

NS_ASSUME_NONNULL_END
