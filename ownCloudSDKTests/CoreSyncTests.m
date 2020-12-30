//
//  CoreSyncTests.m
//  ownCloudSDKTests
//
//  Created by Felix Schwarz on 06.06.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <ownCloudSDK/ownCloudSDK.h>
#import <ownCloudMocking/ownCloudMocking.h>
#import "OCCore+Internal.h"
#import "TestTools.h"
#import "OCTestTarget.h"
#import "OCItem+OCItemCreationDebugging.h"

@interface CoreSyncTestsIssueDismisser : NSObject <OCCoreDelegate>
@end

@implementation CoreSyncTestsIssueDismisser

- (BOOL)core:(OCCore *)core handleSyncIssue:(OCSyncIssue *)syncIssue
{
	OCLog(@"Received and will consume sync issue: %@", syncIssue);

	OCIssue *issue = [OCIssue issueFromSyncIssue:syncIssue forCore:core];

	[issue cancel];

	return (NO);
}

- (void)core:(OCCore *)core handleError:(nullable NSError *)error issue:(nullable OCIssue *)issue
{
	OCLog(@"Consumer received error %@, issue %@", error, issue);
}

@end

@interface CoreSyncTests : XCTestCase

@end

@implementation CoreSyncTests

- (void)setUp
{
	OCItem.creationHistoryEnabled = YES;
}

- (void)tearDown
{
	OCItem.creationHistoryEnabled = NO;
}

- (void)dumpMetaDataTableFromCore:(OCCore *)core withDescription:(NSString *)description rowHook:(void(^)(NSUInteger line, NSDictionary<NSString *,id<NSObject>> *rowDictionary))rowHook completionHandler:(dispatch_block_t)completionHandler
{
	[core.vault.database.sqlDB executeQuery:[OCSQLiteQuery query:[@"SELECT * FROM " stringByAppendingString:OCDatabaseTableNameMetaData] resultHandler:^(OCSQLiteDB *db, NSError *error, OCSQLiteTransaction *transaction, OCSQLiteResultSet *resultSet) {
		OCLog(@"### %@", description);
		[resultSet iterateUsing:^(OCSQLiteResultSet *resultSet, NSUInteger line, NSDictionary<NSString *,id<NSObject>> *rowDictionary, BOOL *stop) {
			OCLog(@"%lu: %@ -- %@ -- %@ -- %@", (unsigned long)line, rowDictionary[@"mdID"], rowDictionary[@"syncAnchor"], rowDictionary[@"path"], rowDictionary[@"name"]);

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

		OCLog(@"Vault location: %@", core.vault.rootURL);

		syncAnchorQuery = [OCQuery queryForChangesSinceSyncAnchor:@(0)];
		syncAnchorQuery.changesAvailableNotificationHandler = ^(OCQuery *query) {
			[query requestChangeSetWithFlags:OCQueryChangeSetRequestFlagDefault completionHandler:^(OCQuery *query, OCQueryChangeSet *changeset) {
				if (changeset != nil)
				{
					OCLog(@"#### ============================================");
					OCLog(@"#### [> %@] SYNC ANCHOR %@ QUERY STATE: %lu", query.querySinceSyncAnchor, changeset.syncAnchor, (unsigned long)query.state);

					OCLog(@"#### [> %@] Changes since: %@", query.querySinceSyncAnchor, changeset.queryResult);

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
					OCLog(@"============================================");
					OCLog(@"[%@] QUERY STATE: %lu", query.queryPath, (unsigned long)query.state);

					OCLog(@"[%@] Query result: %@", query.queryPath, changeset.queryResult);
					[changeset enumerateChangesUsingBlock:^(OCQueryChangeSet *changeSet, OCQueryChangeSetOperation operation, NSArray<OCItem *> *items, NSIndexSet *indexSet) {
						switch(operation)
						{
							case OCQueryChangeSetOperationInsert:
								OCLog(@"[%@] Insertions: %@", query.queryPath, items);
							break;

							case OCQueryChangeSetOperationRemove:
								OCLog(@"[%@] Removals: %@", query.queryPath, items);
							break;

							case OCQueryChangeSetOperationUpdate:
								OCLog(@"[%@] Updates: %@", query.queryPath, items);
							break;

							case OCQueryChangeSetOperationContentSwap:
								OCLog(@"[%@] Content Swap", query.queryPath);
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
	__block XCTestExpectation *receivedDeleteCompleteExpectation = [self expectationWithDescription:@"Received delete completion"];
	__block OCItem *topLevelFileItem = nil, *rootItem = nil, *newFolderItem = nil;

	// Create bookmark for demo.owncloud.org
	bookmark = [OCBookmark bookmarkForURL:OCTestTarget.secureTargetURL];
	bookmark.authenticationData = [OCAuthenticationMethodBasicAuth authenticationDataForUsername:OCTestTarget.userLogin passphrase:OCTestTarget.userPassword authenticationHeaderValue:NULL error:NULL];
	bookmark.authenticationMethodIdentifier = OCAuthenticationMethodIdentifierBasicAuth;

	// Create core with it
	core = [[OCCore alloc] initWithBookmark:bookmark];
	core.automaticItemListUpdatesEnabled = NO;

	// Start core
	[core startWithCompletionHandler:^(OCCore *core, NSError *error) {
		OCQuery *syncAnchorQuery;

		XCTAssert((error==nil), @"Started with error: %@", error);
		[coreStartedExpectation fulfill];

		OCLog(@"Vault location: %@", core.vault.rootURL);

		syncAnchorQuery = [OCQuery queryForChangesSinceSyncAnchor:@(0)];
		syncAnchorQuery.changesAvailableNotificationHandler = ^(OCQuery *query) {
			[query requestChangeSetWithFlags:OCQueryChangeSetRequestFlagDefault completionHandler:^(OCQuery *query, OCQueryChangeSet *changeset) {
				if (changeset != nil)
				{
					OCLog(@"#### ============================================");
					OCLog(@"#### [> %@] SYNC ANCHOR %@ QUERY STATE: %lu", query.querySinceSyncAnchor, changeset.syncAnchor, (unsigned long)query.state);

					OCLog(@"#### [> %@] Changes since: %@", query.querySinceSyncAnchor, changeset.queryResult);

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
								if ((receivedMoveExpectation == nil) && (receivedCopyExpectation!=nil) && (newFolderItem != nil))
								{
									[receivedCopyExpectation fulfill];
									receivedCopyExpectation = nil;

									[core deleteItem:newFolderItem requireMatch:YES resultHandler:^(NSError *error, OCCore *core, OCItem *item, id parameter) {
										XCTAssert(error==nil);
										XCTAssert(item!=nil);
										XCTAssert(parameter!=nil);

										[receivedDeleteCompleteExpectation fulfill];
										receivedDeleteCompleteExpectation = nil;
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
					    (receivedDeleteExpectation==nil) &&
					    (receivedDeleteCompleteExpectation==nil))
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
	__block XCTestExpectation *dirDeletionObservedExpectation = [self expectationWithDescription:@"Directory deletion observed"];
	NSString *folderName = NSUUID.UUID.UUIDString;
	__block OCLocalID localIDOnCreation=nil, localIDBeforeAction=nil, localIDAfterAction=nil;
	__block BOOL _dirCreationObserved = NO;
	dispatch_group_t doneGroup = dispatch_group_create();

	// Create bookmark for demo.owncloud.org
	bookmark = [OCBookmark bookmarkForURL:OCTestTarget.secureTargetURL];
	bookmark.authenticationData = [OCAuthenticationMethodBasicAuth authenticationDataForUsername:OCTestTarget.userLogin passphrase:OCTestTarget.userPassword authenticationHeaderValue:NULL error:NULL];
	bookmark.authenticationMethodIdentifier = OCAuthenticationMethodIdentifierBasicAuth;

	// Create core with it
	core = [[OCCore alloc] initWithBookmark:bookmark];
	core.automaticItemListUpdatesEnabled = NO;

	dispatch_group_enter(doneGroup);
	dispatch_group_enter(doneGroup);

	// Start core
	[core startWithCompletionHandler:^(OCCore *core, NSError *error) {
		OCQuery *query;

		XCTAssert((error==nil), @"Started with error: %@", error);
		[coreStartedExpectation fulfill];

		core.database.itemFilter = self.databaseSanityCheckFilter;

		OCLog(@"Vault location: %@", core.vault.rootURL);

		query = [OCQuery queryForPath:@"/"];
		query.changesAvailableNotificationHandler = ^(OCQuery *query) {
			[query requestChangeSetWithFlags:OCQueryChangeSetRequestFlagDefault completionHandler:^(OCQuery *query, OCQueryChangeSet *changeset) {
				if (changeset != nil)
				{
					OCLog(@"============================================");
					OCLog(@"[%@] QUERY STATE: %lu", query.queryPath, (unsigned long)query.state);

					OCLog(@"[%@] Query result: %@", query.queryPath, changeset.queryResult);
					[changeset enumerateChangesUsingBlock:^(OCQueryChangeSet *changeSet, OCQueryChangeSetOperation operation, NSArray<OCItem *> *items, NSIndexSet *indexSet) {
						switch(operation)
						{
							case OCQueryChangeSetOperationInsert:
								OCLog(@"[%@] Insertions: %@", query.queryPath, items);
							break;

							case OCQueryChangeSetOperationRemove:
								OCLog(@"[%@] Removals: %@", query.queryPath, items);
							break;

							case OCQueryChangeSetOperationUpdate:
								OCLog(@"[%@] Updates: %@", query.queryPath, items);
							break;

							case OCQueryChangeSetOperationContentSwap:
								OCLog(@"[%@] Content Swap", query.queryPath);
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

							localIDBeforeAction = item.localID;

							// TODO: Make it work without dispatch_after - by delivering results only when the sync context finishes. Break at "OCLogError(@"Item without databaseID can't be used for deletion: %@", item);" to debug this!
							dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
								[core deleteItem:item requireMatch:YES resultHandler:^(NSError *error, OCCore *core, OCItem *item, id parameter) {
									OCLog(@"------> Delete item result: error=%@ item=%@ parameter=%@", error, item, parameter);

									XCTAssert(error==nil);
									XCTAssert(item!=nil);

									localIDAfterAction = item.localID;

									[dirDeletedExpectation fulfill];
									dispatch_group_leave(doneGroup);
								}];
							});

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
									localIDOnCreation = item.localID;
								
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
								if (dirDeletionObservedExpectation != nil)
								{
									[dirDeletionObservedExpectation fulfill];
									dirDeletionObservedExpectation = nil;

									// Stop core
									dispatch_group_leave(doneGroup);
								}
							}
						}
					}
				}
			}];
		};

		[core startQuery:query];
	}];

	dispatch_group_notify(doneGroup, dispatch_get_main_queue(), ^{
		[core stopWithCompletionHandler:^(id sender, NSError *error) {
			XCTAssert((error==nil), @"Stopped with error: %@", error);

			[coreStoppedExpectation fulfill];
		}];
	});

	[self waitForExpectationsWithTimeout:60 handler:nil];

	XCTAssert(localIDOnCreation!=nil);
	XCTAssert(localIDBeforeAction!=nil);
	XCTAssert(localIDAfterAction!=nil);
	XCTAssert([localIDOnCreation isEqual:localIDBeforeAction]);
	XCTAssert([localIDOnCreation isEqual:localIDAfterAction]);

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
	__block OCLocalID localIDOnQueryPlaceholder = nil, localIDOnQueryActual=nil, localIDOnCreation=nil;
	__block BOOL _dirCreationObserved = NO, _dirCreationPlaceholderObserved = NO;

	// Create bookmark for demo.owncloud.org
	bookmark = [OCBookmark bookmarkForURL:OCTestTarget.secureTargetURL];
	bookmark.authenticationData = [OCAuthenticationMethodBasicAuth authenticationDataForUsername:OCTestTarget.userLogin passphrase:OCTestTarget.userPassword authenticationHeaderValue:NULL error:NULL];
	bookmark.authenticationMethodIdentifier = OCAuthenticationMethodIdentifierBasicAuth;

	// Create core with it
	core = [[OCCore alloc] initWithBookmark:bookmark];
	core.automaticItemListUpdatesEnabled = NO;

	// Start core
	[core startWithCompletionHandler:^(OCCore *core, NSError *error) {
		OCQuery *query;

		XCTAssert((error==nil), @"Started with error: %@", error);
		[coreStartedExpectation fulfill];

		core.database.itemFilter = self.databaseSanityCheckFilter;

		OCLog(@"Vault location: %@", core.vault.rootURL);

		query = [OCQuery queryForPath:@"/"];
		query.changesAvailableNotificationHandler = ^(OCQuery *query) {
			[query requestChangeSetWithFlags:OCQueryChangeSetRequestFlagDefault completionHandler:^(OCQuery *query, OCQueryChangeSet *changeset) {
				if (changeset != nil)
				{
					OCLog(@"============================================");
					OCLog(@"[%@] QUERY STATE: %lu", query.queryPath, (unsigned long)query.state);

					OCLog(@"[%@] Query result: %@", query.queryPath, changeset.queryResult);
					[changeset enumerateChangesUsingBlock:^(OCQueryChangeSet *changeSet, OCQueryChangeSetOperation operation, NSArray<OCItem *> *items, NSIndexSet *indexSet) {
						switch(operation)
						{
							case OCQueryChangeSetOperationInsert:
								OCLog(@"[%@] Insertions: %@", query.queryPath, items);
							break;

							case OCQueryChangeSetOperationRemove:
								OCLog(@"[%@] Removals: %@", query.queryPath, items);
							break;

							case OCQueryChangeSetOperationUpdate:
								OCLog(@"[%@] Updates: %@", query.queryPath, items);
							break;

							case OCQueryChangeSetOperationContentSwap:
								OCLog(@"[%@] Content Swap", query.queryPath);
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

							localIDOnCreation = item.localID;

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
											localIDOnQueryPlaceholder = item.localID;

											[dirPlaceholderCreationObservedExpectation fulfill];
											_dirCreationPlaceholderObserved = YES;
										}
									}
									else
									{
										localIDOnQueryActual = item.localID;

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

	XCTAssert(localIDOnCreation!=nil);
	XCTAssert(localIDOnQueryPlaceholder!=nil);
	XCTAssert(localIDOnQueryActual!=nil);
	XCTAssert([localIDOnCreation isEqual:localIDOnQueryPlaceholder]);
	XCTAssert([localIDOnCreation isEqual:localIDOnQueryActual]);

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
	__block OCLocalID localIDQueryPlaceholderCopyFile=nil, localIDCopiedFile=nil, localIDQueryPlaceholderCopyFolder=nil, localIDCopiedFolder=nil;
	__block OCLocalID localIDQueryPlaceholderCopyFileParent=nil, localIDCopiedFileParent=nil, localIDQueryPlaceholderCopyFolderParent=nil, localIDCopiedFolderParent=nil;
	__block OCLocalID localIDParentFolderPlaceholderOnQuery=nil, localIDParentFolderCompleteOnQuery=nil, localIDParentFolderOnCompletion=nil, localIDParentFolderOnDeleteCompletion=nil;
	NSString *folderName = NSUUID.UUID.UUIDString;

	// Create bookmark for demo.owncloud.org
	bookmark = [OCBookmark bookmarkForURL:OCTestTarget.secureTargetURL];
	bookmark.authenticationData = [OCAuthenticationMethodBasicAuth authenticationDataForUsername:OCTestTarget.userLogin passphrase:OCTestTarget.userPassword authenticationHeaderValue:NULL error:NULL];
	bookmark.authenticationMethodIdentifier = OCAuthenticationMethodIdentifierBasicAuth;

	// Create core with it
	core = [[OCCore alloc] initWithBookmark:bookmark];
	core.automaticItemListUpdatesEnabled = NO;

	// Start core
	[core startWithCompletionHandler:^(OCCore *core, NSError *error) {
		OCQuery *query;

		XCTAssert((error==nil), @"Started with error: %@", error);
		[coreStartedExpectation fulfill];

		core.database.itemFilter = self.databaseSanityCheckFilter;

		OCLog(@"Vault location: %@", core.vault.rootURL);

		query = [OCQuery queryForPath:@"/"];
		query.changesAvailableNotificationHandler = ^(OCQuery *query) {
			[query requestChangeSetWithFlags:OCQueryChangeSetRequestFlagDefault completionHandler:^(OCQuery *query, OCQueryChangeSet *changeset) {
				if (changeset != nil)
				{
					OCLog(@"============================================");
					OCLog(@"[%@] QUERY STATE: %lu", query.queryPath, (unsigned long)query.state);

					OCLog(@"[%@] Query result: %@", query.queryPath, changeset.queryResult);
					[changeset enumerateChangesUsingBlock:^(OCQueryChangeSet *changeSet, OCQueryChangeSetOperation operation, NSArray<OCItem *> *items, NSIndexSet *indexSet) {
						switch(operation)
						{
							case OCQueryChangeSetOperationInsert:
								OCLog(@"[%@] Insertions: %@", query.queryPath, items);
							break;

							case OCQueryChangeSetOperationRemove:
								OCLog(@"[%@] Removals: %@", query.queryPath, items);
							break;

							case OCQueryChangeSetOperationUpdate:
								OCLog(@"[%@] Updates: %@", query.queryPath, items);
							break;

							case OCQueryChangeSetOperationContentSwap:
								OCLog(@"[%@] Content Swap", query.queryPath);
							break;
						}
					}];
				}

				if (query.state == OCQueryStateIdle)
				{
					if (!didCreateFolder)
					{
						OCItem *copyFolderItem=nil, *copyFileItem=nil;
						NSString *copyFolderItemName=nil, *copyFileItemName=nil;

						for (OCItem *item in query.queryResults)
						{
							if (item.type == OCItemTypeFile)
							{
								copyFileItem = item;
								copyFileItemName = [copyFileItem.name stringByAppendingString:@" copy"];
							}

							if (item.type == OCItemTypeCollection)
							{
								copyFolderItem = item;
								copyFolderItemName = [copyFolderItem.name stringByAppendingString:@" copy"];
							}
						}

						didCreateFolder = YES;

						[core createFolder:folderName inside:query.rootItem options:nil resultHandler:^(NSError *error, OCCore *core, OCItem *newFolderItem, id parameter) {
							XCTAssert(error==nil);
							XCTAssert(newFolderItem!=nil);

							localIDParentFolderOnCompletion = newFolderItem.localID;

							[dirCreatedExpectation fulfill];

							newFolderQuery = [OCQuery queryForPath:newFolderItem.path];
							newFolderQuery.changesAvailableNotificationHandler = ^(OCQuery *query) {
								[query requestChangeSetWithFlags:OCQueryChangeSetRequestFlagDefault completionHandler:^(OCQuery *query, OCQueryChangeSet *changeset) {
									if (changeset != nil)
									{
										OCLog(@"============================================");
										OCLog(@"[%@] NEW QUERY STATE: %lu", query.queryPath, (unsigned long)query.state);

										OCLog(@"[%@] NEW Query result: %@", query.queryPath, changeset.queryResult);
										[changeset enumerateChangesUsingBlock:^(OCQueryChangeSet *changeSet, OCQueryChangeSetOperation operation, NSArray<OCItem *> *items, NSIndexSet *indexSet) {
											switch(operation)
											{
												case OCQueryChangeSetOperationInsert:
													OCLog(@"[%@] Insertions: %@", query.queryPath, items);
												break;

												case OCQueryChangeSetOperationRemove:
													OCLog(@"[%@] Removals: %@", query.queryPath, items);
												break;

												case OCQueryChangeSetOperationUpdate:
													OCLog(@"[%@] Updates: %@", query.queryPath, items);
												break;

												case OCQueryChangeSetOperationContentSwap:
													OCLog(@"[%@] Content Swap", query.queryPath);
												break;
											}
										}];
									}

									if (query.state == OCQueryStateIdle)
									{
										for (OCItem *item in query.queryResults)
										{
											if ([item.name isEqualToString:copyFolderItemName])
											{
												if (item.isPlaceholder && (localIDQueryPlaceholderCopyFolder==nil))
												{
													localIDQueryPlaceholderCopyFolder = item.localID;
													localIDQueryPlaceholderCopyFolderParent = item.parentLocalID;
												}

												[folderCopiedNotificationExpectation fulfill];
												folderCopiedNotificationExpectation = nil;
											}

											if ([item.name isEqualToString:copyFileItemName])
											{
												if (item.isPlaceholder && (localIDQueryPlaceholderCopyFile==nil))
												{
													localIDQueryPlaceholderCopyFile = item.localID;
													localIDQueryPlaceholderCopyFileParent = item.parentLocalID;
												}

												[fileCopiedNotificationExpectation fulfill];
												fileCopiedNotificationExpectation = nil;
											}
										}
									}

									if (query.state == OCQueryStateTargetRemoved)
									{
										if (targetRemovedStateChangeExpectation == nil)
										{
											OCLog(@"Duplicate removal call!");
										}

										[targetRemovedStateChangeExpectation fulfill];
										targetRemovedStateChangeExpectation = nil;
									}
								}];
							};

							[core startQuery:newFolderQuery];

							[core copyItem:copyFolderItem to:newFolderItem withName:copyFolderItemName options:nil resultHandler:^(NSError *error, OCCore *core, OCItem *newItem, id parameter) {
								OCLog(@"Copy folder item: error=%@ item=%@", error, newItem);

								XCTAssert(error==nil);
								XCTAssert(newItem!=nil);
								XCTAssert([newItem.parentFileID isEqual:newFolderItem.fileID]);
								XCTAssert([newItem.name isEqual:copyFolderItemName]);

								localIDCopiedFolder = newItem.localID;
								localIDCopiedFolderParent = newItem.parentLocalID;

								[folderCopiedExpectation fulfill];
							}];

							[core copyItem:copyFileItem to:newFolderItem withName:copyFileItemName options:nil resultHandler:^(NSError *error, OCCore *core, OCItem *newItem, id parameter) {
								OCLog(@"Copy file item: error=%@ item=%@", error, newItem);

								XCTAssert(error==nil);
								XCTAssert(newItem!=nil);
								XCTAssert([newItem.parentFileID isEqual:newFolderItem.fileID]);
								XCTAssert([newItem.name isEqual:copyFileItemName]);

								localIDCopiedFile = newItem.localID;
								localIDCopiedFileParent = newItem.parentLocalID;

								[fileCopiedExpectation fulfill];
							}];

							[core copyItem:copyFileItem to:query.rootItem withName:copyFileItem.name options:nil resultHandler:^(NSError *error, OCCore *core, OCItem *newItem, id parameter) {
								OCLog(@"Copy file item to existing location: error=%@ item=%@", error, newItem);

								XCTAssert(error!=nil);
								XCTAssert([error.domain isEqual:OCErrorDomain]);
								XCTAssert(error.code == OCErrorItemAlreadyExists);
								XCTAssert(newItem==nil);

								[fileCopiedToExistingLocationExpectation fulfill];

								[core deleteItem:newFolderItem requireMatch:YES resultHandler:^(NSError *error, OCCore *core, OCItem *item, id parameter) {
									OCLog(@"Delete test folder: error=%@ item=%@", error, item);

									localIDParentFolderOnDeleteCompletion = item.localID;

									// Stop core
									[core stopWithCompletionHandler:^(id sender, NSError *error) {
										XCTAssert((error==nil), @"Stopped with error: %@", error);

										[coreStoppedExpectation fulfill];
									}];
								}];
							}];
						}];
					}
					else
					{
						for (OCItem *item in query.queryResults)
						{
							if (localIDParentFolderPlaceholderOnQuery == nil)
							{
								if ([item.name isEqual:folderName] && item.isPlaceholder)
								{
									localIDParentFolderPlaceholderOnQuery = item.localID;
								}
							}

							if (localIDParentFolderCompleteOnQuery == nil)
							{
								if ([item.name isEqual:folderName] && !item.isPlaceholder)
								{
									localIDParentFolderCompleteOnQuery = item.localID;
								}
							}
						}
					}
				}
			}];
		};

		[core startQuery:query];
	}];

	[self waitForExpectationsWithTimeout:60 handler:nil];

	XCTAssert([localIDQueryPlaceholderCopyFile isEqual:localIDCopiedFile], @"%@ != %@", localIDQueryPlaceholderCopyFile, localIDCopiedFile);
	XCTAssert([localIDQueryPlaceholderCopyFolder isEqual:localIDCopiedFolder], @"%@ != %@", localIDQueryPlaceholderCopyFolder, localIDCopiedFolder);

	XCTAssert([localIDQueryPlaceholderCopyFileParent isEqual:localIDCopiedFileParent], @"%@ != %@", localIDQueryPlaceholderCopyFileParent, localIDCopiedFileParent);
	XCTAssert([localIDQueryPlaceholderCopyFileParent isEqual:localIDQueryPlaceholderCopyFolderParent], @"%@ != %@", localIDQueryPlaceholderCopyFileParent, localIDQueryPlaceholderCopyFolderParent);
	XCTAssert([localIDQueryPlaceholderCopyFileParent isEqual:localIDCopiedFolderParent], @"%@ != %@", localIDQueryPlaceholderCopyFileParent, localIDCopiedFolderParent);

	XCTAssert([localIDQueryPlaceholderCopyFileParent isEqual:localIDParentFolderPlaceholderOnQuery], @"%@ != %@", localIDQueryPlaceholderCopyFileParent, localIDParentFolderPlaceholderOnQuery);
	XCTAssert([localIDQueryPlaceholderCopyFileParent isEqual:localIDParentFolderCompleteOnQuery], @"%@ != %@", localIDQueryPlaceholderCopyFileParent, localIDParentFolderCompleteOnQuery);
	XCTAssert([localIDQueryPlaceholderCopyFileParent isEqual:localIDParentFolderOnCompletion], @"%@ != %@", localIDQueryPlaceholderCopyFileParent, localIDParentFolderOnCompletion);
	XCTAssert([localIDQueryPlaceholderCopyFileParent isEqual:localIDParentFolderOnDeleteCompletion], @"%@ != %@", localIDQueryPlaceholderCopyFileParent, localIDParentFolderOnDeleteCompletion);

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
	__block XCTestExpectation *targetRemovedStateChangeExpectation = [self expectationWithDescription:@"State changed to target removed"];
	XCTestExpectation *fileMovedOntoItselfFailsExpectation = [self expectationWithDescription:@"fileMovedOntoItselfFails"];
	__block XCTestExpectation *fileCopiedNotificationExpectation = [self expectationWithDescription:@"File copied notification"];
	__block XCTestExpectation *folderCopiedNotificationExpectation = [self expectationWithDescription:@"Folder copied notification"];
	__block XCTestExpectation *fileDisappearedExpectation = [self expectationWithDescription:@"File disappeared."];
	__block XCTestExpectation *fileReappearedExpectation = [self expectationWithDescription:@"File reappeared."];
	__block XCTestExpectation *folderDisappearedExpectation = [self expectationWithDescription:@"Folder disappeared."];
	__block XCTestExpectation *folderReappearedExpectation = [self expectationWithDescription:@"Folder reappeared."];
	NSString *folderName = NSUUID.UUID.UUIDString;
	__block OCItem *moveFolderItem, *moveFileItem;
	__block OCLocalID localIDFileInitial=nil, localIDFileAfterMove=nil, localIDFileMoveBack=nil, localIDFileQueryAfterMove=nil, localIDFileQueryMoveBack=nil;
	__block OCLocalID localIDFolderInitial=nil, localIDFolderAfterMove=nil, localIDFolderMoveBack=nil, localIDFolderQueryAfterMove=nil, localIDFolderQueryMoveBack=nil;
	__block OCLocalID localIDFileParentInitial=nil, localIDFolderParentInitial=nil, localIDRootInitial=nil, localIDFileParentMoveBack=nil, localIDFolderParentMoveBack=nil;
	__block OCLocalID localIDTargetFolderInitial=nil, localIDFileParentAfterMove=nil, localIDFolderParentAfterMove=nil;
	CoreSyncTestsIssueDismisser *issueDismisser = [CoreSyncTestsIssueDismisser new];

	// Create bookmark for demo.owncloud.org
	bookmark = [OCBookmark bookmarkForURL:OCTestTarget.secureTargetURL];
	bookmark.authenticationData = [OCAuthenticationMethodBasicAuth authenticationDataForUsername:OCTestTarget.userLogin passphrase:OCTestTarget.userPassword authenticationHeaderValue:NULL error:NULL];
	bookmark.authenticationMethodIdentifier = OCAuthenticationMethodIdentifierBasicAuth;

	// Create core with it
	core = [[OCCore alloc] initWithBookmark:bookmark];
	core.delegate = issueDismisser;
	core.automaticItemListUpdatesEnabled = NO;

	// Start core
	[core startWithCompletionHandler:^(OCCore *core, NSError *error) {
		OCQuery *query;

		XCTAssert((error==nil), @"Started with error: %@", error);
		[coreStartedExpectation fulfill];

		core.database.itemFilter = self.databaseSanityCheckFilter;

		OCLog(@"Vault location: %@", core.vault.rootURL);

		query = [OCQuery queryForPath:@"/"];
		query.changesAvailableNotificationHandler = ^(OCQuery *query) {
			[query requestChangeSetWithFlags:OCQueryChangeSetRequestFlagDefault completionHandler:^(OCQuery *query, OCQueryChangeSet *changeset) {
				if (changeset != nil)
				{
					OCLog(@"============================================");
					OCLog(@"[%@] QUERY STATE: %lu", query.queryPath, (unsigned long)query.state);

					OCLog(@"[%@] Query result: %@", query.queryPath, changeset.queryResult);
					[changeset enumerateChangesUsingBlock:^(OCQueryChangeSet *changeSet, OCQueryChangeSetOperation operation, NSArray<OCItem *> *items, NSIndexSet *indexSet) {
						switch(operation)
						{
							case OCQueryChangeSetOperationInsert:
								OCLog(@"[%@] Insertions: %@", query.queryPath, items);
							break;

							case OCQueryChangeSetOperationRemove:
								OCLog(@"[%@] Removals: %@", query.queryPath, items);
							break;

							case OCQueryChangeSetOperationUpdate:
								OCLog(@"[%@] Updates: %@", query.queryPath, items);
							break;

							case OCQueryChangeSetOperationContentSwap:
								OCLog(@"[%@] Content Swap", query.queryPath);
							break;
						}
					}];
				}

				if (query.state == OCQueryStateIdle)
				{
					if (!didCreateFolder)
					{
						localIDRootInitial = query.rootItem.localID;

						for (OCItem *item in query.queryResults)
						{
							if (item.type == OCItemTypeFile)
							{
								moveFileItem = item;
								localIDFileInitial = item.localID;
								localIDFileParentInitial = item.parentLocalID;
							}

							if (item.type == OCItemTypeCollection)
							{
								moveFolderItem = item;
								localIDFolderInitial = item.localID;
								localIDFolderParentInitial = item.parentLocalID;
							}
						}

						didCreateFolder = YES;

						[core createFolder:folderName inside:query.rootItem options:nil resultHandler:^(NSError *error, OCCore *core, OCItem *item, id parameter) {
							XCTAssert(error==nil);
							XCTAssert(item!=nil);

							[dirCreatedExpectation fulfill];

							localIDTargetFolderInitial = item.localID;

							newFolderQuery = [OCQuery queryForPath:item.path];
							newFolderQuery.changesAvailableNotificationHandler = ^(OCQuery *query) {
								[query requestChangeSetWithFlags:OCQueryChangeSetRequestFlagDefault completionHandler:^(OCQuery *query, OCQueryChangeSet *changeset) {
									if (changeset != nil)
									{
										OCLog(@"============================================");
										OCLog(@"[%@] NEW QUERY STATE: %lu", query.queryPath, (unsigned long)query.state);

										OCLog(@"[%@] NEW Query result: %@", query.queryPath, changeset.queryResult);
										[changeset enumerateChangesUsingBlock:^(OCQueryChangeSet *changeSet, OCQueryChangeSetOperation operation, NSArray<OCItem *> *items, NSIndexSet *indexSet) {
											switch(operation)
											{
												case OCQueryChangeSetOperationInsert:
													OCLog(@"[%@] Insertions: %@", query.queryPath, items);
												break;

												case OCQueryChangeSetOperationRemove:
													OCLog(@"[%@] Removals: %@", query.queryPath, items);
												break;

												case OCQueryChangeSetOperationUpdate:
													OCLog(@"[%@] Updates: %@", query.queryPath, items);
												break;

												case OCQueryChangeSetOperationContentSwap:
													OCLog(@"[%@] Content Swap", query.queryPath);
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

												if (localIDFolderQueryAfterMove == nil)
												{
													localIDFolderQueryAfterMove = item.localID;
												}
												else
												{
													XCTAssert([localIDFolderQueryAfterMove isEqual:item.localID]);
												}
											}

											if ([item.name isEqualToString:[moveFileItem.name stringByAppendingString:@" moved"]])
											{
												[fileCopiedNotificationExpectation fulfill];
												fileCopiedNotificationExpectation = nil;

												if (localIDFileQueryAfterMove == nil)
												{
													localIDFileQueryAfterMove = item.localID;
												}
												else
												{
													XCTAssert([localIDFileQueryAfterMove isEqual:item.localID]);
												}
											}
										}
									}

									if (query.state == OCQueryStateTargetRemoved)
									{
										[targetRemovedStateChangeExpectation fulfill];
										targetRemovedStateChangeExpectation = nil;
									}
								}];
							};

							[core startQuery:newFolderQuery];

							[core moveItem:moveFolderItem to:item withName:[moveFolderItem.name stringByAppendingString:@" moved"] options:nil resultHandler:^(NSError *error, OCCore *core, OCItem *newItem, id parameter) {
								OCLog(@"Move folder item: error=%@ item=%@", error, newItem);

								XCTAssert(error==nil);
								XCTAssert(newItem!=nil);
								XCTAssert([newItem.parentFileID isEqual:item.fileID]);
								XCTAssert([newItem.name isEqual:[moveFolderItem.name stringByAppendingString:@" moved"]]);

								localIDFolderAfterMove = newItem.localID;
								localIDFolderParentAfterMove = newItem.parentLocalID;

								XCTAssert([localIDTargetFolderInitial isEqual:localIDFolderParentAfterMove]);

								[folderMovedExpectation fulfill];

								[core moveItem:newItem to:query.rootItem withName:moveFolderItem.name options:nil resultHandler:^(NSError *error, OCCore *core, OCItem *newItem, id parameter) {
									OCLog(@"Move folder item back: error=%@ item=%@", error, newItem);

									XCTAssert(error==nil);
									XCTAssert(newItem!=nil);
									XCTAssert([newItem.parentFileID isEqual:query.rootItem.fileID]);
									XCTAssert([newItem.name isEqual:moveFolderItem.name]);

									localIDFolderMoveBack = newItem.localID;
									localIDFolderParentMoveBack = newItem.parentLocalID;

									[folderMovedBackExpectation fulfill];
								}];
							}];

							[core moveItem:moveFileItem to:item withName:[moveFileItem.name stringByAppendingString:@" moved"] options:nil resultHandler:^(NSError *error, OCCore *core, OCItem *newItem, id parameter) {
								OCLog(@"Move file item: error=%@ item=%@", error, newItem);

								XCTAssert(error==nil);
								XCTAssert(newItem!=nil);
								XCTAssert([newItem.parentFileID isEqual:item.fileID]);
								XCTAssert([newItem.name isEqual:[moveFileItem.name stringByAppendingString:@" moved"]]);

								localIDFileAfterMove = newItem.localID;
								localIDFileParentAfterMove = newItem.parentLocalID;

								XCTAssert([localIDTargetFolderInitial isEqual:localIDFileParentAfterMove]);

								[fileMovedExpectation fulfill];

								[core moveItem:newItem to:query.rootItem withName:moveFileItem.name options:nil resultHandler:^(NSError *error, OCCore *core, OCItem *newItem, id parameter) {
									OCLog(@"Move file item back: error=%@ item=%@", error, newItem);

									XCTAssert(error==nil);
									XCTAssert(newItem!=nil);
									XCTAssert([newItem.parentFileID isEqual:query.rootItem.fileID]);
									XCTAssert([newItem.name isEqual:moveFileItem.name]);

									localIDFileMoveBack = newItem.localID;
									localIDFileParentMoveBack = newItem.parentLocalID;

									[fileMovedBackExpectation fulfill];

									[core moveItem:newItem to:query.rootItem withName:newItem.name options:nil resultHandler:^(NSError *error, OCCore *core, OCItem *newItem, id parameter) {
										OCLog(@"Move file item to existing location: error=%@ item=%@", error, newItem);

										XCTAssert(error!=nil);
										XCTAssert([error.domain isEqual:OCErrorDomain]);
										XCTAssert(error.code == OCErrorItemAlreadyExists);
										XCTAssert(newItem==nil);

										[fileMovedOntoItselfFailsExpectation fulfill];

										[core deleteItem:item requireMatch:YES resultHandler:^(NSError *error, OCCore *core, OCItem *item, id parameter) {
											OCLog(@"Delete test folder: error=%@ item=%@", error, item);

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
						OCItem *fileItem = nil, *folderItem = nil;

						for (OCItem *item in query.queryResults)
						{
							if ([item.itemVersionIdentifier isEqual:moveFileItem.itemVersionIdentifier])
							{
								hasSeenFile = YES;
								fileItem = item;
							}

							if ([item.itemVersionIdentifier isEqual:moveFolderItem.itemVersionIdentifier])
							{
								hasSeenFolder = YES;
								folderItem = item;
							}
						}

						if (hasSeenFile)
						{
							if (fileDisappearedExpectation == nil)
							{
								[fileReappearedExpectation fulfill];
								fileReappearedExpectation = nil;

								if (localIDFileQueryMoveBack == nil)
								{
									localIDFileQueryMoveBack = fileItem.localID;
								}
								else
								{
									XCTAssert([localIDFileQueryMoveBack isEqual:fileItem.localID]);
								}
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

								if (localIDFolderQueryMoveBack == nil)
								{
									localIDFolderQueryMoveBack = folderItem.localID;
								}
								else
								{
									XCTAssert([localIDFolderQueryMoveBack isEqual:folderItem.localID]);
								}
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

	XCTAssert([localIDFileInitial isEqual:localIDFileAfterMove]);
	XCTAssert([localIDFileInitial isEqual:localIDFileMoveBack]);
	XCTAssert([localIDFileInitial isEqual:localIDFileQueryAfterMove]);
	XCTAssert([localIDFileInitial isEqual:localIDFileQueryMoveBack]);

	XCTAssert([localIDFolderInitial isEqual:localIDFolderAfterMove]);
	XCTAssert([localIDFolderInitial isEqual:localIDFolderMoveBack]);
	XCTAssert([localIDFolderInitial isEqual:localIDFolderQueryAfterMove]);
	XCTAssert([localIDFolderInitial isEqual:localIDFolderQueryMoveBack]);

	XCTAssert([localIDFileParentInitial isEqual:localIDFolderParentInitial]);
	XCTAssert([localIDFileParentInitial isEqual:localIDRootInitial]);
	XCTAssert([localIDFileParentInitial isEqual:localIDFileParentMoveBack]);
	XCTAssert([localIDFileParentInitial isEqual:localIDFolderParentMoveBack]);

	XCTAssert([localIDTargetFolderInitial isEqual:localIDFileParentAfterMove]);
	XCTAssert([localIDTargetFolderInitial isEqual:localIDFolderParentAfterMove]);
	XCTAssert([localIDFileParentAfterMove isEqual:localIDFolderParentAfterMove]);

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
	core.automaticItemListUpdatesEnabled = NO;

	// Start core
	[core startWithCompletionHandler:^(OCCore *core, NSError *error) {
		OCQuery *query;

		XCTAssert((error==nil), @"Started with error: %@", error);
		[coreStartedExpectation fulfill];

		core.database.itemFilter = self.databaseSanityCheckFilter;

		OCLog(@"Vault location: %@", core.vault.rootURL);

		query = [OCQuery queryForPath:@"/Photos/"];
		query.changesAvailableNotificationHandler = ^(OCQuery *query) {
			[query requestChangeSetWithFlags:OCQueryChangeSetRequestFlagDefault completionHandler:^(OCQuery *query, OCQueryChangeSet *changeset) {
				if (changeset != nil)
				{
					OCLog(@"============================================");
					OCLog(@"[%@] QUERY STATE: %lu", query.queryPath, (unsigned long)query.state);

					OCLog(@"[%@] Query result: %@", query.queryPath, changeset.queryResult);
					[changeset enumerateChangesUsingBlock:^(OCQueryChangeSet *changeSet, OCQueryChangeSetOperation operation, NSArray<OCItem *> *items, NSIndexSet *indexSet) {
						switch(operation)
						{
							case OCQueryChangeSetOperationInsert:
								OCLog(@"[%@] Insertions: %@", query.queryPath, items);
							break;

							case OCQueryChangeSetOperationRemove:
								OCLog(@"[%@] Removals: %@", query.queryPath, items);
							break;

							case OCQueryChangeSetOperationUpdate:
								OCLog(@"[%@] Updates: %@", query.queryPath, items);
							break;

							case OCQueryChangeSetOperationContentSwap:
								OCLog(@"[%@] Content Swap", query.queryPath);
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
								OCLocalID fileLocalID = item.localID;
								OCLocalID fileLocalParentID = item.parentLocalID;

								remainingRenames += 4;

								OCLog(@"Renaming %@ -> %@ -> %@ -> %@ -> %@ (%@)", originalName, modifiedName1, modifiedName2, modifiedName3, originalName, query.queryResults);

								[core renameItem:item to:modifiedName1 options:nil resultHandler:^(NSError *error, OCCore *core, OCItem *newItem, id parameter) {
									OCLog(@"Renamed %@ -> %@: error=%@ item=%@", originalName, newItem.name, error, newItem);
									remainingRenames--;

									XCTAssert(error==nil);
									XCTAssert(newItem!=nil);
									XCTAssert([newItem.parentFileID isEqual:query.rootItem.fileID]);
									XCTAssert([newItem.name isEqual:modifiedName1]);
									XCTAssert([fileLocalID isEqual:newItem.localID]);
									XCTAssert([fileLocalParentID isEqual:newItem.parentLocalID]);

									[core renameItem:newItem to:modifiedName2 options:nil resultHandler:^(NSError *error, OCCore *core, OCItem *newItem, id parameter) {
										OCLog(@"Renamed %@ -> %@: error=%@ item=%@", modifiedName1, newItem.name, error, newItem);
										remainingRenames--;

										XCTAssert(error==nil);
										XCTAssert(newItem!=nil);
										XCTAssert([newItem.parentFileID isEqual:query.rootItem.fileID]);
										XCTAssert([newItem.name isEqual:modifiedName2]);
										XCTAssert([fileLocalID isEqual:newItem.localID]);
										XCTAssert([fileLocalParentID isEqual:newItem.parentLocalID]);

										[core renameItem:newItem to:modifiedName3 options:nil resultHandler:^(NSError *error, OCCore *core, OCItem *newItem, id parameter) {
											OCLog(@"Renamed %@ -> %@: error=%@ item=%@", modifiedName2, newItem.name, error, newItem);
											remainingRenames--;

											XCTAssert(error==nil);
											XCTAssert(newItem!=nil);
											XCTAssert([newItem.parentFileID isEqual:query.rootItem.fileID]);
											XCTAssert([newItem.name isEqual:modifiedName3]);
											XCTAssert([fileLocalID isEqual:newItem.localID]);
											XCTAssert([fileLocalParentID isEqual:newItem.parentLocalID]);

											[core renameItem:newItem to:originalName options:nil resultHandler:^(NSError *error, OCCore *core, OCItem *newItem, id parameter) {
												OCLog(@"Renamed %@ -> %@: error=%@ item=%@", modifiedName3, newItem.name, error, newItem);
												remainingRenames--;

												XCTAssert(error==nil);
												XCTAssert(newItem!=nil);
												XCTAssert([newItem.parentFileID isEqual:query.rootItem.fileID]);
												XCTAssert([newItem.name isEqual:originalName]);
												XCTAssert([fileLocalID isEqual:newItem.localID]);
												XCTAssert([fileLocalParentID isEqual:newItem.parentLocalID]);

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
						OCLog(@"Query update! %@", query.queryResults);
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
	__block OCLocalID localIDQueryBeforeDownload=nil, localIDAfterDownload=nil, localIDQueryAfterDownload=nil;
	__block OCFileID downloadFileID = nil;
	__block BOOL startedDownload = NO;

	// Create bookmark for demo.owncloud.org
	bookmark = [OCBookmark bookmarkForURL:OCTestTarget.secureTargetURL];
	bookmark.authenticationData = [OCAuthenticationMethodBasicAuth authenticationDataForUsername:OCTestTarget.userLogin passphrase:OCTestTarget.userPassword authenticationHeaderValue:NULL error:NULL];
	bookmark.authenticationMethodIdentifier = OCAuthenticationMethodIdentifierBasicAuth;

	// Create core with it
	core = [[OCCore alloc] initWithBookmark:bookmark];
	core.automaticItemListUpdatesEnabled = NO;

	// Start core
	[core startWithCompletionHandler:^(OCCore *core, NSError *error) {
		OCQuery *query;

		XCTAssert((error==nil), @"Started with error: %@", error);
		[coreStartedExpectation fulfill];

		core.database.itemFilter = self.databaseSanityCheckFilter;

		OCLog(@"Vault location: %@", core.vault.rootURL);

		query = [OCQuery queryForPath:@"/"];
		query.changesAvailableNotificationHandler = ^(OCQuery *query) {
			[query requestChangeSetWithFlags:OCQueryChangeSetRequestFlagDefault completionHandler:^(OCQuery *query, OCQueryChangeSet *changeset) {
				if (changeset != nil)
				{
					OCLog(@"============================================");
					OCLog(@"[%@] QUERY STATE: %lu", query.queryPath, (unsigned long)query.state);

					OCLog(@"[%@] Query result: %@", query.queryPath, changeset.queryResult);
					[changeset enumerateChangesUsingBlock:^(OCQueryChangeSet *changeSet, OCQueryChangeSetOperation operation, NSArray<OCItem *> *items, NSIndexSet *indexSet) {
						switch(operation)
						{
							case OCQueryChangeSetOperationInsert:
								OCLog(@"[%@] Insertions: %@", query.queryPath, items);
							break;

							case OCQueryChangeSetOperationRemove:
								OCLog(@"[%@] Removals: %@", query.queryPath, items);
							break;

							case OCQueryChangeSetOperationUpdate:
								OCLog(@"[%@] Updates: %@", query.queryPath, items);
							break;

							case OCQueryChangeSetOperationContentSwap:
								OCLog(@"[%@] Content Swap", query.queryPath);
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

							localIDQueryBeforeDownload = item.localID;

							downloadFileID = item.fileID;

							[core downloadItem:item options:nil resultHandler:^(NSError *error, OCCore *core, OCItem *item, OCFile *file) {
								OCLog(@"Downloaded to %@ with error %@", file.url, error);

								[fileDownloadedExpectation fulfill];

								localIDAfterDownload = item.localID;

								XCTAssert(error==nil);
								XCTAssert(file.url!=nil);

								/* OCFile tests ***/
								{
									#pragma clang diagnostic push
									#pragma clang diagnostic ignored "-Wdeprecated-declarations"
									NSData *fileData = [NSKeyedArchiver archivedDataWithRootObject:file];
									OCFile *recreatedFile = [NSKeyedUnarchiver unarchiveObjectWithData:fileData];
									#pragma clang diagnostic pop

									XCTAssert([recreatedFile.url isEqual:file.url]);
									XCTAssert([recreatedFile.fileID isEqual:file.fileID]);
									XCTAssert([recreatedFile.eTag isEqual:file.eTag]);
									XCTAssert([recreatedFile.checksum isEqual:file.checksum]);
									XCTAssert([recreatedFile.item.itemVersionIdentifier isEqual:file.item.itemVersionIdentifier]);

									XCTAssert([OCFile supportsSecureCoding] == YES);
								}
								/*** OCFile tests */

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
						else if (downloadFileID != nil)
						{
							if ([item.fileID isEqual:downloadFileID] && (item.localRelativePath != nil))
							{
								localIDQueryAfterDownload = item.localID;
							}
						}
					}
				}
			}];
		};

		[core startQuery:query];
	}];

	[self waitForExpectationsWithTimeout:60 handler:nil];

	XCTAssert([localIDQueryBeforeDownload isEqualToString:localIDAfterDownload]);
	XCTAssert([localIDQueryBeforeDownload isEqualToString:localIDQueryAfterDownload]);

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
	__block OCLocalID localIDOnQueryPlaceholder = nil, localIDOnQueryActual=nil;
	__block OCLocalID localIDUploadActionPlaceholder=nil, localIDUploadActionCompletion=nil, localIDUpdateActionPlaceholder=nil, localIDUpdateActionCompletion=nil;
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
	core.automaticItemListUpdatesEnabled = NO;

	// Start core
	[core startWithCompletionHandler:^(OCCore *core, NSError *error) {
		OCQuery *query;

		XCTAssert((error==nil), @"Started with error: %@", error);
		[coreStartedExpectation fulfill];

		core.database.itemFilter = self.databaseSanityCheckFilter;

		OCLog(@"Vault location: %@", core.vault.rootURL);

		query = [OCQuery queryForPath:@"/"];
		query.changesAvailableNotificationHandler = ^(OCQuery *query) {
			[query requestChangeSetWithFlags:OCQueryChangeSetRequestFlagDefault completionHandler:^(OCQuery *query, OCQueryChangeSet *changeset) {
				if (changeset != nil)
				{
					OCLog(@"============================================");
					OCLog(@"[%@] QUERY STATE: %lu", query.queryPath, (unsigned long)query.state);

					OCLog(@"[%@] Query result: %@", query.queryPath, changeset.queryResult);
					[changeset enumerateChangesUsingBlock:^(OCQueryChangeSet *changeSet, OCQueryChangeSetOperation operation, NSArray<OCItem *> *items, NSIndexSet *indexSet) {
						switch(operation)
						{
							case OCQueryChangeSetOperationInsert:
								OCLog(@"[%@] Insertions: %@", query.queryPath, items);
							break;

							case OCQueryChangeSetOperationRemove:
								OCLog(@"[%@] Removals: %@", query.queryPath, items);
							break;

							case OCQueryChangeSetOperationUpdate:
								OCLog(@"[%@] Updates: %@", query.queryPath, items);
							break;

							case OCQueryChangeSetOperationContentSwap:
								OCLog(@"[%@] Content Swap", query.queryPath);
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

								OCLog(@"### Placeholder item: %@", item);

								localIDUploadActionPlaceholder = item.localID;

								[placeholderCreatedExpectation fulfill];
							} resultHandler:^(NSError *error, OCCore *core, OCItem *item, id parameter) {
								XCTAssert(error==nil);
								XCTAssert(item!=nil);
								XCTAssert(!item.isPlaceholder);
								XCTAssert([ComputeChecksumForURL([core localURLForItem:item]) isEqual:uploadFileChecksum]);

								OCLog(@"### Uploaded item: %@", item);

								localIDUploadActionCompletion = item.localID;

								[fileUploadedExpectation fulfill];

								// Test upload by local modification
								[core reportLocalModificationOfItem:item parentItem:query.rootItem withContentsOfFileAtURL:modifiedFileURL isSecurityScoped:NO options:nil placeholderCompletionHandler:^(NSError *error, OCItem *item) {
									XCTAssert(item!=nil);
									XCTAssert(!item.isPlaceholder);
									XCTAssert([ComputeChecksumForURL([core localURLForItem:item]) isEqual:modifiedFileChecksum]);

									OCLog(@"### Update \"placeholder\" item=%@ error=%@", item, error);

									localIDUpdateActionPlaceholder = item.localID;

									[modificationItemCreatedExpectation fulfill];
								} resultHandler:^(NSError *error, OCCore *core, OCItem *item, id parameter) {
									XCTAssert(error==nil);
									XCTAssert(item!=nil);
									XCTAssert(!item.isPlaceholder);
									XCTAssert([ComputeChecksumForURL([core localURLForItem:item]) isEqual:modifiedFileChecksum]);

									OCLog(@"### Uploaded updated item=%@, error=%@", item, error);

									localIDUpdateActionCompletion = item.localID;

									[updatedFileUploadedExpectation fulfill];

									// Stop core
									[core stopWithCompletionHandler:^(id sender, NSError *error) {
										XCTAssert((error==nil), @"Stopped with error: %@", error);

										[coreStoppedExpectation fulfill];
									}];
								}];
							}];
						}
						else
						{
							for (OCItem *item in changeset.queryResult)
							{
								if ([item.name isEqualToString:uploadName])
								{
									if (item.isPlaceholder && (localIDOnQueryPlaceholder==nil))
									{
										localIDOnQueryPlaceholder = item.localID;
									}

									if (!item.isPlaceholder && (localIDOnQueryActual==nil))
									{
										localIDOnQueryActual = item.localID;
									}
								}
							}
						}
					}
				}
			}];
		};

		[core startQuery:query];
	}];

	[self waitForExpectationsWithTimeout:60 handler:nil];

	XCTAssert([localIDOnQueryActual isEqual:localIDOnQueryPlaceholder]);
	XCTAssert([localIDOnQueryActual isEqual:localIDUploadActionPlaceholder]);
	XCTAssert([localIDOnQueryActual isEqual:localIDUploadActionCompletion]);
	XCTAssert([localIDOnQueryActual isEqual:localIDUpdateActionPlaceholder]);
	XCTAssert([localIDOnQueryActual isEqual:localIDUpdateActionCompletion]);

	// Erase vault
	[core.vault eraseSyncWithCompletionHandler:^(id sender, NSError *error) {
		XCTAssert((error==nil), @"Erased with error: %@", error);
	}];

}

- (void)testItemUpdates
{
	OCBookmark *bookmark = [OCTestTarget userBookmark];
	OCCore *core;
	XCTestExpectation *coreStartedExpectation = [self expectationWithDescription:@"Core started"];
	XCTestExpectation *coreStoppedExpectation = [self expectationWithDescription:@"Core stopped"];
	XCTestExpectation *favoriteSetExpectation = [self expectationWithDescription:@"Favorite set"];
	XCTestExpectation *favoriteUnsetExpectation = [self expectationWithDescription:@"Favorite unset"];
	XCTestExpectation *propFindReturnedExpectation = [self expectationWithDescription:@"PROPFIND returned"];
	__block BOOL didFavorite = NO;
	__block OCLocalID localIDBeforeUpdate=nil, localIDAfterFirstUpdate=nil, localIDAfterSecondUpdate = nil;

	// Create core with bookmark
	core = [[OCCore alloc] initWithBookmark:bookmark];
	core.automaticItemListUpdatesEnabled = NO;

	// Start core
	[core startWithCompletionHandler:^(OCCore *core, NSError *error) {
		OCQuery *query;

		XCTAssert((error==nil), @"Started with error: %@", error);
		[coreStartedExpectation fulfill];

		core.database.itemFilter = self.databaseSanityCheckFilter;

		OCLog(@"Vault location: %@", core.vault.rootURL);

		query = [OCQuery queryForPath:@"/"];
		query.changesAvailableNotificationHandler = ^(OCQuery *query) {
			[query requestChangeSetWithFlags:OCQueryChangeSetRequestFlagDefault completionHandler:^(OCQuery *query, OCQueryChangeSet *changeset) {
				if (query.state == OCQueryStateIdle)
				{
					for (OCItem *item in changeset.queryResult)
					{
						OCLog(@"queryResult=%@", changeset.queryResult);

						if ((item.type == OCItemTypeFile) && (!item.isFavorite.boolValue) && !didFavorite)
						{
							NSArray *propertiesToUpdate = @[ OCItemPropertyNameIsFavorite ];

							didFavorite = YES;

							item.isFavorite = @(YES);

							localIDBeforeUpdate = item.localID;

							[core updateItem:item properties:propertiesToUpdate options:nil resultHandler:^(NSError *error, OCCore *core, OCItem *item, NSDictionary <OCItemPropertyName, OCHTTPStatus *> *statusByPropertyName) {
								OCLog(@"Update item=%@ result: error=%@, statusByPropertyName=%@", item, error, statusByPropertyName);

								for (OCItemPropertyName propertyName in propertiesToUpdate)
								{
									XCTAssert(statusByPropertyName[propertyName].isSuccess);
								}

								[favoriteSetExpectation fulfill];

								localIDAfterFirstUpdate = item.localID;

								[core.connection retrieveItemListAtPath:item.path depth:0 completionHandler:^(NSError *error, NSArray<OCItem *> *items) {
									XCTAssert(items.count == 1);
									XCTAssert(items.firstObject.isFavorite.boolValue);

									[propFindReturnedExpectation fulfill];

									item.isFavorite = @(NO);

									[core updateItem:item properties:propertiesToUpdate options:nil resultHandler:^(NSError *error, OCCore *core, OCItem *item, id parameter) {
										OCLog(@"Update item=%@ result: error=%@, statusByPropertyName=%@", item, error, statusByPropertyName);

										localIDAfterSecondUpdate = item.localID;

										for (OCItemPropertyName propertyName in propertiesToUpdate)
										{
											XCTAssert(statusByPropertyName[propertyName].isSuccess);
										}

										[favoriteUnsetExpectation fulfill];

										[core.connection retrieveItemListAtPath:item.path depth:0 completionHandler:^(NSError *error, NSArray<OCItem *> *items) {
											XCTAssert(items.count == 1);
											XCTAssert(!items.firstObject.isFavorite.boolValue);

											// Stop core
											[core stopWithCompletionHandler:^(id sender, NSError *error) {
												XCTAssert((error==nil), @"Stopped with error: %@", error);

												[coreStoppedExpectation fulfill];
											}];
										}];
									}];
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

	XCTAssert([localIDBeforeUpdate isEqual:localIDAfterFirstUpdate]);
	XCTAssert([localIDBeforeUpdate isEqual:localIDAfterSecondUpdate]);

	// Erase vault
	[core.vault eraseSyncWithCompletionHandler:^(id sender, NSError *error) {
		XCTAssert((error==nil), @"Erased with error: %@", error);
	}];
}

@end
