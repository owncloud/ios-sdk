//
//  OCViewProvider.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 17.01.22.
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

#import "OCPlatform.h"
#import "OCViewProviderContext.h"

NS_ASSUME_NONNULL_BEGIN

@protocol OCViewProvider <NSObject>

@required
- (void)provideViewForSize:(CGSize)size inContext:(nullable OCViewProviderContext *)context completion:(void(^)(OCView * _Nullable view))completionHandler; //!< Returns a view suitable to display the object. Sizes are only passed to allow optimization. Pass CGSizeZero if the size at which the object will be displayed is unknown.

@end

NS_ASSUME_NONNULL_END
