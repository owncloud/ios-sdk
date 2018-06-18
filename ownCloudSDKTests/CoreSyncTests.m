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
#import "TestTools.h"

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

	__block OCItem *firstRootItemReturnedBySyncAnchorQuery = nil, *secondRootItemReturnedBySyncAnchorQuery = nil;

	// Create bookmark for demo.owncloud.org
	bookmark = [OCBookmark bookmarkForURL:[NSURL URLWithString:@"https://demo.owncloud.org/"]];
	bookmark.authenticationData = [OCAuthenticationMethodBasicAuth authenticationDataForUsername:@"demo" passphrase:@"demo" authenticationHeaderValue:NULL error:NULL];
	bookmark.authenticationMethodIdentifier = OCAuthenticationMethodBasicAuthIdentifier;

	// Create core with it
	core = [[OCCore alloc] initWithBookmark:bookmark];

	// Start core
	[core startWithCompletionHandler:^(OCCore *core, NSError *error) {
		OCQuery *query;
		OCQuery *syncAnchorQuery;

		XCTAssert((error==nil), @"Started with error: %@", error);
		[coreStartedExpectation fulfill];

		NSLog(@"Vault location: %@", core.vault.rootURL);

		syncAnchorQuery = [OCQuery queryForChangesSinceSyncAnchor:@(0)];
		syncAnchorQuery.changesAvailableNotificationHandler = ^(OCQuery *query) {
			[query requestChangeSetWithFlags:OCQueryChangeSetRequestFlagDefault completionHandler:^(OCQuery *query, OCQueryChangeSet *changeset) {
				if (changeset != nil)
				{
					NSLog(@"#### ============================================");
					NSLog(@"#### [> %@] SYNC ANCHOR %@ QUERY STATE: %lu", query.querySinceSyncAnchor, changeset.syncAnchor, (unsigned long)query.state);

					NSLog(@"#### [> %@] Changes since: %@", query.querySinceSyncAnchor, changeset.queryResult);

					if (firstRootItemReturnedBySyncAnchorQuery == nil)
					{
						firstRootItemReturnedBySyncAnchorQuery = changeset.queryResult.firstObject;
					}
					else
					{
						secondRootItemReturnedBySyncAnchorQuery = changeset.queryResult.firstObject;
					}
 				}
			}];
		};

		[core startQuery:syncAnchorQuery];

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
							[core.vault.database retrieveCacheItemsAtPath:@"/" itemOnly:YES completionHandler:^(OCDatabase *db, NSError *error, OCSyncAnchor syncAnchor, NSArray<OCItem *> *items) {
								OCItem *item;

								XCTAssert(items.count == 1); // Check if itemOnly==YES works

								if ((item = items.firstObject) != nil)
								{
									if ([item.path isEqual:@"/"])
									{
										item.eTag = [item.eTag substringToIndex:2];

										[core.vault.database updateCacheItems:@[ item ] syncAnchor:core.latestSyncAnchor completionHandler:^(OCDatabase *db, NSError *error) {
											sleep(1);

											[core reloadQuery:query];
										}];
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

	// Erase vault
	[core.vault eraseSyncWithCompletionHandler:^(id sender, NSError *error) {
		XCTAssert((error==nil), @"Erased with error: %@", error);
	}];

	XCTAssert([firstRootItemReturnedBySyncAnchorQuery.path isEqual:@"/"]);
	XCTAssert([secondRootItemReturnedBySyncAnchorQuery.path isEqual:@"/"]);
	XCTAssert(firstRootItemReturnedBySyncAnchorQuery != secondRootItemReturnedBySyncAnchorQuery);
}

- (void)testDelete
{
	OCBookmark *bookmark = nil;
	OCCore *core;
	__block BOOL didCreateFolder = NO;
	XCTestExpectation *coreStartedExpectation = [self expectationWithDescription:@"Core started"];
	XCTestExpectation *coreStoppedExpectation = [self expectationWithDescription:@"Core stopped"];
	XCTestExpectation *dirCreatedExpectation = [self expectationWithDescription:@"Directory created"];
	XCTestExpectation *dirDeletedExpectation = [self expectationWithDescription:@"Directory deleted"];
	XCTestExpectation *dirCreationObservedExpectation = [self expectationWithDescription:@"Directory creation observed"];
	XCTestExpectation *dirDeletionObservedExpectation = [self expectationWithDescription:@"Directory deletion observed"];
	NSString *folderName = NSUUID.UUID.UUIDString;
	__block BOOL _dirCreationObserved = NO;

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
					if (!didCreateFolder)
					{
						didCreateFolder = YES;

						[core createFolder:folderName inside:query.rootItem options:nil resultHandler:^(NSError *error, OCCore *core, OCItem *item, id parameter) {
							XCTAssert(error==nil);
							XCTAssert(item!=nil);

							[core deleteItem:item requireMatch:YES resultHandler:^(NSError *error, OCCore *core, OCItem *item, id parameter) {
								NSLog(@"------> Delete item result: error=%@ item=%@ parameter=%@", error, item, parameter);

								XCTAssert(error==nil);
								XCTAssert(item!=nil);

								[dirDeletedExpectation fulfill];
							}];

							[dirCreatedExpectation fulfill];
						}];
					}
					else
					{
						if (!_dirCreationObserved)
						{
							for (OCItem *item in changeset.queryResult)
							{
								if ([item.name isEqualToString:folderName])
								{
									[dirCreationObservedExpectation fulfill];
									_dirCreationObserved = YES;
								}
							}
						}
						else
						{
							BOOL foundDir = NO;

							for (OCItem *item in changeset.queryResult)
							{
								if ([item.name isEqualToString:folderName])
								{
									foundDir = YES;
								}
							}

							if (!foundDir)
							{
								[dirDeletionObservedExpectation fulfill];

								// Stop core
								[core stopWithCompletionHandler:^(id sender, NSError *error) {
									XCTAssert((error==nil), @"Stopped with error: %@", error);

									[coreStoppedExpectation fulfill];
								}];
							}
						}
					}
				}
			}];
		};

		[core startQuery:query];
	}];

	[self waitForExpectationsWithTimeout:60 handler:nil];

	// Erase vault
	[core.vault eraseSyncWithCompletionHandler:^(id sender, NSError *error) {
		XCTAssert((error==nil), @"Erased with error: %@", error);
	}];
}

- (void)testCreateFolder
{
	OCBookmark *bookmark = nil;
	OCCore *core;
	__block BOOL didCreateFolder = NO;
	XCTestExpectation *coreStartedExpectation = [self expectationWithDescription:@"Core started"];
	XCTestExpectation *coreStoppedExpectation = [self expectationWithDescription:@"Core stopped"];
	XCTestExpectation *dirCreatedExpectation = [self expectationWithDescription:@"Directory created"];
	XCTestExpectation *dirCreationObservedExpectation = [self expectationWithDescription:@"Directory creation observed"];
	NSString *folderName = NSUUID.UUID.UUIDString;
	__block BOOL _dirCreationObserved = NO;

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
					if (!didCreateFolder)
					{
						didCreateFolder = YES;

						[core createFolder:folderName inside:query.rootItem options:nil resultHandler:^(NSError *error, OCCore *core, OCItem *item, id parameter) {
							XCTAssert(error==nil);
							XCTAssert(item!=nil);

							[dirCreatedExpectation fulfill];
						}];
					}
					else
					{
						if (!_dirCreationObserved)
						{
							for (OCItem *item in changeset.queryResult)
							{
								if ([item.name isEqualToString:folderName])
								{
									[dirCreationObservedExpectation fulfill];
									_dirCreationObserved = YES;
								}
							}

							if (_dirCreationObserved)
							{
								// Stop core
								[core stopWithCompletionHandler:^(id sender, NSError *error) {
									XCTAssert((error==nil), @"Stopped with error: %@", error);

									[coreStoppedExpectation fulfill];
								}];
							}
						}
					}
				}
			}];
		};

		[core startQuery:query];
	}];

	[self waitForExpectationsWithTimeout:60 handler:nil];

	// Erase vault
	[core.vault eraseSyncWithCompletionHandler:^(id sender, NSError *error) {
		XCTAssert((error==nil), @"Erased with error: %@", error);
	}];
}


@end
