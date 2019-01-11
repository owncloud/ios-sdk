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
	NSData *data;

	[_processingLock lock]; // Lock

	if ((data = self.data) != nil)
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

#pragma mark - Secure Coding
+ (BOOL)supportsSecureCoding
{
	return (YES);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:_url    	forKey:@"url"];
	[coder encodeObject:_data    	forKey:@"data"];
	[coder encodeObject:_mimeType   forKey:@"mimeType"];
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
	if ((self = [self init]) != nil)
	{
		_url = [decoder decodeObjectOfClass:[NSURL class] forKey:@"url"];
		_data = [decoder decodeObjectOfClass:[NSData class] forKey:@"data"];
		_mimeType = [decoder decodeObjectOfClass:[NSString class] forKey:@"mimeType"];
	}

	return (self);
}

@end
