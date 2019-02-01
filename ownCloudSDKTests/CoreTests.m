//
//  CoreTests.m
//  ownCloudSDKTests
//
//  Created by Felix Schwarz on 04.04.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <ownCloudSDK/ownCloudSDK.h>
#import <ownCloudMocking/ownCloudMocking.h>
#import "OCCore+Internal.h"
#import "TestTools.h"
#import "XCTestCase+Tagging.h"

#import "OCTestTarget.h"

@interface CoreTests : XCTestCase <OCCoreDelegate>
{
	void (^coreErrorHandler)(OCCore *core, NSError *error, OCIssue *issue);
}

@end

@implementation CoreTests

#pragma mark - Tests
- (void)testStartStopCoreAndEraseVault
{
	OCBookmark *bookmark = nil;
	OCCore *core;
	XCTestExpectation *coreStartedExpectation = [self expectationWithDescription:@"Core started"];
	XCTestExpectation *coreStoppedExpectation = [self expectationWithDescription:@"Core stopped"];
	XCTestExpectation *vaultErasedExpectation = [self expectationWithDescription:@"Vault erased"];

	// Create bookmark for demo.owncloud.org
	bookmark = [OCBookmark bookmarkForURL:OCTestTarget.secureTargetURL];
	bookmark.authenticationData = [OCAuthenticationMethodBasicAuth authenticationDataForUsername:OCTestTarget.userLogin passphrase:OCTestTarget.userPassword authenticationHeaderValue:NULL error:NULL];
	bookmark.authenticationMethodIdentifier = OCAuthenticationMethodIdentifierBasicAuth;

	// Create core with it
	core = [[OCCore alloc] initWithBookmark:bookmark];
	core.automaticItemListUpdatesEnabled = NO;

	core.stateChangedHandler = ^(OCCore *core) {
		if (core.state == OCCoreStateRunning)
		{
			// Stop core
			[core stopWithCompletionHandler:^(id sender, NSError *error) {
				NSURL *vaultRootURL = core.vault.rootURL;

				XCTAssert((error==nil), @"Stopped with error: %@", error);

				[coreStoppedExpectation fulfill];

				// Erase vault
				[core.vault eraseWithCompletionHandler:^(id sender, NSError *error) {
					XCTAssert((error==nil), @"Erased with error: %@", error);

					if (![[NSFileManager defaultManager] fileExistsAtPath:vaultRootURL.path])
					{
						[vaultErasedExpectation fulfill];
					}
				}];
			}];
		}
	};

	// Start core
	[core startWithCompletionHandler:^(OCCore *core, NSError *error) {
		XCTAssert((error==nil), @"Started with error: %@", error);

		[coreStartedExpectation fulfill];

		OCLog(@"Vault location: %@", core.vault.rootURL);
	}];

	[self waitForExpectationsWithTimeout:60 handler:nil];
}

- (void)testSimpleQuery
{
	OCBookmark *bookmark = nil;
	OCCore *core;
	__block OCQuery *subfolderQuery = nil;
	XCTestExpectation *coreStartedExpectation = [self expectationWithDescription:@"Core started"];
	XCTestExpectation *coreStoppedExpectation = [self expectationWithDescription:@"Core stopped"];

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

		core.vault.database.itemFilter = self.databaseSanityCheckFilter;

		XCTAssert((error==nil), @"Started with error: %@", error);
		[coreStartedExpectation fulfill];

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

					if (query.state == OCQueryStateIdle)
					{
						// Verify parentFileID
						XCTAssert(query.rootItem!=nil); // Root item exists
						XCTAssert(query.rootItem.fileID!=nil); // Root item has fileID
						XCTAssert(query.rootItem.parentFileID==nil); // Root item has no parentFileID
						XCTAssert(query.rootItem.localID!=nil); // Root item has localID
						XCTAssert(query.rootItem.parentLocalID==nil); // Root item has no parentLocalID

						for (OCItem *item in changeset.queryResult)
						{
							XCTAssert(item.fileID!=nil); // all items in the result have a file ID
							XCTAssert(item.parentFileID!=nil); // all items in the result have a parent file ID
							XCTAssert([item.parentFileID isEqual:query.rootItem.fileID]); // all items in result have the parentFileID of their parent dir
							XCTAssert(item.parentLocalID!=nil); // all items in the result have a parent local ID
							XCTAssert([item.parentLocalID isEqual:query.rootItem.localID]); // all items in result have the parentLocalID of their parent dir
						}
					}
				}

				if (query.state == OCQueryStateIdle)
				{
					if (subfolderQuery==nil)
					{
						OCPath subfolderPath = nil;
						OCItem *firstQueryRootItem = query.rootItem;

						for (OCItem *item in query.queryResults)
						{
							if (item.type == OCItemTypeCollection)
							{
								subfolderPath = item.path;
							}
						}

						subfolderQuery = [OCQuery queryForPath:subfolderPath];
						subfolderQuery.changesAvailableNotificationHandler = ^(OCQuery *query) {
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
									// Verify parentFileID
									XCTAssert(query.rootItem!=nil); // Root item exists
									XCTAssert(query.rootItem.fileID!=nil); // Root item has fileID
									XCTAssert(query.rootItem.parentFileID!=nil); // Root item has parentFileID
									XCTAssert([query.rootItem.parentFileID isEqual:firstQueryRootItem.fileID]); // all items in result have the parentFileID of their parent dir
									XCTAssert(query.rootItem.localID!=nil); // Root item has localID
									XCTAssert(query.rootItem.parentLocalID!=nil); // Root item has parentLocalID
									XCTAssert([query.rootItem.parentLocalID isEqual:firstQueryRootItem.localID]); // all items in result have the parentLocalID of their parent dir

									for (OCItem *item in changeset.queryResult)
									{
										XCTAssert(item.fileID!=nil); // all items in the result have a file ID
										XCTAssert(item.parentFileID!=nil); // all items in the result have a parent file ID
										XCTAssert([item.parentFileID isEqual:query.rootItem.fileID]); // all items in result have the parentFileID of their parent dir
										XCTAssert(item.parentLocalID!=nil); // all items in the result have a parent local ID
										XCTAssert([item.parentLocalID isEqual:query.rootItem.localID]); // all items in result have the parentLocalID of their parent dir
									}
								}

								if (query.state == OCQueryStateIdle)
								{
									// Stop core
									[core stopWithCompletionHandler:^(id sender, NSError *error) {
										XCTAssert((error==nil), @"Stopped with error: %@", error);

										[coreStoppedExpectation fulfill];

									}];
								}
							}];
						};

						[core startQuery:subfolderQuery];
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

- (void)testSimpleQueryWithSimulatedCacheUpdate
{
	OCBookmark *bookmark = nil;
	OCCore *core;
	__block OCQuery *subfolderQuery = nil;
	XCTestExpectation *coreStartedExpectation = [self expectationWithDescription:@"Core started"];
	XCTestExpectation *coreStoppedExpectation = [self expectationWithDescription:@"Core stopped"];
	__block BOOL didDisruptOnce = NO;

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

		core.vault.database.itemFilter = self.databaseSanityCheckFilter;

		XCTAssert((error==nil), @"Started with error: %@", error);
		[coreStartedExpectation fulfill];

		OCLog(@"Vault location: %@", core.vault.rootURL);

		query = [OCQuery queryForPath:@"/"];
		query.changesAvailableNotificationHandler = ^(OCQuery *query) {
			[query requestChangeSetWithFlags:OCQueryChangeSetRequestFlagDefault completionHandler:^(OCQuery *query, OCQueryChangeSet *changeset) {
				if ((query.state == OCQueryStateWaitingForServerReply) && !didDisruptOnce)
				{
					didDisruptOnce = YES;
					
					[core.vault.database increaseValueForCounter:OCCoreSyncAnchorCounter withProtectedBlock:^NSError *(NSNumber *previousCounterValue, NSNumber *newCounterValue) {
						OCLog(@"Increasing the counter while fetching is in progress from %@ => %@", previousCounterValue, newCounterValue);

						return (nil);
					} completionHandler:^(NSError *error, NSNumber *previousCounterValue, NSNumber *newCounterValue) {

					}];
				}

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
					if (subfolderQuery==nil)
					{
						OCPath subfolderPath = nil;

						for (OCItem *item in query.queryResults)
						{
							if (item.type == OCItemTypeCollection)
							{
								subfolderPath = item.path;
							}
						}

						subfolderQuery = [OCQuery queryForPath:subfolderPath];
						subfolderQuery.changesAvailableNotificationHandler = ^(OCQuery *query) {
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
									// Stop core
									[core stopWithCompletionHandler:^(id sender, NSError *error) {
										XCTAssert((error==nil), @"Stopped with error: %@", error);

										[coreStoppedExpectation fulfill];

									}];
								}
							}];
						};

						[core startQuery:subfolderQuery];
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


- (void)testOfflineCaching
{
	OCBookmark *bookmark = nil;
	OCCore *core;
	OCHostSimulator *hostSimulator = [[OCHostSimulator alloc] init];
	__block BOOL connectionCut = NO;
	__block OCQuery *subfolderQuery = nil;
	__block NSMutableSet <OCPath> *idlePaths = [NSMutableSet new];
	__block NSMutableSet <OCPath> *fromCachePaths = [NSMutableSet new];

	XCTestExpectation *coreStartedExpectation = [self expectationWithDescription:@"Core started"];
	__block XCTestExpectation *coreStoppedExpectation = [self expectationWithDescription:@"Core stopped"];

	hostSimulator.unroutableRequestHandler = ^BOOL(OCConnection *connection, OCConnectionRequest *request, OCHostSimulatorResponseHandler responseHandler) {
		// Return host not found errors by default
		responseHandler([NSError errorWithDomain:(NSErrorDomain)kCFErrorDomainCFNetwork code:kCFHostErrorHostNotFound userInfo:nil], nil);

		return (YES);
	};

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

		core.vault.database.itemFilter = self.databaseSanityCheckFilter;

		XCTAssert((error==nil), @"Started with error: %@", error);
		[coreStartedExpectation fulfill];

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
					if (subfolderQuery == nil)
					{
						OCPath subfolderPath = nil;

						for (OCItem *item in query.queryResults)
						{
							if (item.type == OCItemTypeCollection)
							{
								subfolderPath = item.path;
							}
						}

						subfolderQuery = [OCQuery queryForPath:subfolderPath];
						subfolderQuery.changesAvailableNotificationHandler = ^(OCQuery *query) {
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
									if (!connectionCut)
									{
										connectionCut = YES;

										for (OCItem *item in changeset.queryResult)
										{
											[idlePaths addObject:item.path];

											XCTAssert(![item.path isEqualToString:query.queryPath], @"root item not contained in live results: %@", item);
										}

										dispatch_async(dispatch_get_main_queue(), ^{
											[core stopQuery:query];

											OCLog(@"================ ###### CUTTING OFF NETWORK ###### ================");
											core.connection.hostSimulator = hostSimulator; // the connection will now get host not found for every request

											[core startQuery:query];
										});
									}
								}

								if (query.state == OCQueryStateContentsFromCache)
								{
									for (OCItem *item in changeset.queryResult)
									{
										[fromCachePaths addObject:item.path];

										XCTAssert(![item.path isEqualToString:query.queryPath], @"root item not contained in cached results: %@", item);
									}

									XCTAssert((fromCachePaths.count==idlePaths.count), @"Same number of cached and idle paths");

									[fromCachePaths minusSet:idlePaths];

									XCTAssert((fromCachePaths.count==0), @"Same paths in cached and idle paths");

									// Stop core
									[core stopWithCompletionHandler:^(id sender, NSError *error) {
										XCTAssert((error==nil), @"Stopped with error: %@", error);

										[coreStoppedExpectation fulfill];
										coreStoppedExpectation = nil;
									}];
								}
							}];
						};

						[core startQuery:subfolderQuery];
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

- (void)testThumbnailRetrieval
{
	OCBookmark *bookmark = nil;
	OCCore *core;
	__block OCItemThumbnail *thumbnail1 = nil, *thumbnail2 = nil;
	XCTestExpectation *coreStartedExpectation = [self expectationWithDescription:@"Core started"];
	XCTestExpectation *coreStoppedExpectation = [self expectationWithDescription:@"Core stopped"];
	__block XCTestExpectation *requestOfLargerSizeExpectation = [self expectationWithDescription:@"Larger size expectation"];
	OCHostSimulator *hostSimulator = [[OCHostSimulator alloc] init];

	hostSimulator.unroutableRequestHandler = ^BOOL(OCConnection *connection, OCConnectionRequest *request, OCHostSimulatorResponseHandler responseHandler) {
		// Return host not found errors by default
		responseHandler([NSError errorWithDomain:(NSErrorDomain)kCFErrorDomainCFNetwork code:kCFHostErrorHostNotFound userInfo:nil], nil);

		XCTFail(@"Request for %@ when no request should have been made.", request.url);

		return (YES);
	};

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

		core.vault.database.itemFilter = self.databaseSanityCheckFilter;

		XCTAssert((error==nil), @"Started with error: %@", error);
		[coreStartedExpectation fulfill];

		OCLog(@"Vault location: %@", core.vault.rootURL);

		query = [OCQuery queryForPath:@"/Photos/"];
		query.changesAvailableNotificationHandler = ^(OCQuery *query) {

			OCLog(@"[%@] QUERY STATE: %lu", query.queryPath, (unsigned long)query.state);

			if (query.state == OCQueryStateIdle)
			{
				[query requestChangeSetWithFlags:OCQueryChangeSetRequestFlagDefault completionHandler:^(OCQuery *query, OCQueryChangeSet *changeset) {
					if (changeset != nil)
					{
						OCLog(@"[%@] Query result: %@", query.queryPath, changeset.queryResult);

						for (OCItem *item in changeset.queryResult)
						{
							if (item.thumbnailAvailability != OCItemThumbnailAvailabilityNone)
							{
								// Test that requests for thumbnails are queued, so that thumbnails aren't loaded several times from the server

								// 1) Keep core busy with other stuff for a bit
								[core queueBlock:^{
									sleep(2);
								}];

								// 2) Send first request
								[core retrieveThumbnailFor:item maximumSize:CGSizeMake(100, 100) scale:1.0 retrieveHandler:^(NSError *error, OCCore *core, OCItem *item, OCItemThumbnail *thumbnail, BOOL isOngoing, NSProgress *progress) {
									if (!isOngoing)
									{
										thumbnail1 = thumbnail;
									}
								}];

								// 3) Send second request
								[core retrieveThumbnailFor:item maximumSize:CGSizeMake(100, 100) scale:1.0 retrieveHandler:^(NSError *error, OCCore *core, OCItem *item, OCItemThumbnail *thumbnail, BOOL isOngoing, NSProgress *progress) {
									if (!isOngoing)
									{
										thumbnail2 = thumbnail;

										// 4) Verify result
										XCTAssert((thumbnail1 != nil), @"Thumbnail 1 should have been set first.");
										XCTAssert((thumbnail2 != nil), @"Thumbnail 2 should not be nil either.");
										XCTAssert((thumbnail1 == thumbnail2), @"Thumbnail 1 is identical to Thumbnail 2");

										thumbnail1 = nil;
										thumbnail2 = nil;

										// Install host simulator that makes the test fail if any connection attempt is made from hereon.
										core.connection.hostSimulator = hostSimulator;

										// Send third request, which should now be served from cache
										[core retrieveThumbnailFor:item maximumSize:CGSizeMake(100, 100) scale:1.0 retrieveHandler:^(NSError *error, OCCore *core, OCItem *item, OCItemThumbnail *thumbnail, BOOL isOngoing, NSProgress *progress) {
											if (!isOngoing)
											{
												thumbnail1 = thumbnail;
											}

											// Send forth request for smaller version, which should use the same thumbnail
											[core retrieveThumbnailFor:item maximumSize:CGSizeMake(50, 50) scale:1.0 retrieveHandler:^(NSError *error, OCCore *core, OCItem *item, OCItemThumbnail *thumbnail, BOOL isOngoing, NSProgress *progress) {
												if (!isOngoing)
												{
													thumbnail2 = thumbnail;

													XCTAssert((thumbnail1 != nil), @"Thumbnail 1 should have been set first.");
													XCTAssert((thumbnail2 != nil), @"Thumbnail 2 should not be nil either.");
													XCTAssert((thumbnail1 == thumbnail2), @"Thumbnail 1 is identical to Thumbnail 2");

													// Verify thumbnail size
													[thumbnail requestImageForSize:CGSizeMake(100,100) scale:1.0 withCompletionHandler:^(OCItemThumbnail *thumbnail, NSError *error, CGSize maximumSizeInPoints, UIImage *image) {
														XCTAssert ((image.size.width == 100.0), @"Thumbnail width is 100: %f", image.size.width);
														XCTAssert ((image.size.height <= 100.0), @"Thumbnail height is <= 100: %f", image.size.height);
														XCTAssert ((image.scale == 1.0), @"Thumbnail scale is 1");

														// Verify that the next call will actually lead to a new request
														hostSimulator.unroutableRequestHandler = ^BOOL(OCConnection *connection, OCConnectionRequest *request, OCHostSimulatorResponseHandler responseHandler) {
															[requestOfLargerSizeExpectation fulfill];
															requestOfLargerSizeExpectation = nil;

															return (NO);
														};

														// Request larger size, so a new request will be sent
														[core retrieveThumbnailFor:item maximumSize:CGSizeMake(200, 200) scale:1.0 retrieveHandler:^(NSError *error, OCCore *core, OCItem *item, OCItemThumbnail *thumbnail, BOOL isOngoing, NSProgress *progress) {
															if (!isOngoing)
															{
																// Remove host simulator
																core.connection.hostSimulator = nil;

																// Stop core
																[core stopWithCompletionHandler:^(id sender, NSError *error) {
																	XCTAssert((error==nil), @"Stopped with error: %@", error);

																	[coreStoppedExpectation fulfill];
																}];
															}
														}];
													}];
												}
											}];
										}];
									}
								}];

								break;
							}
						}
					}
				}];
			}
		};

		[core startQuery:query];
	}];

	[self waitForExpectationsWithTimeout:60 handler:nil];

	// Erase vault
	[core.vault eraseSyncWithCompletionHandler:^(id sender, NSError *error) {
		XCTAssert((error==nil), @"Erased with error: %@", error);
	}];
}

- (void)core:(OCCore *)core handleError:(NSError *)error issue:(OCIssue *)issue
{
	OCLog(@"Core: %@ Error: %@ Issue: %@", core, error, issue);
	if (coreErrorHandler != nil)
	{
		coreErrorHandler(core, error, issue);
	}
}

- (void)testInvalidLoginData
{
	OCCore *core;
	OCBookmark *bookmark = nil;
	XCTestExpectation *coreStartedExpectation = [self expectationWithDescription:@"Core started"];
	__block XCTestExpectation *coreErrorExpectation = [self expectationWithDescription:@"Core reported error"];
	XCTestExpectation *coreStoppedExpectation = [self expectationWithDescription:@"Core stopped"];

	// Create bookmark for demo.owncloud.org
	bookmark = [OCBookmark bookmarkForURL:OCTestTarget.secureTargetURL];
	bookmark.authenticationData = [OCAuthenticationMethodBasicAuth authenticationDataForUsername:@"invalid" passphrase:@"wrong" authenticationHeaderValue:NULL error:NULL];
	bookmark.authenticationMethodIdentifier = OCAuthenticationMethodIdentifierBasicAuth;

	// Create core with it
	core = [[OCCore alloc] initWithBookmark:bookmark];
	core.automaticItemListUpdatesEnabled = NO;
	core.delegate = self;

	__weak CoreTests *weakSelf = self;
	NSArray *tags = [weakSelf logTags];

	coreErrorHandler = ^(OCCore *core, NSError *error, OCIssue *issue) {
		OCRLog(tags, @"######### Handle error: %@, issue: %@", error, issue);

		if (coreErrorExpectation != nil)
		{
			_XCTPrimitiveAssertTrue(weakSelf, (error.code == OCErrorAuthorizationFailed) && ([error.domain isEqual:OCErrorDomain]), @"(error.code == OCErrorAuthorizationFailed) && ([error.domain isEqual:OCErrorDomain])"); // Expected error received

			[coreErrorExpectation fulfill];
			coreErrorExpectation = nil;

			// Stop core
			[core stopWithCompletionHandler:^(id sender, NSError *error) {
				_XCTPrimitiveAssertTrue(weakSelf, (error==nil), @"Stopped without error");
				OCRLog(tags, @"Stopped with error: %@", error);

				[coreStoppedExpectation fulfill];
			}];
		}
	};

	// Start core
	[core startWithCompletionHandler:^(OCCore *core, NSError *error) {
		OCLog(@"Core: %@ Error: %@", core, error);

		core.vault.database.itemFilter = self.databaseSanityCheckFilter;

		[coreStartedExpectation fulfill];
	}];

	[self waitForExpectationsWithTimeout:60 handler:nil];

	// Erase vault
	[core.vault eraseSyncWithCompletionHandler:^(id sender, NSError *error) {
		XCTAssert((error==nil), @"Erased with error: %@", error);
	}];
}

- (void)testOverlappingQueries
{
	OCBookmark *bookmark = [OCTestTarget userBookmark];
	OCQuery *queryOne = [OCQuery queryForPath:@"/"];
	OCQuery *queryTwo = [OCQuery queryForPath:@"/"];
	__block XCTestExpectation *initialPopulationReceivedExpectation = [self expectationWithDescription:@"Initial database population"];
	__block XCTestExpectation *coreReturnedExpectation = [self expectationWithDescription:@"Core returned"];
	__block XCTestExpectation *queryOneItemsReceivedExpectation = [self expectationWithDescription:@"Query 1 idle"];
	__block XCTestExpectation *queryTwoItemsReceivedExpectation = [self expectationWithDescription:@"Query 2 idle"];
	__block XCTestExpectation *vaultErasedExpectation = [self expectationWithDescription:@"Vault erased"];

	__block NSArray <OCItem *> *itemsOne = nil;
	__block NSArray <OCItem *> *itemsTwo = nil;

	__block NSTimeInterval queryOneTimestampStarted = 0;
	__block NSTimeInterval queryOneTimestampCache = 0;
	__block NSTimeInterval queryOneTimestampIdle = 0;

	__block NSTimeInterval queryTwoTimestampStarted = 0;
	__block NSTimeInterval queryTwoTimestampCache = 0;
	__block NSTimeInterval queryTwoTimestampIdle = 0;

	[[OCCoreManager sharedCoreManager] requestCoreForBookmark:bookmark completionHandler:^(OCCore * _Nullable core, NSError * _Nullable error) {
		OCQuery *query = [OCQuery queryForPath:@"/"];
		__weak OCCore *weakCore = core;

		core.vault.database.itemFilter = self.databaseSanityCheckFilter;

		query.changesAvailableNotificationHandler = ^(OCQuery * _Nonnull query) {
			// Wait for population of cache
			if ((query.state == OCQueryStateIdle) && (initialPopulationReceivedExpectation!=nil))
			{
				[initialPopulationReceivedExpectation fulfill];
				initialPopulationReceivedExpectation = nil;

				// Start other queries
				queryOne.changesAvailableNotificationHandler = ^(OCQuery * _Nonnull query) {
					if ((query.state == OCQueryStateWaitingForServerReply) && (queryOneTimestampStarted ==0))
					{
						[weakCore startQuery:queryTwo];
						queryOneTimestampStarted = [NSDate timeIntervalSinceReferenceDate];
					}

					if (query.state == OCQueryStateContentsFromCache)
					{
						queryOneTimestampCache = [NSDate timeIntervalSinceReferenceDate];
					}

					if (query.state == OCQueryStateIdle)
					{
						[query requestChangeSetWithFlags:OCQueryChangeSetRequestFlagOnlyResults completionHandler:^(OCQuery * _Nonnull query, OCQueryChangeSet * _Nullable changeset) {
							itemsOne = changeset.queryResult;
							queryOneTimestampIdle = [NSDate timeIntervalSinceReferenceDate];

							[queryOneItemsReceivedExpectation fulfill];
							queryOneItemsReceivedExpectation = nil;
						}];
					}
				};

				queryTwo.changesAvailableNotificationHandler = ^(OCQuery * _Nonnull query) {
					if (query.state == OCQueryStateWaitingForServerReply)
					{
						queryTwoTimestampStarted = [NSDate timeIntervalSinceReferenceDate];
					}

					if (query.state == OCQueryStateContentsFromCache)
					{
						queryTwoTimestampCache = [NSDate timeIntervalSinceReferenceDate];
					}

					if (query.state == OCQueryStateIdle)
					{
						[query requestChangeSetWithFlags:OCQueryChangeSetRequestFlagOnlyResults completionHandler:^(OCQuery * _Nonnull query, OCQueryChangeSet * _Nullable changeset) {
							itemsTwo = changeset.queryResult;
							queryTwoTimestampIdle = [NSDate timeIntervalSinceReferenceDate];

							if (queryTwoItemsReceivedExpectation != nil)
							{
								[queryTwoItemsReceivedExpectation fulfill];
								queryTwoItemsReceivedExpectation = nil;

								[[OCCoreManager sharedCoreManager] returnCoreForBookmark:bookmark completionHandler:^{
									[coreReturnedExpectation fulfill];
								}];
							}
						}];
					}
				};

				[core startQuery:queryOne];
			}
		};

		[core startQuery:query];
	}];

	[[OCCoreManager sharedCoreManager] scheduleOfflineOperation:^(OCBookmark * _Nonnull bookmark, dispatch_block_t  _Nonnull completionHandler) {
		[[[OCVault alloc] initWithBookmark:bookmark] eraseWithCompletionHandler:^(id sender, NSError *error) {
			[vaultErasedExpectation fulfill];
		}];
	} forBookmark:bookmark];

	[self waitForExpectationsWithTimeout:20 handler:nil];

	OCLog(@"Waiting for reply: one=%f two=%f delta=%f", queryOneTimestampStarted, 	queryTwoTimestampStarted, 	(queryTwoTimestampStarted-queryOneTimestampStarted));
	OCLog(@"Cache contents:    one=%f two=%f delta=%f", queryOneTimestampCache, 	queryTwoTimestampCache, 	(queryTwoTimestampCache-queryOneTimestampCache));
	OCLog(@"Idle: 	  	   one=%f two=%f delta=%f", queryOneTimestampIdle, 	queryTwoTimestampIdle, 		(queryTwoTimestampIdle-queryOneTimestampIdle));
	OCLog(@"Results: one=%@, two=%@", itemsOne, itemsTwo);
}

- (void)testQueryFilter
{
	OCBookmark *bookmark = [OCTestTarget userBookmark];
	__block XCTestExpectation *initialPopulationReceivedExpectation = [self expectationWithDescription:@"Initial database population"];
	__block XCTestExpectation *receivedFilteredQuerySet = [self expectationWithDescription:@"Received filtered query set"];
	__block XCTestExpectation *receivedUnfilteredQuerySet = [self expectationWithDescription:@"Received unfiltered query set"];
	__block XCTestExpectation *coreReturnedExpectation = [self expectationWithDescription:@"Core returned"];
	__block XCTestExpectation *vaultErasedExpectation = [self expectationWithDescription:@"Vault erased"];
	__block OCItem *onlyItem = nil;

	[[OCCoreManager sharedCoreManager] requestCoreForBookmark:bookmark completionHandler:^(OCCore * _Nullable core, NSError * _Nullable error) {
		OCQuery *query = [OCQuery queryForPath:@"/"];

		core.vault.database.itemFilter = self.databaseSanityCheckFilter;
		core.automaticItemListUpdatesEnabled = NO;

		query.changesAvailableNotificationHandler = ^(OCQuery * _Nonnull query) {
			if (query.state == OCQueryStateIdle)
			{
				[query requestChangeSetWithFlags:OCQueryChangeSetRequestFlagOnlyResults completionHandler:^(OCQuery * _Nonnull query, OCQueryChangeSet * _Nullable changeset) {
					OCLog(@"Received queryResult=%@", changeset.queryResult);

					if (initialPopulationReceivedExpectation != nil)
					{
						if (onlyItem == nil)
						{
							if ((onlyItem = changeset.queryResult.firstObject) != nil)
							{
								[initialPopulationReceivedExpectation fulfill];
								initialPopulationReceivedExpectation = nil;

								[query addFilter:[OCQueryFilter filterWithHandler:^BOOL(OCQuery *query, OCQueryFilter *filter, OCItem *item) {
									return ([item.itemVersionIdentifier isEqual:onlyItem.itemVersionIdentifier]);
								}] withIdentifier:@"filter1"];
							}
						}
					}
					else
					{
						if ([query filterWithIdentifier:@"filter1"] != nil)
						{
							if ((changeset.queryResult.count == 1) && ([changeset.queryResult.firstObject.itemVersionIdentifier isEqual:onlyItem.itemVersionIdentifier]))
							{
								if (receivedFilteredQuerySet != nil)
								{
									[receivedFilteredQuerySet fulfill];
									receivedFilteredQuerySet = nil;

									[query removeFilter:[query filterWithIdentifier:@"filter1"]];
								}
							}
						}
						else
						{
							if (changeset.queryResult.count > 1)
							{
								if (receivedUnfilteredQuerySet != nil)
								{
									[receivedUnfilteredQuerySet fulfill];
									receivedUnfilteredQuerySet = nil;

									[[OCCoreManager sharedCoreManager] returnCoreForBookmark:bookmark completionHandler:^{
										[coreReturnedExpectation fulfill];
									}];
								}
							}
						}
					}
				}];
			}
		};

		[core startQuery:query];
	}];

	[[OCCoreManager sharedCoreManager] scheduleOfflineOperation:^(OCBookmark * _Nonnull bookmark, dispatch_block_t  _Nonnull completionHandler) {
		[[[OCVault alloc] initWithBookmark:bookmark] eraseWithCompletionHandler:^(id sender, NSError *error) {
			[vaultErasedExpectation fulfill];
		}];
	} forBookmark:bookmark];

	[self waitForExpectationsWithTimeout:20 handler:nil];
}

@end
