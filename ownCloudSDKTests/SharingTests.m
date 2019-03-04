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
	XCTestExpectation *expectShareCreated = [self expectationWithDescription:@"Created share"];
	XCTestExpectation *expectSharesRetrieved = [self expectationWithDescription:@"Received share list"];
	XCTestExpectation *expectDisconnect = [self expectationWithDescription:@"Disconnected"];
	XCTestExpectation *expectLists = [self expectationWithDescription:@"Disconnected"];
	OCConnection *connection = nil;

	connection = [[OCConnection alloc] initWithBookmark:OCTestTarget.adminBookmark];
	XCTAssert(connection!=nil);

	[connection connectWithCompletionHandler:^(NSError *error, OCIssue *issue) {
		XCTAssert(error==nil);
		XCTAssert(issue==nil);

		[connection retrieveItemListAtPath:@"/" depth:1 completionHandler:^(NSError *error, NSArray<OCItem *> *items) {
			[connection createShare:[OCShare shareWithPublicLinkToPath:items[1].path linkName:@"iOS SDK CI" permissions:OCSharePermissionsMaskRead password:@"test" expiration:[NSDate dateWithTimeIntervalSinceNow:24*60*60 * 2]] options:nil resultTarget:[OCEventTarget eventTargetWithEphermalEventHandlerBlock:^(OCEvent * _Nonnull event, id  _Nonnull sender) {
				OCLog(@"error=%@, newShare=%@", event.error, event.result);

				[expectShareCreated fulfill];

				[connection retrieveItemListAtPath:@"/Documents/" depth:1 completionHandler:^(NSError *error, NSArray<OCItem *> *items) {
					[expectLists fulfill];

					if (error == nil)
					{
						[connection retrieveSharesWithScope:OCConnectionShareScopeSharedByUser forItem:nil options:nil completionHandler:^(NSError *error, NSArray<OCShare *> *shares) {
							OCLogDebug(@"error=%@, shares=%@", error, shares);

							[expectSharesRetrieved fulfill];

							[connection disconnectWithCompletionHandler:^{
								[expectDisconnect fulfill];
							}];
						}];
					}
				}];
			} userInfo:nil ephermalUserInfo:nil]];
		}];
		[expectConnect fulfill];
	}];

	[self waitForExpectationsWithTimeout:60 handler:nil];
}

@end
