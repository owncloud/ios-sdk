//
//  OCImage.m
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

#import "OCImage.h"
#import "UIImage+OCTools.h"

@interface OCImage ()
{
	NSMutableDictionary <NSValue *, UIImage *> *_imageByRequestedMaximumSize;
}
@end

@implementation OCImage

@synthesize url = _url;

@synthesize data = _data;
@synthesize mimeType = _mimeType;

@synthesize image = _image;

#pragma mark - Init & Dealloc
- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_processingLock = [NSRecursiveLock new];
	}

	return(self);
}


- (NSData *)data
{
	NSData *returnData = nil;

	[_processingLock lock]; // Lock

	@synchronized(self)
	{
		returnData = _data;
	}

	if ((returnData == nil) && (_url != nil))
	{
		returnData = [[NSData alloc] initWithContentsOfURL:_url options:NSDataReadingUncached error:NULL];
	}

	@synchronized(self)
	{
		if ((_data == nil) && (returnData != nil))
		{
			_data = returnData;
		}
	}

	[_processingLock unlock]; // Unlock

	return (returnData);
}

- (UIImage *)image
{
	UIImage *returnImage = nil;

	[_processingLock lock]; // Lock

	if (self.data != nil)
	{
		@synchronized(self)
		{
			returnImage = _image;
		}

		if (returnImage == nil)
		{
			returnImage = [self decodeImage];

			@synchronized(self)
			{
				_image = returnImage;
			}
		}
	}
	else
	{
		@synchronized(self)
		{
			returnImage = _image;
		}
	}

	[_processingLock unlock]; // Unlock

	return (returnImage);
}

- (UIImage *)decodeImage
{
	UIImage *image = nil;

	if (self.data != nil)
	{
		image = [[UIImage alloc] initWithData:self.data];
	}

	return (image);
}

- (BOOL)requestImageWithCompletionHandler:(void(^)(OCImage *ocImage, NSError *error, UIImage *image))completionHandler
{
	BOOL imageAlreadyLoaded = NO;
	UIImage *image = nil;

	@synchronized(self)
	{
		if (_image != nil)
		{
			image = _image;

			imageAlreadyLoaded = YES;
		}
		else
		{
			dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
				UIImage *image = nil;

				image = self.image;

				if (completionHandler != nil)
				{
					completionHandler(self, nil, image);
				}
			});
		}
	}

	if (image != nil)
	{
		if (completionHandler != nil)
		{
			completionHandler(self, nil, image);
		}
	}

	return (imageAlreadyLoaded);
}

#pragma mark - Scaled version
- (BOOL)requestImageForSize:(CGSize)requestedMaximumSizeInPoints scale:(CGFloat)scale withCompletionHandler:(void (^)(OCImage * _Nullable ocImage, NSError * _Nullable error, CGSize, UIImage * _Nullable image))completionHandler
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
		if (_imageByRequestedMaximumSize == nil)
		{
			_imageByRequestedMaximumSize = [NSMutableDictionary new];
		}

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
	return ((maximumSizeInPixels.width <= _maxPixelSize.width) && (maximumSizeInPixels.height <= _maxPixelSize.height));
}


#pragma mark - Secure Coding
+ (BOOL)supportsSecureCoding
{
	return (YES);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:_url    		forKey:@"url"];
	[coder encodeObject:_data    		forKey:@"data"];
	[coder encodeObject:_mimeType  		forKey:@"mimeType"];
	[coder encodeCGSize:_maxPixelSize 	forKey:@"maxPixelSize"];
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
	if ((self = [self init]) != nil)
	{
		_url = [decoder decodeObjectOfClass:NSURL.class forKey:@"url"];
		_data = [decoder decodeObjectOfClass:NSData.class forKey:@"data"];
		_mimeType = [decoder decodeObjectOfClass:NSString.class forKey:@"mimeType"];
		_maxPixelSize = [decoder decodeCGSizeForKey:@"maxPixelSize"];
	}

	return (self);
}

@end
