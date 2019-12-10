//
//  ItemPolicyTests.m
//  ownCloudSDKTests
//
//  Created by Felix Schwarz on 31.07.19.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <ownCloudSDK/ownCloudSDK.h>
#import "OCTestTarget.h"

@interface ItemPolicyTests : XCTestCase

@end

@implementation ItemPolicyTests

- (void)_runTestWithBookmark:(OCBookmark *)bookmark implementation:(void(^)(OCCore *core, OCQuery *query, void(^endTest)(BOOL doEraseVault)))implementation
{
	XCTestExpectation *expectRequestCore = [self expectationWithDescription:@"Request core"];
	XCTestExpectation *expectReturnCore = [self expectationWithDescription:@"Return core"];
	XCTestExpectation *expectEraseVault = [self expectationWithDescription:@"Erase vault"];
	__block XCTestExpectation *expectItemList = [self expectationWithDescription:@"Item list"];

	[OCCoreManager.sharedCoreManager requestCoreForBookmark:bookmark setup:nil completionHandler:^(OCCore * _Nullable core, NSError * _Nullable error) {
		__block BOOL testEnding = NO;

		void(^endTest)(BOOL doEraseVault) = ^(BOOL doEraseVault){
			if (testEnding) { return; }

			testEnding = YES;

			[OCCoreManager.sharedCoreManager returnCoreForBookmark:bookmark completionHandler:^{
				[expectReturnCore fulfill];

				if (doEraseVault)
				{
					[OCCoreManager.sharedCoreManager scheduleOfflineOperation:^(OCBookmark * _Nonnull bookmark, dispatch_block_t  _Nonnull completionHandler) {
						OCVault *vault = [[OCVault alloc] initWithBookmark:bookmark];

						[vault eraseWithCompletionHandler:^(id sender, NSError *error) {
							completionHandler();

							[expectEraseVault fulfill];
						}];
					} forBookmark:bookmark];
				}
				else
				{
					[expectEraseVault fulfill];
				}
			}];
		};

		OCQuery *query = [OCQuery queryForPath:@"/"];

		query.changesAvailableNotificationHandler = ^(OCQuery * _Nonnull query) {
			if (query.state == OCQueryStateIdle)
			{
				[expectItemList fulfill];
				expectItemList = nil;
			}

			if (!testEnding)
			{
				implementation(core, query, endTest);
			}
		};

		[core startQuery:query];

		[expectRequestCore fulfill];
	}];

	[self waitForExpectationsWithTimeout:120 handler:nil];
}

#pragma mark - Item policy processors
- (void)testAvailableOffline
{
	/*
		- finds a file and a folder at the root level
		- requests both to be available offline
		- checks policy coverage for the file and folder and the folder's items
		- checks all files in the folder were downloaded
		- removes the available offline policy for the folder
		- checks that all downloaded files are removed from that folder
	*/
	OCBookmark *bookmark = OCTestTarget.demoBookmark;

	__block OCItem *fileItem = nil;
	__block OCItem *folderItem = nil;

	__block OCItemPolicy *fileItemPolicy = nil;
	__block OCItemPolicy *folderItemPolicy = nil;

	__block XCTestExpectation *expectDirectCoverageOfFile = [self expectationWithDescription:@"Expect file to have direct available offline coverage"];
	__block XCTestExpectation *expectDirectCoverageOfFolder = [self expectationWithDescription:@"Expect folder to have direct available offline coverage"];
	__block XCTestExpectation *expectFolderFilesOffline = [self expectationWithDescription:@"Expect folder files to be available offline"];

	__block OCQuery *folderQuery = nil;

	[self _runTestWithBookmark:bookmark implementation:^(OCCore *theCore, OCQuery *query, void (^endTest)(BOOL doEraseVault)) {
		__weak OCCore *core = theCore;

		[query requestChangeSetWithFlags:OCQueryChangeSetRequestFlagOnlyResults completionHandler:^(OCQuery * _Nonnull query, OCQueryChangeSet * _Nullable changeset) {
			if (query.state == OCQueryStateIdle)
			{
				OCLogDebug(@"Items: %@", changeset.queryResult);

				if ((fileItem == nil) && (folderItem == nil))
				{
					for (OCItem *item in changeset.queryResult)
					{
						if ((item.type == OCItemTypeFile) && (fileItem == nil))
						{
							fileItem = item;
						}

						if ((item.type == OCItemTypeCollection) && (item.size > 0) && (folderItem == nil))
						{
							folderItem = item;

							folderQuery = [OCQuery queryForPath:folderItem.path];

							folderQuery.changesAvailableNotificationHandler = ^(OCQuery * _Nonnull query) {
								if (query.state == OCQueryStateIdle)
								{
									[query requestChangeSetWithFlags:OCQueryChangeSetRequestFlagOnlyResults completionHandler:^(OCQuery * _Nonnull query, OCQueryChangeSet * _Nullable changeset) {
										if (expectFolderFilesOffline != nil)
										{
											BOOL allDownloadedAndAvailableOffline = YES;
											BOOL hadItems = NO;

											for (OCItem *item in changeset.queryResult)
											{
												if (([core availableOfflinePolicyCoverageOfItem:item] == OCCoreAvailableOfflineCoverageIndirect) &&
												    ([core localCopyOfItem:item] != nil) &&
												    [item.downloadTriggerIdentifier isEqual:OCItemDownloadTriggerIDAvailableOffline]
												   )
												{
													hadItems = YES;
												}
												else
												{
													allDownloadedAndAvailableOffline = NO;
												}
											}

											if (hadItems && allDownloadedAndAvailableOffline)
											{
												[expectFolderFilesOffline fulfill];
												expectFolderFilesOffline = nil;

												[core removeAvailableOfflinePolicy:folderItemPolicy completionHandler:^(NSError * _Nullable error) {
													XCTAssert(error == nil);
												}];
											}
										}
										else
										{
											BOOL hadAvailableOfflineItems = NO;

											for (OCItem *item in changeset.queryResult)
											{
												if (([core availableOfflinePolicyCoverageOfItem:item] == OCCoreAvailableOfflineCoverageIndirect) &&
												    ([core localCopyOfItem:item] != nil) &&
												    [item.downloadTriggerIdentifier isEqual:OCItemDownloadTriggerIDAvailableOffline]
												   )
												{
													hadAvailableOfflineItems = YES;
												}
											}

											if (!hadAvailableOfflineItems && (changeset.queryResult.count > 0))
											{
												endTest(YES);
											}

										}
									}];
								}
							};

							[core startQuery:folderQuery];
						}
					}

					OCLogDebug(@"Taking %@ and %@ offline", fileItem.path, folderItem.path);

					XCTAssert(fileItem   != nil, @"No file found");
					XCTAssert(folderItem != nil, @"No folder found");

					[core makeAvailableOffline:folderItem options:@{ OCCoreOptionSkipRedundancyChecks : @(YES) } completionHandler:^(NSError * _Nullable error, OCItemPolicy * _Nullable itemPolicy) {
						XCTAssert(error == nil);
						XCTAssert(itemPolicy != nil);

						folderItemPolicy = itemPolicy;
					}];

					[core makeAvailableOffline:fileItem options:@{ OCCoreOptionSkipRedundancyChecks : @(YES) } completionHandler:^(NSError * _Nullable error, OCItemPolicy * _Nullable itemPolicy) {
						XCTAssert(error == nil);
						XCTAssert(itemPolicy != nil);

						fileItemPolicy = itemPolicy;
					}];
				}

				if (fileItemPolicy != nil)
				{
					for (OCItem *item in changeset.queryResult)
					{
						if ([item.localID isEqual:fileItem.localID])
						{
							if ([core availableOfflinePolicyCoverageOfItem:item] == OCCoreAvailableOfflineCoverageDirect)
							{
								[expectDirectCoverageOfFile fulfill];
								expectDirectCoverageOfFile = nil;
							}
						}
						else if ([item.localID isEqual:folderItem.localID])
						{
							if ([core availableOfflinePolicyCoverageOfItem:item] == OCCoreAvailableOfflineCoverageDirect)
							{
								[expectDirectCoverageOfFolder fulfill];
								expectDirectCoverageOfFolder = nil;
							}
						} else {
							XCTAssert([core availableOfflinePolicyCoverageOfItem:item] == OCCoreAvailableOfflineCoverageNone);
						}
					}
				}
			}
		}];
	}];
}

- (void)testDownloadExpiry
{
	/*
		- finds a file at the root level
		- downloads file
		- verifies file has been downloaded
		- sets download expiry to 2 seconds
		- verifies local copy of file has been auto-removed
	*/
	OCBookmark *bookmark = OCTestTarget.demoBookmark;

	__block OCItem *fileItem = nil;

	__block XCTestExpectation *expectDownloadComplete = [self expectationWithDescription:@"Expect file download to complete"];
	__block XCTestExpectation *expectAutoRemovalComplete = [self expectationWithDescription:@"Expect file auto-removal to complete"];

	[self _runTestWithBookmark:bookmark implementation:^(OCCore *theCore, OCQuery *query, void (^endTest)(BOOL doEraseVault)) {
		__weak OCCore *core = theCore;

		[query requestChangeSetWithFlags:OCQueryChangeSetRequestFlagOnlyResults completionHandler:^(OCQuery * _Nonnull query, OCQueryChangeSet * _Nullable changeset) {
			if (query.state == OCQueryStateIdle)
			{
				OCLogDebug(@"Items: %@", changeset.queryResult);

				if (fileItem == nil)
				{
					for (OCItem *item in changeset.queryResult)
					{
						if ((item.type == OCItemTypeFile) && (fileItem == nil))
						{
							fileItem = item;
						}
					}

					XCTAssert(fileItem != nil, @"No file found");

					OCLogDebug(@"Downloading %@", fileItem.path);

					[core downloadItem:fileItem options:nil resultHandler:^(NSError * _Nullable error, OCCore * _Nonnull core, OCItem * _Nullable item, OCFile * _Nullable file) {
						XCTAssert(error == nil);
						XCTAssert(item != nil);
						XCTAssert(file != nil);
					}];
				}
				else
				{
					for (OCItem *item in changeset.queryResult)
					{
						if ([item.localID isEqual:fileItem.localID])
						{
							if (expectDownloadComplete != nil)
							{
								if ([core localCopyOfItem:item] != nil)
								{
									[expectDownloadComplete fulfill];
									expectDownloadComplete = nil;

									// Set 1 second expiry
									[OCItemPolicyProcessor setUserPreferenceValue:@(1) forClassSettingsKey:OCClassSettingsKeyItemPolicyLocalCopyExpiration];
								}
							}
							else if (expectAutoRemovalComplete != nil)
							{
								if ([core localCopyOfItem:item] == nil)
								{
									[expectAutoRemovalComplete fulfill];
									expectAutoRemovalComplete = nil;

									endTest(YES);
								}
							}
						}
					}
				}
			}
		}];
	}];

	// Reset expiry to default value
	[OCItemPolicyProcessor setUserPreferenceValue:nil forClassSettingsKey:OCClassSettingsKeyItemPolicyLocalCopyExpiration];
}

- (void)testVacuum
{
	/*
		- uploads a file
		- deletes the file
		- sets sync anchor TTL to 1 second
		- verifies file has been removed locally and from database
		- ressets sync anchor TTL
	*/
	OCBookmark *bookmark = OCTestTarget.demoBookmark;

	__block OCItem *uploadedItem = nil;
	__block OCDatabaseID uploadedItemDatabaseID = nil;

	__block XCTestExpectation *expectUploadStart = [self expectationWithDescription:@"Upload started"];
	__block XCTestExpectation *expectUploadComplete = [self expectationWithDescription:@"Upload complete"];
	__block XCTestExpectation *expectDeleteComplete = [self expectationWithDescription:@"Delete complete"];
	__block XCTestExpectation *expectDatabaseRecordRemoved = [self expectationWithDescription:@"Database record removed"];

	NSURL *uploadFileURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"rainbow" withExtension:@"png"];
	NSString *uploadName = [NSString stringWithFormat:@"rainbow-%f.png", NSDate.timeIntervalSinceReferenceDate];

	[self _runTestWithBookmark:bookmark implementation:^(OCCore *theCore, OCQuery *query, void (^endTest)(BOOL doEraseVault)) {
		__weak OCCore *core = theCore;

		if (query.state == OCQueryStateIdle)
		{
			if (expectUploadStart != nil)
			{
				[expectUploadStart fulfill];
				expectUploadStart = nil;

				[core importFileNamed:uploadName at:query.rootItem fromURL:uploadFileURL isSecurityScoped:NO options:nil placeholderCompletionHandler:nil resultHandler:^(NSError * _Nullable error, OCCore * _Nonnull core, OCItem * _Nullable item, id  _Nullable parameter) {
					XCTAssert(error == nil, @"Import failed with error: %@", error);
					XCTAssert(item != nil);

					[expectUploadComplete fulfill];
					expectUploadComplete = nil;

					uploadedItem = item;
					uploadedItemDatabaseID = item.databaseID;

					XCTAssert(uploadedItemDatabaseID != nil);

					// Set TTL to 1 second
					[OCItemPolicyProcessor setUserPreferenceValue:@(1) forClassSettingsKey:OCClassSettingsKeyItemPolicyVacuumSyncAnchorTTL];

					[core deleteItem:uploadedItem requireMatch:YES resultHandler:^(NSError * _Nullable error, OCCore * _Nonnull core, OCItem * _Nullable item, id  _Nullable parameter) {
						[expectDeleteComplete fulfill];

						dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
							__block BOOL stillInDB = YES;
							NSUInteger iteration = 0;

							while (stillInDB && (iteration < 100) && (core != nil) && core.vault.database.sqlDB.opened)
							{
								[core.vault.database.sqlDB executeQuery:[OCSQLiteQuery query:[NSString stringWithFormat:@"SELECT * FROM %@ WHERE mdID = %@", OCDatabaseTableNameMetaData, uploadedItemDatabaseID] withParameters:nil resultHandler:^(OCSQLiteDB * _Nonnull db, NSError * _Nullable error, OCSQLiteTransaction * _Nullable transaction, OCSQLiteResultSet * _Nullable resultSet) {
									__block BOOL found = NO;

									[resultSet iterateUsing:^(OCSQLiteResultSet * _Nonnull resultSet, NSUInteger line, OCSQLiteRowDictionary  _Nonnull rowDictionary, BOOL * _Nonnull stop) {
										found = YES;
									} error:NULL];

									if (!found)
									{
										stillInDB = NO;

										[expectDatabaseRecordRemoved fulfill];
										expectDatabaseRecordRemoved = nil;

										endTest(YES);
									}
								}]];

								sleep(1);
							};
						});
					}];
				}];
			}
		}

	}];

	// Set TTL to default
	[OCItemPolicyProcessor setUserPreferenceValue:nil forClassSettingsKey:OCClassSettingsKeyItemPolicyVacuumSyncAnchorTTL];
}

#pragma mark - Claims
- (void)testClaimForLifetimeOfCore
{
	/*
		- creates claim bound to the lifetime of the core
		- verifies the claim is valid while the core runs
		- verifies the claim becomes invalid once the core is terminated
	*/
	__block OCClaim *coreBoundClaim = nil;

	[self _runTestWithBookmark:OCTestTarget.demoBookmark implementation:^(OCCore *core, OCQuery *query, void (^endTest)(BOOL doEraseVault)) {
		if (query.state == OCQueryStateIdle)
		{
			coreBoundClaim = [OCClaim claimForLifetimeOfCore:core explicitIdentifier:nil];

			XCTAssert(coreBoundClaim != nil);
			XCTAssert(coreBoundClaim.isValid);

			endTest(YES);
		}
	}];

	OCLogDebug(@"%@", coreBoundClaim);

	XCTAssert(coreBoundClaim != nil);
	XCTAssert(!coreBoundClaim.isValid);
}

- (void)testClaimExpires
{
	OCClaim *claim = [OCClaim claimExpiringAtDate:[NSDate dateWithTimeIntervalSinceNow:2]];
	OCClaim *claimForProcess = [OCClaim claimForProcessExpiringAtDate:[NSDate dateWithTimeIntervalSinceNow:2]];

	XCTAssert(claim != nil);
	XCTAssert(claim.isValid);

	XCTAssert(claimForProcess != nil);
	XCTAssert(claimForProcess.isValid);

	OCLogDebug(@"%@", claim);
	OCLogDebug(@"%@", claimForProcess);

	sleep(3);

	XCTAssert(claim != nil);
	XCTAssert(!claim.isValid);

	XCTAssert(claimForProcess != nil);
	XCTAssert(!claimForProcess.isValid);

}

- (void)testClaimProcess
{
	OCClaim *claim = [OCClaim processClaim];

	XCTAssert(claim != nil);
	XCTAssert(claim.isValid);

	OCLogDebug(@"%@", claim);

	claim = [claim removingClaimWithIdentifier:claim.identifier];

	XCTAssert(claim == nil);
}

- (void)testClaimExplicit
{
	OCClaim *claim = [OCClaim explicitClaimWithIdentifier:@"exID"];

	XCTAssert(claim != nil);
	XCTAssert(claim.isValid);

	OCLogDebug(@"%@", claim);

	claim = [claim removingClaimsWithExplicitIdentifier:@"exID"];

	XCTAssert(claim == nil);
}

- (void)testClaimGroup
{
	OCClaim *claim1 = [OCClaim explicitClaimWithIdentifier:@"exID1"];
	OCClaim *claim2 = [OCClaim explicitClaimWithIdentifier:@"exID2"];

	XCTAssert(claim1 != nil);
	XCTAssert(claim1.isValid);
	XCTAssert(claim2 != nil);
	XCTAssert(claim2.isValid);

	OCLogDebug(@"%@", claim1);
	OCLogDebug(@"%@", claim2);

	OCClaim *groupClaim = [OCClaim combining:claim1 with:claim2 usingOperator:OCClaimGroupOperatorOR];

	XCTAssert(groupClaim != nil);
	XCTAssert(groupClaim.groupClaims.count == 2);
	XCTAssert(groupClaim.isValid);

	OCLogDebug(@"%@", groupClaim);

	groupClaim = [groupClaim removingClaimsWithExplicitIdentifier:@"exID1"];

	XCTAssert(groupClaim != nil);
	XCTAssert(groupClaim.groupClaims.count == 1);
	XCTAssert(groupClaim.isValid);

	OCLogDebug(@"%@", groupClaim);

	groupClaim = [groupClaim removingClaimsWithExplicitIdentifier:@"exID2"];

	XCTAssert(groupClaim == nil);
}

- (void)testClaimSerialization
{
	__block OCClaim *coreBoundClaim = nil;

	[self _runTestWithBookmark:OCTestTarget.demoBookmark implementation:^(OCCore *core, OCQuery *query, void (^endTest)(BOOL doEraseVault)) {
		if (query.state == OCQueryStateIdle)
		{
			coreBoundClaim = [OCClaim claimForLifetimeOfCore:core explicitIdentifier:@"explicit"];

			XCTAssert(coreBoundClaim != nil);
			XCTAssert(coreBoundClaim.isValid);

			endTest(YES);
		}
	}];

	OCLogDebug(@"%@", coreBoundClaim);

	NSData *claimData = [NSKeyedArchiver archivedDataWithRootObject:coreBoundClaim];

	OCClaim *restoredClaim = [NSKeyedUnarchiver unarchivedObjectOfClass:[OCClaim class] fromData:claimData error:nil];

	XCTAssert(restoredClaim != nil);

	XCTAssert(restoredClaim.type == coreBoundClaim.type);
	XCTAssert(restoredClaim.creationTimestamp == coreBoundClaim.creationTimestamp);
	XCTAssert([restoredClaim.identifier isEqual:coreBoundClaim.identifier]);
	XCTAssert([restoredClaim.processSession.uuid isEqual:coreBoundClaim.processSession.uuid]);
	XCTAssert([restoredClaim.coreRunIdentifier isEqual:coreBoundClaim.coreRunIdentifier]);
	XCTAssert([restoredClaim.explicitIdentifier isEqual:coreBoundClaim.explicitIdentifier]);
}

@end
