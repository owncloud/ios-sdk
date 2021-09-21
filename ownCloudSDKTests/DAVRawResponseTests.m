//
//  DAVRawResponseTests.m
//  ownCloudSDKTests
//
//  Created by Felix Schwarz on 24.06.21.
//  Copyright © 2021 ownCloud GmbH. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <ownCloudSDK/ownCloudSDK.h>
#import "OCTestTarget.h"

@interface DAVRawResponseTests : XCTestCase

@end

@implementation DAVRawResponseTests

- (void)testRawResponse {
// Test commented out until a public server with infinite PROPFIND is available
//	OCBookmark *testBookmark = [OCTestTarget bookmarkWithURL:[NSURL URLWithString:@""] username:@"" passphrase:@""];
//	OCVault *vault = [[OCVault alloc] initWithBookmark:testBookmark];
//	XCTestExpectation *expectCompletion = [self expectationWithDescription:@"Expect raw response"];
//
//	[vault retrieveMetadataWithCompletionHandler:^(NSError * _Nullable error, OCDAVRawResponse * _Nullable davRawResponse) {
//		NSLog (@"Error=%@, rawResponse.url=%@", error, davRawResponse.responseDataURL);
//
//		[expectCompletion fulfill];
//	}];
//
//	[self waitForExpectationsWithTimeout:60.0 handler:nil];
}

- (void)testRawResponseConvenience {
// Test commented out until a public server with infinite PROPFIND is available
//	OCBookmark *testBookmark = [OCTestTarget bookmarkWithURL:[NSURL URLWithString:@""] username:@"" passphrase:@""];
//	XCTestExpectation *expectCompletion = [self expectationWithDescription:@""];
//	NSProgress *progress;
//
//	progress = [testBookmark prepopulateWithCompletionHandler:^(NSError * _Nonnull error) {
//		OCLog(@"Database path: %@", [[OCVault alloc] initWithBookmark:testBookmark].databaseURL.path);
//		[expectCompletion fulfill];
//	}];
//
//	[self waitForExpectationsWithTimeout:90.0 handler:nil];
}

@end
