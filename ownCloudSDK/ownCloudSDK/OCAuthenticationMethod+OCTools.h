//
//  OCAuthenticationMethod+OCTools.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 26.02.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import <ownCloudSDK/ownCloudSDK.h>

@interface OCAuthenticationMethod (OCTools)

+ (NSString *)basicAuthorizationValueForUsername:(NSString *)username passphrase:(NSString *)passPhrase;

@end
