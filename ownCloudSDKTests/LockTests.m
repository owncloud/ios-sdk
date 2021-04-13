//
//  LockTests.m
//  ownCloudSDKTests
//
//  Created by Felix Schwarz on 06.02.21.
//  Copyright © 2021 ownCloud GmbH. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <ownCloudSDK/ownCloudSDK.h>

@interface LockTests : XCTestCase
{
	NSURL *_keyValueStoreURL;
}

@end

@interface OCLockManager (Private)
- (void)_updateLocks;
- (void)setNeedsLockUpdate;
@end

@interface PausableLockManager : OCLockManager
@property(assign) BOOL paused;
@end

@implementation PausableLockManager
- (void)_updateLocks
{
	if (!_paused)
	{
		[super _updateLocks];
	}
}
@end

@implementation LockTests

- (void)setUp
{
	NSURL *temporaryDirectoryURL = [NSURL fileURLWithPath:NSTemporaryDirectory()];
	NSError *error =nil;
	[NSFileManager.defaultManager createDirectoryAtURL:temporaryDirectoryURL withIntermediateDirectories:YES attributes:nil error:&error];
	_keyValueStoreURL = [temporaryDirectoryURL URLByAppendingPathComponent:NSUUID.UUID.UUIDString];

	OCLogDebug(@"Using keyValueStoreURL=%@, error=%@", _keyValueStoreURL, error);
}

- (void)tearDown
{
	OCLogDebug(@"Deleting keyValueStoreURL=%@", _keyValueStoreURL);

	[[NSFileManager defaultManager] removeItemAtURL:_keyValueStoreURL error:NULL];
	_keyValueStoreURL = nil;
}

- (void)testConcurrencyLock
{
	__block XCTestExpectation *expectLock1 = [self expectationWithDescription:@"Lock 1 acquired"];
	__block XCTestExpectation *expectLock1Release = [self expectationWithDescription:@"Lock 1 acquired"];
	__block XCTestExpectation *expectLock2 = [self expectationWithDescription:@"Lock 2 acquired"];

	OCLockManager *lockManager1 = [[OCLockManager alloc] initWithKeyValueStore:[[OCKeyValueStore alloc] initWithURL:_keyValueStoreURL identifier:@"lockTestKVS"]];
	OCLockManager *lockManager2 = [[OCLockManager alloc] initWithKeyValueStore:[[OCKeyValueStore alloc] initWithURL:_keyValueStoreURL identifier:@"lockTestKVS"]];

	NSLog(@"LockManager 1: %@, LockManager 2: %@", lockManager1, lockManager2);

	[lockManager1 requestLock:[[OCLockRequest alloc] initWithResourceIdentifier:@"resource-1" acquiredHandler:^(NSError * _Nullable error, OCLock * _Nullable lock) {
		NSLog(@"Lock 1 acquired");

		[expectLock1 fulfill];

		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			expectLock1 = nil;

			NSLog(@"Lock 1 release");
			[lock releaseLock];

			[expectLock1Release fulfill];
		});
	}]];

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		[lockManager2 requestLock:[[OCLockRequest alloc] initWithResourceIdentifier:@"resource-1" acquiredHandler:^(NSError * _Nullable error, OCLock * _Nullable lock) {
			NSLog(@"Lock 2 acquired");

			XCTAssert(expectLock1 == nil);

			[expectLock2 fulfill];
		}]];
	});

	[self waitForExpectationsWithTimeout:10.0 handler:nil];

	NSLog(@"LockManager 1: %@, LockManager 2: %@", lockManager1, lockManager2);
}

- (void)testConcurrencyLockTimeout
{
	__block XCTestExpectation *expectLock1 = [self expectationWithDescription:@"Lock 1 acquired"];
	__block XCTestExpectation *expectLock2 = [self expectationWithDescription:@"Lock 2 acquired"];

	__block OCLockManager *lockManager1 = [[OCLockManager alloc] initWithKeyValueStore:[[OCKeyValueStore alloc] initWithURL:_keyValueStoreURL identifier:@"lockTestKVS"]];
	OCLockManager *lockManager2 = [[OCLockManager alloc] initWithKeyValueStore:[[OCKeyValueStore alloc] initWithURL:_keyValueStoreURL identifier:@"lockTestKVS"]];

	NSLog(@"LockManager 1: %@, LockManager 2: %@", lockManager1, lockManager2);

	[lockManager1 requestLock:[[OCLockRequest alloc] initWithResourceIdentifier:@"resource-2" acquiredHandler:^(NSError * _Nullable error, OCLock * _Nullable lock) {
		NSLog(@"Lock 1 acquired");

		[expectLock1 fulfill];
		expectLock1 = nil;

		lockManager1 = nil;
	}]];

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		[lockManager2 requestLock:[[OCLockRequest alloc] initWithResourceIdentifier:@"resource-2" acquiredHandler:^(NSError * _Nullable error, OCLock * _Nullable lock) {
			NSLog(@"Lock 2 acquired");

			XCTAssert(expectLock1 == nil);

			[expectLock2 fulfill];
		}]];
	});

	[self waitForExpectationsWithTimeout:10.0 handler:nil];
}

- (void)testConcurrencyLockExpiraton
{
	__block XCTestExpectation *expectLock1 = [self expectationWithDescription:@"Lock 1 acquired"];
	__block XCTestExpectation *expectLock1Expiry = [self expectationWithDescription:@"Lock 1 expired"];
	__block XCTestExpectation *expectLock2 = [self expectationWithDescription:@"Lock 2 acquired"];

	PausableLockManager *lockManager1 = [[PausableLockManager alloc] initWithKeyValueStore:[[OCKeyValueStore alloc] initWithURL:_keyValueStoreURL identifier:@"lockTestKVS"]];
	OCLockManager *lockManager2 = [[OCLockManager alloc] initWithKeyValueStore:[[OCKeyValueStore alloc] initWithURL:_keyValueStoreURL identifier:@"lockTestKVS"]];

	NSLog(@"LockManager 1: %@, LockManager 2: %@", lockManager1, lockManager2);

	[lockManager1 requestLock:[[OCLockRequest alloc] initWithResourceIdentifier:@"resource-2" acquiredHandler:^(NSError * _Nullable error, OCLock * _Nullable lock) {
		NSLog(@"Lock 1 acquired");

		lock.expirationHandler = ^{
			NSLog(@"Lock 1 expired");
			[expectLock1Expiry fulfill];
		};

		lockManager1.paused = YES;

		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(OCLockExpirationInterval*1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			lockManager1.paused = NO;
			[lockManager1 setNeedsLockUpdate];
		});

		[expectLock1 fulfill];
		expectLock1 = nil;
	}]];

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		[lockManager2 requestLock:[[OCLockRequest alloc] initWithResourceIdentifier:@"resource-2" acquiredHandler:^(NSError * _Nullable error, OCLock * _Nullable lock) {
			NSLog(@"Lock 2 acquired");

			XCTAssert(expectLock1 == nil);

			[expectLock2 fulfill];
		}]];
	});

	[self waitForExpectationsWithTimeout:10.0 handler:nil];

	NSLog(@"LockManager 1: %@, LockManager 2: %@", lockManager1, lockManager2);
}

@end
