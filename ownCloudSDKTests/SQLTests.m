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
				NSLog(@"Create table error: %@", error);

				XCTAssert((error==nil), @"No error");

				[expectCallback1 fulfill];
			}]];

			[db executeQuery:[OCSQLiteQuery query:@"INSERT INTO t1 (a,b) VALUES (:hello, :world)" withNamedParameters:@{ @"hello" : @"Hallo", @"world" : @"Welt" } resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
				NSLog(@"Insert error: %@", error);

				XCTAssert((error==nil), @"No error");

				[expectCallback2 fulfill];
			}]];

			[db executeQuery:[OCSQLiteQuery query:@"INSERT INTO t1 (a,b) VALUES (:hello, :world)" withNamedParameters:@{ @"hello" : @"Bonjour", @"world" : @"Monde" } resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
				NSLog(@"Insert error: %@", error);

				XCTAssert((error==nil), @"No error");

				[expectCallback3 fulfill];
			}]];

			[db executeQuery:[OCSQLiteQuery query:@"INSERT INTO t1 (a,b) VALUES (:hello, :world)" withNamedParameters:@{ @"hello" : @"¡Hola!", @"world" : @"el mundo" } resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
				NSLog(@"Insert error: %@", error);

				XCTAssert((error==nil), @"No error");

				[expectCallback4 fulfill];
			}]];

			[db executeQuery:[OCSQLiteQuery query:@"SELECT * FROM t1 WHERE a=$hello and b=:world" withNamedParameters:@{ @"hello" : @"Hallo", @"world" : @"Welt" } resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
				NSUInteger returnedRows;

				returnedRows = [resultSet iterateUsing:^(OCSQLiteResultSet *resultSet, NSUInteger line, NSDictionary<NSString *,id<NSObject>> *rowDictionary, BOOL *stop) {
					NSLog(@"Line(I) %lu: %@", (unsigned long)line, rowDictionary);
				} error:NULL];

				XCTAssert((returnedRows==1), @"Returned 1 row");

				XCTAssert((error==nil), @"No error");

				[expectCallback5 fulfill];
			}]];

			[db executeQuery:[OCSQLiteQuery query:@"SELECT * FROM t1" withNamedParameters:nil resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
				NSUInteger returnedRows;

				returnedRows = [resultSet iterateUsing:^(OCSQLiteResultSet *resultSet, NSUInteger line, NSDictionary<NSString *,id<NSObject>> *rowDictionary, BOOL *stop) {
					NSLog(@"Line(II) %lu: %@", (unsigned long)line, rowDictionary);
				} error:NULL];

				XCTAssert((returnedRows==3), @"Returned 3 rows");

				XCTAssert((error==nil), @"No error");

				[expectCallback6 fulfill];
			}]];
		}];
	}

	[self waitForExpectationsWithTimeout:5 handler:NULL];
}

- (void)testSQLiteTransactions
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
				[OCSQLiteQuery query:@"INSERT INTO t1 (a,b) VALUES (:hello, :world)" withNamedParameters:@{ @"hello" : @"Hallo", @"world" : @"Welt" } resultHandler:nil],
				[OCSQLiteQuery query:@"INSERT INTO t1 (a,b) VALUES (:hello, :world)" withNamedParameters:@{ @"hello" : @"Bonjour", @"world" : @"Monde" } resultHandler:nil],
				[OCSQLiteQuery query:@"INSERT INTO t1 (a,b) VALUES (:hello, :world)" withNamedParameters:@{ @"hello" : @"¡Hola!", @"world" : @"el mundo" } resultHandler:nil],
			] type:OCSQLiteTransactionTypeDeferred completionHandler:^(OCSQLiteDB *db, OCSQLiteTransaction *transaction, NSError *error) {
				NSLog(@"Transaction finished with %@", error);

				XCTAssert((error==nil), @"No error");

				[expectCallback1 fulfill];
			}]];

			[db executeQuery:[OCSQLiteQuery query:@"SELECT * FROM t1 WHERE a=$hello and b=:world" withNamedParameters:@{ @"hello" : @"Hallo", @"world" : @"Welt" } resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
				NSUInteger returnedRows;

				returnedRows = [resultSet iterateUsing:^(OCSQLiteResultSet *resultSet, NSUInteger line, NSDictionary<NSString *,id<NSObject>> *rowDictionary, BOOL *stop) {
					NSLog(@"Line(I) %lu: %@", (unsigned long)line, rowDictionary);
				} error:NULL];

				XCTAssert((returnedRows==1), @"Returned 1 row");

				XCTAssert((error==nil), @"No error");

				[expectCallback2 fulfill];
			}]];

			[db executeQuery:[OCSQLiteQuery query:@"SELECT * FROM t1" withNamedParameters:nil resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
				NSUInteger returnedRows;

				returnedRows = [resultSet iterateUsing:^(OCSQLiteResultSet *resultSet, NSUInteger line, NSDictionary<NSString *,id<NSObject>> *rowDictionary, BOOL *stop) {
					NSLog(@"Line(II) %lu: %@", (unsigned long)line, rowDictionary);
				} error:NULL];

				XCTAssert((returnedRows==3), @"Returned 3 rows");

				XCTAssert((error==nil), @"No error");

				[expectCallback3 fulfill];
			}]];
		}];
	}

	[self waitForExpectationsWithTimeout:5 handler:NULL];
}

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
				NSLog(@"Transaction finished with %@", error);
			}]];

			[db executeQuery:[OCSQLiteQuery query:@"SELECT * FROM t1" resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
				[resultSet iterateUsing:^(OCSQLiteResultSet *resultSet, NSUInteger line, NSDictionary<NSString *,id<NSObject>> *rowDictionary, BOOL *stop) {
					NSLog(@"Line %lu: %@", (unsigned long)line, rowDictionary);

					NSLog(@"Date recovered from database: %f (vs %f)", ((NSDate *)rowDictionary[@"modifiedDate"]).timeIntervalSinceReferenceDate, dateYesterday.timeIntervalSinceReferenceDate);

					XCTAssert((fabs([((NSDate *)rowDictionary[@"modifiedDate"]) timeIntervalSinceDate:dateYesterday]) < 0.001), @"Date recovered from database");

					[expectCallback fulfill];
				} error:NULL];
			}]];
		}];
	}

	[self waitForExpectationsWithTimeout:5 handler:NULL];
}

@end
