//
//  SQLTests.m
//  ownCloudSDKTests
//
//  Created by Felix Schwarz on 27.03.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <ownCloudSDK/ownCloudSDK.h>

@interface SQLTests : XCTestCase

@end

@implementation SQLTests

- (void)setUp {
	[super setUp];
	// Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
	// Put teardown code here. This method is called after the invocation of each test method in the class.
	[super tearDown];
}

- (void)testSQLiteChainedQueries
{
	XCTestExpectation *expectCallback1 = [self expectationWithDescription:@"Expect receiving callback"];
	XCTestExpectation *expectCallback2 = [self expectationWithDescription:@"Expect receiving callback"];
	XCTestExpectation *expectCallback3 = [self expectationWithDescription:@"Expect receiving callback"];
	XCTestExpectation *expectCallback4 = [self expectationWithDescription:@"Expect receiving callback"];
	XCTestExpectation *expectCallback5 = [self expectationWithDescription:@"Expect receiving callback"];
	XCTestExpectation *expectCallback6 = [self expectationWithDescription:@"Expect receiving callback"];
	OCSQLiteDB *sqlDB;

	if ((sqlDB = [OCSQLiteDB new]) != nil)
	{
		[sqlDB openWithFlags:OCSQLiteOpenFlagsDefault completionHandler:^(OCSQLiteDB *db, NSError *error) {
			[db executeQuery:[OCSQLiteQuery query:@"CREATE TABLE t1(a, b PRIMARY KEY)" withNamedParameters:nil resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
				OCLog(@"Create table error: %@", error);

				XCTAssert((error==nil), @"No error");

				[expectCallback1 fulfill];
			}]];

			[db executeQuery:[OCSQLiteQuery query:@"INSERT INTO t1 (a,b) VALUES (:hello, :world)" withNamedParameters:@{ @"hello" : @"Hallo", @"world" : @"Welt" } resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
				OCLog(@"Insert error: %@", error);

				XCTAssert((error==nil), @"No error");

				XCTAssert([[db lastInsertRowID] isEqual:@(1)], @"Insert Row ID is 1");

				[expectCallback2 fulfill];
			}]];

			[db executeQuery:[OCSQLiteQuery query:@"INSERT INTO t1 (a,b) VALUES (:hello, :world)" withNamedParameters:@{ @"hello" : @"Bonjour", @"world" : @"Monde" } resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
				OCLog(@"Insert error: %@", error);

				XCTAssert((error==nil), @"No error");

				XCTAssert([[db lastInsertRowID] isEqual:@(2)], @"Insert Row ID is 2");

				[expectCallback3 fulfill];
			}]];

			[db executeQuery:[OCSQLiteQuery query:@"INSERT INTO t1 (a,b) VALUES (:hello, :world)" withNamedParameters:@{ @"hello" : @"¡Hola!", @"world" : @"el mundo" } resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
				OCLog(@"Insert error: %@", error);

				XCTAssert((error==nil), @"No error");

				XCTAssert([[db lastInsertRowID] isEqual:@(3)], @"Insert Row ID is 3");

				[expectCallback4 fulfill];
			}]];

			[db executeQuery:[OCSQLiteQuery query:@"SELECT *, ROWID FROM t1 WHERE a=$hello and b=:world" withNamedParameters:@{ @"hello" : @"Hallo", @"world" : @"Welt" } resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
				NSUInteger returnedRows;

				returnedRows = [resultSet iterateUsing:^(OCSQLiteResultSet *resultSet, NSUInteger line, NSDictionary<NSString *,id<NSObject>> *rowDictionary, BOOL *stop) {
					OCLog(@"Line(I) %lu: %@", (unsigned long)line, rowDictionary);
				} error:NULL];

				XCTAssert((returnedRows==1), @"Returned 1 row");

				XCTAssert((error==nil), @"No error");

				[expectCallback5 fulfill];
			}]];

			[db executeQuery:[OCSQLiteQuery query:@"SELECT *, ROWID FROM t1" withNamedParameters:nil resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
				NSUInteger returnedRows;

				returnedRows = [resultSet iterateUsing:^(OCSQLiteResultSet *resultSet, NSUInteger line, NSDictionary<NSString *,id<NSObject>> *rowDictionary, BOOL *stop) {
					OCLog(@"Line(II) %lu: %@", (unsigned long)line, rowDictionary);
				} error:NULL];

				XCTAssert((returnedRows==3), @"Returned 3 rows");

				XCTAssert((error==nil), @"No error");

				[expectCallback6 fulfill];
			}]];
		}];
	}

	[self waitForExpectationsWithTimeout:5 handler:NULL];

	OCSyncExec(waitSQL, {
		[sqlDB closeWithCompletionHandler:^(OCSQLiteDB *db, NSError *error) {
			OCSyncExecDone(waitSQL);
		}];
	});
}

- (void)testSQLiteTransactionsWithQueries
{
	XCTestExpectation *expectCallback1 = [self expectationWithDescription:@"Expect receiving callback"];
	XCTestExpectation *expectCallback2 = [self expectationWithDescription:@"Expect receiving callback"];
	XCTestExpectation *expectCallback3 = [self expectationWithDescription:@"Expect receiving callback"];
	OCSQLiteDB *sqlDB;

	if ((sqlDB = [OCSQLiteDB new]) != nil)
	{
		[sqlDB openWithFlags:OCSQLiteOpenFlagsDefault completionHandler:^(OCSQLiteDB *db, NSError *error) {
			[db executeTransaction:[OCSQLiteTransaction transactionWithQueries:@[
				[OCSQLiteQuery query:@"CREATE TABLE t1(a, b PRIMARY KEY)" resultHandler:nil],
				[OCSQLiteQuery query:@"INSERT INTO t1 (a,b) VALUES (:hello, :world)" withNamedParameters:@{ @"hello" : @"Hallo", @"world" : @"Welt" } resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
					XCTAssert([[db lastInsertRowID] isEqual:@(1)], @"Insert Row ID is 1");
				}],
				[OCSQLiteQuery query:@"INSERT INTO t1 (a,b) VALUES (:hello, :world)" withNamedParameters:@{ @"hello" : @"Bonjour", @"world" : @"Monde" } resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
					XCTAssert([[db lastInsertRowID] isEqual:@(2)], @"Insert Row ID is 2");
				}],
				[OCSQLiteQuery query:@"INSERT INTO t1 (a,b) VALUES (:hello, :world)" withNamedParameters:@{ @"hello" : @"¡Hola!", @"world" : @"el mundo" } resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
					XCTAssert([[db lastInsertRowID] isEqual:@(3)], @"Insert Row ID is 3");
				}],
			] type:OCSQLiteTransactionTypeDeferred completionHandler:^(OCSQLiteDB *db, OCSQLiteTransaction *transaction, NSError *error) {
				OCLog(@"Transaction finished with %@", error);

				XCTAssert((error==nil), @"No error");

				[expectCallback1 fulfill];
			}]];

			[db executeQuery:[OCSQLiteQuery query:@"SELECT ROWID, * FROM t1 WHERE a=$hello and b=:world" withNamedParameters:@{ @"hello" : @"Hallo", @"world" : @"Welt" } resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
				NSUInteger returnedRows;

				returnedRows = [resultSet iterateUsing:^(OCSQLiteResultSet *resultSet, NSUInteger line, NSDictionary<NSString *,id<NSObject>> *rowDictionary, BOOL *stop) {
					OCLog(@"Line(I) %lu: %@", (unsigned long)line, rowDictionary);
				} error:NULL];

				XCTAssert((returnedRows==1), @"Returned 1 row");

				XCTAssert((error==nil), @"No error");

				[expectCallback2 fulfill];
			}]];

			[db executeQuery:[OCSQLiteQuery query:@"SELECT ROWID, * FROM t1" withNamedParameters:nil resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
				NSUInteger returnedRows;

				returnedRows = [resultSet iterateUsing:^(OCSQLiteResultSet *resultSet, NSUInteger line, NSDictionary<NSString *,id<NSObject>> *rowDictionary, BOOL *stop) {
					OCLog(@"Line(II) %lu: %@", (unsigned long)line, rowDictionary);
				} error:NULL];

				XCTAssert((returnedRows==3), @"Returned 3 rows");

				XCTAssert((error==nil), @"No error");

				[expectCallback3 fulfill];
			}]];
		}];
	}

	[self waitForExpectationsWithTimeout:5 handler:NULL];

	OCSyncExec(waitSQL, {
		[sqlDB closeWithCompletionHandler:^(OCSQLiteDB *db, NSError *error) {
			OCSyncExecDone(waitSQL);
		}];
	});
}

- (void)testSQLiteTransactionsWithBlocks
{
	XCTestExpectation *expectCallback1 = [self expectationWithDescription:@"Expect receiving callback"];
	XCTestExpectation *expectCallback2 = [self expectationWithDescription:@"Expect receiving callback"];
	XCTestExpectation *expectCallback3 = [self expectationWithDescription:@"Expect receiving callback"];
	OCSQLiteDB *sqlDB;

	if ((sqlDB = [OCSQLiteDB new]) != nil)
	{
		[sqlDB openWithFlags:OCSQLiteOpenFlagsDefault completionHandler:^(OCSQLiteDB *db, NSError *error) {
			[db executeTransaction:[OCSQLiteTransaction transactionWithBlock:^NSError *(OCSQLiteDB *db, OCSQLiteTransaction *transaction) {
				[db executeQuery:[OCSQLiteQuery query:@"CREATE TABLE t1(a, b PRIMARY KEY)" resultHandler:nil]];

				[db executeQuery:[OCSQLiteQuery query:@"INSERT INTO t1 (a,b) VALUES (:hello, :world)" withNamedParameters:@{ @"hello" : @"Hallo", @"world" : @"Welt" } resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
					XCTAssert([[db lastInsertRowID] isEqual:@(1)], @"Insert Row ID is 1");
				}]];

				[db executeQuery:[OCSQLiteQuery query:@"INSERT INTO t1 (a,b) VALUES (:hello, :world)" withNamedParameters:@{ @"hello" : @"Bonjour", @"world" : @"Monde" } resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
					XCTAssert([[db lastInsertRowID] isEqual:@(2)], @"Insert Row ID is 2");
				}]];

				[db executeQuery:[OCSQLiteQuery query:@"INSERT INTO t1 (a,b) VALUES (:hello, :world)" withNamedParameters:@{ @"hello" : @"¡Hola!", @"world" : @"el mundo" } resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
					XCTAssert([[db lastInsertRowID] isEqual:@(3)], @"Insert Row ID is 3");
				}]];

				return (nil);
			} type:OCSQLiteTransactionTypeDeferred completionHandler:^(OCSQLiteDB *db, OCSQLiteTransaction *transaction, NSError *error) {
				OCLog(@"Transaction finished with %@", error);

				XCTAssert((error==nil), @"No error");

				[expectCallback1 fulfill];
			}]];

			[db executeQuery:[OCSQLiteQuery query:@"SELECT ROWID, * FROM t1 WHERE a=$hello and b=:world" withNamedParameters:@{ @"hello" : @"Hallo", @"world" : @"Welt" } resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
				NSUInteger returnedRows;

				returnedRows = [resultSet iterateUsing:^(OCSQLiteResultSet *resultSet, NSUInteger line, NSDictionary<NSString *,id<NSObject>> *rowDictionary, BOOL *stop) {
					OCLog(@"Line(I) %lu: %@", (unsigned long)line, rowDictionary);
				} error:NULL];

				XCTAssert((returnedRows==1), @"Returned 1 row");

				XCTAssert((error==nil), @"No error");

				[expectCallback2 fulfill];
			}]];

			[db executeQuery:[OCSQLiteQuery query:@"SELECT ROWID, * FROM t1" withNamedParameters:nil resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
				NSUInteger returnedRows;

				returnedRows = [resultSet iterateUsing:^(OCSQLiteResultSet *resultSet, NSUInteger line, NSDictionary<NSString *,id<NSObject>> *rowDictionary, BOOL *stop) {
					OCLog(@"Line(II) %lu: %@", (unsigned long)line, rowDictionary);
				} error:NULL];

				XCTAssert((returnedRows==3), @"Returned 3 rows");

				XCTAssert((error==nil), @"No error");

				[expectCallback3 fulfill];
			}]];
		}];
	}

	[self waitForExpectationsWithTimeout:5 handler:NULL];

	OCSyncExec(waitSQL, {
		[sqlDB closeWithCompletionHandler:^(OCSQLiteDB *db, NSError *error) {
			OCSyncExecDone(waitSQL);
		}];
	});
}

// TODO: Add tests for nested transactions

- (void)testSQLiteDateConversions
{
	XCTestExpectation *expectCallback = [self expectationWithDescription:@"Expect receiving callback"];
	OCSQLiteDB *sqlDB;

	if ((sqlDB = [OCSQLiteDB new]) != nil)
	{
		[sqlDB openWithFlags:OCSQLiteOpenFlagsDefault completionHandler:^(OCSQLiteDB *db, NSError *error) {
			NSDate *dateYesterday = [NSDate dateWithTimeIntervalSinceNow:-60*60*24];
			// NSDate *dateYesterday = [NSDate dateWithTimeIntervalSinceReferenceDate:((UInt64)[NSDate timeIntervalSinceReferenceDate]-60*60*24)]; // Make sure date doesn't use any subseconds

			[db executeTransaction:[OCSQLiteTransaction transactionWithQueries:@[
				[OCSQLiteQuery query:@"CREATE TABLE t1(modifiedDate REAL, name PRIMARY KEY)" resultHandler:nil],
				[OCSQLiteQuery query:@"INSERT INTO t1 (modifiedDate,name) VALUES (:modifiedDate, :name)" withNamedParameters:@{ @"modifiedDate" : dateYesterday, @"name" : @"24 hours ago" } resultHandler:nil],
			] type:OCSQLiteTransactionTypeDeferred completionHandler:^(OCSQLiteDB *db, OCSQLiteTransaction *transaction, NSError *error) {
				OCLog(@"Transaction finished with %@", error);
			}]];

			[db executeQuery:[OCSQLiteQuery query:@"SELECT * FROM t1" resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
				[resultSet iterateUsing:^(OCSQLiteResultSet *resultSet, NSUInteger line, NSDictionary<NSString *,id<NSObject>> *rowDictionary, BOOL *stop) {
					OCLog(@"Line %lu: %@", (unsigned long)line, rowDictionary);

					OCLog(@"Date recovered from database: %f (vs %f)", ((NSDate *)rowDictionary[@"modifiedDate"]).timeIntervalSinceReferenceDate, dateYesterday.timeIntervalSinceReferenceDate);

					XCTAssert((fabs([((NSDate *)rowDictionary[@"modifiedDate"]) timeIntervalSinceDate:dateYesterday]) < 0.001), @"Date recovered from database");

					[expectCallback fulfill];
				} error:NULL];
			}]];
		}];
	}

	[self waitForExpectationsWithTimeout:5 handler:NULL];

	OCSyncExec(waitSQL, {
		[sqlDB closeWithCompletionHandler:^(OCSQLiteDB *db, NSError *error) {
			OCSyncExecDone(waitSQL);
		}];
	});
}

- (void)testSQLiteQueryConstructionInsert
{
	OCSQLiteDB *sqlDB;
	XCTestExpectation *expectCallback = [self expectationWithDescription:@"Expect receiving callback"];
	XCTestExpectation *expectTwoRows = [self expectationWithDescription:@"Expect two rows"];

	if ((sqlDB = [OCSQLiteDB new]) != nil)
	{
		[sqlDB openWithFlags:OCSQLiteOpenFlagsDefault completionHandler:^(OCSQLiteDB *db, NSError *error) {
			[db executeTransaction:[OCSQLiteTransaction transactionWithQueries:@[
				[OCSQLiteQuery query:@"CREATE TABLE t1(number REAL, name PRIMARY KEY)" resultHandler:nil],
				[OCSQLiteQuery queryInsertingIntoTable:@"t1" rowValues:@{
					@"number" : @(1.23),
					@"name" : @"one dot two three"
				} resultHandler:^(OCSQLiteDB *db, NSError *error, NSNumber *rowID) {
					OCLog(@"Inserted row with ID: %@", rowID);
					XCTAssert(rowID.integerValue==1, @"Row ID is 1");
				}],
				[OCSQLiteQuery queryInsertingIntoTable:@"t1" rowValues:@{
					@"number" : @(2.34),
					@"name" : @"two dot three four"
				} resultHandler:^(OCSQLiteDB *db, NSError *error, NSNumber *rowID) {
					OCLog(@"Inserted row with ID: %@", rowID);
					XCTAssert(rowID.integerValue==2, @"Row ID is 2");
				}]
			] type:OCSQLiteTransactionTypeDeferred completionHandler:^(OCSQLiteDB *db, OCSQLiteTransaction *transaction, NSError *error) {
				OCLog(@"Transaction finished with %@", error);

				[db executeQuery:[OCSQLiteQuery query:@"SELECT * FROM t1" resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
					[resultSet iterateUsing:^(OCSQLiteResultSet *resultSet, NSUInteger line, NSDictionary<NSString *,id<NSObject>> *rowDictionary, BOOL *stop) {
						OCLog(@"Line %lu: %@", (unsigned long)line, rowDictionary);

						if (line == 1) { [expectTwoRows fulfill]; }
					} error:NULL];
				}]];

				XCTAssert((error==nil), @"Transaction finished without errors");

				[expectCallback fulfill];
			}]];
		}];
	}

	[self waitForExpectationsWithTimeout:5 handler:NULL];

	OCSyncExec(waitSQL, {
		[sqlDB closeWithCompletionHandler:^(OCSQLiteDB *db, NSError *error) {
			OCSyncExecDone(waitSQL);
		}];
	});
}

- (void)testSQLiteQueryConstructionInsertAndUpdate
{
	OCSQLiteDB *sqlDB;
	XCTestExpectation *expectCallback = [self expectationWithDescription:@"Expect receiving callback"];
	XCTestExpectation *expectTwoRows = [self expectationWithDescription:@"Expect two rows"];

	if ((sqlDB = [OCSQLiteDB new]) != nil)
	{
		[sqlDB openWithFlags:OCSQLiteOpenFlagsDefault completionHandler:^(OCSQLiteDB *db, NSError *error) {
			[db executeTransaction:[OCSQLiteTransaction transactionWithQueries:@[
				[OCSQLiteQuery query:@"CREATE TABLE t1(number REAL, name PRIMARY KEY)" resultHandler:nil],

				// Insert row 1
				[OCSQLiteQuery queryInsertingIntoTable:@"t1" rowValues:@{
					@"number" : @(1),
					@"name" : @"one"
				} resultHandler:^(OCSQLiteDB *db, NSError *error, NSNumber *rowID) {
					OCLog(@"Inserted row with ID: %@", rowID);
					XCTAssert(rowID.integerValue==1, @"Row ID is 1");
				}],

				// Insert row 2
				[OCSQLiteQuery queryInsertingIntoTable:@"t1" rowValues:@{
					@"number" : @(2),
					@"name" : @"two"
				} resultHandler:^(OCSQLiteDB *db, NSError *error, NSNumber *rowID) {
					OCLog(@"Inserted row with ID: %@", rowID);
					XCTAssert(rowID.integerValue==2, @"Row ID is 2");
				}],

				// Update row 2 (by value of "number" column)
				[OCSQLiteQuery queryUpdatingRowsWhere:@{
					@"number" : @(2)
				} inTable:@"t1" withRowValues:@{
					@"name" : @"_TWO_"
				} completionHandler:^(OCSQLiteDB *db, NSError *error) {
					OCLog(@"Updated row with error: %@", error);
				}],

				// Update row 1 (by row ID)
				[OCSQLiteQuery queryUpdatingRowWithID:@(1) inTable:@"t1" withRowValues:@{
					@"name" : @"One"
				} completionHandler:^(OCSQLiteDB *db, NSError *error) {
					OCLog(@"Updated row with error: %@", error);
				}],
			] type:OCSQLiteTransactionTypeDeferred completionHandler:^(OCSQLiteDB *db, OCSQLiteTransaction *transaction, NSError *error) {
				OCLog(@"Transaction finished with %@", error);

				[db executeQuery:[OCSQLiteQuery query:@"SELECT * FROM t1" resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
					[resultSet iterateUsing:^(OCSQLiteResultSet *resultSet, NSUInteger line, NSDictionary<NSString *,id<NSObject>> *rowDictionary, BOOL *stop) {

						OCLog(@"Line %lu: %@", (unsigned long)line, rowDictionary);

						switch (line)
						{
							case 0:
								XCTAssert([rowDictionary[@"name"] isEqual:@"One"], @"Expected value");
								XCTAssert([rowDictionary[@"number"] isEqual:@(1)], @"Expected value");
							break;

							case 1:
								XCTAssert([rowDictionary[@"name"] isEqual:@"_TWO_"], @"Expected value");
								XCTAssert([rowDictionary[@"number"] isEqual:@(2)], @"Expected value");

								[expectTwoRows fulfill];
							break;
						}
					} error:NULL];
				}]];

				XCTAssert((error==nil), @"Transaction finished without errors");

				[expectCallback fulfill];
			}]];
		}];
	}

	[self waitForExpectationsWithTimeout:5 handler:NULL];

	OCSyncExec(waitSQL, {
		[sqlDB closeWithCompletionHandler:^(OCSQLiteDB *db, NSError *error) {
			OCSyncExecDone(waitSQL);
		}];
	});
}

- (void)testSQLiteQueryConstructionInsertAndDelete
{
	OCSQLiteDB *sqlDB;
	XCTestExpectation *expectCallback = [self expectationWithDescription:@"Expect receiving callback"];
	XCTestExpectation *expectTwoRows = [self expectationWithDescription:@"Expect two rows"];

	if ((sqlDB = [OCSQLiteDB new]) != nil)
	{
		[sqlDB openWithFlags:OCSQLiteOpenFlagsDefault completionHandler:^(OCSQLiteDB *db, NSError *error) {
			[db executeTransaction:[OCSQLiteTransaction transactionWithQueries:@[
				[OCSQLiteQuery query:@"CREATE TABLE t1(number REAL, name PRIMARY KEY)" resultHandler:nil],
				[OCSQLiteQuery queryInsertingIntoTable:@"t1" rowValues:@{
					@"number" : @(1),
					@"name" : @"one"
				} resultHandler:^(OCSQLiteDB *db, NSError *error, NSNumber *rowID) {
					OCLog(@"Inserted row with ID: %@", rowID);
					XCTAssert(rowID.integerValue==1, @"Row ID is 1");
				}],
				[OCSQLiteQuery queryInsertingIntoTable:@"t1" rowValues:@{
					@"number" : @(2),
					@"name" : @"two"
				} resultHandler:^(OCSQLiteDB *db, NSError *error, NSNumber *rowID) {
					OCLog(@"Inserted row with ID: %@", rowID);
					XCTAssert(rowID.integerValue==2, @"Row ID is 2");
				}],
				[OCSQLiteQuery queryInsertingIntoTable:@"t1" rowValues:@{
					@"number" : @(3),
					@"name" : @"three"
				} resultHandler:^(OCSQLiteDB *db, NSError *error, NSNumber *rowID) {
					OCLog(@"Inserted row with ID: %@", rowID);
					XCTAssert(rowID.integerValue==3, @"Row ID is 3");
				}],
				[OCSQLiteQuery queryInsertingIntoTable:@"t1" rowValues:@{
					@"number" : @(4),
					@"name" : @"four"
				} resultHandler:^(OCSQLiteDB *db, NSError *error, NSNumber *rowID) {
					OCLog(@"Inserted row with ID: %@", rowID);
					XCTAssert(rowID.integerValue==4, @"Row ID is 4");
				}],
				[OCSQLiteQuery queryDeletingRowWithID:@(2) fromTable:@"t1" completionHandler:^(OCSQLiteDB *db, NSError *error) {
					OCLog(@"Deleted row with error: %@", error);
					XCTAssert(error==nil, @"No error deleting row");
				}],
				[OCSQLiteQuery queryDeletingRowsWhere:@{ @"number" : @(4) } fromTable:@"t1" completionHandler:^(OCSQLiteDB *db, NSError *error) {
					OCLog(@"Deleted row with error: %@", error);
					XCTAssert(error==nil, @"No error deleting row");
				}]
			] type:OCSQLiteTransactionTypeDeferred completionHandler:^(OCSQLiteDB *db, OCSQLiteTransaction *transaction, NSError *error) {
				OCLog(@"Transaction finished with %@", error);

				[db executeQuery:[OCSQLiteQuery query:@"SELECT * FROM t1" resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
					[resultSet iterateUsing:^(OCSQLiteResultSet *resultSet, NSUInteger line, NSDictionary<NSString *,id<NSObject>> *rowDictionary, BOOL *stop) {
						OCLog(@"Line %lu: %@", (unsigned long)line, rowDictionary);

						if (line == 1)
						{
							XCTAssert([rowDictionary[@"number"] isEqual:@(3)], @"Second row is number=3, confirming the deletion of row 2");
							[expectTwoRows fulfill];
						}

						XCTAssert((line<2), @"2 lines maxium");
					} error:NULL];
				}]];

				XCTAssert((error==nil), @"Transaction finished without errors");

				[expectCallback fulfill];
			}]];
		}];
	}

	[self waitForExpectationsWithTimeout:5 handler:NULL];

	OCSyncExec(waitSQL, {
		[sqlDB closeWithCompletionHandler:^(OCSQLiteDB *db, NSError *error) {
			OCSyncExecDone(waitSQL);
		}];
	});
}

- (void)testSQLiteQueryConstructionInsertAndSelect
{
	OCSQLiteDB *sqlDB;
	XCTestExpectation *expectCallback = [self expectationWithDescription:@"Expect receiving callback"];
	XCTestExpectation *expectResult1 = [self expectationWithDescription:@"Expected result 1"];
	XCTestExpectation *expectResult2 = [self expectationWithDescription:@"Expected result 2"];

	if ((sqlDB = [OCSQLiteDB new]) != nil)
	{
		[sqlDB openWithFlags:OCSQLiteOpenFlagsDefault completionHandler:^(OCSQLiteDB *db, NSError *error) {
			[db executeTransaction:[OCSQLiteTransaction transactionWithQueries:@[
				[OCSQLiteQuery query:@"CREATE TABLE t1(number REAL, name PRIMARY KEY)" resultHandler:nil],
				[OCSQLiteQuery queryInsertingIntoTable:@"t1" rowValues:@{
					@"number" : @(1),
					@"name" : @"one"
				} resultHandler:^(OCSQLiteDB *db, NSError *error, NSNumber *rowID) {
					OCLog(@"Inserted row with ID: %@", rowID);
					XCTAssert(rowID.integerValue==1, @"Row ID is 1");
				}],
				[OCSQLiteQuery queryInsertingIntoTable:@"t1" rowValues:@{
					@"number" : @(2),
					@"name" : @"two"
				} resultHandler:^(OCSQLiteDB *db, NSError *error, NSNumber *rowID) {
					OCLog(@"Inserted row with ID: %@", rowID);
					XCTAssert(rowID.integerValue==2, @"Row ID is 2");
				}],
				[OCSQLiteQuery queryInsertingIntoTable:@"t1" rowValues:@{
					@"number" : @(3),
					@"name" : @"three"
				} resultHandler:^(OCSQLiteDB *db, NSError *error, NSNumber *rowID) {
					OCLog(@"Inserted row with ID: %@", rowID);
					XCTAssert(rowID.integerValue==3, @"Row ID is 3");
				}],
				[OCSQLiteQuery queryInsertingIntoTable:@"t1" rowValues:@{
					@"number" : @(4),
					@"name" : @"four"
				} resultHandler:^(OCSQLiteDB *db, NSError *error, NSNumber *rowID) {
					OCLog(@"Inserted row with ID: %@", rowID);
					XCTAssert(rowID.integerValue==4, @"Row ID is 4");
				}],
				[OCSQLiteQuery querySelectingColumns:@[@"name"] fromTable:@"t1" where:@{ @"number" : @(4) } resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
					[resultSet iterateUsing:^(OCSQLiteResultSet *resultSet, NSUInteger line, NSDictionary<NSString *,id<NSObject>> *rowDictionary, BOOL *stop) {
						if ((line==0) && (rowDictionary.count==1) && ([rowDictionary[@"name"] isEqual:@"four"]))
						{
							[expectResult1 fulfill];
						}
					} error:nil];
				}],
				[OCSQLiteQuery querySelectingColumns:@[@"number", @"name"] fromTable:@"t1" where:@{ @"number" : @(3) } resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
					[resultSet iterateUsing:^(OCSQLiteResultSet *resultSet, NSUInteger line, NSDictionary<NSString *,id<NSObject>> *rowDictionary, BOOL *stop) {
						if ((line==0) && (rowDictionary.count==2) && ([rowDictionary[@"name"] isEqual:@"three"]) && ([rowDictionary[@"number"] isEqual:@(3)]))
						{
							[expectResult2 fulfill];
						}
					} error:nil];
				}]
			] type:OCSQLiteTransactionTypeDeferred completionHandler:^(OCSQLiteDB *db, OCSQLiteTransaction *transaction, NSError *error) {
				OCLog(@"Transaction finished with %@", error);

				XCTAssert((error==nil), @"Transaction finished without errors");

				[expectCallback fulfill];
			}]];
		}];
	}

	[self waitForExpectationsWithTimeout:5 handler:NULL];

	OCSyncExec(waitSQL, {
		[sqlDB closeWithCompletionHandler:^(OCSQLiteDB *db, NSError *error) {
			OCSyncExecDone(waitSQL);
		}];
	});
}

- (void)testSQLiteTableUpgrade
{
	XCTestExpectation *expectSchemaCallback1 = [self expectationWithDescription:@"Expect receiving schema callback 1"];
	XCTestExpectation *expectSchemaCallback2 = [self expectationWithDescription:@"Expect receiving schema callback 2"];
	XCTestExpectation *expectMatchingDefinition = [self expectationWithDescription:@"Expect definition to match"];
	XCTestExpectation *expectMigrationCallback = [self expectationWithDescription:@"Expect receiving migration callback"];
	OCSQLiteDB *sqlDB;

	if ((sqlDB = [OCSQLiteDB new]) != nil)
	{
		// Version 1
		[sqlDB addTableSchema:[OCSQLiteTableSchema schemaWithTableName:@"products" version:1 creationQueries:@[@"CREATE TABLE IF NOT EXISTS products (productID integer PRIMARY KEY, name TEXT NOT NULL)"] openStatements:nil upgradeMigrator:nil]];

		[sqlDB openWithFlags:OCSQLiteOpenFlagsDefault completionHandler:^(OCSQLiteDB *db, NSError *error) {
			[sqlDB applyTableSchemasWithCompletionHandler:^(OCSQLiteDB *db, NSError *error) {
				XCTAssert((error==nil), @"Creation succeeded without errors");
				[expectSchemaCallback1 fulfill];

				// Version 2
				[sqlDB addTableSchema:[OCSQLiteTableSchema schemaWithTableName:@"products" version:2 creationQueries:@[@"CREATE TABLE IF NOT EXISTS products (productID integer PRIMARY KEY, name TEXT NOT NULL, version TEXT)"] openStatements:nil upgradeMigrator:^(OCSQLiteDB *db, OCSQLiteTableSchema *schema, void (^completionHandler)(NSError *error)) {
					[expectMigrationCallback fulfill];

					// Migrate to version 2
					[db executeQuery:[OCSQLiteQuery query:@"ALTER TABLE products ADD COLUMN version TEXT" resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
						completionHandler(error);
					}]];
				}]];

				[sqlDB applyTableSchemasWithCompletionHandler:^(OCSQLiteDB *db, NSError *error) {
					XCTAssert((error==nil), @"Migration succeeded without errors");
					[expectSchemaCallback2 fulfill];

					// Verify table structure
					[sqlDB executeQuery:[OCSQLiteQuery query:@"SELECT sql FROM sqlite_master WHERE name=\"products\"" resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
						[resultSet iterateUsing:^(OCSQLiteResultSet *resultSet, NSUInteger line, NSDictionary<NSString *,id<NSObject>> *rowDictionary, BOOL *stop) {
							if ([rowDictionary[@"sql"] isEqual:@"CREATE TABLE products (productID integer PRIMARY KEY, name TEXT NOT NULL, version TEXT)"])
							{
								[expectMatchingDefinition fulfill];
							}

							OCLog(@"%@", rowDictionary);
						} error:nil];
					}]];
				}];
			}];
		}];
	}

	[self waitForExpectationsWithTimeout:5 handler:NULL];

	OCSyncExec(waitSQL, {
		[sqlDB closeWithCompletionHandler:^(OCSQLiteDB *db, NSError *error) {
			OCSyncExecDone(waitSQL);
		}];
	});
}

- (void)testSQLiteTableCreation
{
	XCTestExpectation *expectSchemaCallback1 = [self expectationWithDescription:@"Expect receiving schema callback 1"];
	XCTestExpectation *expectSchemaCallback2 = [self expectationWithDescription:@"Expect receiving schema callback 2"];
	XCTestExpectation *expectMatchingDefinition = [self expectationWithDescription:@"Expect definition to match"];
	OCSQLiteDB *sqlDB;

	if ((sqlDB = [OCSQLiteDB new]) != nil)
	{
		// Version 1
		[sqlDB addTableSchema:[OCSQLiteTableSchema schemaWithTableName:@"products" version:1 creationQueries:@[@"CREATE TABLE IF NOT EXISTS products (productID integer PRIMARY KEY, name TEXT NOT NULL)"] openStatements:nil upgradeMigrator:nil]];

		// Version 2
		[sqlDB addTableSchema:[OCSQLiteTableSchema schemaWithTableName:@"products" version:2 creationQueries:@[@"CREATE TABLE IF NOT EXISTS products (productID integer PRIMARY KEY, name TEXT NOT NULL, version TEXT)"] openStatements:nil upgradeMigrator:^(OCSQLiteDB *db, OCSQLiteTableSchema *schema, void (^completionHandler)(NSError *error)) {
			XCTFail(@"Migration shouldn't be called. Instead, the table should be created using the creation queries right away");

			// Migrate to version 2
			[db executeQuery:[OCSQLiteQuery query:@"ALTER TABLE products ADD COLUMN version TEXT" resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
				completionHandler(error);
			}]];
		}]];

		[sqlDB openWithFlags:OCSQLiteOpenFlagsDefault completionHandler:^(OCSQLiteDB *db, NSError *error) {
			[sqlDB applyTableSchemasWithCompletionHandler:^(OCSQLiteDB *db, NSError *error) {
				[expectSchemaCallback1 fulfill];

				[sqlDB applyTableSchemasWithCompletionHandler:^(OCSQLiteDB *db, NSError *error) {
					[expectSchemaCallback2 fulfill];

					// Verify table structure
					[sqlDB executeQuery:[OCSQLiteQuery query:@"SELECT sql FROM sqlite_master WHERE name=\"products\"" resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
						[resultSet iterateUsing:^(OCSQLiteResultSet *resultSet, NSUInteger line, NSDictionary<NSString *,id<NSObject>> *rowDictionary, BOOL *stop) {
							if ([rowDictionary[@"sql"] isEqual:@"CREATE TABLE products (productID integer PRIMARY KEY, name TEXT NOT NULL, version TEXT)"])
							{
								[expectMatchingDefinition fulfill];
							}

							OCLog(@"%@", rowDictionary);
						} error:nil];
					}]];
				}];
			}];
		}];
	}

	[self waitForExpectationsWithTimeout:5 handler:NULL];

	OCSyncExec(waitSQL, {
		[sqlDB closeWithCompletionHandler:^(OCSQLiteDB *db, NSError *error) {
			OCSyncExecDone(waitSQL);
		}];
	});
}

@end
