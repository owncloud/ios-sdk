//
//  DatabaseTests.m
//  ownCloudSDKTests
//
//  Created by Felix Schwarz on 15.05.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <ownCloudSDK/ownCloudSDK.h>


@interface DatabaseTests : XCTestCase
{
}

@end

@implementation DatabaseTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testCounterPrimitive
{
	OCBookmark *bookmark = [OCBookmark bookmarkForURL:[NSURL URLWithString:@"test://test"]];
	OCVault *vault = [[OCVault alloc] initWithBookmark:bookmark];
	OCDatabase *database = vault.database;

	OCDatabaseCounterIdentifier counterIdentifier = @"counter";
	XCTestExpectation *increaseExpectation = [self expectationWithDescription:@"Increase block called"];
	XCTestExpectation *completionExpectation = [self expectationWithDescription:@"Completion block called"];
	XCTestExpectation *vaultEraseExpectation = [self expectationWithDescription:@"Vault erased"];

	[vault openWithCompletionHandler:^(id sender, NSError *error) {
		[database increaseValueForCounter:counterIdentifier withProtectedBlock:^NSError *(NSNumber *previousCounterValue, NSNumber *newCounterValue) {
			OCLog(@"Increase from %@ to %@", previousCounterValue, newCounterValue);

			XCTAssert((previousCounterValue!=nil) && (previousCounterValue.integerValue == 0));
			XCTAssert((newCounterValue!=nil) && (newCounterValue.integerValue == 1));

			[increaseExpectation fulfill];

			return(nil);
		} completionHandler:^(NSError *error, NSNumber *previousCounterValue, NSNumber *newCounterValue) {
			OCLog(@"Completion with %@ for increase from %@ to %@", error, previousCounterValue, newCounterValue);

			XCTAssert((error == nil));
			XCTAssert((previousCounterValue!=nil) && (previousCounterValue.integerValue == 0));
			XCTAssert((newCounterValue!=nil) && (newCounterValue.integerValue == 1));

			[completionExpectation fulfill];

			[vault closeWithCompletionHandler:^(id sender, NSError *error) {
				[vault eraseWithCompletionHandler:^(id sender, NSError *error) {
					OCLog(@"Vault erase result: %@", error);

					[vaultEraseExpectation fulfill];
				}];
			}];
		}];
	}];

	[self waitForExpectationsWithTimeout:3 handler:nil];
}

- (void)testCounterPrimitiveHighLocalConcurrency
{
	// Test counter primitive calls from 10 different threads on the same OCDatabase instance

	XCTestExpectation *vaultEraseExpectation = [self expectationWithDescription:@"Vault erased"];
	XCTestExpectation *operationsCompleteExpectation = [self expectationWithDescription:@"Operations complete"];

	OCBookmark *bookmark = [OCBookmark bookmarkForURL:[NSURL URLWithString:@"test://test"]];
	OCVault *vault = [[OCVault alloc] initWithBookmark:bookmark];
	OCDatabase *database = vault.database;
	NSMutableArray <OCRunLoopThread *> *runLoopThreads = [NSMutableArray new];
	NSMutableArray <NSMutableArray<NSNumber *> *> *newCounterValues = [NSMutableArray new];
	NSMutableArray <NSMutableArray<NSNumber *> *> *previousCounterValues = [NSMutableArray new];
	NSUInteger concurrencyLevel = 10;
	NSUInteger transactions = 100;

	OCDatabaseCounterIdentifier counterIdentifier = @"counter";

	dispatch_group_t waitGroup = dispatch_group_create();

	dispatch_group_enter(waitGroup);

	[vault openWithCompletionHandler:^(id sender, NSError *error) {
		OCLog(@"Vault open=%@", error);

		for (NSUInteger i=0; i<concurrencyLevel; i++)
		{
			OCRunLoopThread *runLoopThread = [OCRunLoopThread runLoopThreadNamed:[NSString stringWithFormat:@"concurrency-%lu", i]];
			NSMutableArray<NSNumber *> *newValues = [NSMutableArray new];
			NSMutableArray<NSNumber *> *previousValues = [NSMutableArray new];

			[runLoopThreads addObject:runLoopThread];
			[newCounterValues addObject:newValues];
			[previousCounterValues addObject:previousValues];

			dispatch_group_enter(waitGroup);

			[runLoopThread dispatchBlockToRunLoopAsync:^{
				for (NSUInteger j=0; j < transactions; j++)
				{
					[database increaseValueForCounter:counterIdentifier withProtectedBlock:^NSError *(NSNumber *previousCounterValue, NSNumber *newCounterValue) {
						[previousValues addObject:previousCounterValue];
						[newValues addObject:newCounterValue];

						return(nil);
					} completionHandler:^(NSError *error, NSNumber *previousCounterValue, NSNumber *newCounterValue) {
						if (error != nil)
						{
							OCLog(@"Completion with error=%@", error);
						}

						if (newValues.count == transactions)
						{
							dispatch_group_leave(waitGroup);
						}
					}];
				}
			}];
		}

		dispatch_group_leave(waitGroup);
	}];

	if (dispatch_group_wait(waitGroup, DISPATCH_TIME_FOREVER) == 0)
	{
		[operationsCompleteExpectation fulfill];
	}

	NSMutableSet *newSet = [NSMutableSet set];
	NSMutableSet *previousSet = [NSMutableSet set];

	for (NSMutableArray<NSNumber *> *counterValues in newCounterValues)
	{
		NSUInteger previousCount = newSet.count;

		[newSet addObjectsFromArray:counterValues];

		XCTAssert((previousCount + counterValues.count) == newSet.count);
	}

	for (NSMutableArray<NSNumber *> *counterValues in previousCounterValues)
	{
		NSUInteger previousCount = previousSet.count;

		[previousSet addObjectsFromArray:counterValues];

		XCTAssert((previousCount + counterValues.count) == previousSet.count);
	}

	XCTAssert(previousSet.count == (concurrencyLevel*transactions));
	XCTAssert(newSet.count == (concurrencyLevel*transactions));

	[vault closeWithCompletionHandler:^(id sender, NSError *error) {
		[vault eraseWithCompletionHandler:^(id sender, NSError *error) {
			OCLog(@"Vault erase result: %@", error);

			[vaultEraseExpectation fulfill];
		}];
	}];

	[self waitForExpectationsWithTimeout:3 handler:nil];
}

- (void)testCounterPrimitiveHighDistributedConcurrency
{
	// Test counter primitive calls from 10 different threads on 10 different OCDatabase instances

	XCTestExpectation *vaultEraseExpectation = [self expectationWithDescription:@"Vault erased"];
	XCTestExpectation *operationsCompleteExpectation = [self expectationWithDescription:@"Operations complete"];

	OCBookmark *bookmark = [OCBookmark bookmarkForURL:[NSURL URLWithString:@"test://test"]];
	OCVault *vault = [[OCVault alloc] initWithBookmark:bookmark];
	NSMutableArray <OCRunLoopThread *> *runLoopThreads = [NSMutableArray new];
	NSMutableArray <NSMutableArray<NSNumber *> *> *newCounterValues = [NSMutableArray new];
	NSMutableArray <NSMutableArray<NSNumber *> *> *previousCounterValues = [NSMutableArray new];
	NSUInteger concurrencyLevel = 10;
	NSUInteger transactions = 100;

	OCDatabaseCounterIdentifier counterIdentifier = @"counter";

	dispatch_group_t waitGroup = dispatch_group_create();

	dispatch_group_enter(waitGroup);

	[vault openWithCompletionHandler:^(id sender, NSError *error) {
		OCLog(@"Vault open=%@", error);

		NSURL *databaseURL = vault.databaseURL;

		OCSQLiteDB.allowConcurrentFileAccess = YES; // Make sure separate threads are used to back each OCSQLiteDB instance.

		for (NSUInteger i=0; i<concurrencyLevel; i++)
		{
			OCRunLoopThread *runLoopThread = [OCRunLoopThread runLoopThreadNamed:[NSString stringWithFormat:@"concurrency-%lu", i]];
			NSMutableArray<NSNumber *> *newValues = [NSMutableArray new];
			NSMutableArray<NSNumber *> *previousValues = [NSMutableArray new];

			[runLoopThreads addObject:runLoopThread];
			[newCounterValues addObject:newValues];
			[previousCounterValues addObject:previousValues];

			dispatch_group_enter(waitGroup);

			OCDatabase *database = [[OCDatabase alloc] initWithURL:databaseURL];

			database.sqlDB.maxBusyRetryTimeInterval = 10;

			[database openWithCompletionHandler:^(OCDatabase *db, NSError *error) {
				[runLoopThread dispatchBlockToRunLoopAsync:^{

					for (NSUInteger j=0; j < transactions; j++)
					{
						[database increaseValueForCounter:counterIdentifier withProtectedBlock:^NSError *(NSNumber *previousCounterValue, NSNumber *newCounterValue) {
							[previousValues addObject:previousCounterValue];
							[newValues addObject:newCounterValue];

							return(nil);
						} completionHandler:^(NSError *error, NSNumber *previousCounterValue, NSNumber *newCounterValue) {
							if (error != nil)
							{
								OCLog(@"Completion with error=%@", error);
							}

							if (newValues.count == transactions)
							{
								[database closeWithCompletionHandler:^(OCDatabase *db, NSError *error) {
									dispatch_group_leave(waitGroup);
								}];
							}
						}];
					}
				}];
			}];
		}

		dispatch_group_leave(waitGroup);

		OCSQLiteDB.allowConcurrentFileAccess = NO;  // Back to normal
	}];

	if (dispatch_group_wait(waitGroup, DISPATCH_TIME_FOREVER) == 0)
	{
		[operationsCompleteExpectation fulfill];
	}

	NSMutableSet *newSet = [NSMutableSet set];
	NSMutableSet *previousSet = [NSMutableSet set];

	for (NSMutableArray<NSNumber *> *counterValues in newCounterValues)
	{
		NSUInteger previousCount = newSet.count;

		[newSet addObjectsFromArray:counterValues];

		XCTAssert((previousCount + counterValues.count) == newSet.count);
	}

	for (NSMutableArray<NSNumber *> *counterValues in previousCounterValues)
	{
		NSUInteger previousCount = previousSet.count;

		[previousSet addObjectsFromArray:counterValues];

		XCTAssert((previousCount + counterValues.count) == previousSet.count);
	}

	XCTAssert(previousSet.count == (concurrencyLevel*transactions));
	XCTAssert(newSet.count == (concurrencyLevel*transactions));

	[vault closeWithCompletionHandler:^(id sender, NSError *error) {
		[vault eraseWithCompletionHandler:^(id sender, NSError *error) {
			OCLog(@"Vault erase result: %@", error);

			[vaultEraseExpectation fulfill];
		}];
	}];

	[self waitForExpectationsWithTimeout:3 handler:nil];
}

- (void)testConsistentOperationMechanics
{
	// Testing sunshine conditions

	OCBookmark *bookmark = [OCBookmark bookmarkForURL:[NSURL URLWithString:@"test://test"]];
	OCVault *vault = [[OCVault alloc] initWithBookmark:bookmark];
	OCDatabase *database = vault.database;
	OCDatabaseCounterIdentifier counterID = @"counter";

	XCTestExpectation *preparationExpectation = [self expectationWithDescription:@"Preparation block called"];
	XCTestExpectation *performExpectation = [self expectationWithDescription:@"Perform block called"];
	XCTestExpectation *completionExpectation = [self expectationWithDescription:@"Completion block called"];
	XCTestExpectation *vaultEraseExpectation = [self expectationWithDescription:@"Vault erased"];

	[vault openWithCompletionHandler:^(id sender, NSError *error) {
		OCDatabaseConsistentOperation *consistentOperation;

		consistentOperation = [[OCDatabaseConsistentOperation alloc] initWithDatabase:database counterIdentifier:counterID preparation:^(OCDatabaseConsistentOperation *operation, OCDatabaseConsistentOperationAction action, NSNumber *newCounterValue, void (^completionHandler)(NSError *error, id preparationResult)) {
			[preparationExpectation fulfill];

			OCLog(@"Prepare with new counter value = %@ (%@)", newCounterValue, ((action==OCDatabaseConsistentOperationActionInitial) ? @"inital" : @"repeated"));

			completionHandler(nil, @"prep result");
		}];

		[consistentOperation prepareWithCompletionHandler:^{
			[consistentOperation performOperation:^NSError *(OCDatabaseConsistentOperation *operation, id preparationResult, NSNumber *newCounterValue) {
				XCTAssert([preparationResult isEqual:@"prep result"]);

				OCLog(@"Perform with new counter value = %@", newCounterValue);

				[performExpectation fulfill];

				return (nil);
			} completionHandler:^(NSError *error, NSNumber *previousCounterValue, NSNumber *newCounterValue) {
				[completionExpectation fulfill];

				[vault closeWithCompletionHandler:^(id sender, NSError *error) {
					[vault eraseWithCompletionHandler:^(id sender, NSError *error) {
						OCLog(@"Vault erase result: %@", error);

						[vaultEraseExpectation fulfill];
					}];
				}];
			}];
		}];
	}];

	[self waitForExpectationsWithTimeout:3 handler:nil];
}

- (void)testConsistentOperationConflictResolution
{
	OCBookmark *bookmark = [OCBookmark bookmarkForURL:[NSURL URLWithString:@"test://test"]];
	OCVault *vault = [[OCVault alloc] initWithBookmark:bookmark];
	OCDatabase *database = vault.database;
	OCDatabaseCounterIdentifier counterID = @"counter";
	__block NSUInteger preparationCalls = 0;

	// XCTestExpectation *preparationExpectation = [self expectationWithDescription:@"Preparation block called"];
	XCTestExpectation *performExpectation = [self expectationWithDescription:@"Perform block called"];
	XCTestExpectation *completionExpectation = [self expectationWithDescription:@"Completion block called"];
	XCTestExpectation *vaultEraseExpectation = [self expectationWithDescription:@"Vault erased"];

	[vault openWithCompletionHandler:^(id sender, NSError *error) {
		OCDatabaseConsistentOperation *consistentOperation;

		consistentOperation = [[OCDatabaseConsistentOperation alloc] initWithDatabase:database counterIdentifier:counterID preparation:^(OCDatabaseConsistentOperation *operation, OCDatabaseConsistentOperationAction action, NSNumber *newCounterValue, void (^completionHandler)(NSError *error, id preparationResult)) {

			preparationCalls++;

			OCLog(@"Prepare with new counter value = %@ (%@)", newCounterValue, ((action==OCDatabaseConsistentOperationActionInitial) ? @"inital" : @"repeated"));

			completionHandler(nil, @"prep result");
		}];

		[consistentOperation prepareWithCompletionHandler:^{
			[database increaseValueForCounter:counterID withProtectedBlock:^NSError *(NSNumber *previousCounterValue, NSNumber *newCounterValue) {
				OCLog(@"Incremented counter value from %@ to %@", previousCounterValue, newCounterValue);

				return (nil);
			} completionHandler:^(NSError *error, NSNumber *previousCounterValue, NSNumber *newCounterValue) {
				[consistentOperation performOperation:^NSError *(OCDatabaseConsistentOperation *operation, id preparationResult, NSNumber *newCounterValue) {
					XCTAssert([preparationResult isEqual:@"prep result"]);

					OCLog(@"Perform with new counter value = %@", newCounterValue);

					[performExpectation fulfill];

					return (nil);
				} completionHandler:^(NSError *error, NSNumber *previousCounterValue, NSNumber *newCounterValue) {
					[completionExpectation fulfill];

					[vault closeWithCompletionHandler:^(id sender, NSError *error) {
						[vault eraseWithCompletionHandler:^(id sender, NSError *error) {
							OCLog(@"Vault erase result: %@", error);

							[vaultEraseExpectation fulfill];
						}];
					}];
				}];
			}];
		}];
	}];

	[self waitForExpectationsWithTimeout:3 handler:nil];

	XCTAssert((preparationCalls==2));
}

@end
