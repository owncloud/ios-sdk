//
//  SharingTests.m
//  ownCloudSDKTests
//
//  Created by Felix Schwarz on 01.03.19.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <ownCloudSDK/ownCloudSDK.h>

#import "OCTestTarget.h"

@interface SharingTests : XCTestCase

@end

@implementation SharingTests

- (void)testPublicShareCreationAndRetrieval
{
	XCTestExpectation *expectConnect = [self expectationWithDescription:@"Connected"];
	XCTestExpectation *expectShareCreated = [self expectationWithDescription:@"Created share"];
	XCTestExpectation *expectSharesRetrieved = [self expectationWithDescription:@"Received single list"];
	XCTestExpectation *expectSingleShareRetrieved = [self expectationWithDescription:@"Received single share"];
	XCTestExpectation *expectShareAmongList = [self expectationWithDescription:@"Share among list of received shares"];
	XCTestExpectation *expectDisconnect = [self expectationWithDescription:@"Disconnected"];
	XCTestExpectation *expectList = [self expectationWithDescription:@"File list retrieved"];
	OCConnection *connection = nil;

	connection = [[OCConnection alloc] initWithBookmark:OCTestTarget.adminBookmark];
	XCTAssert(connection!=nil);

	[connection connectWithCompletionHandler:^(NSError *error, OCIssue *issue) {
		XCTAssert(error==nil);
		XCTAssert(issue==nil);

		[connection retrieveItemListAtPath:@"/" depth:1 completionHandler:^(NSError *error, NSArray<OCItem *> *items) {
			OCShare *createShare = [OCShare shareWithPublicLinkToPath:items[1].path linkName:@"iOS SDK CI Share" permissions:OCSharePermissionsMaskRead password:@"test" expiration:[NSDate dateWithTimeIntervalSinceNow:24*60*60 * 2]];

			[expectList fulfill];

			[connection createShare:createShare options:nil resultTarget:[OCEventTarget eventTargetWithEphermalEventHandlerBlock:^(OCEvent * _Nonnull event, id  _Nonnull sender) {
				OCShare *newShare = (OCShare *)event.result;

				XCTAssert(event.error==nil);
				XCTAssert(event.result!=nil);

				OCLog(@"Created new share with error=%@, newShare=%@", event.error, event.result);

				XCTAssert([createShare.name 		isEqual:newShare.name]);
				XCTAssert(createShare.permissions 	== newShare.permissions);
				XCTAssert([createShare.itemPath 	isEqual:newShare.itemPath]);

				XCTAssert(newShare.url != nil);
				XCTAssert(newShare.token != nil);
				XCTAssert(newShare.creationDate != nil);
				XCTAssert(createShare.expirationDate.timeIntervalSinceNow >= (24*60*60));

				[expectShareCreated fulfill];

				XCTAssert([[NSKeyedUnarchiver unarchiveObjectWithData:[NSKeyedArchiver archivedDataWithRootObject:newShare]] isEqual:newShare]); // Test OCShare archive/dearchive/comparison

				[connection retrieveShareWithID:newShare.identifier options:nil completionHandler:^(NSError * _Nullable error, OCShare * _Nullable share) {
					OCLog(@"Retrieved new share with error=%@, share=%@", error, share);

					XCTAssert(error==nil);
					XCTAssert(share!=nil);
					XCTAssert(share!=newShare);

					XCTAssert([share.identifier 	isEqual:newShare.identifier]);
					XCTAssert([share.name 		isEqual:newShare.name]);
					XCTAssert(share.permissions 	== newShare.permissions);
					XCTAssert([share.url 		isEqual:newShare.url]);
					XCTAssert([share.token 		isEqual:newShare.token]);
					XCTAssert([share.creationDate 	isEqual:newShare.creationDate]);
					XCTAssert([share.expirationDate isEqual:newShare.expirationDate]);
					XCTAssert([share.itemPath 	isEqual:newShare.itemPath]);

					[expectSingleShareRetrieved fulfill];

					if (error == nil)
					{
						[connection retrieveSharesWithScope:OCShareScopeSharedByUser forItem:nil options:nil completionHandler:^(NSError *error, NSArray<OCShare *> *shares) {
							OCLogDebug(@"retrieveSharesWithScope: error=%@, shares=%@", error, shares);

							[expectSharesRetrieved fulfill];

							XCTAssert(error==nil);
							XCTAssert(shares!=nil);
							XCTAssert(shares.count>0);

							for (OCShare *share in shares)
							{
								if ([share.identifier isEqual:newShare.identifier])
								{
									[expectShareAmongList fulfill];

									XCTAssert([share.identifier 	isEqual:newShare.identifier]);
									XCTAssert([share.name 		isEqual:newShare.name]);
									XCTAssert(share.permissions 	== newShare.permissions);
									XCTAssert([share.url 		isEqual:newShare.url]);
									XCTAssert([share.token 		isEqual:newShare.token]);
									XCTAssert([share.creationDate 	isEqual:newShare.creationDate]);
									XCTAssert([share.expirationDate isEqual:newShare.expirationDate]);
									XCTAssert([share.itemPath 	isEqual:newShare.itemPath]);
								}
							}

							[connection deleteShare:newShare resultTarget:[OCEventTarget eventTargetWithEphermalEventHandlerBlock:^(OCEvent * _Nonnull event, id  _Nonnull sender) {
								OCLogDebug(@"deleteShare: error=%@", event.error);

								XCTAssert(event.error==nil);

								[connection retrieveShareWithID:newShare.identifier options:nil completionHandler:^(NSError * _Nullable error, OCShare * _Nullable share) {
									OCLogDebug(@"retrieveShareWithID (after deletion): error=%@, share=%@", error, share);

									XCTAssert([error isOCErrorWithCode:OCErrorShareNotFound]);
									XCTAssert(share==nil);

									[connection disconnectWithCompletionHandler:^{
										[expectDisconnect fulfill];
									}];
								}];
							} userInfo:nil ephermalUserInfo:nil]];
						}];
					}
				}];
			} userInfo:nil ephermalUserInfo:nil]];
		}];
		[expectConnect fulfill];
	}];

	[self waitForExpectationsWithTimeout:60 handler:nil];
}

- (void)testPublicShareCreationAndUpdate
{
	XCTestExpectation *expectConnect = [self expectationWithDescription:@"Connected"];
	XCTestExpectation *expectShareCreated = [self expectationWithDescription:@"Created share"];
	XCTestExpectation *expectSingleShareRetrieved = [self expectationWithDescription:@"Received single share"];
	XCTestExpectation *expectDisconnect = [self expectationWithDescription:@"Disconnected"];
	XCTestExpectation *expectList = [self expectationWithDescription:@"File list retrieved"];
	OCConnection *connection = nil;

	connection = [[OCConnection alloc] initWithBookmark:OCTestTarget.adminBookmark];
	XCTAssert(connection!=nil);

	[connection connectWithCompletionHandler:^(NSError *error, OCIssue *issue) {
		XCTAssert(error==nil);
		XCTAssert(issue==nil);

		[connection retrieveItemListAtPath:@"/" depth:1 completionHandler:^(NSError *error, NSArray<OCItem *> *items) {
			OCShare *passwordLessShare = [OCShare shareWithPublicLinkToPath:items[1].path linkName:@"iOS SDK CI Share" permissions:OCSharePermissionsMaskRead password:nil expiration:[NSDate dateWithTimeIntervalSinceNow:24*60*60 * 2]];
			XCTAssert(!passwordLessShare.protectedByPassword);

			OCShare *createShare = [OCShare shareWithPublicLinkToPath:items[1].path linkName:@"iOS SDK CI Share" permissions:OCSharePermissionsMaskRead password:@"test" expiration:[NSDate dateWithTimeIntervalSinceNow:24*60*60 * 2]];
			XCTAssert(createShare.protectedByPassword);

			[expectList fulfill];

			[connection createShare:createShare options:nil resultTarget:[OCEventTarget eventTargetWithEphermalEventHandlerBlock:^(OCEvent * _Nonnull event, id  _Nonnull sender) {
				OCShare *newShare = (OCShare *)event.result;

				XCTAssert(event.error==nil);
				XCTAssert(event.result!=nil);

				OCLog(@"Created new share with error=%@, newShare=%@", event.error, event.result);

				XCTAssert([createShare.name 		isEqual:newShare.name]);
				XCTAssert(createShare.permissions 	== newShare.permissions);
				XCTAssert([createShare.itemPath 	isEqual:newShare.itemPath]);

				XCTAssert(newShare.url != nil);
				XCTAssert(newShare.token != nil);
				XCTAssert(newShare.creationDate != nil);
				XCTAssert(newShare.protectedByPassword);
				XCTAssert(createShare.expirationDate.timeIntervalSinceNow >= (24*60*60));

				[expectShareCreated fulfill];

				[connection updateShare:newShare afterPerformingChanges:^(OCShare * _Nonnull share) {
					share.name = @"iOS SDK CI Share (updated)";
					share.permissions = OCSharePermissionsMaskRead|OCSharePermissionsMaskCreate|OCSharePermissionsMaskUpdate|OCSharePermissionsMaskDelete;
					share.protectedByPassword = NO;
					share.expirationDate = [NSDate dateWithTimeIntervalSinceNow:(24*60*60 * 14)];
				} resultTarget:[OCEventTarget eventTargetWithEphermalEventHandlerBlock:^(OCEvent * _Nonnull event, id  _Nonnull sender) {
					OCShare *updatedShare = (OCShare *)event.result;

					OCLog(@"Updated share with error=%@, share=%@", event.error, event.result);

					XCTAssert(!updatedShare.protectedByPassword);

					[connection updateShare:newShare afterPerformingChanges:^(OCShare * _Nonnull share) {
						// Change nothing => should return immediately
					} resultTarget:[OCEventTarget eventTargetWithEphermalEventHandlerBlock:^(OCEvent * _Nonnull event, id  _Nonnull sender) {
						XCTAssert(event.error == nil);

						[connection retrieveShareWithID:newShare.identifier options:nil completionHandler:^(NSError * _Nullable error, OCShare * _Nullable share) {
							XCTAssert(error==nil);
							XCTAssert(share!=nil);
							XCTAssert(share!=newShare);

							OCLog(@"Retrieved updated share with error=%@, share=%@", error, share);

							[expectSingleShareRetrieved fulfill];

							XCTAssert([share.identifier 	isEqual:newShare.identifier]);
							XCTAssert([share.name 		isEqual:@"iOS SDK CI Share (updated)"]);
							XCTAssert(share.permissions == (OCSharePermissionsMaskRead|OCSharePermissionsMaskCreate|OCSharePermissionsMaskUpdate|OCSharePermissionsMaskDelete));
							XCTAssert([share.url 		isEqual:newShare.url]);
							XCTAssert([share.token 		isEqual:newShare.token]);
							XCTAssert([share.creationDate 	isEqual:newShare.creationDate]);
							XCTAssert(!share.protectedByPassword);
							XCTAssert(share.expirationDate.timeIntervalSinceNow >= (24*60*60*12));
							XCTAssert([share.itemPath 	isEqual:newShare.itemPath]);

							[connection deleteShare:newShare resultTarget:[OCEventTarget eventTargetWithEphermalEventHandlerBlock:^(OCEvent * _Nonnull event, id  _Nonnull sender) {
								OCLogDebug(@"deleteShare: error=%@", event.error);

								XCTAssert(event.error==nil);

								[connection retrieveShareWithID:newShare.identifier options:nil completionHandler:^(NSError * _Nullable error, OCShare * _Nullable share) {
									OCLogDebug(@"retrieveShareWithID (after deletion): error=%@, share=%@", error, share);

									XCTAssert([error isOCErrorWithCode:OCErrorShareNotFound]);
									XCTAssert(share==nil);

									[connection disconnectWithCompletionHandler:^{
										[expectDisconnect fulfill];
									}];
								}];
							} userInfo:nil ephermalUserInfo:nil]];
						}];
					} userInfo:nil ephermalUserInfo:nil]];
				} userInfo:nil ephermalUserInfo:nil]];
			} userInfo:nil ephermalUserInfo:nil]];
		}];
		[expectConnect fulfill];
	}];

	[self waitForExpectationsWithTimeout:60 handler:nil];
}

- (void)testUserToUserSharing
{
	XCTestExpectation *expectConnect = [self expectationWithDescription:@"Connected"];
	XCTestExpectation *expectShareCreated = [self expectationWithDescription:@"Created share"];
	XCTestExpectation *expectShareRetrieved = [self expectationWithDescription:@"Share retrieved"];
	XCTestExpectation *expectShareRetrievedInRootSubitems = [self expectationWithDescription:@"Share retrieved in root subitems"];
	XCTestExpectation *expectRecipientSharesRetrieved = [self expectationWithDescription:@"Recipient shares retrieved"];
	XCTestExpectation *expectRecipientSharesContainNewShare = [self expectationWithDescription:@"Recipient shares contain new share"];
	XCTestExpectation *expectDisconnect = [self expectationWithDescription:@"Disconnected"];
	XCTestExpectation *expectList = [self expectationWithDescription:@"File list retrieved"];
	OCConnection *connection = nil;

	OCConnection *recipientConnection = nil;

	connection = [[OCConnection alloc] initWithBookmark:OCTestTarget.adminBookmark];
	XCTAssert(connection!=nil);

	recipientConnection = [[OCConnection alloc] initWithBookmark:OCTestTarget.userBookmark];
	XCTAssert(recipientConnection!=nil);

	[connection connectWithCompletionHandler:^(NSError *error, OCIssue *issue) {
		XCTAssert(error==nil);
		XCTAssert(issue==nil);

		[connection retrieveItemListAtPath:@"/" depth:1 completionHandler:^(NSError *error, NSArray<OCItem *> *items) {
			OCItem *shareItem = items.lastObject;
			OCItem *rootItem = items.firstObject;

			OCShare *createShare = [OCShare shareWithRecipient:[OCRecipient recipientWithUser:[OCUser userWithUserName:OCTestTarget.userLogin displayName:nil]] path:shareItem.path permissions:OCSharePermissionsMaskRead expiration:nil];

			[expectList fulfill];

			[connection createShare:createShare options:nil resultTarget:[OCEventTarget eventTargetWithEphermalEventHandlerBlock:^(OCEvent * _Nonnull event, id  _Nonnull sender) {
				OCShare *newShare = (OCShare *)event.result;

				XCTAssert(event.error==nil);
				XCTAssert(event.result!=nil);

				OCLog(@"Created new share with error=%@, newShare=%@", event.error, event.result);

				XCTAssert(createShare.recipient 	!= nil);
				XCTAssert(createShare.recipient.user 	!= nil);
				XCTAssert(!createShare.recipient.user.isRemote);
				XCTAssert(createShare.recipient.user.isRemote == newShare.recipient.user.isRemote);
				XCTAssert(createShare.permissions 	== newShare.permissions);
				XCTAssert([createShare.itemPath 	isEqual:newShare.itemPath]);

				XCTAssert(newShare.token == nil);
				XCTAssert(newShare.creationDate != nil);

				[expectShareCreated fulfill];

				[connection retrieveSharesWithScope:OCShareScopeItem forItem:shareItem options:nil completionHandler:^(NSError * _Nullable error, NSArray<OCShare *> * _Nullable shares) {
					XCTAssert(error==nil);
					XCTAssert(shares.count > 0);

					OCLog(@"Retrieved shares: %@", shares);

					for (OCShare *share in shares)
					{
						if ([share.identifier isEqual:newShare.identifier])
						{
							[expectShareRetrieved fulfill];
						}
					}

					[connection retrieveSharesWithScope:OCShareScopeSubItems forItem:rootItem options:nil completionHandler:^(NSError * _Nullable error, NSArray<OCShare *> * _Nullable shares) {
						OCLog(@"Retrieved shares of %@: %@", rootItem.path, shares);

						for (OCShare *share in shares)
						{
							if ([share.identifier isEqual:newShare.identifier])
							{
								[expectShareRetrievedInRootSubitems fulfill];
							}
						}

						[recipientConnection connectWithCompletionHandler:^(NSError *error, OCIssue *issue) {
							[recipientConnection retrieveSharesWithScope:OCShareScopeSharedWithUser forItem:nil options:nil completionHandler:^(NSError * _Nullable error, NSArray<OCShare *> * _Nullable shares) {
								XCTAssert(error == nil);
								XCTAssert(shares.count > 0);

								OCLog(@"Recipient shares: %@", shares);

								[expectRecipientSharesRetrieved fulfill];

								for (OCShare *share in shares)
								{
									if ([share.identifier isEqual:newShare.identifier])
									{
										[expectRecipientSharesContainNewShare fulfill];

										dispatch_block_t cleanup = ^{
											[connection deleteShare:newShare resultTarget:[OCEventTarget eventTargetWithEphermalEventHandlerBlock:^(OCEvent * _Nonnull event, id  _Nonnull sender) {
												XCTAssert(event.error == nil);

												[recipientConnection retrieveSharesWithScope:OCShareScopeSharedWithUser forItem:nil options:nil completionHandler:^(NSError * _Nullable error, NSArray<OCShare *> * _Nullable shares) {
													XCTAssert(error==nil);

													OCLog(@"Recipient shares after deletion: %@", shares);

													for (OCShare *share in shares)
													{
														if ([share.identifier isEqual:newShare.identifier])
														{
															XCTFail(@"Deleted share still around");
														}
													}

													[recipientConnection disconnectWithCompletionHandler:^{
														[connection disconnectWithCompletionHandler:^{
															[expectDisconnect fulfill];
														}];
													}];
												}];
											} userInfo:nil ephermalUserInfo:nil]];
										};

										if (recipientConnection.capabilities.sharingAutoAcceptShare.boolValue)
										{
											// Server is set up to auto-accept user-to-user shares
											XCTAssert([share.state isEqual:OCShareStateAccepted]);
											cleanup();
										}
										else
										{
											// Server is set up to not auto-accept user-to-user shares
											XCTAssert([share.state isEqual:OCShareStatePending]);

											// Accept share
											[recipientConnection makeDecisionOnShare:share accept:YES resultTarget:[OCEventTarget eventTargetWithEphermalEventHandlerBlock:^(OCEvent * _Nonnull event, id  _Nonnull sender) {
												OCLogDebug(@"Accepted with event.result=%@, .error=%@", event.result, event.error);

												// Retrieve shares again ..
												[recipientConnection retrieveSharesWithScope:OCShareScopeSharedWithUser forItem:nil options:nil completionHandler:^(NSError * _Nullable error, NSArray<OCShare *> * _Nullable shares) {
													for (OCShare *share in shares)
													{
														if ([share.identifier isEqual:newShare.identifier])
														{
															// .. and check that it's now accepted.
															XCTAssert([share.state isEqual:OCShareStateAccepted]);
														}
													}

													// Now reject share
													[recipientConnection makeDecisionOnShare:share accept:NO resultTarget:[OCEventTarget eventTargetWithEphermalEventHandlerBlock:^(OCEvent * _Nonnull event, id  _Nonnull sender) {
														OCLogDebug(@"Rejected with event.result=%@, .error=%@", event.result, event.error);

														// Retrieve shares again ..
														[recipientConnection retrieveSharesWithScope:OCShareScopeSharedWithUser forItem:nil options:nil completionHandler:^(NSError * _Nullable error, NSArray<OCShare *> * _Nullable shares) {
															for (OCShare *share in shares)
															{
																if ([share.identifier isEqual:newShare.identifier])
																{
																	// .. and check that it's now accepted.
																	XCTAssert([share.state isEqual:OCShareStateRejected]);
																}
															}

															// Finally clean up
															cleanup();
														}];
													} userInfo:nil ephermalUserInfo:nil]];
												}];
											} userInfo:nil ephermalUserInfo:nil]];
										}

										break;
									}
								}
							}];
						}];
					}];
				}];
			} userInfo:nil ephermalUserInfo:nil]];
		}];
		[expectConnect fulfill];
	}];

	[self waitForExpectationsWithTimeout:60 handler:nil];
}

- (void)testUserToUserToUserResharing
{
	XCTestExpectation *expectConnect = [self expectationWithDescription:@"Connected"];
	XCTestExpectation *expectShareCreated = [self expectationWithDescription:@"Created share"];
	XCTestExpectation *expectShareRetrieved = [self expectationWithDescription:@"Share retrieved"];
	XCTestExpectation *expectShareRetrievedInRootSubitems = [self expectationWithDescription:@"Share retrieved in root subitems"];
	XCTestExpectation *expectRecipientSharesRetrieved = [self expectationWithDescription:@"Recipient shares retrieved"];
	XCTestExpectation *expectRecipientSharesContainNewShare = [self expectationWithDescription:@"Recipient shares contain new share"];
	XCTestExpectation *expectReshare = [self expectationWithDescription:@"Shares contain reshare"];
	XCTestExpectation *expectReshareRecipientSeesReshare = [self expectationWithDescription:@"Reshare recipient sees reshare"];
	XCTestExpectation *expectOriginalShare = [self expectationWithDescription:@"Shares contain original share"];
	XCTestExpectation *expectDisconnect = [self expectationWithDescription:@"Disconnected"];
	XCTestExpectation *expectList = [self expectationWithDescription:@"File list retrieved"];
	OCConnection *connection = nil;
	OCConnection *recipientConnection = nil;
	OCConnection *reshareRecipientConnection = nil;

	connection = [[OCConnection alloc] initWithBookmark:OCTestTarget.adminBookmark];
	XCTAssert(connection!=nil);

	recipientConnection = [[OCConnection alloc] initWithBookmark:OCTestTarget.userBookmark];
	XCTAssert(recipientConnection!=nil);

	reshareRecipientConnection = [[OCConnection alloc] initWithBookmark:OCTestTarget.demoBookmark];
	XCTAssert(reshareRecipientConnection!=nil);

	[connection connectWithCompletionHandler:^(NSError *error, OCIssue *issue) {
		XCTAssert(error==nil);
		XCTAssert(issue==nil);

		[connection retrieveItemListAtPath:@"/" depth:1 completionHandler:^(NSError *error, NSArray<OCItem *> *items) {
			OCItem *shareItem = items.lastObject;
			OCItem *rootItem = items.firstObject;

			OCShare *createShare = [OCShare shareWithRecipient:[OCRecipient recipientWithUser:[OCUser userWithUserName:OCTestTarget.userLogin displayName:nil]] path:shareItem.path permissions:OCSharePermissionsMaskRead|OCSharePermissionsMaskShare expiration:nil];

			[expectList fulfill];

			[connection createShare:createShare options:nil resultTarget:[OCEventTarget eventTargetWithEphermalEventHandlerBlock:^(OCEvent * _Nonnull event, id  _Nonnull sender) {
				OCShare *newShare = (OCShare *)event.result;

				XCTAssert(event.error==nil);
				XCTAssert(event.result!=nil);

				OCLog(@"Created new share with error=%@, newShare=%@", event.error, event.result);

				XCTAssert(createShare.recipient 	!= nil);
				XCTAssert(createShare.recipient.user 	!= nil);
				XCTAssert(!createShare.recipient.user.isRemote);
				XCTAssert(createShare.recipient.user.isRemote == newShare.recipient.user.isRemote);
				XCTAssert(createShare.permissions 	== newShare.permissions);
				XCTAssert([createShare.itemPath 	isEqual:newShare.itemPath]);

				XCTAssert(newShare.token == nil);
				XCTAssert(newShare.creationDate != nil);

				[expectShareCreated fulfill];

				[connection retrieveSharesWithScope:OCShareScopeItem forItem:shareItem options:nil completionHandler:^(NSError * _Nullable error, NSArray<OCShare *> * _Nullable shares) {
					XCTAssert(error==nil);
					XCTAssert(shares.count > 0);

					OCLog(@"Retrieved shares: %@", shares);

					for (OCShare *share in shares)
					{
						if ([share.identifier isEqual:newShare.identifier])
						{
							[expectShareRetrieved fulfill];
						}
					}

					[connection retrieveSharesWithScope:OCShareScopeSubItems forItem:rootItem options:nil completionHandler:^(NSError * _Nullable error, NSArray<OCShare *> * _Nullable shares) {
						OCLog(@"Retrieved shares of %@: %@", rootItem.path, shares);

						for (OCShare *share in shares)
						{
							if ([share.identifier isEqual:newShare.identifier])
							{
								[expectShareRetrievedInRootSubitems fulfill];
							}
						}

						[recipientConnection connectWithCompletionHandler:^(NSError *error, OCIssue *issue) {
							[recipientConnection retrieveSharesWithScope:OCShareScopeSharedWithUser forItem:nil options:nil completionHandler:^(NSError * _Nullable error, NSArray<OCShare *> * _Nullable shares) {
								XCTAssert(error == nil);
								XCTAssert(shares.count > 0);

								OCLog(@"Recipient shares: %@", shares);

								[expectRecipientSharesRetrieved fulfill];

								for (OCShare *share in shares)
								{
									if ([share.identifier isEqual:newShare.identifier])
									{
										[expectRecipientSharesContainNewShare fulfill];

										OCShare *createReshare = [OCShare shareWithRecipient:[OCRecipient recipientWithUser:[OCUser userWithUserName:OCTestTarget.demoLogin displayName:nil]] path:share.itemPath permissions:OCSharePermissionsMaskRead|OCSharePermissionsMaskShare expiration:nil];

										[recipientConnection createShare:createReshare options:nil resultTarget:[OCEventTarget eventTargetWithEphermalEventHandlerBlock:^(OCEvent * _Nonnull event, id  _Nonnull sender) {
											OCShare *newReshare = (OCShare *)event.result;

											XCTAssert(event.error == nil);
											XCTAssert(event.result != nil);

											OCLog(@"Created re-share: %@", newReshare);

											[connection retrieveSharesWithScope:OCShareScopeItemWithReshares forItem:shareItem options:nil completionHandler:^(NSError * _Nullable error, NSArray<OCShare *> * _Nullable shares) {

												XCTAssert(error==nil);
												XCTAssert(shares!=nil);

												OCLog(@"Retrieved items including re-share: %@", shares);

												for (OCShare *share in shares)
												{
													if ([share.identifier isEqual:newShare.identifier])
													{
														[expectOriginalShare fulfill];
													}

													if ([share.identifier isEqual:newReshare.identifier])
													{
														[expectReshare fulfill];
													}
												}

												[reshareRecipientConnection connectWithCompletionHandler:^(NSError *error, OCIssue *issue) {
													[reshareRecipientConnection retrieveSharesWithScope:OCShareScopeSharedWithUser forItem:nil options:nil completionHandler:^(NSError * _Nullable error, NSArray<OCShare *> * _Nullable shares) {
														XCTAssert(error==nil);
														XCTAssert(shares!=nil);

														for (OCShare *share in shares)
														{
															if ([share.identifier isEqual:newReshare.identifier])
															{
																[expectReshareRecipientSeesReshare fulfill];
															}
														}

														[recipientConnection deleteShare:newReshare resultTarget:[OCEventTarget eventTargetWithEphermalEventHandlerBlock:^(OCEvent * _Nonnull event, id  _Nonnull sender) {
															XCTAssert(event.error == nil);

															[connection deleteShare:newShare resultTarget:[OCEventTarget eventTargetWithEphermalEventHandlerBlock:^(OCEvent * _Nonnull event, id  _Nonnull sender) {
																XCTAssert(event.error == nil);

																[recipientConnection retrieveSharesWithScope:OCShareScopeSharedWithUser forItem:nil options:nil completionHandler:^(NSError * _Nullable error, NSArray<OCShare *> * _Nullable shares) {
																	XCTAssert(error==nil);

																	OCLog(@"Recipient shares after deletion: %@", shares);

																	for (OCShare *share in shares)
																	{
																		if ([share.identifier isEqual:newShare.identifier])
																		{
																			XCTFail(@"Deleted share still around");
																		}

																		if ([share.identifier isEqual:newReshare.identifier])
																		{
																			XCTFail(@"Re-share of deleted share still around");
																		}
																	}

																	[reshareRecipientConnection disconnectWithCompletionHandler:^{
																		[recipientConnection disconnectWithCompletionHandler:^{
																			[connection disconnectWithCompletionHandler:^{
																				[expectDisconnect fulfill];
																			}];
																		}];
																	}];
																}];
															} userInfo:nil ephermalUserInfo:nil]];
														} userInfo:nil ephermalUserInfo:nil]];
													}];
												}];
											}];
										} userInfo:nil ephermalUserInfo:nil]];

										break;
									}
								}
							}];
						}];
					}];
				}];
			} userInfo:nil ephermalUserInfo:nil]];
		}];
		[expectConnect fulfill];
	}];

	[self waitForExpectationsWithTimeout:120 handler:nil];
}

- (void)testFederatedSharing
{
	XCTestExpectation *expectConnect = [self expectationWithDescription:@"Connected"];
	XCTestExpectation *expectShareCreated = [self expectationWithDescription:@"Created share"];
	XCTestExpectation *expectShareRetrieved = [self expectationWithDescription:@"Share retrieved"];
	XCTestExpectation *expectPendingSharesRetrieved = [self expectationWithDescription:@"Pending shares retrieved"];
	XCTestExpectation *expectPendingSharesContainNewShare = [self expectationWithDescription:@"Pending shares contain new share"];
	XCTestExpectation *expectDisconnect = [self expectationWithDescription:@"Disconnected"];
	XCTestExpectation *expectList = [self expectationWithDescription:@"File list retrieved"];
	OCConnection *connection = nil;

	OCConnection *recipientConnection = nil;

	connection = [[OCConnection alloc] initWithBookmark:OCTestTarget.adminBookmark];
	XCTAssert(connection!=nil);

	recipientConnection = [[OCConnection alloc] initWithBookmark:OCTestTarget.federatedBookmark];
	XCTAssert(recipientConnection!=nil);

	[connection connectWithCompletionHandler:^(NSError *error, OCIssue *issue) {
		XCTAssert(error==nil);
		XCTAssert(issue==nil);

		NSString *remoteUser = OCTestTarget.federatedLogin;
		NSString *remoteHost = OCTestTarget.federatedTargetURL.host;

		NSString *remoteUserIDFull = [remoteUser stringByAppendingFormat:@"@%@", remoteHost];

		[connection retrieveItemListAtPath:@"/" depth:1 completionHandler:^(NSError *error, NSArray<OCItem *> *items) {
			OCShare *createShare = [OCShare shareWithRecipient:[OCRecipient recipientWithUser:[OCUser userWithUserName:remoteUserIDFull displayName:nil]] path:items[1].path permissions:OCSharePermissionsMaskRead expiration:nil];

			[expectList fulfill];

			[connection createShare:createShare options:nil resultTarget:[OCEventTarget eventTargetWithEphermalEventHandlerBlock:^(OCEvent * _Nonnull event, id  _Nonnull sender) {
				OCShare *newShare = (OCShare *)event.result;

				XCTAssert(event.error==nil);
				XCTAssert(event.result!=nil);

				OCLog(@"Created new share with error=%@, newShare=%@", event.error, event.result);

				XCTAssert(createShare.recipient 	!= nil);
				XCTAssert(createShare.recipient.user 	!= nil);
				XCTAssert(createShare.recipient.user.isRemote == newShare.recipient.user.isRemote);
				XCTAssert([createShare.recipient.user.remoteUserName isEqual:newShare.recipient.user.remoteUserName]);
				XCTAssert([createShare.recipient.user.remoteHost isEqual:newShare.recipient.user.remoteHost]);
				XCTAssert([createShare.recipient.user.remoteUserName isEqual:remoteUser]);
				XCTAssert([createShare.recipient.user.remoteHost isEqual:remoteHost]);
				XCTAssert(createShare.permissions 	== newShare.permissions);
				XCTAssert([createShare.itemPath 	isEqual:newShare.itemPath]);

				XCTAssert(newShare.token != nil);
				XCTAssert(newShare.creationDate != nil);

				[expectShareCreated fulfill];

				[connection retrieveSharesWithScope:OCShareScopeSharedByUser forItem:nil options:nil completionHandler:^(NSError * _Nullable error, NSArray<OCShare *> * _Nullable shares) {
					XCTAssert(error==nil);
					XCTAssert(shares.count > 0);

					OCLog(@"Retrieved shares: %@", shares);

					for (OCShare *share in shares)
					{
						if ([share.token isEqual:newShare.token])
						{
							[expectShareRetrieved fulfill];
						}
					}

					[recipientConnection connectWithCompletionHandler:^(NSError *error, OCIssue *issue) {
						[recipientConnection retrieveSharesWithScope:OCShareScopePendingCloudShares forItem:nil options:nil completionHandler:^(NSError * _Nullable error, NSArray<OCShare *> * _Nullable shares) {
							XCTAssert(error == nil);
							XCTAssert(shares.count > 0);

							OCLog(@"Pending shares: %@", shares);

							[expectPendingSharesRetrieved fulfill];

							for (OCShare *share in shares)
							{
								if ([share.token isEqual:newShare.token])
								{
									[expectPendingSharesContainNewShare fulfill];
									XCTAssert((share.accepted!=nil) && !share.accepted.boolValue);

									[recipientConnection makeDecisionOnShare:share accept:YES resultTarget:[OCEventTarget eventTargetWithEphermalEventHandlerBlock:^(OCEvent * _Nonnull event, id  _Nonnull sender) {
										OCLog(@"Accepted share: %@, error=%@, result=%@", event, event.error, event.result);

										XCTAssert(event.error == nil);

										sleep(2); // Apparently accepted shares /can/ be slow to be updated :-/

										[recipientConnection retrieveSharesWithScope:OCShareScopeAcceptedCloudShares forItem:nil options:nil completionHandler:^(NSError * _Nullable error, NSArray<OCShare *> * _Nullable shares) {
											OCShare *deleteShare = nil;

											XCTAssert(error==nil);
											XCTAssert(shares.count > 0);

											OCLog(@"Accepted shares: %@", shares);

											for (OCShare *share in shares)
											{
												if ([share.token isEqual:newShare.token])
												{
													deleteShare = share;
													XCTAssert(share.accepted.boolValue);

												}
											}

											if (deleteShare != nil)
											{
												[recipientConnection deleteShare:deleteShare resultTarget:[OCEventTarget eventTargetWithEphermalEventHandlerBlock:^(OCEvent * _Nonnull event, id  _Nonnull sender) {
													XCTAssert(event.error == nil);

													sleep(2); // Apparently accepted shares /can/ be slow to be updated :-/

													[recipientConnection retrieveSharesWithScope:OCShareScopeAcceptedCloudShares forItem:nil options:nil completionHandler:^(NSError * _Nullable error, NSArray<OCShare *> * _Nullable shares) {
														XCTAssert(error==nil);

														OCLog(@"Accepted shares: %@", shares);

														for (OCShare *share in shares)
														{
															if ([share.token isEqual:newShare.token])
															{
																XCTFail(@"Deleted share still around");
															}
														}

														[recipientConnection disconnectWithCompletionHandler:^{
															[connection disconnectWithCompletionHandler:^{
																[expectDisconnect fulfill];
															}];
														}];
													}];
												} userInfo:nil ephermalUserInfo:nil]];
											}
										}];
									} userInfo:nil ephermalUserInfo:nil]];

									break;
								}
							}
						}];
					}];
				}];
			} userInfo:nil ephermalUserInfo:nil]];
		}];
		[expectConnect fulfill];
	}];

	[self waitForExpectationsWithTimeout:60 handler:nil];
}

- (void)testSharingErrors
{
	XCTestExpectation *expectConnect = [self expectationWithDescription:@"Connected"];
//	XCTestExpectation *expectShareCreated = [self expectationWithDescription:@"Created share"];
//	XCTestExpectation *expectShareRetrieved = [self expectationWithDescription:@"Share retrieved"];
//	XCTestExpectation *expectShareRetrievedInRootSubitems = [self expectationWithDescription:@"Share retrieved in root subitems"];
//	XCTestExpectation *expectRecipientSharesRetrieved = [self expectationWithDescription:@"Recipient shares retrieved"];
//	XCTestExpectation *expectRecipientSharesContainNewShare = [self expectationWithDescription:@"Recipient shares contain new share"];
	XCTestExpectation *expectDisconnect = [self expectationWithDescription:@"Disconnected"];
	XCTestExpectation *expectList = [self expectationWithDescription:@"File list retrieved"];
	OCConnection *connection = nil;

	OCConnection *recipientConnection = nil;

	connection = [[OCConnection alloc] initWithBookmark:OCTestTarget.adminBookmark];
	XCTAssert(connection!=nil);

	recipientConnection = [[OCConnection alloc] initWithBookmark:OCTestTarget.userBookmark];
	XCTAssert(recipientConnection!=nil);

	[connection connectWithCompletionHandler:^(NSError *error, OCIssue *issue) {
		XCTAssert(error==nil);
		XCTAssert(issue==nil);

		[connection retrieveItemListAtPath:@"/" depth:1 completionHandler:^(NSError *error, NSArray<OCItem *> *items) {

			dispatch_group_t waitForCompletion = dispatch_group_create();

//			OCItem *shareItem = items.lastObject;
			OCItem *rootItem = items.firstObject;

			OCShare *createRootShare = [OCShare shareWithRecipient:[OCRecipient recipientWithUser:[OCUser userWithUserName:OCTestTarget.userLogin displayName:nil]] path:rootItem.path permissions:OCSharePermissionsMaskRead expiration:nil];

			[expectList fulfill];

			// Can't share root folder
			dispatch_group_enter(waitForCompletion);

			[connection createShare:createRootShare options:nil resultTarget:[OCEventTarget eventTargetWithEphermalEventHandlerBlock:^(OCEvent * _Nonnull event, id  _Nonnull sender) {
				XCTAssert(event.error != nil); // Can't share root folder error
				dispatch_group_leave(waitForCompletion);
			} userInfo:nil ephermalUserInfo:nil]];

			// Retrieve shares for item without item
			dispatch_group_enter(waitForCompletion);

			[connection retrieveSharesWithScope:OCShareScopeItem forItem:nil options:nil completionHandler:^(NSError * _Nullable error, NSArray<OCShare *> * _Nullable shares) {
				XCTAssert(error != nil); // Scope requires item
				XCTAssert([error isOCErrorWithCode:OCErrorInsufficientParameters]);
				dispatch_group_leave(waitForCompletion);
			}];

			// Retrieve shares for non-existant item
			OCItem *nonexistantItem = [OCItem placeholderItemOfType:OCItemTypeFile];
			nonexistantItem.path = @"/does.not.exist";

			dispatch_group_enter(waitForCompletion);

			[connection retrieveSharesWithScope:OCShareScopeItem forItem:nonexistantItem options:nil completionHandler:^(NSError * _Nullable error, NSArray<OCShare *> * _Nullable shares) {
				XCTAssert(error != nil); // Scope requires item
				XCTAssert([error isOCErrorWithCode:OCErrorShareItemNotFound]);
				dispatch_group_leave(waitForCompletion);
			}];

			dispatch_group_notify(waitForCompletion, dispatch_get_main_queue(), ^{
				[connection disconnectWithCompletionHandler:^{
					[expectDisconnect fulfill];
				}];
			});
		}];
		[expectConnect fulfill];
	}];

	[self waitForExpectationsWithTimeout:60 handler:nil];
}

- (void)testSharesRetrieval
{
	XCTestExpectation *expectConnect = [self expectationWithDescription:@"Connected"];
	XCTestExpectation *expectShareCreated = [self expectationWithDescription:@"Created share"];
	XCTestExpectation *expectSharesRetrieved = [self expectationWithDescription:@"Received share list"];
	XCTestExpectation *expectDisconnect = [self expectationWithDescription:@"Disconnected"];
	XCTestExpectation *expectLists = [self expectationWithDescription:@"Disconnected"];
	OCConnection *connection = nil;

	connection = [[OCConnection alloc] initWithBookmark:OCTestTarget.adminBookmark];
	XCTAssert(connection!=nil);

	[connection connectWithCompletionHandler:^(NSError *error, OCIssue *issue) {
		XCTAssert(error==nil);
		XCTAssert(issue==nil);

		[connection retrieveItemListAtPath:@"/" depth:1 completionHandler:^(NSError *error, NSArray<OCItem *> *items) {
			[connection createShare:[OCShare shareWithPublicLinkToPath:items[1].path linkName:@"iOS SDK CI" permissions:OCSharePermissionsMaskRead password:@"test" expiration:[NSDate dateWithTimeIntervalSinceNow:24*60*60 * 2]] options:nil resultTarget:[OCEventTarget eventTargetWithEphermalEventHandlerBlock:^(OCEvent * _Nonnull event, id  _Nonnull sender) {
				OCLog(@"error=%@, newShare=%@", event.error, event.result);

				[expectShareCreated fulfill];

				[connection retrieveItemListAtPath:@"/Documents/" depth:1 completionHandler:^(NSError *error, NSArray<OCItem *> *items) {
					[expectLists fulfill];

					if (error == nil)
					{
						[connection retrieveSharesWithScope:OCShareScopeSharedByUser forItem:nil options:nil completionHandler:^(NSError *error, NSArray<OCShare *> *shares) {
							OCLogDebug(@"error=%@, shares=%@", error, shares);

							[expectSharesRetrieved fulfill];

							[connection disconnectWithCompletionHandler:^{
								[expectDisconnect fulfill];
							}];
						}];
					}
				}];
			} userInfo:nil ephermalUserInfo:nil]];
		}];
		[expectConnect fulfill];
	}];

	[self waitForExpectationsWithTimeout:60 handler:nil];
}

- (void)testRecipientsSearch
{
	XCTestExpectation *expectConnect = [self expectationWithDescription:@"Connected"];
	XCTestExpectation *expectDisconnect = [self expectationWithDescription:@"Disconnected"];

	OCConnection *connection = nil;

	connection = [[OCConnection alloc] initWithBookmark:OCTestTarget.adminBookmark];
	XCTAssert(connection!=nil);

	[connection connectWithCompletionHandler:^(NSError *error, OCIssue *issue) {
		[expectConnect fulfill];

		void (^CountUsersAndGroups)(NSArray<OCRecipient *> *recipient, NSUInteger expectedUsers, NSUInteger expectedGroups) = ^(NSArray<OCRecipient *> *recipients, NSUInteger expectedUsers, NSUInteger expectedGroups) {
			NSInteger users = 0, groups = 0;

			for (OCRecipient *recipient in recipients)
			{
				XCTAssert([[NSKeyedUnarchiver unarchiveObjectWithData:[NSKeyedArchiver archivedDataWithRootObject:recipient]] isEqual:recipient]); // Test OCRecipient/OCUser/OCGroup archive/dearchive/comparison

				if (recipient.type == OCRecipientTypeUser)
				{
					users++;
				}

				if (recipient.type == OCRecipientTypeGroup)
				{
					groups++;
				}
			}

			XCTAssert(expectedUsers == users);
			XCTAssert(expectedGroups == groups);
		};

		[connection retrieveRecipientsForItemType:OCItemTypeFile ofShareType:nil searchTerm:nil maximumNumberOfRecipients:200 completionHandler:^(NSError * _Nullable error, NSArray<OCRecipient *> * _Nullable recipients) {
			OCLog(@"Retrieved recipients=%@ with error=%@", recipients, error);

			XCTAssert(error==nil);
			XCTAssert(recipients!=nil);
			CountUsersAndGroups(recipients, 3, 1);

			[connection retrieveRecipientsForItemType:OCItemTypeCollection ofShareType:@[@(OCShareTypeGroupShare)] searchTerm:nil maximumNumberOfRecipients:200 completionHandler:^(NSError * _Nullable error, NSArray<OCRecipient *> * _Nullable recipients) {
				OCLog(@"Retrieved recipients=%@ with error=%@", recipients, error);

				XCTAssert(error==nil);
				XCTAssert(recipients!=nil);
				CountUsersAndGroups(recipients, 0, 1);

				[connection retrieveRecipientsForItemType:OCItemTypeFile ofShareType:@[@(OCShareTypeUserShare)] searchTerm:nil maximumNumberOfRecipients:200 completionHandler:^(NSError * _Nullable error, NSArray<OCRecipient *> * _Nullable recipients) {
					OCLog(@"Retrieved recipients=%@ with error=%@", recipients, error);

					XCTAssert(error==nil);
					XCTAssert(recipients!=nil);
					CountUsersAndGroups(recipients, 3, 0);

					[connection retrieveRecipientsForItemType:OCItemTypeFile ofShareType:@[@(OCShareTypeUserShare), @(OCShareTypeGroupShare)] searchTerm:nil maximumNumberOfRecipients:200 completionHandler:^(NSError * _Nullable error, NSArray<OCRecipient *> * _Nullable recipients) {
						OCLog(@"Retrieved recipients=%@ with error=%@", recipients, error);

						XCTAssert(error==nil);
						XCTAssert(recipients!=nil);
						CountUsersAndGroups(recipients, 3, 1);

						[connection retrieveRecipientsForItemType:OCItemTypeFile ofShareType:@[@(OCShareTypeUserShare)] searchTerm:@"admin" maximumNumberOfRecipients:200 completionHandler:^(NSError * _Nullable error, NSArray<OCRecipient *> * _Nullable recipients) {
							OCLog(@"Retrieved recipients=%@ with error=%@", recipients, error);

							XCTAssert(error==nil);
							XCTAssert(recipients!=nil);
							CountUsersAndGroups(recipients, 1, 0);

							[connection retrieveRecipientsForItemType:OCItemTypeCollection ofShareType:@[@(OCShareTypeGroupShare)] searchTerm:@"admin" maximumNumberOfRecipients:200 completionHandler:^(NSError * _Nullable error, NSArray<OCRecipient *> * _Nullable recipients) {
								OCLog(@"Retrieved recipients=%@ with error=%@", recipients, error);

								XCTAssert(error==nil);
								XCTAssert(recipients!=nil);
								CountUsersAndGroups(recipients, 0, 1);

								[connection retrieveRecipientsForItemType:OCItemTypeCollection ofShareType:nil searchTerm:@"admin" maximumNumberOfRecipients:200 completionHandler:^(NSError * _Nullable error, NSArray<OCRecipient *> * _Nullable recipients) {
									OCLog(@"Retrieved recipients=%@ with error=%@", recipients, error);

									XCTAssert(error==nil);
									XCTAssert(recipients!=nil);
									CountUsersAndGroups(recipients, 1, 1);

									[connection retrieveRecipientsForItemType:OCItemTypeCollection ofShareType:nil searchTerm:@"admin" maximumNumberOfRecipients:0 completionHandler:^(NSError * _Nullable error, NSArray<OCRecipient *> * _Nullable recipients) {
										OCLog(@"Retrieved recipients=%@ with error=%@", recipients, error);

										XCTAssert(error!=nil);
										XCTAssert([error isOCErrorWithCode:OCErrorInsufficientParameters]);
										XCTAssert(recipients==nil);

										[connection retrieveRecipientsForItemType:OCItemTypeCollection ofShareType:nil searchTerm:@"admin@demo.owncloud." maximumNumberOfRecipients:10 completionHandler:^(NSError * _Nullable error, NSArray<OCRecipient *> * _Nullable recipients) {
											OCLog(@"Retrieved recipients=%@ with error=%@", recipients, error);

											XCTAssert(error==nil);
											XCTAssert(recipients.count == 1);
											XCTAssert(recipients.firstObject.type == OCRecipientTypeUser);
											XCTAssert([recipients.firstObject.user.userName isEqual:@"admin@demo.owncloud."]);
											XCTAssert([recipients.firstObject.user.displayName isEqual:@"admin@demo.owncloud."]);

											[connection disconnectWithCompletionHandler:^{
												[expectDisconnect fulfill];
											}];
										}];
									}];
								}];
							}];
						}];
					}];
				}];
			}];
		}];
	}];

	[self waitForExpectationsWithTimeout:60 handler:nil];
}

- (void)testSharingItemWithSpecialChars
{
	XCTestExpectation *expectConnect = [self expectationWithDescription:@"Connected"];
	XCTestExpectation *expectFolderCreated = [self expectationWithDescription:@"Created folder"];
	XCTestExpectation *expectFolderDeleted = [self expectationWithDescription:@"Deleted folder"];
	XCTestExpectation *expectShareCreated = [self expectationWithDescription:@"Created share"];
	XCTestExpectation *expectDisconnect = [self expectationWithDescription:@"Disconnected"];
	XCTestExpectation *expectLists = [self expectationWithDescription:@"Lists"];
	OCConnection *connection = nil;

	connection = [[OCConnection alloc] initWithBookmark:OCTestTarget.adminBookmark];
	XCTAssert(connection!=nil);

	[connection connectWithCompletionHandler:^(NSError *error, OCIssue *issue) {
		XCTAssert(error==nil);
		XCTAssert(issue==nil);

		[connection retrieveItemListAtPath:@"/" depth:1 completionHandler:^(NSError *error, NSArray<OCItem *> *items) {
			NSString *folderName = [@"Test+" stringByAppendingString:[NSDate new].description];

			[expectLists fulfill];

			[connection createFolder:folderName inside:items[0] options:nil resultTarget:[OCEventTarget eventTargetWithEphermalEventHandlerBlock:^(OCEvent * _Nonnull event, id  _Nonnull sender) {
				OCItem *newFolderItem = (OCItem *)event.result;

				XCTAssert(event.error == nil);
				XCTAssert(newFolderItem != nil);

				OCLog(@"error=%@, newFolder=%@", event.error, event.result);

				[expectFolderCreated fulfill];

				[connection createShare:[OCShare shareWithPublicLinkToPath:newFolderItem.path linkName:@"iOS SDK CI" permissions:OCSharePermissionsMaskRead password:@"test" expiration:[NSDate dateWithTimeIntervalSinceNow:24*60*60 * 2]] options:nil resultTarget:[OCEventTarget eventTargetWithEphermalEventHandlerBlock:^(OCEvent * _Nonnull event, id  _Nonnull sender) {
					OCLog(@"error=%@, newShare=%@", event.error, event.result);

					XCTAssert(event.error == nil);
					XCTAssert(event.result != nil);

					[expectShareCreated fulfill];

					[connection deleteItem:newFolderItem requireMatch:NO resultTarget:[OCEventTarget eventTargetWithEphermalEventHandlerBlock:^(OCEvent * _Nonnull event, id  _Nonnull sender) {
						XCTAssert(event.error == nil);

						OCLog(@"error=%@, result=%@", event.error, event.result);

						[expectFolderDeleted fulfill];

						[connection disconnectWithCompletionHandler:^{
							[expectDisconnect fulfill];
						}];
					} userInfo:nil ephermalUserInfo:nil]];
				} userInfo:nil ephermalUserInfo:nil]];

			} userInfo:nil ephermalUserInfo:nil]];
		}];

		[expectConnect fulfill];
	}];

	[self waitForExpectationsWithTimeout:60 handler:nil];
}

- (void)testRequestPrivateLink
{
	XCTestExpectation *expectConnect = [self expectationWithDescription:@"Connected"];
	XCTestExpectation *expectDisconnect = [self expectationWithDescription:@"Disconnected"];
	XCTestExpectation *expectLists = [self expectationWithDescription:@"Lists"];
	XCTestExpectation *expectPrivateLink = [self expectationWithDescription:@"Private link retrieved"];
	OCConnection *connection = nil;

	connection = [[OCConnection alloc] initWithBookmark:OCTestTarget.adminBookmark];
	XCTAssert(connection!=nil);

	[connection connectWithCompletionHandler:^(NSError *error, OCIssue *issue) {
		XCTAssert(error==nil);
		XCTAssert(issue==nil);

		[connection retrieveItemListAtPath:@"/" depth:1 completionHandler:^(NSError *error, NSArray<OCItem *> *items) {
			[expectLists fulfill];

			for (OCItem *item in items)
			{
				if ((item.type == OCItemTypeFile) && (item.privateLink == nil))
				{
					[connection retrievePrivateLinkForItem:item completionHandler:^(NSError * _Nullable error, NSURL * _Nullable privateLink) {
						XCTAssert(error == nil);
						XCTAssert(privateLink != nil);
						XCTAssert(item.privateLink == privateLink);

						OCLogDebug(@"error=%@, privateLink: %@", error, privateLink);

						[expectPrivateLink fulfill];

						[connection disconnectWithCompletionHandler:^{
							[expectDisconnect fulfill];
						}];
					}];
					break;
				}
			}
		}];

		[expectConnect fulfill];
	}];

	[self waitForExpectationsWithTimeout:60 handler:nil];
}

@end
