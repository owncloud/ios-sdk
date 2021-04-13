//
//  OCBookmark+IPNotificationNames.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 08.05.19.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
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

#import "OCBookmark.h"
#import "OCIPNotificationCenter.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCBookmark (IPNotificationNames)

@property(readonly,nonatomic) OCIPCNotificationName coreUpdateNotificationName;

@property(readonly,nonatomic) OCIPCNotificationName bookmarkAuthUpdateNotificationName; //!< Bookmark-specific notification name
@property(readonly,nonatomic,class) OCIPCNotificationName bookmarkAuthUpdateNotificationName; //!< Global, catch-all notification name

@end

NS_ASSUME_NONNULL_END
