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

+ (NSURL *)federatedTargetURL
{
	return ([NSURL URLWithString:@"https://demo.owncloud.com/"]);
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

+ (NSString *)demoLogin
{
	return (@"demo");
}

+ (NSString *)demoPassword
{
	return (@"demo");
}

+ (NSString *)federatedLogin
{
	return (@"test");
}

+ (NSString *)federatedPassword
{
	return (@"test");
}

+ (OCBookmark *)bookmarkWithURL:(NSURL *)url username:(NSString *)username passphrase:(NSString *)passphrase
{
	OCBookmark *bookmark;

	bookmark = [OCBookmark bookmarkForURL:url];
	bookmark.authenticationData = [OCAuthenticationMethodBasicAuth authenticationDataForUsername:username passphrase:passphrase authenticationHeaderValue:NULL error:NULL];
	bookmark.authenticationMethodIdentifier = OCAuthenticationMethodIdentifierBasicAuth;

	return (bookmark);
}

+ (OCBookmark *)userBookmark
{
	return ([self bookmarkWithURL:OCTestTarget.secureTargetURL username:OCTestTarget.userLogin passphrase:OCTestTarget.userPassword]);
}

+ (OCBookmark *)adminBookmark
{
	return ([self bookmarkWithURL:OCTestTarget.secureTargetURL username:OCTestTarget.adminLogin passphrase:OCTestTarget.adminPassword]);
}

+ (OCBookmark *)demoBookmark
{
	return ([self bookmarkWithURL:OCTestTarget.secureTargetURL username:OCTestTarget.demoLogin passphrase:OCTestTarget.demoPassword]);
}

+ (OCBookmark *)oidcBookmark
{
//	OCBookmark *bookmark=[OCBookmark bookmarkForURL:[NSURL URLWithString:@"http://10.0.5.69:8080/"]];
//	bookmark.userInfo = (id) @{ OCBookmarkUserInfoKeyAllowHTTPConnection : NSDate.new };
//
//	return (bookmark);
	return (nil);
}

+ (OCBookmark *)federatedBookmark
{
	return ([self bookmarkWithURL:OCTestTarget.federatedTargetURL username:OCTestTarget.federatedLogin passphrase:OCTestTarget.federatedPassword]);
}

@end
