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
#import "OCTestTarget.h"

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

- (void)_testSyncAnchorIncreaseOnETagChange // TODO: Fix this test to rely on events rather than timing, then add it back
{
	OCBookmark *bookmark = nil;
	OCCore *core;
	__block BOOL didTamper = NO;
	XCTestExpectation *coreStartedExpectation = [self expectationWithDescription:@"Core started"];
	XCTestExpectation *coreStoppedExpectation = [self expectationWithDescription:@"Core stopped"];

	XCTestExpectation *firstItemReturnedExpectation = [self expectationWithDescription:@"First item returned"];
	XCTestExpectation *secondItemReturnedExpectation = [self expectationWithDescription:@"Second item returned"];

	__block OCItem *firstRootItemReturnedBySyncAnchorQuery = nil, *secondRootItemReturnedBySyncAnchorQuery = nil;

	// Create bookmark for demo.owncloud.org
	bookmark = [OCBookmark bookmarkForURL:OCTestTarget.secureTargetURL];
	bookmark.authenticationData = [OCAuthenticationMethodBasicAuth authenticationDataForUsername:OCTestTarget.userLogin passphrase:OCTestTarget.userPassword authenticationHeaderValue:NULL error:NULL];
	bookmark.authenticationMethodIdentifier = OCAuthenticationMethodIdentifierBasicAuth;

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

					for (OCItem *item in changeset.queryResult)
					{
						if ([item.path isEqual:@"/"])
						{
							if (firstRootItemReturnedBySyncAnchorQuery == nil)
							{
								firstRootItemReturnedBySyncAnchorQuery = item;
								[firstItemReturnedExpectation fulfill];
							}
							else
							{
								if (secondRootItemReturnedBySyncAnchorQuery == nil)
								{
									secondRootItemReturnedBySyncAnchorQuery = item;
									[secondItemReturnedExpectation fulfill];
								}
							}
						}
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

- (void)testSyncAnchorQueryUpdates
{
	OCBookmark *bookmark = nil;
	OCCore *core;
	NSString *testFolderName = NSUUID.UUID.UUIDString;
	XCTestExpectation *coreStartedExpectation = [self expectationWithDescription:@"Core started"];
	XCTestExpectation *coreStoppedExpectation = [self expectationWithDescription:@"Core stopped"];
	__block XCTestExpectation *receivedRootDirExpectation = [self expectationWithDescription:@"Received root dir item"];
	__block XCTestExpectation *receivedNewDirExpectation = [self expectationWithDescription:@"Received new dir item"];
	__block XCTestExpectation *receivedMoveExpectation = [self expectationWithDescription:@"Received moved item"];
	__block XCTestExpectation *receivedCopyExpectation = [self expectationWithDescription:@"Received copied item"];
	__block XCTestExpectation *receivedMoveDeleteExpectation = [self expectationWithDescription:@"Received moved removed item"];
	__block XCTestExpectation *receivedDeleteExpectation = [self expectationWithDescription:@"Received removed item"];
	__block OCItem *topLevelFileItem = nil, *rootItem = nil, *newFolderItem = nil;

	// Create bookmark for demo.owncloud.org
	bookmark = [OCBookmark bookmarkForURL:OCTestTarget.secureTargetURL];
	bookmark.authenticationData = [OCAuthenticationMethodBasicAuth authenticationDataForUsername:OCTestTarget.userLogin passphrase:OCTestTarget.userPassword authenticationHeaderValue:NULL error:NULL];
	bookmark.authenticationMethodIdentifier = OCAuthenticationMethodIdentifierBasicAuth;

	// Create core with it
	core = [[OCCore alloc] initWithBookmark:bookmark];

	// Start core
	[core startWithCompletionHandler:^(OCCore *core, NSError *error) {
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

					for (OCItem *item in changeset.queryResult)
					{
						if ((item.type == OCItemTypeFile) && (topLevelFileItem==nil))
						{
							topLevelFileItem = item;
						}

						if ([item.path isEqual:@"/"])
						{
							rootItem = item;

							if (receivedRootDirExpectation != nil)
							{
								[receivedRootDirExpectation fulfill];
								receivedRootDirExpectation = nil;

								[core createFolder:testFolderName inside:item options:nil resultHandler:^(NSError *error, OCCore *core, OCItem *item, id parameter) {
									XCTAssert(error==nil);
									XCTAssert(item!=nil);

									newFolderItem = item;
								}];
							}
						}

						if ([item.name isEqual:testFolderName])
						{
							if (receivedNewDirExpectation != nil)
							{
								[receivedNewDirExpectation fulfill];
								receivedNewDirExpectation = nil;

								[core moveItem:topLevelFileItem to:item withName:topLevelFileItem.name options:nil resultHandler:^(NSError *error, OCCore *core, OCItem *item, id parameter) {
									XCTAssert(error==nil);
									XCTAssert(item!=nil);
								}];
							}
						}

						if (topLevelFileItem!=nil)
						{
							OCPath movedItemPath = [NSString stringWithFormat:@"/%@/%@", testFolderName, topLevelFileItem.name];

							if ([item.path isEqual:movedItemPath])
							{
								if (receivedMoveExpectation != nil)
								{
									[receivedMoveExpectation fulfill];
									receivedMoveExpectation = nil;

									[core copyItem:item to:rootItem withName:topLevelFileItem.name options:nil resultHandler:^(NSError *error, OCCore *core, OCItem *item, id parameter) {
										XCTAssert(error==nil);
										XCTAssert(item!=nil);
									}];
								}
							}
						}

						if ([item.path isEqual:topLevelFileItem.path])
						{
							if (!item.removed)
							{
								if ((receivedMoveExpectation == nil) && (receivedCopyExpectation!=nil))
								{
									[receivedCopyExpectation fulfill];
									receivedCopyExpectation = nil;

									[core deleteItem:newFolderItem requireMatch:YES resultHandler:^(NSError *error, OCCore *core, OCItem *item, id parameter) {
										XCTAssert(error==nil);
										XCTAssert(item!=nil);
										XCTAssert(parameter!=nil);
									}];
								}
							}
							else
							{
								if (receivedMoveDeleteExpectation != nil)
								{
									[receivedMoveDeleteExpectation fulfill];
									receivedMoveDeleteExpectation = nil;
								}
							}
						}

						if ([item.path isEqual:newFolderItem.path])
						{
							if (item.removed)
							{
								if (receivedDeleteExpectation != nil)
								{
									[receivedDeleteExpectation fulfill];
									receivedDeleteExpectation = nil;
								}
							}
						}
					}

					if ((receivedRootDirExpectation == nil) &&
					    (receivedNewDirExpectation==nil) &&
					    (receivedMoveExpectation==nil) &&
					    (receivedMoveDeleteExpectation==nil) &&
					    (receivedCopyExpectation==nil) &&
					    (receivedDeleteExpectation==nil))
					{
						// Stop core
						[core stopWithCompletionHandler:^(id sender, NSError *error) {
							XCTAssert((error==nil), @"Stopped with error: %@", error);

							[coreStoppedExpectation fulfill];
						}];
					}
 				}
			}];
		};

		[core startQuery:syncAnchorQuery];

		[core startQuery:[OCQuery queryForPath:@"/"]];
	}];

	[self waitForExpectationsWithTimeout:60 handler:nil];

	// Erase vault
	[core.vault eraseSyncWithCompletionHandler:^(id sender, NSError *error) {
		XCTAssert((error==nil), @"Erased with error: %@", error);
	}];
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
	bookmark = [OCBookmark bookmarkForURL:OCTestTarget.secureTargetURL];
	bookmark.authenticationData = [OCAuthenticationMethodBasicAuth authenticationDataForUsername:OCTestTarget.userLogin passphrase:OCTestTarget.userPassword authenticationHeaderValue:NULL error:NULL];
	bookmark.authenticationMethodIdentifier = OCAuthenticationMethodIdentifierBasicAuth;

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
	XCTestExpectation *dirPlaceholderCreationObservedExpectation = [self expectationWithDescription:@"Directory placeholder creation observed"];
	NSString *folderName = NSUUID.UUID.UUIDString;
	__block BOOL _dirCreationObserved = NO, _dirCreationPlaceholderObserved = NO;

	// Create bookmark for demo.owncloud.org
	bookmark = [OCBookmark bookmarkForURL:OCTestTarget.secureTargetURL];
	bookmark.authenticationData = [OCAuthenticationMethodBasicAuth authenticationDataForUsername:OCTestTarget.userLogin passphrase:OCTestTarget.userPassword authenticationHeaderValue:NULL error:NULL];
	bookmark.authenticationMethodIdentifier = OCAuthenticationMethodIdentifierBasicAuth;

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
									if (item.isPlaceholder)
									{
										if (!_dirCreationPlaceholderObserved)
										{
											[dirPlaceholderCreationObservedExpectation fulfill];
											_dirCreationPlaceholderObserved = YES;
										}
									}
									else
									{
										[dirCreationObservedExpectation fulfill];
										_dirCreationObserved = YES;
									}
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

- (void)testCopy
{
	OCBookmark *bookmark = nil;
	OCCore *core;
	__block BOOL didCreateFolder = NO;
	__block OCQuery *newFolderQuery = nil;
	XCTestExpectation *coreStartedExpectation = [self expectationWithDescription:@"Core started"];
	XCTestExpectation *coreStoppedExpectation = [self expectationWithDescription:@"Core stopped"];
	XCTestExpectation *dirCreatedExpectation = [self expectationWithDescription:@"Directory created"];
	XCTestExpectation *fileCopiedExpectation = [self expectationWithDescription:@"File copied"];
	XCTestExpectation *fileCopiedToExistingLocationExpectation = [self expectationWithDescription:@"File copied to existing location failed"];
	XCTestExpectation *folderCopiedExpectation = [self expectationWithDescription:@"Folder copied"];
	__block XCTestExpectation *targetRemovedStateChangeExpectation = [self expectationWithDescription:@"State changed to target removed"];
	__block XCTestExpectation *fileCopiedNotificationExpectation = [self expectationWithDescription:@"File copied notification"];
	__block XCTestExpectation *folderCopiedNotificationExpectation = [self expectationWithDescription:@"Folder copied notification"];
	NSString *folderName = NSUUID.UUID.UUIDString;

	// Create bookmark for demo.owncloud.org
	bookmark = [OCBookmark bookmarkForURL:OCTestTarget.secureTargetURL];
	bookmark.authenticationData = [OCAuthenticationMethodBasicAuth authenticationDataForUsername:OCTestTarget.userLogin passphrase:OCTestTarget.userPassword authenticationHeaderValue:NULL error:NULL];
	bookmark.authenticationMethodIdentifier = OCAuthenticationMethodIdentifierBasicAuth;

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
						OCItem *copyFolderItem, *copyFileItem;

						for (OCItem *item in query.queryResults)
						{
							if (item.type == OCItemTypeFile)
							{
								copyFileItem = item;
							}

							if (item.type == OCItemTypeCollection)
							{
								copyFolderItem = item;
							}
						}

						didCreateFolder = YES;

						[core createFolder:folderName inside:query.rootItem options:nil resultHandler:^(NSError *error, OCCore *core, OCItem *item, id parameter) {
							XCTAssert(error==nil);
							XCTAssert(item!=nil);

							[dirCreatedExpectation fulfill];

							newFolderQuery = [OCQuery queryForPath:item.path];
							newFolderQuery.changesAvailableNotificationHandler = ^(OCQuery *query) {
								[query requestChangeSetWithFlags:OCQueryChangeSetRequestFlagDefault completionHandler:^(OCQuery *query, OCQueryChangeSet *changeset) {
									if (changeset != nil)
									{
										NSLog(@"============================================");
										NSLog(@"[%@] NEW QUERY STATE: %lu", query.queryPath, (unsigned long)query.state);

										NSLog(@"[%@] NEW Query result: %@", query.queryPath, changeset.queryResult);
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
										for (OCItem *item in query.queryResults)
										{
											if ([item.name isEqualToString:[copyFolderItem.name stringByAppendingString:@" copy"]])
											{
												[folderCopiedNotificationExpectation fulfill];
												folderCopiedNotificationExpectation = nil;
											}

											if ([item.name isEqualToString:[copyFileItem.name stringByAppendingString:@" copy"]])
											{
												[fileCopiedNotificationExpectation fulfill];
												fileCopiedNotificationExpectation = nil;
											}
										}
									}

									if (query.state == OCQueryStateTargetRemoved)
									{
										if (targetRemovedStateChangeExpectation == nil)
										{
											NSLog(@"Duplicate removal call!");
										}

										[targetRemovedStateChangeExpectation fulfill];
										targetRemovedStateChangeExpectation = nil;
									}
								}];
							};

							[core startQuery:newFolderQuery];

							[core copyItem:copyFolderItem to:item withName:[copyFolderItem.name stringByAppendingString:@" copy"] options:nil resultHandler:^(NSError *error, OCCore *core, OCItem *newItem, id parameter) {
								NSLog(@"Copy folder item: error=%@ item=%@", error, newItem);

								XCTAssert(error==nil);
								XCTAssert(newItem!=nil);
								XCTAssert([newItem.parentFileID isEqual:item.fileID]);
								XCTAssert([newItem.name isEqual:[copyFolderItem.name stringByAppendingString:@" copy"]]);

								[folderCopiedExpectation fulfill];
							}];

							[core copyItem:copyFileItem to:item withName:[copyFileItem.name stringByAppendingString:@" copy"] options:nil resultHandler:^(NSError *error, OCCore *core, OCItem *newItem, id parameter) {
								NSLog(@"Copy file item: error=%@ item=%@", error, newItem);

								XCTAssert(error==nil);
								XCTAssert(newItem!=nil);
								XCTAssert([newItem.parentFileID isEqual:item.fileID]);
								XCTAssert([newItem.name isEqual:[copyFileItem.name stringByAppendingString:@" copy"]]);

								[fileCopiedExpectation fulfill];
							}];

							[core copyItem:copyFileItem to:query.rootItem withName:copyFileItem.name options:nil resultHandler:^(NSError *error, OCCore *core, OCItem *newItem, id parameter) {
								NSLog(@"Copy file item to existing location: error=%@ item=%@", error, newItem);

								XCTAssert(error!=nil);
								XCTAssert([error.domain isEqual:OCErrorDomain]);
								XCTAssert(error.code == OCErrorItemAlreadyExists);
								XCTAssert(newItem==nil);

								[fileCopiedToExistingLocationExpectation fulfill];

								[core deleteItem:item requireMatch:YES resultHandler:^(NSError *error, OCCore *core, OCItem *item, id parameter) {
									NSLog(@"Delete test folder: error=%@ item=%@", error, item);

									// Stop core
									[core stopWithCompletionHandler:^(id sender, NSError *error) {
										XCTAssert((error==nil), @"Stopped with error: %@", error);

										[coreStoppedExpectation fulfill];
									}];
								}];
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
}

- (void)testMove
{
	OCBookmark *bookmark = nil;
	OCCore *core;
	__block BOOL didCreateFolder = NO;
	__block OCQuery *newFolderQuery = nil;
	XCTestExpectation *coreStartedExpectation = [self expectationWithDescription:@"Core started"];
	XCTestExpectation *coreStoppedExpectation = [self expectationWithDescription:@"Core stopped"];
	XCTestExpectation *dirCreatedExpectation = [self expectationWithDescription:@"Directory created"];
	XCTestExpectation *fileMovedExpectation = [self expectationWithDescription:@"File moved"];
	XCTestExpectation *folderMovedExpectation = [self expectationWithDescription:@"Folder moved"];
	XCTestExpectation *fileMovedBackExpectation = [self expectationWithDescription:@"File moved back"];
	XCTestExpectation *folderMovedBackExpectation = [self expectationWithDescription:@"Folder moved back"];
	XCTestExpectation *targetRemovedStateChangeExpectation = [self expectationWithDescription:@"State changed to target removed"];
	XCTestExpectation *fileMovedOntoItselfFailsExpectation = [self expectationWithDescription:@"fileMovedOntoItselfFails"];
	__block XCTestExpectation *fileCopiedNotificationExpectation = [self expectationWithDescription:@"File copied notification"];
	__block XCTestExpectation *folderCopiedNotificationExpectation = [self expectationWithDescription:@"Folder copied notification"];
	__block XCTestExpectation *fileDisappearedExpectation = [self expectationWithDescription:@"File disappeared."];
	__block XCTestExpectation *fileReappearedExpectation = [self expectationWithDescription:@"File reappeared."];
	__block XCTestExpectation *folderDisappearedExpectation = [self expectationWithDescription:@"Folder disappeared."];
	__block XCTestExpectation *folderReappearedExpectation = [self expectationWithDescription:@"Folder reappeared."];
	NSString *folderName = NSUUID.UUID.UUIDString;
	__block OCItem *moveFolderItem, *moveFileItem;


	// Create bookmark for demo.owncloud.org
	bookmark = [OCBookmark bookmarkForURL:OCTestTarget.secureTargetURL];
	bookmark.authenticationData = [OCAuthenticationMethodBasicAuth authenticationDataForUsername:OCTestTarget.userLogin passphrase:OCTestTarget.userPassword authenticationHeaderValue:NULL error:NULL];
	bookmark.authenticationMethodIdentifier = OCAuthenticationMethodIdentifierBasicAuth;

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
						for (OCItem *item in query.queryResults)
						{
							if (item.type == OCItemTypeFile)
							{
								moveFileItem = item;
							}

							if (item.type == OCItemTypeCollection)
							{
								moveFolderItem = item;
							}
						}

						didCreateFolder = YES;

						[core createFolder:folderName inside:query.rootItem options:nil resultHandler:^(NSError *error, OCCore *core, OCItem *item, id parameter) {
							XCTAssert(error==nil);
							XCTAssert(item!=nil);

							[dirCreatedExpectation fulfill];

							newFolderQuery = [OCQuery queryForPath:item.path];
							newFolderQuery.changesAvailableNotificationHandler = ^(OCQuery *query) {
								[query requestChangeSetWithFlags:OCQueryChangeSetRequestFlagDefault completionHandler:^(OCQuery *query, OCQueryChangeSet *changeset) {
									if (changeset != nil)
									{
										NSLog(@"============================================");
										NSLog(@"[%@] NEW QUERY STATE: %lu", query.queryPath, (unsigned long)query.state);

										NSLog(@"[%@] NEW Query result: %@", query.queryPath, changeset.queryResult);
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
										for (OCItem *item in query.queryResults)
										{
											if ([item.name isEqualToString:[moveFolderItem.name stringByAppendingString:@" moved"]])
											{
												[folderCopiedNotificationExpectation fulfill];
												folderCopiedNotificationExpectation = nil;
											}

											if ([item.name isEqualToString:[moveFileItem.name stringByAppendingString:@" moved"]])
											{
												[fileCopiedNotificationExpectation fulfill];
												fileCopiedNotificationExpectation = nil;
											}
										}
									}

									if (query.state == OCQueryStateTargetRemoved)
									{
										[targetRemovedStateChangeExpectation fulfill];
									}
								}];
							};

							[core startQuery:newFolderQuery];

							[core moveItem:moveFolderItem to:item withName:[moveFolderItem.name stringByAppendingString:@" moved"] options:nil resultHandler:^(NSError *error, OCCore *core, OCItem *newItem, id parameter) {
								NSLog(@"Move folder item: error=%@ item=%@", error, newItem);

								XCTAssert(error==nil);
								XCTAssert(newItem!=nil);
								XCTAssert([newItem.parentFileID isEqual:item.fileID]);
								XCTAssert([newItem.name isEqual:[moveFolderItem.name stringByAppendingString:@" moved"]]);

								[folderMovedExpectation fulfill];

								[core moveItem:newItem to:query.rootItem withName:moveFolderItem.name options:nil resultHandler:^(NSError *error, OCCore *core, OCItem *newItem, id parameter) {
									NSLog(@"Move folder item back: error=%@ item=%@", error, newItem);

									XCTAssert(error==nil);
									XCTAssert(newItem!=nil);
									XCTAssert([newItem.parentFileID isEqual:query.rootItem.fileID]);
									XCTAssert([newItem.name isEqual:moveFolderItem.name]);

									[folderMovedBackExpectation fulfill];
								}];
							}];

							[core moveItem:moveFileItem to:item withName:[moveFileItem.name stringByAppendingString:@" moved"] options:nil resultHandler:^(NSError *error, OCCore *core, OCItem *newItem, id parameter) {
								NSLog(@"Move file item: error=%@ item=%@", error, newItem);

								XCTAssert(error==nil);
								XCTAssert(newItem!=nil);
								XCTAssert([newItem.parentFileID isEqual:item.fileID]);
								XCTAssert([newItem.name isEqual:[moveFileItem.name stringByAppendingString:@" moved"]]);

								[fileMovedExpectation fulfill];

								[core moveItem:newItem to:query.rootItem withName:moveFileItem.name options:nil resultHandler:^(NSError *error, OCCore *core, OCItem *newItem, id parameter) {
									NSLog(@"Move file item back: error=%@ item=%@", error, newItem);

									XCTAssert(error==nil);
									XCTAssert(newItem!=nil);
									XCTAssert([newItem.parentFileID isEqual:query.rootItem.fileID]);
									XCTAssert([newItem.name isEqual:moveFileItem.name]);

									[fileMovedBackExpectation fulfill];

									[core moveItem:newItem to:query.rootItem withName:newItem.name options:nil resultHandler:^(NSError *error, OCCore *core, OCItem *newItem, id parameter) {
										NSLog(@"Move file item to existing location: error=%@ item=%@", error, newItem);

										XCTAssert(error!=nil);
										XCTAssert([error.domain isEqual:OCErrorDomain]);
										XCTAssert(error.code == OCErrorItemAlreadyExists);
										XCTAssert(newItem==nil);

										[fileMovedOntoItselfFailsExpectation fulfill];

										[core deleteItem:item requireMatch:YES resultHandler:^(NSError *error, OCCore *core, OCItem *item, id parameter) {
											NSLog(@"Delete test folder: error=%@ item=%@", error, item);

											// Stop core
											[core stopWithCompletionHandler:^(id sender, NSError *error) {
												XCTAssert((error==nil), @"Stopped with error: %@", error);

												[coreStoppedExpectation fulfill];
											}];
										}];
									}];
								}];
							}];
						}];
					}
					else
					{
						BOOL hasSeenFolder=NO, hasSeenFile=NO;

						for (OCItem *item in query.queryResults)
						{
							if ([item.itemVersionIdentifier isEqual:moveFileItem.itemVersionIdentifier])
							{
								hasSeenFile = YES;
							}

							if ([item.itemVersionIdentifier isEqual:moveFolderItem.itemVersionIdentifier])
							{
								hasSeenFolder = YES;
							}
						}

						if (hasSeenFile)
						{
							if (fileDisappearedExpectation == nil)
							{
								[fileReappearedExpectation fulfill];
								fileReappearedExpectation = nil;
							}
						}
						else
						{
							[fileDisappearedExpectation fulfill];
							fileDisappearedExpectation = nil;
						}

						if (hasSeenFolder)
						{
							if (folderDisappearedExpectation == nil)
							{
								[folderReappearedExpectation fulfill];
								folderReappearedExpectation = nil;
							}
						}
						else
						{
							[folderDisappearedExpectation fulfill];
							folderDisappearedExpectation = nil;
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

- (void)testRenameStressTest
{
	OCBookmark *bookmark = nil;
	OCCore *core;
	__block BOOL didStartRenames = NO;
	XCTestExpectation *coreStartedExpectation = [self expectationWithDescription:@"Core started"];
	XCTestExpectation *coreStoppedExpectation = [self expectationWithDescription:@"Core stopped"];
	__block NSInteger remainingRenames = 0;

	// Create bookmark for demo.owncloud.org
	bookmark = [OCBookmark bookmarkForURL:OCTestTarget.secureTargetURL];
	bookmark.authenticationData = [OCAuthenticationMethodBasicAuth authenticationDataForUsername:OCTestTarget.userLogin passphrase:OCTestTarget.userPassword authenticationHeaderValue:NULL error:NULL];
	bookmark.authenticationMethodIdentifier = OCAuthenticationMethodIdentifierBasicAuth;

	// Create core with it
	core = [[OCCore alloc] initWithBookmark:bookmark];

	// Start core
	[core startWithCompletionHandler:^(OCCore *core, NSError *error) {
		OCQuery *query;

		XCTAssert((error==nil), @"Started with error: %@", error);
		[coreStartedExpectation fulfill];

		NSLog(@"Vault location: %@", core.vault.rootURL);

		query = [OCQuery queryForPath:@"/Photos/"];
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
					if (!didStartRenames)
					{
						for (OCItem *item in query.queryResults)
						{
							if (item.type == OCItemTypeFile)
							{
								NSString *originalName = item.name;
								NSString *modifiedName1 = [item.name stringByAppendingString:@"1"];
								NSString *modifiedName2 = [item.name stringByAppendingString:@"2"];
								NSString *modifiedName3 = [item.name stringByAppendingString:@"3"];

								remainingRenames += 4;

								NSLog(@"Renaming %@ -> %@ -> %@ -> %@ -> %@ (%@)", originalName, modifiedName1, modifiedName2, modifiedName3, originalName, query.queryResults);

								[core renameItem:item to:modifiedName1 options:nil resultHandler:^(NSError *error, OCCore *core, OCItem *newItem, id parameter) {
									NSLog(@"Renamed %@ -> %@: error=%@ item=%@", originalName, newItem.name, error, newItem);
									remainingRenames--;

									XCTAssert(error==nil);
									XCTAssert(newItem!=nil);
									XCTAssert([newItem.parentFileID isEqual:query.rootItem.fileID]);
									XCTAssert([newItem.name isEqual:modifiedName1]);

									[core renameItem:newItem to:modifiedName2 options:nil resultHandler:^(NSError *error, OCCore *core, OCItem *newItem, id parameter) {
										NSLog(@"Renamed %@ -> %@: error=%@ item=%@", modifiedName1, newItem.name, error, newItem);
										remainingRenames--;

										XCTAssert(error==nil);
										XCTAssert(newItem!=nil);
										XCTAssert([newItem.parentFileID isEqual:query.rootItem.fileID]);
										XCTAssert([newItem.name isEqual:modifiedName2]);

										[core renameItem:newItem to:modifiedName3 options:nil resultHandler:^(NSError *error, OCCore *core, OCItem *newItem, id parameter) {
											NSLog(@"Renamed %@ -> %@: error=%@ item=%@", modifiedName2, newItem.name, error, newItem);
											remainingRenames--;

											XCTAssert(error==nil);
											XCTAssert(newItem!=nil);
											XCTAssert([newItem.parentFileID isEqual:query.rootItem.fileID]);
											XCTAssert([newItem.name isEqual:modifiedName3]);

											[core renameItem:newItem to:originalName options:nil resultHandler:^(NSError *error, OCCore *core, OCItem *newItem, id parameter) {
												NSLog(@"Renamed %@ -> %@: error=%@ item=%@", modifiedName3, newItem.name, error, newItem);
												remainingRenames--;

												XCTAssert(error==nil);
												XCTAssert(newItem!=nil);
												XCTAssert([newItem.parentFileID isEqual:query.rootItem.fileID]);
												XCTAssert([newItem.name isEqual:originalName]);

												if (remainingRenames == 0)
												{
													// Stop core
													[core stopWithCompletionHandler:^(id sender, NSError *error) {
														XCTAssert((error==nil), @"Stopped with error: %@", error);

														[coreStoppedExpectation fulfill];
													}];
												}
											}];
										}];
									}];
								}];
							}
						}

						didStartRenames = YES;
					}
					else
					{
						NSLog(@"Query update! %@", query.queryResults);
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

- (void)testDownload
{
	OCBookmark *bookmark = nil;
	OCCore *core;
	XCTestExpectation *coreStartedExpectation = [self expectationWithDescription:@"Core started"];
	XCTestExpectation *coreStoppedExpectation = [self expectationWithDescription:@"Core stopped"];
	XCTestExpectation *fileDownloadedExpectation = [self expectationWithDescription:@"File downloaded"];
	__block BOOL startedDownload = NO;

	// Create bookmark for demo.owncloud.org
	bookmark = [OCBookmark bookmarkForURL:OCTestTarget.secureTargetURL];
	bookmark.authenticationData = [OCAuthenticationMethodBasicAuth authenticationDataForUsername:OCTestTarget.userLogin passphrase:OCTestTarget.userPassword authenticationHeaderValue:NULL error:NULL];
	bookmark.authenticationMethodIdentifier = OCAuthenticationMethodIdentifierBasicAuth;

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
					for (OCItem *item in changeset.queryResult)
					{
						if ((item.type == OCItemTypeFile) && !startedDownload)
						{
							startedDownload = YES;

							[core downloadItem:item options:nil resultHandler:^(NSError *error, OCCore *core, OCItem *item, OCFile *file) {
								NSLog(@"Downloaded to %@ with error %@", file.url, error);

								[fileDownloadedExpectation fulfill];

								XCTAssert(error==nil);
								XCTAssert(file.url!=nil);

								if ((error == nil) && (file.url != nil))
								{
									[[NSFileManager defaultManager] removeItemAtURL:file.url error:NULL];
								}

								// Stop core
								[core stopWithCompletionHandler:^(id sender, NSError *error) {
									XCTAssert((error==nil), @"Stopped with error: %@", error);

									[coreStoppedExpectation fulfill];
								}];
							}];
							break;
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

- (void)testUpload
{
	OCBookmark *bookmark = nil;
	OCCore *core;
	XCTestExpectation *coreStartedExpectation = [self expectationWithDescription:@"Core started"];
	XCTestExpectation *coreStoppedExpectation = [self expectationWithDescription:@"Core stopped"];
	XCTestExpectation *placeholderCreatedExpectation = [self expectationWithDescription:@"Placeholder created"];
	XCTestExpectation *modificationItemCreatedExpectation = [self expectationWithDescription:@"Modification item created"];
	XCTestExpectation *fileUploadedExpectation = [self expectationWithDescription:@"File uploaded"];
	XCTestExpectation *updatedFileUploadedExpectation = [self expectationWithDescription:@"File uploaded"];
	NSURL *uploadFileURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"rainbow" withExtension:@"png"];
	NSURL *modifiedFileURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"rainbow-crystalized" withExtension:@"png"];
	NSString *uploadName = [NSString stringWithFormat:@"rainbow-%f.png", NSDate.timeIntervalSinceReferenceDate];
	__block BOOL startedUpload = NO;
	OCChecksum *(^ComputeChecksumForURL)(NSURL *url) = ^(NSURL *url) {
		__block OCChecksum *checksum = nil;

		OCSyncExec(computeChecksum, {
			[OCChecksum computeForFile:url checksumAlgorithm:OCChecksumAlgorithmIdentifierSHA1 completionHandler:^(NSError *error, OCChecksum *computedChecksum) {
				checksum = computedChecksum;
				OCSyncExecDone(computeChecksum);
			}];
		});

		return (checksum);
	};
	OCChecksum *uploadFileChecksum = ComputeChecksumForURL(uploadFileURL);
	OCChecksum *modifiedFileChecksum = ComputeChecksumForURL(modifiedFileURL);

	// Create bookmark for demo.owncloud.org
	bookmark = [OCBookmark bookmarkForURL:OCTestTarget.secureTargetURL];
	bookmark.authenticationData = [OCAuthenticationMethodBasicAuth authenticationDataForUsername:OCTestTarget.userLogin passphrase:OCTestTarget.userPassword authenticationHeaderValue:NULL error:NULL];
	bookmark.authenticationMethodIdentifier = OCAuthenticationMethodIdentifierBasicAuth;

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
					if (query.rootItem != nil)
					{
						if (!startedUpload)
						{
							startedUpload = YES;

							// Test upload by import
							[core importFileNamed:uploadName at:query.rootItem fromURL:uploadFileURL isSecurityScoped:NO options:nil placeholderCompletionHandler:^(NSError *error, OCItem *item) {
								XCTAssert(item!=nil);
								XCTAssert(item.isPlaceholder);
								XCTAssert([ComputeChecksumForURL([core localURLForItem:item]) isEqual:uploadFileChecksum]);

								NSLog(@"### Placeholder item: %@", item);


								[placeholderCreatedExpectation fulfill];
							} resultHandler:^(NSError *error, OCCore *core, OCItem *item, id parameter) {
								XCTAssert(error==nil);
								XCTAssert(item!=nil);
								XCTAssert(!item.isPlaceholder);
								XCTAssert([ComputeChecksumForURL([core localURLForItem:item]) isEqual:uploadFileChecksum]);

								NSLog(@"### Uploaded item: %@", item);

								[fileUploadedExpectation fulfill];

								// Test upload by local modification
								[core reportLocalModificationOfItem:item parentItem:query.rootItem withContentsOfFileAtURL:modifiedFileURL isSecurityScoped:NO options:nil placeholderCompletionHandler:^(NSError *error, OCItem *item) {
									XCTAssert(item!=nil);
									XCTAssert(!item.isPlaceholder);
									XCTAssert([ComputeChecksumForURL([core localURLForItem:item]) isEqual:modifiedFileChecksum]);

									NSLog(@"### Update \"placeholder\" item=%@ error=%@", item, error);

									[modificationItemCreatedExpectation fulfill];
								} resultHandler:^(NSError *error, OCCore *core, OCItem *item, id parameter) {
									XCTAssert(error==nil);
									XCTAssert(item!=nil);
									XCTAssert(!item.isPlaceholder);
									XCTAssert([ComputeChecksumForURL([core localURLForItem:item]) isEqual:modifiedFileChecksum]);

									NSLog(@"### Uploaded updated item=%@, error=%@", item, error);

									[updatedFileUploadedExpectation fulfill];

									// Stop core
									[core stopWithCompletionHandler:^(id sender, NSError *error) {
										XCTAssert((error==nil), @"Stopped with error: %@", error);

										[coreStoppedExpectation fulfill];
									}];
								}];
							}];
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
