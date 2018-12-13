//
//  OCLogTag.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 12.12.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NSString* OCLogTagName;

@protocol OCLogTagging <NSObject>
+ (NSArray<OCLogTagName> *)logTags;
- (NSArray<OCLogTagName> *)logTags;
@end

#define OCLogTagTypedID(idType,identfr) ((identfr!=nil)?[NSString stringWithFormat:@"%@:%@",idType,identfr]:nil)
#define OCLogTagInstance(obj) [NSString stringWithFormat:@"Instance:%p",obj]

NS_ASSUME_NONNULL_END
