//
//  OCTestTarget.h
//  ownCloudSDKTests
//
//  Created by Felix Schwarz on 27.07.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface OCTestTarget : NSObject

@property(strong,readonly,nonnull,class) NSURL *secureTargetURL;
@property(strong,readonly,nonnull,class) NSURL *insecureTargetURL;

@property(strong,readonly,nonnull,class) NSString *adminLogin;
@property(strong,readonly,nonnull,class) NSString *adminPassword;

@property(strong,readonly,nonnull,class) NSString *userLogin;
@property(strong,readonly,nonnull,class) NSString *userPassword;

@end
