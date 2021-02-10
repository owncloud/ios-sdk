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
	XCTestExpectation *offlineOperationExpectation = [self expectationWithDescription:@"expect offline operation to run"];
	__block NSValue *core1Address = NULL, *core2Address = NULL;
	__block __weak OCCore *core1 = nil;
	__block __weak OCCore *core2 = nil;

	@autoreleasepool {
		OCBookmark *bookmark = [OCTestTarget userBookmark];

		XCTAssert(OCCoreManager.sharedCoreManager!=nil);

		[[OCCoreManager sharedCoreManager] requestCoreForBookmark:bookmark setup:nil completionHandler:^(OCCore * _Nullable core, NSError * _Nullable error) {
			core1 = core;
			core1Address = [NSValue valueWithNonretainedObject:core];

			XCTAssert(core!=nil);
			XCTAssert(error==nil);

			[core1Expectation fulfill];

			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
				[[OCCoreManager sharedCoreManager] returnCoreForBookmark:bookmark completionHandler:^{
					[core1ReturnExpectation fulfill];
				}];
			});
		}];

		[[OCCoreManager sharedCoreManager] requestCoreForBookmark:bookmark setup:nil completionHandler:^(OCCore * _Nullable core, NSError * _Nullable error) {
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
				completionHandler();
				[offlineOperationExpectation fulfill];
			});
		} forBookmark:bookmark];

		[self waitForExpectationsWithTimeout:20 handler:nil];
	}

	[[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];

	XCTAssert(core1==nil);
	XCTAssert(core2==nil);
	XCTAssert([core1Address isEqual:core2Address]);
}

- (void)testConcurrentReturnAndRequest
{
	XCTestExpectation *offlineOperationExpectation = [self expectationWithDescription:@"expect offline operation to run"];
	OCBookmark *bookmark = [OCTestTarget userBookmark];
	__block OCCoreRunIdentifier core1RunID = nil, core2RunID = nil;

	@autoreleasepool {
		[[OCCoreManager sharedCoreManager] requestCoreForBookmark:bookmark setup:nil completionHandler:^(OCCore * _Nullable core, NSError * _Nullable error) {
			OCLog(@"Started core1=%@", core);
			core1RunID = core.runIdentifier;

			// Calling -returnCoreForBookmark/-requestCoreForBookmark: directly in the completionHandler of -requestCoreForBookmark: would dead-lock
			dispatch_async(dispatch_get_main_queue(), ^{
				@autoreleasepool {
					[[OCCoreManager sharedCoreManager] returnCoreForBookmark:bookmark completionHandler:^{
						OCLog(@"Returned core1");
					}];

					[[OCCoreManager sharedCoreManager] requestCoreForBookmark:bookmark setup:nil completionHandler:^(OCCore * _Nullable core, NSError * _Nullable error) {

						OCLog(@"Started core2=%@", core);
						core2RunID = core.runIdentifier;

						[[OCCoreManager sharedCoreManager] returnCoreForBookmark:bookmark completionHandler:^{
							OCLog(@"Returned core2");
						}];

						[[OCCoreManager sharedCoreManager] scheduleOfflineOperation:^(OCBookmark * _Nonnull bookmark, dispatch_block_t  _Nonnull completionHandler) {
							dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
								completionHandler();
								[offlineOperationExpectation fulfill];
							});
						} forBookmark:bookmark];
					}];
				};
			});
		}];
	}

	[self waitForExpectationsWithTimeout:30 handler:nil];

	OCLog(@"core1RunID=%@, core2RunID=%@", core1RunID, core2RunID);

	XCTAssert(![core1RunID isEqual:core2RunID]);
}

@end
