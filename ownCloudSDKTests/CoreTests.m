//
//  CoreTests.m
//  ownCloudSDKTests
//
//  Created by Felix Schwarz on 04.04.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <ownCloudSDK/ownCloudSDK.h>
#import "OCHostSimulator.h"
#import "OCCore+Internal.h"

@interface CoreTests : XCTestCase

@end

@implementation CoreTests

- (void)setUp
{
	[super setUp];
	// Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
	// Put teardown code here. This method is called after the invocation of each test method in the class.
	[super tearDown];
}

- (void)testStartStopCoreAndEraseVault
{
	OCBookmark *bookmark = nil;
	OCCore *core;
	XCTestExpectation *coreStartedExpectation = [self expectationWithDescription:@"Core started"];
	XCTestExpectation *coreStoppedExpectation = [self expectationWithDescription:@"Core stopped"];
	XCTestExpectation *vaultErasedExpectation = [self expectationWithDescription:@"Vault erased"];

	// Create bookmark for demo.owncloud.org
	bookmark = [OCBookmark bookmarkForURL:[NSURL URLWithString:@"https://demo.owncloud.org/"]];
	bookmark.authenticationData = [OCAuthenticationMethodBasicAuth authenticationDataForUsername:@"demo" passphrase:@"demo" authenticationHeaderValue:NULL error:NULL];
	bookmark.authenticationMethodIdentifier = OCAuthenticationMethodBasicAuthIdentifier;

	// Create core with it
	core = [[OCCore alloc] initWithBookmark:bookmark];

	// Start core
	[core startWithCompletionHandler:^(OCCore *core, NSError *error) {
		NSURL *vaultRootURL = core.vault.rootURL;

		XCTAssert((error==nil), @"Started with error: %@", error);

		[coreStartedExpectation fulfill];

		NSLog(@"Vault location: %@", core.vault.rootURL);

		// Stop core
		[core stopWithCompletionHandler:^(id sender, NSError *error) {
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
	bookmark = [OCBookmark bookmarkForURL:[NSURL URLWithString:@"https://demo.owncloud.org/"]];
	[bookmark setValue:[[NSUUID alloc] initWithUUIDString:@"31D22AF2-6592-4445-821B-FA9E0D195CE3"] forKeyPath:@"uuid"];
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
	[core.vault eraseWithCompletionHandler:^(id sender, NSError *error) {
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
	bookmark = [OCBookmark bookmarkForURL:[NSURL URLWithString:@"https://demo.owncloud.org/"]];
	[bookmark setValue:[[NSUUID alloc] initWithUUIDString:@"31D22AF2-6592-4445-821B-FA9E0D195CE3"] forKeyPath:@"uuid"];
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

											NSLog(@"================ ###### CUTTING OFF NETWORK ###### ================");
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
	[core.vault eraseWithCompletionHandler:^(id sender, NSError *error) {
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
	bookmark = [OCBookmark bookmarkForURL:[NSURL URLWithString:@"https://demo.owncloud.org/"]];
	[bookmark setValue:[[NSUUID alloc] initWithUUIDString:@"31D22AF2-6592-4445-821B-FA9E0D195CE3"] forKeyPath:@"uuid"];
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

		query = [OCQuery queryForPath:@"/Photos/"];
		query.changesAvailableNotificationHandler = ^(OCQuery *query) {

			NSLog(@"[%@] QUERY STATE: %lu", query.queryPath, (unsigned long)query.state);

			if (query.state == OCQueryStateIdle)
			{
				[query requestChangeSetWithFlags:OCQueryChangeSetRequestFlagDefault completionHandler:^(OCQuery *query, OCQueryChangeSet *changeset) {
					if (changeset != nil)
					{
						NSLog(@"[%@] Query result: %@", query.queryPath, changeset.queryResult);

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
										}];

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
	[core.vault eraseWithCompletionHandler:^(id sender, NSError *error) {
		XCTAssert((error==nil), @"Erased with error: %@", error);
	}];
}

@end
