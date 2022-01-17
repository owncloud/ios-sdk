//
//  OCResourceRequestItemThumbnail.h
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

#import "OCResourceRequestImage.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCResourceRequestItemThumbnail : OCResourceRequestImage

@property(strong,readonly,nonatomic) OCItem *item;

+ (instancetype)requestThumbnailFor:(OCItem *)item maximumSize:(CGSize)requestedMaximumSizeInPoints scale:(CGFloat)scale waitForConnectivity:(BOOL)waitForConnectivity changeHandler:(nullable OCResourceRequestChangeHandler)changeHandler;

@end

NS_ASSUME_NONNULL_END
