//
//  OCTestTarget.h
//  ownCloudSDKTests
//
//  Created by Felix Schwarz on 27.07.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

@class OCBookmark;

NS_ASSUME_NONNULL_BEGIN

@interface OCTestTarget : NSObject

@property(strong,readonly,nonnull,class) NSURL *secureTargetURL;
@property(strong,readonly,nonnull,class) NSURL *insecureTargetURL;

@property(strong,readonly,nonnull,class) NSURL *federatedTargetURL;

@property(strong,readonly,nonnull,class) NSString *adminLogin;
@property(strong,readonly,nonnull,class) NSString *adminPassword;

@property(strong,readonly,nonnull,class) NSString *userLogin;
@property(strong,readonly,nonnull,class) NSString *userPassword;

@property(strong,readonly,nonnull,class) NSString *demoLogin;
@property(strong,readonly,nonnull,class) NSString *demoPassword;

@property(strong,readonly,nonnull,class) NSString *federatedLogin;
@property(strong,readonly,nonnull,class) NSString *federatedPassword;

+ (OCBookmark *)bookmarkWithURL:(NSURL *)url username:(NSString *)username passphrase:(NSString *)passphrase;

+ (OCBookmark *)adminBookmark;
+ (OCBookmark *)userBookmark;
+ (OCBookmark *)demoBookmark;

+ (OCBookmark *)oidcBookmark;

+ (OCBookmark *)federatedBookmark;

@end

NS_ASSUME_NONNULL_END

#define XCTWeakSelfAssert(expression, ...) \
    _XCTPrimitiveAssertTrue(weakSelf, expression, @#expression, __VA_ARGS__)

