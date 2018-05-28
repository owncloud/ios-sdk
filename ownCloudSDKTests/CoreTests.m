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

@interface CoreTests : XCTestCase <OCCoreDelegate>
{
	void (^coreErrorHandler)(OCCore *core, NSError *error, OCConnectionIssue *issue);
}

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

@end
