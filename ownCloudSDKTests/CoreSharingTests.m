//
//  CoreSharingTests.m
//  ownCloudSDKTests
//
//  Created by Felix Schwarz on 14.03.19.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <ownCloudSDK/ownCloudSDK.h>
#import "OCTestTarget.h"

@interface CoreSharingTests : XCTestCase <OCRecipientSearchControllerDelegate>
{
	void(^searchControllerDelegateIsWaitingForResults)(OCRecipientSearchController *searchController, BOOL isSearching);
	void(^searchControllerDelegateHasNewResults)(OCRecipientSearchController *searchController, NSError *error);
}

@end

@implementation CoreSharingTests

#pragma mark - Search controller
- (void)testSearchController
{
	XCTestExpectation *expectFileList = [self expectationWithDescription:@"Root dir file list"];
	XCTestExpectation *expectCoreStop = [self expectationWithDescription:@"Core stop"];
	__block XCTestExpectation *expectIsSearching = [self expectationWithDescription:@"Is searching"];
	__block XCTestExpectation *expectIsDoneSearching = [self expectationWithDescription:@"Is done searching"];
	__block XCTestExpectation *expectReceiveFirstResults = [self expectationWithDescription:@"Receipt of first results"];
	__block XCTestExpectation *expectReceiveSecondResults = [self expectationWithDescription:@"Receipt of second results"];

	OCCore *core = [[OCCore alloc] initWithBookmark:OCTestTarget.userBookmark];
	OCQuery *query = [OCQuery queryForPath:@"/"];
	__block OCRecipientSearchController *searchController;

	__weak CoreSharingTests *weakSelf = self;

	[core startWithCompletionHandler:^(id sender, NSError *error) {
		query.changesAvailableNotificationHandler = ^(OCQuery * _Nonnull query) {
			if (query.state == OCQueryStateIdle)
			{
				OCItem *shareItem = nil;
				[expectFileList fulfill];

				for (OCItem *item in query.queryResults)
				{
					if (![item.path isEqual:@"/"])
					{
						shareItem = item;
						break;
					}
				}

				if (shareItem != nil)
				{
					self->searchControllerDelegateIsWaitingForResults = ^(OCRecipientSearchController *searchController, BOOL isSearching) {
						if (isSearching)
						{
							if (expectIsSearching != nil)
							{
								[expectIsSearching fulfill];
								expectIsSearching = nil;

								XCTWeakSelfAssert(expectIsDoneSearching!=nil);
							}
						}
						else
						{
							if (expectIsDoneSearching != nil)
							{
								[expectIsDoneSearching fulfill];
								expectIsDoneSearching = nil;

								XCTWeakSelfAssert(expectIsSearching==nil);
							}
						}
					};

					self->searchControllerDelegateHasNewResults = ^(OCRecipientSearchController *searchController, NSError *error) {
						OCWTLogDebug(nil, @"Recipients: %@", searchController.recipients);

						if (expectReceiveFirstResults != nil)
						{
							[expectReceiveFirstResults fulfill];
							expectReceiveFirstResults = nil;

							XCTWeakSelfAssert(searchController.recipients.count == 4);

							searchController.searchTerm = @"demo";
							searchController.searchTerm = @"admin";
							searchController.shareTypes = @[ @(OCShareTypeUserShare) ];
						}
						else if (expectReceiveSecondResults != nil)
						{
							if (!searchController.isWaitingForResults)
							{
								XCTWeakSelfAssert(searchController.recipients.count == 1);
								XCTWeakSelfAssert(searchController.recipients.firstObject.type == OCRecipientTypeUser);
								XCTWeakSelfAssert([searchController.recipients.firstObject.user.userName isEqual:@"admin"]);

								[expectReceiveSecondResults fulfill];
								expectReceiveSecondResults = nil;

								[core stopWithCompletionHandler:^(id sender, NSError *error) {
									[core.vault eraseWithCompletionHandler:^(id sender, NSError *error) {
										[expectCoreStop fulfill];
									}];
								}];
							}
						}
					};

					searchController = [core recipientSearchControllerForItem:shareItem];
					searchController.delegate = self;

					[searchController search];
				}
			}
		};

		[core startQuery:query];
	}];

	[self waitForExpectationsWithTimeout:120.0 handler:nil];
}

- (void)searchController:(OCRecipientSearchController *)searchController isWaitingForResults:(BOOL)isSearching
{
	if (searchControllerDelegateIsWaitingForResults != nil)
	{
		searchControllerDelegateIsWaitingForResults(searchController, isSearching);
	}
}

- (void)searchControllerHasNewResults:(nonnull OCRecipientSearchController *)searchController error:(nullable NSError *)error
{
	if (searchControllerDelegateHasNewResults != nil)
	{
		searchControllerDelegateHasNewResults(searchController, error);
	}
}

#pragma mark - Sharing queries
- (void)testSharingQueriesCreateUpdateAndDelete
{
	XCTestExpectation *expectFileList = [self expectationWithDescription:@"Expect root dir file list"];
	XCTestExpectation *expectCoreStop = [self expectationWithDescription:@"Expect core to stop"];
	__block XCTestExpectation *expectCreateShare = [self expectationWithDescription:@"Create share"];
	__block XCTestExpectation *expectUpdateShare = [self expectationWithDescription:@"Updated share"];
	__block XCTestExpectation *expectDeleteShare = [self expectationWithDescription:@"Delete share"];
	__block XCTestExpectation *expectQueryContainsNewShare = [self expectationWithDescription:@"Query contains new share"];
	__block XCTestExpectation *expectQueryContainsUpdatedShare = [self expectationWithDescription:@"Query contains updated share"];
	__block XCTestExpectation *expectQueryNoLongerContainsNewShare = [self expectationWithDescription:@"Query no longer contains new share"];

	__block XCTestExpectation *expectShareQueryItemContainsNewShare = [self expectationWithDescription:@"shareQueryItem contains new share"];
	__block XCTestExpectation *expectShareQueryItemLosesNewShare = [self expectationWithDescription:@"shareQueryItem loses new share"];

	__block XCTestExpectation *expectShareQueryItemWithResharesContainsNewShare = [self expectationWithDescription:@"shareQueryItemWithReshares contains new share"];
	__block XCTestExpectation *expectShareQueryItemWithResharesLosesNewShare = [self expectationWithDescription:@"shareQueryItemWithReshares loses new share"];

	__block XCTestExpectation *expectShareQuerySubItemsContainsNewShare = [self expectationWithDescription:@"shareQuerySubitems contains new share"];
	__block XCTestExpectation *expectShareQuerySubItemsLosesNewShare = [self expectationWithDescription:@"shareQuerySubitems loses new share"];

	OCCore *core = [[OCCore alloc] initWithBookmark:OCTestTarget.userBookmark];
	OCQuery *query = [OCQuery queryForPath:@"/"];
	OCShareQuery *shareQuery = [OCShareQuery queryWithScope:OCShareScopeSharedByUser item:nil];
	NSString *initialName = NSUUID.UUID.UUIDString, *updatedName= NSUUID.UUID.UUIDString;
	__block OCShare *createdShare = nil;
	__block OCShare *updatedShare = nil;

	__block OCShareQuery *shareQueryWithUser;
	__block OCShareQuery *shareQueryPendingCloudShares;
	__block OCShareQuery *shareQueryAcceptedCloudShares;
	__block OCShareQuery *shareQueryItem;
	__block OCShareQuery *shareQueryItemWithReshares;
	__block OCShareQuery *shareQuerySubItems;

	BOOL(^ContainsShareNamed)(OCShareQuery *shareQuery, NSString *name) = ^(OCShareQuery *shareQuery, NSString *name) {
		for (OCShare *share in shareQuery.queryResults)
		{
			if ([share.name isEqual:name])
			{
				return (YES);
			}
		}

		return (NO);
	};

	BOOL(^ContainsShareLike)(NSArray<OCShare *> *shareQueryResults, OCShare *likeShare) = ^(NSArray<OCShare *> *shareQueryResults, OCShare *likeShare) {
		for (OCShare *share in shareQueryResults)
		{
			if ([share.identifier isEqual:likeShare.identifier])
			{
				return (YES);
			}
		}

		return (NO);
	};

	shareQueryWithUser = [OCShareQuery queryWithScope:OCShareScopeSharedWithUser item:nil];
	shareQueryWithUser.changesAvailableNotificationHandler = ^(OCShareQuery * _Nonnull query) {
		XCTAssert(!ContainsShareNamed(query,initialName));
	};

	shareQueryPendingCloudShares = [OCShareQuery queryWithScope:OCShareScopePendingCloudShares item:nil];
	shareQueryPendingCloudShares.changesAvailableNotificationHandler = shareQueryWithUser.changesAvailableNotificationHandler;

	shareQueryAcceptedCloudShares = [OCShareQuery queryWithScope:OCShareScopeAcceptedCloudShares item:nil];
	shareQueryAcceptedCloudShares.changesAvailableNotificationHandler = shareQueryWithUser.changesAvailableNotificationHandler;

	[core startWithCompletionHandler:^(id sender, NSError *error) {
		[core startQuery:shareQueryWithUser];
		[core startQuery:shareQueryPendingCloudShares];
		[core startQuery:shareQueryAcceptedCloudShares];

		query.includeRootItem = YES;
		query.changesAvailableNotificationHandler = ^(OCQuery * _Nonnull query) {
			if (query.state == OCQueryStateIdle)
			{
				OCItem *shareItem = nil;
				[expectFileList fulfill];

				for (OCItem *item in query.queryResults)
				{
					if (![item.path isEqual:@"/"])
					{
						if (shareItem == nil)
						{
							shareItem = item;

							shareQueryItem = [OCShareQuery queryWithScope:OCShareScopeItem item:item];
							shareQueryItem.changesAvailableNotificationHandler = ^(OCShareQuery * _Nonnull query) {
								if (ContainsShareNamed(query,initialName))
								{
									[expectShareQueryItemContainsNewShare fulfill];
									expectShareQueryItemContainsNewShare = nil;
								}
								else if (expectShareQueryItemContainsNewShare == nil)
								{
									if (!ContainsShareLike(query.queryResults,createdShare))
									{
										[expectShareQueryItemLosesNewShare fulfill];
										expectShareQueryItemLosesNewShare = nil;
									}
								}
							};
							[core startQuery:shareQueryItem];

							shareQueryItemWithReshares = [OCShareQuery queryWithScope:OCShareScopeItemWithReshares item:item];
							shareQueryItemWithReshares.changesAvailableNotificationHandler = ^(OCShareQuery * _Nonnull query) {
								if (ContainsShareNamed(query,initialName))
								{
									[expectShareQueryItemWithResharesContainsNewShare fulfill];
									expectShareQueryItemWithResharesContainsNewShare = nil;
								}
								else if (expectShareQueryItemWithResharesContainsNewShare == nil)
								{
									if (!ContainsShareLike(query.queryResults,createdShare))
									{
										[expectShareQueryItemWithResharesLosesNewShare fulfill];
										expectShareQueryItemWithResharesLosesNewShare = nil;
									}
								}
							};
							[core startQuery:shareQueryItemWithReshares];
						}
					}
					else
					{
						if (shareQuerySubItems == nil)
						{
							shareQuerySubItems = [OCShareQuery queryWithScope:OCShareScopeSubItems item:item];
							shareQuerySubItems.changesAvailableNotificationHandler = ^(OCShareQuery * _Nonnull query) {
								if (ContainsShareNamed(query,initialName))
								{
									[expectShareQuerySubItemsContainsNewShare fulfill];
									expectShareQuerySubItemsContainsNewShare = nil;
								}
								else if (expectShareQuerySubItemsContainsNewShare == nil)
								{
									if (!ContainsShareLike(query.queryResults,createdShare))
									{
										[expectShareQuerySubItemsLosesNewShare fulfill];
										expectShareQuerySubItemsLosesNewShare = nil;
									}
								}
							};
							[core startQuery:shareQuerySubItems];
						}
					}
				}

				if (shareItem != nil)
				{
					__block NSArray <OCShare *> *queryShares = nil;
					dispatch_block_t iterateResultAnalysis = ^{
						if ((createdShare!=nil) && [queryShares containsObject:createdShare] && (expectQueryContainsNewShare!=nil))
						{
							if (expectQueryContainsNewShare != nil)
							{
								[expectQueryContainsNewShare fulfill];
								expectQueryContainsNewShare = nil;
							}
						}
						else if ((expectQueryContainsNewShare == nil) && (expectUpdateShare == nil))
						{
							if ((expectQueryContainsUpdatedShare != nil) && ContainsShareLike(queryShares,createdShare) && ([queryShares indexOfObjectIdenticalTo:updatedShare]!=NSNotFound))
							{
								[expectQueryContainsUpdatedShare fulfill];
								expectQueryContainsUpdatedShare = nil;
							}
							else if ((expectQueryContainsUpdatedShare == nil) && (expectDeleteShare == nil))
							{
								if ((expectQueryNoLongerContainsNewShare != nil) && (!ContainsShareLike(queryShares,createdShare)))
								{
									[expectQueryNoLongerContainsNewShare fulfill];
									expectQueryNoLongerContainsNewShare = nil;

									[core stopWithCompletionHandler:^(id sender, NSError *error) {
										[core.vault eraseWithCompletionHandler:^(id sender, NSError *error) {
											[expectCoreStop fulfill];
										}];
									}];
								}
							}
						}
					};

					// Test creating new share
					shareQuery.changesAvailableNotificationHandler = ^(OCShareQuery * _Nonnull query) {
						OCLogDebug(@"shareQuery.queryResults=%@", query.queryResults);
						queryShares = query.queryResults;

						iterateResultAnalysis();
					};

					[core startQuery:shareQuery];

					[core createShare:[OCShare shareWithPublicLinkToPath:shareItem.path linkName:initialName permissions:OCSharePermissionsMaskRead password:nil expiration:nil] options:nil completionHandler:^(NSError * _Nullable error, OCShare * _Nullable newShare) {
						OCLogDebug(@"Created share: %@, error: %@", newShare, error);

						XCTAssert(error == nil);
						XCTAssert(newShare != nil);

						createdShare = newShare;

						[expectCreateShare fulfill];

						iterateResultAnalysis();

						[core updateShare:createdShare afterPerformingChanges:^(OCShare * _Nonnull share) {
							share.name = updatedName;
						} completionHandler:^(NSError * _Nullable error, OCShare * _Nullable newShare) {
							updatedShare = newShare;

							[expectUpdateShare fulfill];
							expectUpdateShare = nil;

							iterateResultAnalysis();

							[core deleteShare:updatedShare completionHandler:^(NSError * _Nullable error) {
								[expectDeleteShare fulfill];
								expectDeleteShare = nil;

								iterateResultAnalysis();
							}];
						}];
					}];
				}
			}
		};

		[core startQuery:query];
	}];

	[self waitForExpectationsWithTimeout:120.0 handler:nil];
}

- (void)testShareQueryDiffNoDifferences
{
	XCTestExpectation *expectFileList = [self expectationWithDescription:@"Expect root dir file list"];
	XCTestExpectation *expectCoreStop = [self expectationWithDescription:@"Expect core to stop"];
	__block XCTestExpectation *expectCreateShare = [self expectationWithDescription:@"Create share"];
	__block XCTestExpectation *expectDeleteShare = [self expectationWithDescription:@"Delete share"];
	__block XCTestExpectation *expectInitialShareQueryResults = [self expectationWithDescription:@"Initial share query results"];

	OCCore *core = [[OCCore alloc] initWithBookmark:OCTestTarget.userBookmark];
	OCQuery *query = [OCQuery queryForPath:@"/"];
	OCShareQuery *shareQuery = [OCShareQuery queryWithScope:OCShareScopeSharedByUser item:nil];
	NSString *initialName = NSUUID.UUID.UUIDString;
	__block OCShare *createdShare = nil;

	BOOL(^ContainsShareNamed)(OCShareQuery *shareQuery, NSString *name) = ^(OCShareQuery *shareQuery, NSString *name) {
		for (OCShare *share in shareQuery.queryResults)
		{
			if ([share.name isEqual:name])
			{
				return (YES);
			}
		}

		return (NO);
	};

	[core startWithCompletionHandler:^(id sender, NSError *error) {
		query.includeRootItem = YES;
		query.changesAvailableNotificationHandler = ^(OCQuery * _Nonnull query) {
			if (query.state == OCQueryStateIdle)
			{
				OCItem *shareItem = nil;
				[expectFileList fulfill];

				for (OCItem *item in query.queryResults)
				{
					if (![item.path isEqual:@"/"])
					{
						shareItem = item;
						break;
					}
				}

				if (shareItem != nil)
				{
					[core createShare:[OCShare shareWithPublicLinkToPath:shareItem.path linkName:initialName permissions:OCSharePermissionsMaskRead password:nil expiration:nil] options:nil completionHandler:^(NSError * _Nullable error, OCShare * _Nullable newShare) {
						OCLogDebug(@"Created share: %@, error: %@", newShare, error);

						XCTAssert(error == nil);
						XCTAssert(newShare != nil);

						createdShare = newShare;

						[expectCreateShare fulfill];

						shareQuery.changesAvailableNotificationHandler = ^(OCShareQuery * _Nonnull query) {
							XCTAssert(ContainsShareNamed(query, initialName));

							[expectInitialShareQueryResults fulfill]; // The initial call should be the only one

							[core reloadQuery:query]; // Reload query so that the core gets to compare existing results with fresh results and conclude nothing changed
						};
						[core startQuery:shareQuery];

						dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
							[core stopQuery:shareQuery];

							[core deleteShare:createdShare completionHandler:^(NSError * _Nullable error) {
								[expectDeleteShare fulfill];
								expectDeleteShare = nil;

								[core stopWithCompletionHandler:^(id sender, NSError *error) {
									[core.vault eraseWithCompletionHandler:^(id sender, NSError *error) {
										[expectCoreStop fulfill];
									}];
								}];
							}];
						});
					}];
				}
			}
		};

		[core startQuery:query];
	}];

	[self waitForExpectationsWithTimeout:120.0 handler:nil];

}

- (void)testShareQueryDiffCreatedNewShare
{
	XCTestExpectation *expectFileList = [self expectationWithDescription:@"Expect root dir file list"];
	XCTestExpectation *expectCoreStop = [self expectationWithDescription:@"Expect core to stop"];
	__block XCTestExpectation *expectCreateShare = [self expectationWithDescription:@"Create share"];
	__block XCTestExpectation *expectDeleteShare = [self expectationWithDescription:@"Delete share"];
	__block XCTestExpectation *expectInitialShareQueryResults = [self expectationWithDescription:@"Initial share query results"];
	__block XCTestExpectation *expectUpdatedShareQueryResults = [self expectationWithDescription:@"Updated share query results"];

	OCCore *core = [[OCCore alloc] initWithBookmark:OCTestTarget.userBookmark];
	OCQuery *query = [OCQuery queryForPath:@"/"];
	OCShareQuery *shareQuery = [OCShareQuery queryWithScope:OCShareScopeSharedByUser item:nil];
	NSString *initialName = NSUUID.UUID.UUIDString, *secondName = NSUUID.UUID.UUIDString;
	__block OCShare *createdShare = nil;

	BOOL(^ContainsShareNamed)(OCShareQuery *shareQuery, NSString *name) = ^(OCShareQuery *shareQuery, NSString *name) {
		for (OCShare *share in shareQuery.queryResults)
		{
			if ([share.name isEqual:name])
			{
				return (YES);
			}
		}

		return (NO);
	};

	[core startWithCompletionHandler:^(id sender, NSError *error) {
		query.includeRootItem = YES;
		query.changesAvailableNotificationHandler = ^(OCQuery * _Nonnull query) {
			if (query.state == OCQueryStateIdle)
			{
				OCItem *shareItem = nil;
				[expectFileList fulfill];

				for (OCItem *item in query.queryResults)
				{
					if (![item.path isEqual:@"/"])
					{
						shareItem = item;
						break;
					}
				}

				if (shareItem != nil)
				{
					[core createShare:[OCShare shareWithPublicLinkToPath:shareItem.path linkName:initialName permissions:OCSharePermissionsMaskRead password:nil expiration:nil] options:nil completionHandler:^(NSError * _Nullable error, OCShare * _Nullable newShare) {
						OCLogDebug(@"Created share: %@, error: %@", newShare, error);

						XCTAssert(error == nil);
						XCTAssert(newShare != nil);

						createdShare = newShare;

						[expectCreateShare fulfill];

						shareQuery.changesAvailableNotificationHandler = ^(OCShareQuery * _Nonnull query) {
							if (expectInitialShareQueryResults != nil)
							{
								XCTAssert(ContainsShareNamed(query, initialName));

								[expectInitialShareQueryResults fulfill];
								expectInitialShareQueryResults = nil;

								[core.connection createShare:[OCShare shareWithPublicLinkToPath:shareItem.path linkName:secondName permissions:OCSharePermissionsMaskRead password:nil expiration:nil] options:nil resultTarget:[OCEventTarget eventTargetWithEphermalEventHandlerBlock:^(OCEvent * _Nonnull event, id  _Nonnull sender) {
									[core reloadQuery:query]; // Reload query so that the core gets to compare existing results with fresh results and include the second created one
								} userInfo:nil ephermalUserInfo:nil]];
							}
							else
							{
								XCTAssert(ContainsShareNamed(query, initialName));
								XCTAssert(ContainsShareNamed(query, secondName));

								[expectUpdatedShareQueryResults fulfill];

								[core reloadQuery:query]; // Reload query so that the core gets to compare existing results with fresh results and conclude nothing changed

								dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
									[core stopQuery:query];

									[core deleteShare:createdShare completionHandler:^(NSError * _Nullable error) {
										[expectDeleteShare fulfill];
										expectDeleteShare = nil;

										[core stopWithCompletionHandler:^(id sender, NSError *error) {
											[core.vault eraseWithCompletionHandler:^(id sender, NSError *error) {
												[expectCoreStop fulfill];
											}];
										}];
									}];
								});
							}
						};
						[core startQuery:shareQuery];
					}];
				}
			}
		};

		[core startQuery:query];
	}];

	[self waitForExpectationsWithTimeout:120.0 handler:nil];
}

- (void)testShareQueryDiffUpdatedShare
{
	XCTestExpectation *expectFileList = [self expectationWithDescription:@"Expect root dir file list"];
	XCTestExpectation *expectCoreStop = [self expectationWithDescription:@"Expect core to stop"];
	__block XCTestExpectation *expectCreateShare = [self expectationWithDescription:@"Create share"];
	__block XCTestExpectation *expectDeleteShare = [self expectationWithDescription:@"Delete share"];
	__block XCTestExpectation *expectInitialShareQueryResults = [self expectationWithDescription:@"Initial share query results"];
	__block XCTestExpectation *expectUpdatedShareQueryResults = [self expectationWithDescription:@"Updated share query results"];

	OCCore *core = [[OCCore alloc] initWithBookmark:OCTestTarget.userBookmark];
	OCQuery *query = [OCQuery queryForPath:@"/"];
	OCShareQuery *shareQuery = [OCShareQuery queryWithScope:OCShareScopeSharedByUser item:nil];
	NSString *initialName = NSUUID.UUID.UUIDString, *secondName = NSUUID.UUID.UUIDString;
	__block OCShare *createdShare = nil;

	BOOL(^ContainsShareNamed)(OCShareQuery *shareQuery, NSString *name) = ^(OCShareQuery *shareQuery, NSString *name) {
		for (OCShare *share in shareQuery.queryResults)
		{
			if ([share.name isEqual:name])
			{
				return (YES);
			}
		}

		return (NO);
	};

	[core startWithCompletionHandler:^(id sender, NSError *error) {
		query.includeRootItem = YES;
		query.changesAvailableNotificationHandler = ^(OCQuery * _Nonnull query) {
			if (query.state == OCQueryStateIdle)
			{
				OCItem *shareItem = nil;
				[expectFileList fulfill];

				for (OCItem *item in query.queryResults)
				{
					if (![item.path isEqual:@"/"])
					{
						shareItem = item;
						break;
					}
				}

				if (shareItem != nil)
				{
					[core createShare:[OCShare shareWithPublicLinkToPath:shareItem.path linkName:initialName permissions:OCSharePermissionsMaskRead password:nil expiration:nil] options:nil completionHandler:^(NSError * _Nullable error, OCShare * _Nullable newShare) {
						OCLogDebug(@"Created share: %@, error: %@", newShare, error);

						XCTAssert(error == nil);
						XCTAssert(newShare != nil);

						createdShare = newShare;

						[expectCreateShare fulfill];

						shareQuery.changesAvailableNotificationHandler = ^(OCShareQuery * _Nonnull query) {
							if (expectInitialShareQueryResults != nil)
							{
								XCTAssert(ContainsShareNamed(query, initialName));

								[expectInitialShareQueryResults fulfill];
								expectInitialShareQueryResults = nil;

								[core.connection updateShare:createdShare afterPerformingChanges:^(OCShare * _Nonnull share) {
									share.name = secondName;
								} resultTarget:[OCEventTarget eventTargetWithEphermalEventHandlerBlock:^(OCEvent * _Nonnull event, id  _Nonnull sender) {
									[core reloadQuery:query]; // Reload query so that the core gets to compare existing results with fresh results and include the second created one
								} userInfo:nil ephermalUserInfo:nil]];
							}
							else
							{
								XCTAssert(!ContainsShareNamed(query, initialName));
								XCTAssert(ContainsShareNamed(query, secondName));

								[expectUpdatedShareQueryResults fulfill];

								[core reloadQuery:query]; // Reload query so that the core gets to compare existing results with fresh results and conclude nothing changed

								dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
									[core stopQuery:query];

									[core deleteShare:createdShare completionHandler:^(NSError * _Nullable error) {
										[expectDeleteShare fulfill];
										expectDeleteShare = nil;

										[core stopWithCompletionHandler:^(id sender, NSError *error) {
											[core.vault eraseWithCompletionHandler:^(id sender, NSError *error) {
												[expectCoreStop fulfill];
											}];
										}];
									}];
								});
							}
						};
						[core startQuery:shareQuery];
					}];
				}
			}
		};

		[core startQuery:query];
	}];

	[self waitForExpectationsWithTimeout:120.0 handler:nil];
}

- (void)testShareQueryPollingUpdates
{
	XCTestExpectation *expectFileList = [self expectationWithDescription:@"Expect root dir file list"];
	XCTestExpectation *expectCoreStop = [self expectationWithDescription:@"Expect core to stop"];
	__block XCTestExpectation *expectCreateShare = [self expectationWithDescription:@"Create share"];
	__block XCTestExpectation *expectDeleteShare = [self expectationWithDescription:@"Delete share"];
	__block XCTestExpectation *expectNewShareInQueryResults = [self expectationWithDescription:@"New share in query results"];
	__block XCTestExpectation *expectNewShareMissingInQueryResults = [self expectationWithDescription:@"New share missing in query results"];
	__block XCTestExpectation *expectInitialPopulationHandlerCall = [self expectationWithDescription:@"Initial population handler called"];

	OCCore *core = [[OCCore alloc] initWithBookmark:OCTestTarget.userBookmark];
	OCQuery *query = [OCQuery queryForPath:@"/"];
	OCShareQuery *shareQuery = [OCShareQuery queryWithScope:OCShareScopeSharedByUser item:nil];
	NSString *initialName = NSUUID.UUID.UUIDString;
	__block OCShare *createdShare = nil;

	BOOL(^ContainsShareNamed)(OCShareQuery *shareQuery, NSString *name) = ^(OCShareQuery *shareQuery, NSString *name) {
		for (OCShare *share in shareQuery.queryResults)
		{
			if ([share.name isEqual:name])
			{
				return (YES);
			}
		}

		return (NO);
	};

	[core startWithCompletionHandler:^(id sender, NSError *error) {
		query.includeRootItem = YES;
		query.changesAvailableNotificationHandler = ^(OCQuery * _Nonnull query) {
			if (query.state == OCQueryStateIdle)
			{
				OCItem *shareItem = nil;
				[expectFileList fulfill];

				for (OCItem *item in query.queryResults)
				{
					if (![item.path isEqual:@"/"])
					{
						shareItem = item;
						break;
					}
				}

				if (shareItem != nil)
				{
					shareQuery.refreshInterval = 2;
					shareQuery.changesAvailableNotificationHandler = ^(OCShareQuery * _Nonnull query) {
						OCLogDebug(@"shareQuery.queryResults=%@", query.queryResults);

						if (ContainsShareNamed(query, initialName) && (expectNewShareInQueryResults!=nil))
						{
							[expectNewShareInQueryResults fulfill];
							expectNewShareInQueryResults = nil;

							[core.connection deleteShare:createdShare resultTarget:[OCEventTarget eventTargetWithEphermalEventHandlerBlock:^(OCEvent * _Nonnull event, id  _Nonnull sender) {
								[expectDeleteShare fulfill];
								expectDeleteShare = nil;
							} userInfo:nil ephermalUserInfo:nil]];
						}
						else if ((expectNewShareInQueryResults == nil) && (expectNewShareMissingInQueryResults != nil))
						{
							[expectNewShareMissingInQueryResults fulfill];
							expectNewShareMissingInQueryResults = nil;

							[core stopQuery:query];

							[core stopWithCompletionHandler:^(id sender, NSError *error) {
								[core.vault eraseWithCompletionHandler:^(id sender, NSError *error) {
									[expectCoreStop fulfill];
								}];
							}];
						}
					};
					shareQuery.initialPopulationHandler = ^(OCShareQuery * _Nonnull query) {
						[expectInitialPopulationHandlerCall fulfill];

						XCTAssert(query.queryResults.count == 0);

						[core.connection createShare:[OCShare shareWithPublicLinkToPath:shareItem.path linkName:initialName permissions:OCSharePermissionsMaskRead password:nil expiration:nil] options:nil resultTarget:[OCEventTarget eventTargetWithEphermalEventHandlerBlock:^(OCEvent * _Nonnull event, id  _Nonnull sender) {
							createdShare = (OCShare *)event.result;

							OCLogDebug(@"Created share: %@, error: %@", createdShare, error);

							XCTAssert(event.error == nil);
							XCTAssert(createdShare != nil);

							[expectCreateShare fulfill];
						} userInfo:nil ephermalUserInfo:nil]];
					};
					[core startQuery:shareQuery];
				}
			}
		};

		[core startQuery:query];
	}];

	[self waitForExpectationsWithTimeout:120.0 handler:nil];
}

- (void)testFederatedAccept
{
	XCTestExpectation *expectEraseComplete = [self expectationWithDescription:@"Erase complete"];
	XCTestExpectation *expectDisconnectComplete = [self expectationWithDescription:@"Erase complete"];
	__block XCTestExpectation *expectPendingShare = [self expectationWithDescription:@"Expect pending share"];
	__block XCTestExpectation *expectPendingShareGone = [self expectationWithDescription:@"Expect pending share gone"];
	__block XCTestExpectation *expectAcceptedShare = [self expectationWithDescription:@"Expect accepted share"];

	OCConnection *remoteConnection = [[OCConnection alloc] initWithBookmark:OCTestTarget.federatedBookmark];
	__block OCShare *remoteShare = nil;
	__block OCCore *core = nil;

	[remoteConnection connectWithCompletionHandler:^(NSError *error, OCIssue *issue) {
		[remoteConnection createShare:[OCShare shareWithRecipient:[OCRecipient recipientWithUser:[OCUser userWithUserName:[OCTestTarget.userLogin stringByAppendingFormat:@"@%@", OCTestTarget.userBookmark.url.host] displayName:nil]] path:@"/Photos/" permissions:OCSharePermissionsMaskRead expiration:nil] options:nil resultTarget:[OCEventTarget eventTargetWithEphermalEventHandlerBlock:^(OCEvent * _Nonnull event, id  _Nonnull sender) {
			XCTAssert(event.error == nil);
			XCTAssert(event.result != nil);

			if (event.result != nil)
			{
				remoteShare = (OCShare *)event.result;

				dispatch_block_t shutdownAndCleanup = ^{
					[core stopWithCompletionHandler:^(id sender, NSError *error) {
						[core.vault eraseWithCompletionHandler:^(id sender, NSError *error) {
							[expectEraseComplete fulfill];
						}];

						[remoteConnection deleteShare:remoteShare resultTarget:[OCEventTarget eventTargetWithEphermalEventHandlerBlock:^(OCEvent * _Nonnull event, id  _Nonnull sender) {
							XCTAssert(event.error == nil);

							[remoteConnection disconnectWithCompletionHandler:^{
								[expectDisconnectComplete fulfill];
							}];
						} userInfo:nil ephermalUserInfo:nil]];
					}];
				};

				core = [[OCCore alloc] initWithBookmark:OCTestTarget.userBookmark];

				[core startWithCompletionHandler:^(id sender, NSError *error) {
					OCShareQuery *pendingQuery = [OCShareQuery queryWithScope:OCShareScopePendingCloudShares item:nil];
					OCShareQuery *acceptedQuery = [OCShareQuery queryWithScope:OCShareScopeAcceptedCloudShares item:nil];

					pendingQuery.changesAvailableNotificationHandler = ^(OCShareQuery * _Nonnull query) {
						OCLogDebug(@"Pending federated shares: %@", query.queryResults);
						OCShare *foundShare = nil;

						for (OCShare *share in query.queryResults)
						{
							if ([share.token isEqual:remoteShare.token])
							{
								foundShare = share;
							}
						}

						if ((expectPendingShare != nil) && (foundShare!=nil))
						{
							XCTAssert(foundShare.accepted!=nil && !foundShare.accepted.boolValue);

							[core makeDecisionOnShare:foundShare accept:YES completionHandler:^(NSError * _Nullable error) {

							}];

							[expectPendingShare fulfill];
							expectPendingShare = nil;
						}
						else
						{
							if ((expectPendingShare == nil) && (foundShare==nil))
							{
								[expectPendingShareGone fulfill];
							}
						}
					};

					acceptedQuery.changesAvailableNotificationHandler = ^(OCShareQuery * _Nonnull query) {
						OCLogDebug(@"Accepted federated shares: %@", query.queryResults);
						OCShare *foundShare = nil;

						for (OCShare *share in query.queryResults)
						{
							if ([share.token isEqual:remoteShare.token])
							{
								foundShare = share;
							}
						}

						if ((expectAcceptedShare != nil) && (foundShare!=nil))
						{
							XCTAssert(foundShare.accepted!=nil && foundShare.accepted.boolValue);

							[expectAcceptedShare fulfill];
							expectAcceptedShare = nil;

							shutdownAndCleanup();
						}
					};

					[core startQuery:pendingQuery];
					[core startQuery:acceptedQuery];
				}];
			}
		} userInfo:nil ephermalUserInfo:nil]];
	}];

	[self waitForExpectationsWithTimeout:120.0 handler:nil];
}

@end
