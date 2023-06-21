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

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, OCImageFillMode)
{
	OCImageFillModeUnknown,
	OCImageFillModeScaleToFit,
	OCImageFillModeScaleToFill
};

@interface OCImage : NSObject <NSSecureCoding>
{
	NSURL *_url;
	NSData *_data;
	NSString *_mimeType;

	UIImage *_image;

	NSRecursiveLock *_processingLock;
}

@property(strong,nullable) NSURL *url; //!< URL of the image file
@property(strong,nullable,nonatomic) NSData *data; //!< Binary data of the image. If none is present, tries to synchronously load the data from the URL.
@property(strong) NSString *mimeType; //!< MIME-Type of the image

@property(assign) OCImageFillMode fillMode; //!< Fill mode of the image, defaults to unkonwn

#pragma mark - Basic decoding
@property(strong,nullable,nonatomic) UIImage *image; //!< The decoded image. Attention: if not decoded already, decodes .data synchronously. For best performance, use -requestImageWithCompletionHandler:

- (nullable UIImage *)decodeImage; //!< Called by .image if data hasn't yet been decoded.

- (BOOL)requestImageWithCompletionHandler:(void(^)(OCImage *ocImage, NSError * _Nullable error, UIImage * _Nullable image))completionHandler; //!< Returns YES if the image is already available and the completionHandler has already been called. Returns NO if the image is not yet available, will call completionHandler when it is.

#pragma mark - Scaled version
@property(assign) CGSize maxPixelSize;

- (BOOL)requestImageForSize:(CGSize)maximumSizeInPoints scale:(CGFloat)scale withCompletionHandler:(void(^)(OCImage * _Nullable ocImage, NSError * _Nullable error, CGSize maximumSizeInPoints, UIImage * _Nullable image))completionHandler; //!< Returns YES if the image is already available and the completionHandler has already been called. Returns NO if the image is not yet available, will call completionHandler when it is.

- (BOOL)canProvideForMaximumSizeInPixels:(CGSize)maximumSizeInPixels;

@end

NS_ASSUME_NONNULL_END
