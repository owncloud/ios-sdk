//
//  OCClassSettingsFlatSourcePropertyList.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 22.03.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import <ownCloudSDK/ownCloudSDK.h>

@interface OCClassSettingsFlatSourcePropertyList : OCClassSettingsFlatSource

- (instancetype)initWithURL:(NSURL *)propertyListURL;

@end
