//
//  OCTestTarget.m
//  ownCloudSDKTests
//
//  Created by Felix Schwarz on 27.07.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import "OCTestTarget.h"

@implementation OCTestTarget

+ (NSURL *)secureTargetURL
{
	return ([NSURL URLWithString:@"https://demo.owncloud.org/"]);
}

+ (NSURL *)insecureTargetURL
{
	return ([NSURL URLWithString:@"http://demo.owncloud.org/"]);
}

+ (NSString *)adminLogin
{
	return (@"admin");
}

+ (NSString *)adminPassword
{
	return (@"admin");
}

+ (NSString *)userLogin
{
	return (@"test");
}

+ (NSString *)userPassword
{
	return (@"test");
}

@end
