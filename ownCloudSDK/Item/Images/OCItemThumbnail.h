//
//  OCItemThumbnail.h
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
#import "OCTypes.h"
#import "OCItemVersionIdentifier.h"

@interface OCItemThumbnail : OCImage
{
	CGSize _maximumSizeInPixels;

	NSMutableDictionary <NSValue *, UIImage *> *_imageByRequestedMaximumSize;

	OCItemVersionIdentifier *_versionIdentifier;
}

@property(assign) CGSize maximumSizeInPixels;

@property(strong) OCItemVersionIdentifier *versionIdentifier;

- (BOOL)requestImageForSize:(CGSize)maximumSizeInPoints scale:(CGFloat)scale withCompletionHandler:(void(^)(OCItemThumbnail *thumbnail, NSError *error, CGSize maximumSizeInPoints, UIImage *image))completionHandler; //!< Returns YES if the image is already available and the completionHandler has already been called. Returns NO if the image is not yet available, will call completionHandler when it is.

- (BOOL)canProvideForMaximumSizeInPixels:(CGSize)maximumSizeInPixels;

@end
