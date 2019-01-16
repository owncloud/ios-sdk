//
//  CoreManagerTests.m
//  ownCloudSDKTests
//
//  Created by Felix Schwarz on 16.01.19.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <ownCloudSDK/ownCloudSDK.h>
#import "OCTestTarget.h"

@interface CoreManagerTests : XCTestCase

@end

@implementation CoreManagerTests

- (void)testRequestReturnOfflineOperationAndInstanceRelease
{
	XCTestExpectation *core1Expectation = [self expectationWithDescription:@"expect core 1"];
	XCTestExpectation *core2Expectation = [self expectationWithDescription:@"expect core 2"];
	XCTestExpectation *core1ReturnExpectation = [self expectationWithDescription:@"expect core 1 return"];
	XCTestExpectation *core2ReturnExpectation = [self expectationWithDescription:@"expect core 2 return"];
	XCTestExpectation *offlineOperationExpectation = [self expectationWithDescription:@"expect core 2 return"];
	OCBookmark *bookmark = [OCTestTarget userBookmark];
	__block NSValue *core1Address = NULL, *core2Address = NULL;
	__block __weak OCCore *core1 = nil;
	__block __weak OCCore *core2 = nil;

	@autoreleasepool {
		XCTAssert(OCCoreManager.sharedCoreManager!=nil);

		[[OCCoreManager sharedCoreManager] requestCoreForBookmark:bookmark completionHandler:^(OCCore * _Nullable core, NSError * _Nullable error) {
			core1 = core;
			core1Address = [NSValue valueWithNonretainedObject:core];

			XCTAssert(core!=nil);
			XCTAssert(error==nil);

			[core1Expectation fulfill];

			[[OCCoreManager sharedCoreManager] returnCoreForBookmark:bookmark completionHandler:^{
				[core1ReturnExpectation fulfill];
			}];
		}];

		[[OCCoreManager sharedCoreManager] requestCoreForBookmark:bookmark completionHandler:^(OCCore * _Nullable core, NSError * _Nullable error) {
			core2 = core;
			core2Address = [NSValue valueWithNonretainedObject:core];

			XCTAssert(core!=nil);
			XCTAssert(error==nil);

			[core2Expectation fulfill];

			[[OCCoreManager sharedCoreManager] returnCoreForBookmark:bookmark completionHandler:^{
				[core2ReturnExpectation fulfill];
			}];
		}];

		[[OCCoreManager sharedCoreManager] scheduleOfflineOperation:^(OCBookmark * _Nonnull bookmark, dispatch_block_t  _Nonnull completionHandler) {
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
				[offlineOperationExpectation fulfill];
				completionHandler();
			});
		} forBookmark:bookmark];

		[self waitForExpectationsWithTimeout:10 handler:nil];
	}

	XCTAssert(core1==nil);
	XCTAssert(core2==nil);
	XCTAssert([core1Address isEqual:core2Address]);
}

@end
