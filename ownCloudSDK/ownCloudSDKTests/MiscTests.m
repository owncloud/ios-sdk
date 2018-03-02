//
//  MiscTests.m
//  ownCloudSDKTests
//
//  Created by Felix Schwarz on 02.03.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <ownCloudSDK/ownCloudSDK.h>

@interface MiscTests : XCTestCase

@end

@implementation MiscTests

#pragma mark - NSURL+OCURLNormalization
- (void)testURLNormalization
{
	// Test variations, leading and trailing space, missing or lower/uppercase scheme
	NSDictionary <NSString *, NSString *> *expectedResultByInput = @{
		// Input					  // Expected
		@"https://demo.owncloud.org/index.php"  	: @"https://demo.owncloud.org/",
		@"https://demo.owncloud.org/index.php/apps/"  	: @"https://demo.owncloud.org/",
		@"https://demo.owncloud.org" 			: @"https://demo.owncloud.org/",
		@"HTTP://demo.owncloud.org" 			: @"http://demo.owncloud.org/",
		@"HTTPS://demo.owncloud.org" 			: @"https://demo.owncloud.org/",
		@"Https://demo.owncloud.org" 			: @"https://demo.owncloud.org/",
		@" 	http://demo.owncloud.org" 		: @"http://demo.owncloud.org/",
		@" 	demo.owncloud.org" 			: @"https://demo.owncloud.org/",
		@"	 demo.owncloud.org" 			: @"https://demo.owncloud.org/",
		@"http://demo.owncloud.org	 " 		: @"http://demo.owncloud.org/",
		@"demo.owncloud.org	" 			: @"https://demo.owncloud.org/",
		@"demo.owncloud.org	 " 			: @"https://demo.owncloud.org/",
		@"	demo.owncloud.org	 " 		: @"https://demo.owncloud.org/",
	};
	
	for (NSString *inputString in expectedResultByInput)
	{
		NSString *expectedURLString = expectedResultByInput[inputString];
		NSURL *computedURL = [NSURL URLWithUsername:NULL password:NULL afterNormalizingURLString:inputString];

		NSAssert([[computedURL absoluteString] isEqual:expectedURLString], @"Computed URL matches expectation: %@=%@", [computedURL absoluteString], expectedURLString);
	}
	
	// Test user + pass extraction
	{
		NSString *user=nil, *pass=nil;
		NSURL *normalizedURL;
		
		// Test username + password
		normalizedURL = [NSURL URLWithUsername:&user password:&pass afterNormalizingURLString:@"https://usr:pwd@demo.owncloud.org/"];
		
		NSAssert([[normalizedURL absoluteString] isEqual:@"https://demo.owncloud.org/"], @"Result URL has no username or password in it: %@", normalizedURL);

		NSAssert([user isEqual:@"usr"], @"Username has been extracted successfully: %@", user);
		NSAssert([pass isEqual:@"pwd"], @"Password has been extracted successfully: %@", pass);

		// Test username only
		normalizedURL = [NSURL URLWithUsername:&user password:&pass afterNormalizingURLString:@"https://usr@demo.owncloud.org/"];
		
		NSAssert([[normalizedURL absoluteString] isEqual:@"https://demo.owncloud.org/"], @"Result URL has no username or password in it: %@", normalizedURL);

		NSAssert([user isEqual:@"usr"], @"Username has been extracted successfully: %@", user);
		NSAssert((pass==nil), @"No password has been used in this URL: %@", pass);
	}
}

@end
