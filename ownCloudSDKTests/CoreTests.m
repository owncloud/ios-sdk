//
//  CoreTests.m
//  ownCloudSDKTests
//
//  Created by Felix Schwarz on 04.04.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <ownCloudSDK/ownCloudSDK.h>

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
					OCQuery *subfolderQuery;
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

@end
