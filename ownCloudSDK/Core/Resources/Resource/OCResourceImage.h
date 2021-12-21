//
//  OCResourceImage.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 21.12.21.
//  Copyright © 2021 ownCloud GmbH. All rights reserved.
//

#import "OCResource.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCResourceImage : OCResource

@property(assign) CGSize maxPixelSize; //!< Maximum size of the resource in pixels, CGSizeZero otherwise

- (void)drawInRect:(CGRect)rect;

@end

NS_ASSUME_NONNULL_END
