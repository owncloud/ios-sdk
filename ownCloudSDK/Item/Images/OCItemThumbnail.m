//
//  OCItemThumbnail.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 25.04.18.
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

#import "OCItemThumbnail.h"
#import "UIImage+OCTools.h"

@implementation OCItemThumbnail

@synthesize itemVersionIdentifier = _itemVersionIdentifier;

@synthesize specID = _specID;

#pragma mark - Init & Dealloc
- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_imageByRequestedMaximumSize = [NSMutableDictionary dictionary];
	}

	return(self);
}

- (BOOL)requestImageForSize:(CGSize)requestedMaximumSizeInPoints scale:(CGFloat)scale withCompletionHandler:(void(^)(OCItemThumbnail *thumbnail, NSError *error, CGSize maximumSizeInPoints, UIImage *image))completionHandler
{
	CGSize requestedMaximumSizeInPixels;
	NSValue *requestedMaximumSizeInPixelsValue;
	UIImage *existingImage = nil;

	if (scale==0)
	{
		scale = UIScreen.mainScreen.scale;
	}

	requestedMaximumSizeInPixels = CGSizeMake(requestedMaximumSizeInPoints.width * scale, requestedMaximumSizeInPoints.height * scale);
	requestedMaximumSizeInPixelsValue = [NSValue valueWithCGSize:requestedMaximumSizeInPixels];

	@synchronized(self)
	{
		existingImage = [_imageByRequestedMaximumSize objectForKey:requestedMaximumSizeInPixelsValue];
	}

	if (existingImage == nil)
	{
		// No existing image, compute async
		dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
			UIImage *returnImage = nil;

			[self->_processingLock lock]; // Lock to make any subsequent (possibly identical) computations wait until this one is done, in order not to do the same computations twice

			{
				UIImage *sourceImage = nil;

				// Check if, by now, what is being requested is already there
				@synchronized(self)
				{
					returnImage = [self->_imageByRequestedMaximumSize objectForKey:requestedMaximumSizeInPixelsValue];

					if (returnImage == nil)
					{
						// Check if an existing image can be used. If so, go for the smallest, existing image that's still bigger than what was requested, so computation is fastest.
						CGFloat sourceImagePixelCount = 0;

						for (NSValue *otherMaximumSizeValue in self->_imageByRequestedMaximumSize)
						{
							CGSize otherMaximumSize = otherMaximumSizeValue.CGSizeValue;

							if ((otherMaximumSize.width < requestedMaximumSizeInPixels.width) || (otherMaximumSize.height < requestedMaximumSizeInPixels.height))
							{
								CGFloat pixelCount = otherMaximumSize.width * otherMaximumSize.height;

								if ((pixelCount < sourceImagePixelCount) || (sourceImagePixelCount == 0))
								{
									sourceImage = self->_imageByRequestedMaximumSize[otherMaximumSizeValue];
									sourceImagePixelCount = pixelCount;
								}
							}
						}
					}
				}

				if (returnImage == nil)
				{
					// Compute a new image
					if (sourceImage == nil)
					{
						sourceImage = [self decodeImage]; // Don't cache the decoded image to save memory
					}

					if (sourceImage != nil)
					{
						if ((returnImage = [sourceImage scaledImageFittingInSize:requestedMaximumSizeInPoints scale:scale]) != nil)
						{
							@synchronized(self)
							{
								[self->_imageByRequestedMaximumSize removeAllObjects];
								[self->_imageByRequestedMaximumSize setObject:returnImage forKey:requestedMaximumSizeInPixelsValue];
							}
						}
					}
				}
			}

			[self->_processingLock unlock]; // Done! Unlock!

			if (completionHandler != nil)
			{
				completionHandler(self, nil, requestedMaximumSizeInPoints, returnImage);
			}
		});

		return (NO);
	}

	// Image exists already
	if (completionHandler != nil)
	{
		completionHandler(self, nil, requestedMaximumSizeInPoints, existingImage);
	}

	return (YES);
}

- (BOOL)canProvideForMaximumSizeInPixels:(CGSize)maximumSizeInPixels
{
	return ((maximumSizeInPixels.width <= _maximumSizeInPixels.width) && (maximumSizeInPixels.height <= _maximumSizeInPixels.height));
}

@end
