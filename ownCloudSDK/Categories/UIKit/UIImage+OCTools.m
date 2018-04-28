//
//  UIImage+OCTools.m
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

#import "UIImage+OCTools.h"

@implementation UIImage (OCTools)

+ (CGSize)sizeThatFits:(CGSize)sourceSize into:(CGSize)maximumSize
{
	CGSize fittingSize;

	if ((sourceSize.width==0) || (sourceSize.height==0) || (maximumSize.width==0) || (maximumSize.height==0))
	{
		return (CGSizeZero);
	}

	if (sourceSize.width > sourceSize.height)
	{
		fittingSize.width  = maximumSize.width;
		fittingSize.height = (maximumSize.width * sourceSize.height) / sourceSize.width;

		if (fittingSize.height > maximumSize.height)
		{
			fittingSize.width  = (maximumSize.width * maximumSize.height) / fittingSize.height;
			fittingSize.height = maximumSize.height;
		}
	}
	else
	{
		fittingSize.width  = (maximumSize.height * sourceSize.width) / sourceSize.height;
		fittingSize.height = maximumSize.height;

		if (fittingSize.width > maximumSize.width)
		{
			fittingSize.height = (maximumSize.width * maximumSize.height) / fittingSize.width;
			fittingSize.width  = maximumSize.width;
		}
	}

	return (fittingSize);
}

- (UIImage *)scaledImageFittingInSize:(CGSize)maximumSize scale:(CGFloat)scale
{
	CGSize size = self.size;
	UIImage *scaledImage = nil;

	scale = ((scale==0) ? self.scale : scale);

	if ((size.width < maximumSize.width) && (size.height < maximumSize.height))
	{
		scaledImage = self;
	}
	else
	{
		CGSize scaledSize = [UIImage sizeThatFits:size into:maximumSize];

		if (((size.width * self.scale) == (scaledSize.width * scale)) && ((size.height * self.scale) == (scaledSize.height * scale)))
		{
			scaledImage = self;
		}
		else if ((scaledSize.width!=0) && (scaledSize.height!=0))
		{
			UIGraphicsBeginImageContextWithOptions(scaledSize, NO, ((scale==0) ? self.scale : scale));

			[self drawInRect:CGRectMake(0, 0, scaledSize.width, scaledSize.height)];

			scaledImage = UIGraphicsGetImageFromCurrentImageContext();

			UIGraphicsEndImageContext();
		}
	}

	return (scaledImage);
}

- (UIImage *)scaledImageFittingInSize:(CGSize)maximumSize
{
	return [self scaledImageFittingInSize:maximumSize scale:UIScreen.mainScreen.scale];
}

@end
