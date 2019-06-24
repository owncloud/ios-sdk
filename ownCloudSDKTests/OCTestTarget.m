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
	return ([NSURL URLWithString:@"http://localhost/"]);
}

+ (NSURL *)insecureTargetURL
{
	return ([NSURL URLWithString:@"http://localhost/"]);
}

+ (NSURL *)federatedTargetURL
{
	return ([NSURL URLWithString:@"http://localhost/"]);
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

+ (OCBookmark *)demoBookmark
{
	OCBookmark *bookmark;

	bookmark = [OCBookmark bookmarkForURL:OCTestTarget.secureTargetURL];
	bookmark.authenticationData = [OCAuthenticationMethodBasicAuth authenticationDataForUsername:OCTestTarget.demoLogin passphrase:OCTestTarget.demoPassword authenticationHeaderValue:NULL error:NULL];
	bookmark.authenticationMethodIdentifier = OCAuthenticationMethodIdentifierBasicAuth;

	return (bookmark);
}

+ (OCBookmark *)federatedBookmark
{
	OCBookmark *bookmark;

	bookmark = [OCBookmark bookmarkForURL:OCTestTarget.federatedTargetURL];
	bookmark.authenticationData = [OCAuthenticationMethodBasicAuth authenticationDataForUsername:OCTestTarget.federatedLogin passphrase:OCTestTarget.federatedPassword authenticationHeaderValue:NULL error:NULL];
	bookmark.authenticationMethodIdentifier = OCAuthenticationMethodIdentifierBasicAuth;

	return (bookmark);
}

@end
