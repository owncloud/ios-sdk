//
//  OCItem+OCFileURLMetadata.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 03.10.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import "OCItem.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCItem (OCFileURLMetadata)

- (NSError * __nullable)updateMetadataFromFileURL:(NSURL *)fileURL;

@end

NS_ASSUME_NONNULL_END
