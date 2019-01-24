//
//  OCTestTarget.m
//  ownCloudSDKTests
//
//  Created by Felix Schwarz on 27.07.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import "OCTestTarget.h"
#import <ownCloudSDK/ownCloudSDK.h>

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

+ (OCBookmark *)userBookmark
{
	OCBookmark *bookmark;

	bookmark = [OCBookmark bookmarkForURL:OCTestTarget.secureTargetURL];
	bookmark.authenticationData = [OCAuthenticationMethodBasicAuth authenticationDataForUsername:OCTestTarget.userLogin passphrase:OCTestTarget.userPassword authenticationHeaderValue:NULL error:NULL];
	bookmark.authenticationMethodIdentifier = OCAuthenticationMethodIdentifierBasicAuth;

	return (bookmark);
}

+ (OCBookmark *)adminBookmark
{
	OCBookmark *bookmark;

	bookmark = [OCBookmark bookmarkForURL:OCTestTarget.secureTargetURL];
	bookmark.authenticationData = [OCAuthenticationMethodBasicAuth authenticationDataForUsername:OCTestTarget.adminLogin passphrase:OCTestTarget.adminPassword authenticationHeaderValue:NULL error:NULL];
	bookmark.authenticationMethodIdentifier = OCAuthenticationMethodIdentifierBasicAuth;

	return (bookmark);
}

@end
