//
//  OCImage.h
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

#import <TargetConditionals.h>

#if TARGET_OS_OSX
#import <AppKit/AppKit.h>
#else
#import <UIKit/UIKit.h>
#endif

#ifdef TARGET_OS_MAC
typedef NSImage Image;
#else
typedef UIImage Image;
#endif

@interface OCImage : NSObject <NSSecureCoding>
{
	NSURL *_url;
	NSData *_data;
	NSString *_mimeType;

    Image *_image;

	NSRecursiveLock *_processingLock;
}

@property(strong) NSURL *url; //!< URL of the image file
@property(strong,nonatomic) NSData *data; //!< Binary data of the image. If none is present, tries to synchronously load the data from the URL.
@property(strong) NSString *mimeType; //!< MIME-Type of the image

@property(strong,nonatomic) Image *image; //!< The decoded image. Attention: if not decoded already, decodes .data synchronously. For best performance, use -requestImageWithCompletionHandler:

- (Image *)decodeImage; //!< Called by .image if data hasn't yet been decoded.

- (BOOL)requestImageWithCompletionHandler:(void(^)(OCImage *ocImage, NSError *error, Image *image))completionHandler; //!< Returns YES if the image is already available and the completionHandler has already been called. Returns NO if the image is not yet available, will call completionHandler when it is.

@end
