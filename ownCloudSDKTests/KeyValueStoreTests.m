//
//  KeyValueStoreTests.m
//  ownCloudSDKTests
//
//  Created by Felix Schwarz on 23.08.19.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <ownCloudSDK/ownCloudSDK.h>

@interface AtomicTestSet : NSObject <NSSecureCoding>

@property(strong) NSMutableArray<NSMutableIndexSet *> *sets;

@end

@implementation AtomicTestSet

- (instancetype)initWithCount:(NSUInteger)count
{
	self = [super init];

	_sets = [NSMutableArray new];

	for (NSUInteger i=0; i<count; i++)
	{
		_sets[i] = [NSMutableIndexSet new];
	}

	return (self);
}

+ (BOOL)supportsSecureCoding
{
	return(YES);
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super init]) != nil)
	{
		_sets = [decoder decodeObjectOfClasses:[NSSet setWithObjects:[NSMutableIndexSet class], [NSMutableArray class], nil] forKey:@"sets"];
	}

	return (self);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:_sets forKey:@"sets"];
}

@end

@interface KeyValueStoreTests : XCTestCase
{
	NSURL *keyValueStoreURL;
}

@end

@implementation KeyValueStoreTests

- (void)setUp
{
	NSURL *temporaryDirectoryURL = [NSURL fileURLWithPath:NSTemporaryDirectory()];
	keyValueStoreURL = [temporaryDirectoryURL URLByAppendingPathComponent:[NSUUID UUID].UUIDString];

	OCLogDebug(@"Using keyValueStoreURL=%@", keyValueStoreURL);
}

- (void)tearDown
{
	OCLogDebug(@"Deleting keyValueStoreURL=%@", keyValueStoreURL);

	[[NSFileManager defaultManager] removeItemAtURL:keyValueStoreURL error:NULL];
	keyValueStoreURL = nil;
}

- (void)testKeyValueStoreConcurrency
{
	@autoreleasepool {
		XCTestExpectation *expect1Value1Update = [self expectationWithDescription:@"Expect value 1 update [1]"];
		XCTestExpectation *expect1Value2Update = [self expectationWithDescription:@"Expect value 2 update [1]"];
		XCTestExpectation *expect1Value3Update = [self expectationWithDescription:@"Expect value 3 update [1]"];
		XCTestExpectation *expect1Value4Update = [self expectationWithDescription:@"Expect value 4 update [1]"];

		XCTestExpectation *expect2Value1Update = [self expectationWithDescription:@"Expect value 1 update [2]"];
		XCTestExpectation *expect2Value2Update = [self expectationWithDescription:@"Expect value 2 update [2]"];
		XCTestExpectation *expect2Value3Update = [self expectationWithDescription:@"Expect value 3 update [2]"];
		XCTestExpectation *expect2Value4Update = [self expectationWithDescription:@"Expect value 4 update [2]"];

		__block XCTestExpectation *expect1ValueT1Update = [self expectationWithDescription:@"Expect value t1 update [1]"];
		__block XCTestExpectation *expect1ValueT1Removal = [self expectationWithDescription:@"Expect value t1 removal [1]"];

		__block XCTestExpectation *expect2ValueT1Update = [self expectationWithDescription:@"Expect value t1 update [2]"];
		__block XCTestExpectation *expect2ValueT1Removal = [self expectationWithDescription:@"Expect value t1 removal [2]"];

		OCKeyValueStore *keyValueStore1 = [[OCKeyValueStore alloc] initWithURL:keyValueStoreURL identifier:@"test.kvs1"];
		OCKeyValueStore *keyValueStore2 = [[OCKeyValueStore alloc] initWithURL:keyValueStoreURL identifier:@"test.kvs1"];

		[keyValueStore1 addObserver:^(OCKeyValueStore *store, id  _Nullable owner, OCKeyValueStoreKey key, id  _Nullable newValue) {
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

		[keyValueStore2 addObserver:^(OCKeyValueStore *store, id  _Nullable owner, OCKeyValueStoreKey key, id  _Nullable newValue) {
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


		[keyValueStore1 addObserver:^(OCKeyValueStore *store, id  _Nullable owner, OCKeyValueStoreKey key, id  _Nullable newValue) {
			OCLog(@"[1] New value: %@", newValue);

			if (expect1ValueT1Update != nil)
			{
				if ([newValue isEqual:@"t1"])
				{
					[expect1ValueT1Update fulfill];
					expect1ValueT1Update = nil;
				}
			}
			else
			{
				if (newValue == nil)
				{
					[expect1ValueT1Removal fulfill];
					expect1ValueT1Removal = nil;
				}
			}
		} forKey:@"test2" withOwner:self initial:YES];

		[keyValueStore2 addObserver:^(OCKeyValueStore *store, id  _Nullable owner, OCKeyValueStoreKey key, id  _Nullable newValue) {
			OCLog(@"[2] New value: %@", newValue);

			if (expect2ValueT1Update != nil)
			{
				if ([newValue isEqual:@"t1"])
				{
					[expect2ValueT1Update fulfill];
					expect2ValueT1Update = nil;
				}
			}
			else
			{
				if (newValue == nil)
				{
					[expect2ValueT1Removal fulfill];
					expect2ValueT1Removal = nil;
				}
			}
		} forKey:@"test2" withOwner:self initial:YES];

		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			[keyValueStore1 storeObject:@"1"  forKey:@"test"];
			XCTAssert([[keyValueStore1 readObjectForKey:@"test"] isEqual:@"1"]);

			[keyValueStore1 storeObject:@"t1" forKey:@"test2"];
			XCTAssert([[keyValueStore1 readObjectForKey:@"test2"] isEqual:@"t1"]);
		});

		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			[keyValueStore1 storeObject:@"2" forKey:@"test"];
			XCTAssert([[keyValueStore1 readObjectForKey:@"test"] isEqual:@"2"]);
		});

		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			[keyValueStore2 storeObject:@"3" forKey:@"test"];
			XCTAssert([[keyValueStore2 readObjectForKey:@"test"] isEqual:@"3"]);

			[keyValueStore2 storeObject:nil  forKey:@"test2"];
			XCTAssert([keyValueStore2 readObjectForKey:@"test2"] == nil);
		});

		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			[keyValueStore2 storeObject:@"4" forKey:@"test"];
			XCTAssert([[keyValueStore2 readObjectForKey:@"test"] isEqual:@"4"]);
		});

		[self waitForExpectationsWithTimeout:10.0 handler:nil];

		NSLog (@"keyValueStore1=%@, keyValueStore2=%@", keyValueStore1, keyValueStore2);
	}
}

- (void)testKeyValueStoreHighVolume
{
	@autoreleasepool {
		XCTestExpectation *expectFinalValue1Update = [self expectationWithDescription:@"Expect final value [1]"];
		XCTestExpectation *expectFinalValue2Update = [self expectationWithDescription:@"Expect final value [2]"];

		OCKeyValueStore *keyValueStore1 = [[OCKeyValueStore alloc] initWithURL:keyValueStoreURL identifier:@"test.kvs2"];
		OCKeyValueStore *keyValueStore2 = [[OCKeyValueStore alloc] initWithURL:keyValueStoreURL identifier:@"test.kvs2"];

		[keyValueStore1 addObserver:^(OCKeyValueStore *store, id  _Nullable owner, OCKeyValueStoreKey key, id  _Nullable newValue) {
			OCLog(@"[1] New value: %@", newValue);

			if ([newValue isEqual:@"final"])
			{
				[expectFinalValue1Update fulfill];
			}
		} forKey:@"test" withOwner:self initial:YES];

		[keyValueStore2 addObserver:^(OCKeyValueStore *store, id  _Nullable owner, OCKeyValueStoreKey key, id  _Nullable newValue) {
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
					XCTAssert([[keyValueStore1 readObjectForKey:@"test"] isEqual:@(i)]);
				}
				else
				{
					[keyValueStore2 storeObject:@(i) forKey:@"test"];
					XCTAssert([[keyValueStore2 readObjectForKey:@"test"] isEqual:@(i)]);
				}
			}

			[keyValueStore2 storeObject:@"final" forKey:@"test"];
			XCTAssert([[keyValueStore2 readObjectForKey:@"test"] isEqual:@"final"]);
		});

		[self waitForExpectationsWithTimeout:10.0 handler:nil];

		keyValueStore1 = nil;
		keyValueStore2 = nil;
	}
}

- (void)testKeyValueStoreConcurrentAtomicUpdates
{
	@autoreleasepool {
		NSUInteger concurrentStores = 10;
		NSUInteger modificationCount = 50;

		NSMutableArray<XCTestExpectation *> *expectations = [NSMutableArray new];
		NSMutableArray<OCKeyValueStore *> *keyValueStores = [NSMutableArray new];

		XCTestExpectation *expectAllFilled = [self expectationWithDescription:@"All sets fully filled"];

		__block BOOL storeZeroDidFulfill = NO;

		for (NSUInteger store=0; store < concurrentStores; store++)
		{
			expectations[store] = [self expectationWithDescription:[NSString stringWithFormat:@"Expect final value [%lu]", store]];
			keyValueStores[store] = [[OCKeyValueStore alloc] initWithURL:keyValueStoreURL identifier:@"test.kvs3"];
			[keyValueStores[store] registerClass:[AtomicTestSet class] forKey:@"test"];

			[keyValueStores[store] addObserver:^(OCKeyValueStore *keyValueStore, id  _Nullable owner, OCKeyValueStoreKey key, AtomicTestSet * _Nullable newValue) {
				// OCLogDebug(@"Contents [%lu]: %@", store, newValue.sets[store]);

				if (newValue.sets[store].count == modificationCount)
				{
					if (store == 0)
					{
						if (!storeZeroDidFulfill)
						{
							storeZeroDidFulfill = YES;
							[expectations[store] fulfill];
						}

						BOOL allFullyFilled = YES;

						for (NSUInteger checkStore=0; checkStore < concurrentStores; checkStore++)
						{
							// OCLogDebug(@"Store [%lu]: %lu of %lu", checkStore, newValue.sets[checkStore].count, modificationCount);

							if (newValue.sets[checkStore].count != modificationCount)
							{
								allFullyFilled = NO;
								break;
							}
						}

						// OCLogDebug(@"Result: allFullyFilled=%d", allFullyFilled);

						if (allFullyFilled)
						{
							[expectAllFilled fulfill];
							[keyValueStore removeObserverForOwner:owner forKey:key];
						}
					}
					else
					{
						[expectations[store] fulfill];
						[keyValueStore removeObserverForOwner:owner forKey:key];
					}

					OCLogDebug(@"Done [%lu]: %@", store, newValue.sets[store]);
				}

			} forKey:@"test" withOwner:self initial:YES];

			dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
				for (NSUInteger idx=0;idx<modificationCount;idx++)
				{
					[keyValueStores[store] updateObjectForKey:@"test" usingModifier:^id _Nullable(AtomicTestSet *existingObject, BOOL *outDidModify) {
						if (existingObject == nil)
						{
							existingObject = [[AtomicTestSet alloc] initWithCount:concurrentStores];
						}
						[existingObject.sets[store] addIndex:idx];
						*outDidModify = YES;

						return (existingObject);
					}];
					XCTAssert([((AtomicTestSet *)[keyValueStores[store] readObjectForKey:@"test"]).sets[store] containsIndex:idx]);
				}
			});
		}

		[self waitForExpectationsWithTimeout:10.0 * concurrentStores handler:nil];

		NSLog(@"%@", keyValueStores);
	}
}

- (void)testKeyValueStack
{
	@autoreleasepool {
		XCTestExpectation *expectTimeout = [self expectationWithDescription:@"Timeout reached"];

		OCKeyValueStore *keyValueStore1 = [[OCKeyValueStore alloc] initWithURL:keyValueStoreURL identifier:@"test.kvs4"];
		OCClaim *claim10 = nil;

		[keyValueStore1 pushObject:@(0) onStackForKey:@"test" withClaim:(claim10 = [OCClaim claimExpiringAtDate:[NSDate dateWithTimeIntervalSinceNow:10.0] withLockType:OCClaimLockTypeRead])];
		[keyValueStore1 pushObject:@(1) onStackForKey:@"test" withClaim:[OCClaim claimExpiringAtDate:[NSDate dateWithTimeIntervalSinceNow:6.0] withLockType:OCClaimLockTypeRead]];
		[keyValueStore1 pushObject:@(2) onStackForKey:@"test" withClaim:[OCClaim claimExpiringAtDate:[NSDate dateWithTimeIntervalSinceNow:4.0] withLockType:OCClaimLockTypeRead]];
		[keyValueStore1 pushObject:@(3) onStackForKey:@"test" withClaim:[OCClaim claimExpiringAtDate:[NSDate dateWithTimeIntervalSinceNow:2.0] withLockType:OCClaimLockTypeRead]];

		XCTAssert([[keyValueStore1 readObjectForKey:@"test"] isEqual:@(3)]);
		OCLogDebug(@"(0) testValue=%@", [keyValueStore1 readObjectForKey:@"test"]);

		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			XCTAssert([[keyValueStore1 readObjectForKey:@"test"] isEqual:@(3)]);
			OCLogDebug(@"(1) testValue=%@", [keyValueStore1 readObjectForKey:@"test"]);
		});

		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			[keyValueStore1 popObjectWithClaimID:claim10.identifier fromStackForKey:@"test"];
		});

		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			XCTAssert([[keyValueStore1 readObjectForKey:@"test"] isEqual:@(2)]);
			OCLogDebug(@"(2) testValue=%@", [keyValueStore1 readObjectForKey:@"test"]);
		});

		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			XCTAssert([[keyValueStore1 readObjectForKey:@"test"] isEqual:@(1)]);
			OCLogDebug(@"(3) testValue=%@", [keyValueStore1 readObjectForKey:@"test"]);
		});

		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(7.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			XCTAssert([keyValueStore1 readObjectForKey:@"test"] == nil);
			OCLogDebug(@"(4) testValue=%@", [keyValueStore1 readObjectForKey:@"test"]);

			[expectTimeout fulfill];
		});

		[self waitForExpectationsWithTimeout:10.0 handler:nil];
	}
}

@end
