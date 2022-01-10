//
//  OCResourceImage.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 21.12.21.
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

#import "OCResource.h"
#import "OCImage.h"
#import "OCItemThumbnail.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCResourceImage : OCResource

@property(assign) CGSize maxPixelSize; //!< Maximum size of the resource in pixels, CGSizeZero otherwise
@property(strong,nullable,nonatomic) OCImage *image; //!< OCImage representation of image, for caching existing instances - or generated on-the-fly. NOT serialized!
@property(strong,readonly,nullable,nonatomic) OCItemThumbnail *thumbnail; //!< OCItemThumbnail representation of .image - generated on-the-fly. NOT serialized!

// - (void)drawInRect:(CGRect)rect;

@end

NS_ASSUME_NONNULL_END
