//
//  SharingTests.m
//  ownCloudSDKTests
//
//  Created by Felix Schwarz on 01.03.19.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <ownCloudSDK/ownCloudSDK.h>

#import "OCTestTarget.h"

@interface SharingTests : XCTestCase

@end

@implementation SharingTests

- (void)testSharesRetrieval
{
	XCTestExpectation *expectConnect = [self expectationWithDescription:@"Connected"];
	XCTestExpectation *expectSharesRetrieved = [self expectationWithDescription:@"Received file list"];
	XCTestExpectation *expectDisconnect = [self expectationWithDescription:@"Disconnected"];
	OCConnection *connection = nil;

	connection = [[OCConnection alloc] initWithBookmark:OCTestTarget.adminBookmark];
	XCTAssert(connection!=nil);

	[connection connectWithCompletionHandler:^(NSError *error, OCIssue *issue) {
		XCTAssert(error==nil);
		XCTAssert(issue==nil);

		if (error == nil)
		{
			[connection retrieveSharesWithScope:OCConnectionShareScopeSharedWithUser forItem:nil options:nil completionHandler:^(NSError *error, NSArray<OCShare *> *shares) {
				OCLogDebug(@"error=%@, shares=%@", error, shares);

				[expectSharesRetrieved fulfill];

				[connection disconnectWithCompletionHandler:^{
					[expectDisconnect fulfill];
				}];
			}];
		}

		[expectConnect fulfill];
	}];

	[self waitForExpectationsWithTimeout:60 handler:nil];
}

@end
