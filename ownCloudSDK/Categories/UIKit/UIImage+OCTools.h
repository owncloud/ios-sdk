//
//  UIImage+OCTools.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 28.04.18.
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

#import <UIKit/UIKit.h>

@interface UIImage (OCTools)

+ (CGSize)sizeThatFits:(CGSize)sourceSize into:(CGSize)maximumSize;

- (UIImage *)scaledImageFittingInSize:(CGSize)maximumSize scale:(CGFloat)scale; //!< Returns a scaled version of the image that fully fits into the provided size, respects aspect ratio and doesn't scale up (if the image is smaller).

- (UIImage *)scaledImageFittingInSize:(CGSize)maximumSize; //!< Like -scaledImageFittingInSize:scale:, but using the scale of the main screen


@end
