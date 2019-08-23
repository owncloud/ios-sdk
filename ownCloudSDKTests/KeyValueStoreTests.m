//
//  KeyValueStoreTests.m
//  ownCloudSDKTests
//
//  Created by Felix Schwarz on 23.08.19.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <ownCloudSDK/ownCloudSDK.h>

@interface KeyValueStoreTests : XCTestCase

@end

@implementation KeyValueStoreTests

- (void)testKeyValueStoreThreadConcurrency
{
	XCTestExpectation *expect1Value1Update = [self expectationWithDescription:@"Expect value 1 update [1]"];
	XCTestExpectation *expect1Value2Update = [self expectationWithDescription:@"Expect value 2 update [1]"];
	XCTestExpectation *expect1Value3Update = [self expectationWithDescription:@"Expect value 3 update [1]"];
	XCTestExpectation *expect1Value4Update = [self expectationWithDescription:@"Expect value 4 update [1]"];

	XCTestExpectation *expect2Value1Update = [self expectationWithDescription:@"Expect value 1 update [2]"];
	XCTestExpectation *expect2Value2Update = [self expectationWithDescription:@"Expect value 2 update [2]"];
	XCTestExpectation *expect2Value3Update = [self expectationWithDescription:@"Expect value 3 update [2]"];
	XCTestExpectation *expect2Value4Update = [self expectationWithDescription:@"Expect value 4 update [2]"];

	NSURL *temporaryDirectoryURL = [NSURL fileURLWithPath:NSTemporaryDirectory()];
	NSURL *keyValueStoreURL = [temporaryDirectoryURL URLByAppendingPathComponent:[NSUUID UUID].UUIDString];

	OCKeyValueStore *keyValueStore1 = [[OCKeyValueStore alloc] initWithURL:keyValueStoreURL identifier:@"test.kvs"];
	OCKeyValueStore *keyValueStore2 = [[OCKeyValueStore alloc] initWithURL:keyValueStoreURL identifier:@"test.kvs"];

	[keyValueStore1 addObserver:^(id  _Nullable owner, id  _Nullable newValue) {
		OCLog(@"[1] New value: %@", newValue);

		if ([newValue isEqual:@"1"])
		{
			[expect1Value1Update fulfill];
		}

		if ([newValue isEqual:@"2"])
		{
			[expect1Value2Update fulfill];
		}

		if ([newValue isEqual:@"3"])
		{
			[expect1Value3Update fulfill];
		}

		if ([newValue isEqual:@"4"])
		{
			[expect1Value4Update fulfill];
		}
	} forKey:@"test" withOwner:self initial:YES];

	[keyValueStore2 addObserver:^(id  _Nullable owner, id  _Nullable newValue) {
		OCLog(@"[2] New value: %@", newValue);

		if ([newValue isEqual:@"1"])
		{
			[expect2Value1Update fulfill];
		}

		if ([newValue isEqual:@"2"])
		{
			[expect2Value2Update fulfill];
		}

		if ([newValue isEqual:@"3"])
		{
			[expect2Value3Update fulfill];
		}

		if ([newValue isEqual:@"4"])
		{
			[expect2Value4Update fulfill];
		}
	} forKey:@"test" withOwner:self initial:YES];

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		[keyValueStore1 storeObject:@"1" forKey:@"test"];
	});

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		[keyValueStore1 storeObject:@"2" forKey:@"test"];
	});

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		[keyValueStore2 storeObject:@"3" forKey:@"test"];
	});

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		[keyValueStore2 storeObject:@"4" forKey:@"test"];
	});

	[self waitForExpectationsWithTimeout:10.0 handler:nil];

	NSLog (@"keyValueStore1=%@, keyValueStore2=%@", keyValueStore1, keyValueStore2);

	[[NSFileManager defaultManager] removeItemAtURL:keyValueStoreURL error:NULL];
}

- (void)testKeyValueStoreHighVolume
{
	XCTestExpectation *expectFinalValue1Update = [self expectationWithDescription:@"Expect final value [1]"];
	XCTestExpectation *expectFinalValue2Update = [self expectationWithDescription:@"Expect final value [2]"];

	NSURL *temporaryDirectoryURL = [NSURL fileURLWithPath:NSTemporaryDirectory()];
	NSURL *keyValueStoreURL = [temporaryDirectoryURL URLByAppendingPathComponent:[NSUUID UUID].UUIDString];

	OCKeyValueStore *keyValueStore1 = [[OCKeyValueStore alloc] initWithURL:keyValueStoreURL identifier:@"test.kvs"];
	OCKeyValueStore *keyValueStore2 = [[OCKeyValueStore alloc] initWithURL:keyValueStoreURL identifier:@"test.kvs"];

	[keyValueStore1 addObserver:^(id  _Nullable owner, id  _Nullable newValue) {
		OCLog(@"[1] New value: %@", newValue);

		if ([newValue isEqual:@"final"])
		{
			[expectFinalValue1Update fulfill];
		}
	} forKey:@"test" withOwner:self initial:YES];

	[keyValueStore2 addObserver:^(id  _Nullable owner, id  _Nullable newValue) {
		OCLog(@"[2] New value: %@", newValue);

		if ([newValue isEqual:@"final"])
		{
			[expectFinalValue2Update fulfill];
		}
	} forKey:@"test" withOwner:self initial:YES];

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
		for (NSUInteger i=0; i<1000; i++)
		{
			if ((i % 3) == 0)
			{
				[keyValueStore1 storeObject:@(i) forKey:@"test"];
			}
			else
			{
				[keyValueStore2 storeObject:@(i) forKey:@"test"];
			}
		}

		[keyValueStore2 storeObject:@"final" forKey:@"test"];
	});

	[self waitForExpectationsWithTimeout:10.0 handler:nil];

	NSLog (@"keyValueStore1=%@, keyValueStore2=%@", keyValueStore1, keyValueStore2);

	[[NSFileManager defaultManager] removeItemAtURL:keyValueStoreURL error:NULL];
}

@end
