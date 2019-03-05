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
				OCShare *newShare = event.result;

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
						[connection retrieveSharesWithScope:OCConnectionShareScopeSharedByUser forItem:nil options:nil completionHandler:^(NSError *error, NSArray<OCShare *> *shares) {
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
			OCShare *createShare = [OCShare shareWithPublicLinkToPath:items[1].path linkName:@"iOS SDK CI Share" permissions:OCSharePermissionsMaskRead password:@"test" expiration:[NSDate dateWithTimeIntervalSinceNow:24*60*60 * 2]];

			[expectList fulfill];

			[connection createShare:createShare options:nil resultTarget:[OCEventTarget eventTargetWithEphermalEventHandlerBlock:^(OCEvent * _Nonnull event, id  _Nonnull sender) {
				OCShare *newShare = event.result;

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

				[connection updateShare:newShare afterPerformingChanges:^(OCShare * _Nonnull share) {
					share.name = @"iOS SDK CI Share (updated)";
					share.permissions = OCSharePermissionsMaskRead|OCSharePermissionsMaskCreate|OCSharePermissionsMaskUpdate|OCSharePermissionsMaskDelete;
					share.password = @"testpassword";
					share.expirationDate = [NSDate dateWithTimeIntervalSinceNow:(24*60*60 * 14)];
				} resultTarget:[OCEventTarget eventTargetWithEphermalEventHandlerBlock:^(OCEvent * _Nonnull event, id  _Nonnull sender) {
					OCLog(@"Updated share with error=%@, share=%@", event.error, event.result);

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
		}];
		[expectConnect fulfill];
	}];

	[self waitForExpectationsWithTimeout:60 handler:nil];}

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
						[connection retrieveSharesWithScope:OCConnectionShareScopeSharedByUser forItem:nil options:nil completionHandler:^(NSError *error, NSArray<OCShare *> *shares) {
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

@end
