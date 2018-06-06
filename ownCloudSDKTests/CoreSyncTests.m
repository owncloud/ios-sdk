//
//  CoreSyncTests.m
//  ownCloudSDKTests
//
//  Created by Felix Schwarz on 06.06.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <ownCloudSDK/ownCloudSDK.h>
#import "OCHostSimulator.h"
#import "OCCore+Internal.h"

@interface CoreSyncTests : XCTestCase

@end

@implementation CoreSyncTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)dumpMetaDataTableFromCore:(OCCore *)core withDescription:(NSString *)description rowHook:(void(^)(NSUInteger line, NSDictionary<NSString *,id<NSObject>> *rowDictionary))rowHook completionHandler:(dispatch_block_t)completionHandler
{
	[core.vault.database.sqlDB executeQuery:[OCSQLiteQuery query:[@"SELECT * FROM " stringByAppendingString:OCDatabaseTableNameMetaData] resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
		NSLog(@"### %@", description);
		[resultSet iterateUsing:^(OCSQLiteResultSet *resultSet, NSUInteger line, NSDictionary<NSString *,id<NSObject>> *rowDictionary, BOOL *stop) {
			NSLog(@"%lu: %@ -- %@ -- %@ -- %@", (unsigned long)line, rowDictionary[@"mdID"], rowDictionary[@"syncAnchor"], rowDictionary[@"path"], rowDictionary[@"name"]);

			if (rowHook != nil)
			{
				rowHook(line, rowDictionary);
			}
		} error:nil];

		if (completionHandler != nil) {
			completionHandler();
		}
	}]];
}

- (void)testSyncAnchorIncreaseOnETagChange
{
	OCBookmark *bookmark = nil;
	OCCore *core;
	__block BOOL didTamper = NO;
	XCTestExpectation *coreStartedExpectation = [self expectationWithDescription:@"Core started"];
	XCTestExpectation *coreStoppedExpectation = [self expectationWithDescription:@"Core stopped"];

	// Create bookmark for demo.owncloud.org
	bookmark = [OCBookmark bookmarkForURL:[NSURL URLWithString:@"https://demo.owncloud.org/"]];
	bookmark.authenticationData = [OCAuthenticationMethodBasicAuth authenticationDataForUsername:@"demo" passphrase:@"demo" authenticationHeaderValue:NULL error:NULL];
	bookmark.authenticationMethodIdentifier = OCAuthenticationMethodBasicAuthIdentifier;

	// Create core with it
	core = [[OCCore alloc] initWithBookmark:bookmark];

	// Start core
	[core startWithCompletionHandler:^(OCCore *core, NSError *error) {
		OCQuery *query;

		XCTAssert((error==nil), @"Started with error: %@", error);
		[coreStartedExpectation fulfill];

		NSLog(@"Vault location: %@", core.vault.rootURL);

		query = [OCQuery queryForPath:@"/"];
		query.changesAvailableNotificationHandler = ^(OCQuery *query) {
			[query requestChangeSetWithFlags:OCQueryChangeSetRequestFlagDefault completionHandler:^(OCQuery *query, OCQueryChangeSet *changeset) {
				if (changeset != nil)
				{
					NSLog(@"============================================");
					NSLog(@"[%@] QUERY STATE: %lu", query.queryPath, (unsigned long)query.state);

					NSLog(@"[%@] Query result: %@", query.queryPath, changeset.queryResult);

					[changeset enumerateChangesUsingBlock:^(OCQueryChangeSet *changeSet, OCQueryChangeSetOperation operation, NSArray<OCItem *> *items, NSIndexSet *indexSet) {
						switch(operation)
						{
							case OCQueryChangeSetOperationInsert:
								NSLog(@"[%@] Insertions: %@", query.queryPath, items);
							break;

							case OCQueryChangeSetOperationRemove:
								NSLog(@"[%@] Removals: %@", query.queryPath, items);
							break;

							case OCQueryChangeSetOperationUpdate:
								NSLog(@"[%@] Updates: %@", query.queryPath, items);
							break;

							case OCQueryChangeSetOperationContentSwap:
								NSLog(@"[%@] Content Swap", query.queryPath);
							break;
						}
					}];
				}

				if (query.state == OCQueryStateIdle)
				{
					if (!didTamper)
					{
						didTamper = YES;

						[self dumpMetaDataTableFromCore:core withDescription:@"First complete retrieval:" rowHook:^(NSUInteger line, NSDictionary<NSString *,id<NSObject>> *rowDictionary) {
							XCTAssert([rowDictionary[@"syncAnchor"] isEqual:@(1)]);
						} completionHandler:^{
							// Modify eTag in database to make the next retrieved update look like a change and prompt a syncAnchor increase
							[core.vault.database retrieveCacheItemsAtPath:@"/" completionHandler:^(OCDatabase *db, NSError *error, NSArray<OCItem *> *items) {
								for (OCItem *item in items)
								{
									if ([item.path isEqual:@"/"])
									{
										item.eTag = [item.eTag substringToIndex:2];

										[core.vault.database updateCacheItems:@[ item ] syncAnchor:core.latestSyncAnchor completionHandler:^(OCDatabase *db, NSError *error) {
											[core reloadQuery:query];
										}];
										break;
									}
								}
							}];
						}];
					}
					else
					{
						[self dumpMetaDataTableFromCore:core withDescription:@"Second complete retrieval:"  rowHook:^(NSUInteger line, NSDictionary<NSString *,id<NSObject>> *rowDictionary) {
							if ([rowDictionary[@"path"] isEqual:@"/"])
							{
								XCTAssert([rowDictionary[@"syncAnchor"] isEqual:@(2)]);
							}
							else
							{
								XCTAssert([rowDictionary[@"syncAnchor"] isEqual:@(1)]);
							}
						} completionHandler:^{
							// Stop core
							[core stopWithCompletionHandler:^(id sender, NSError *error) {
								XCTAssert((error==nil), @"Stopped with error: %@", error);

								[coreStoppedExpectation fulfill];
							}];
						}];
					}
				}
			}];
		};

		[core startQuery:query];
	}];

	[self waitForExpectationsWithTimeout:60 handler:nil];

	NSLog(@"%@", [core.vault.databaseURL.absoluteString stringByDeletingLastPathComponent]);

	// Erase vault
	[core.vault eraseWithCompletionHandler:^(id sender, NSError *error) {
		XCTAssert((error==nil), @"Erased with error: %@", error);
	}];
}

@end
