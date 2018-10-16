//
//  OCCore+SyncEngine.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 15.05.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2018, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCCore+SyncEngine.h"
#import "OCCore+Internal.h"
#import "NSError+OCError.h"
#import "OCLogger.h"
#import "OCSyncAction.h"
#import "OCMacros.h"
#import "NSProgress+OCExtensions.h"
#import "NSString+OCParentPath.h"
#import "OCQuery+Internal.h"
#import "OCSyncContext.h"
#import "OCCore+FileProvider.h"
#import "OCCore+ItemList.h"
#import "NSString+OCFormatting.h"

@implementation OCCore (SyncEngine)

#pragma mark - Sync Anchor
- (void)retrieveLatestSyncAnchorWithCompletionHandler:(void(^)(NSError *error, OCSyncAnchor latestSyncAnchor))completionHandler
{
	[self.vault.database retrieveValueForCounter:OCCoreSyncAnchorCounter completionHandler:^(NSError *error, NSNumber *counterValue) {
		[self willChangeValueForKey:@"latestSyncAnchor"];
		self->_latestSyncAnchor = counterValue;
		[self didChangeValueForKey:@"latestSyncAnchor"];

		if (completionHandler != nil)
		{
			completionHandler(error, counterValue);
		}
	}];
}

- (OCSyncAnchor)retrieveLatestSyncAnchorWithError:(NSError * __autoreleasing *)outError
{
	__block OCSyncAnchor syncAnchor = nil;

	OCSyncExec(syncAnchorRetrieval, {
		[self retrieveLatestSyncAnchorWithCompletionHandler:^(NSError *error, OCSyncAnchor latestSyncAnchor) {
			if (outError != NULL)
			{
				*outError = error;
			}

			syncAnchor = latestSyncAnchor;

			OCSyncExecDone(syncAnchorRetrieval);
		}];
	});

	return (syncAnchor);
}

- (OCItem *)retrieveLatestVersionOfItem:(OCItem *)item withError:(NSError * __autoreleasing *)outError
{
	__block OCItem *latestItem = nil;

	OCSyncExec(databaseRetrieval, {
		[self.database retrieveCacheItemsAtPath:item.path itemOnly:YES completionHandler:^(OCDatabase *db, NSError *error, OCSyncAnchor syncAnchor, NSArray<OCItem *> *items) {
			if (outError != NULL)
			{
				*outError = error;
			}

			latestItem = items[0];

			OCSyncExecDone(databaseRetrieval);
		}];
	});

	return (latestItem);
}

- (void)incrementSyncAnchorWithProtectedBlock:(NSError *(^)(OCSyncAnchor previousSyncAnchor, OCSyncAnchor newSyncAnchor))protectedBlock completionHandler:(void(^)(NSError *error, OCSyncAnchor previousSyncAnchor, OCSyncAnchor newSyncAnchor))completionHandler
{
	[self.vault.database increaseValueForCounter:OCCoreSyncAnchorCounter withProtectedBlock:^NSError *(NSNumber *previousCounterValue, NSNumber *newCounterValue) {
		if (protectedBlock != nil)
		{
			return (protectedBlock(previousCounterValue, newCounterValue));
		}

		return (nil);
	} completionHandler:^(NSError *error, NSNumber *previousCounterValue, NSNumber *newCounterValue) {
		[self willChangeValueForKey:@"latestSyncAnchor"];
		self->_latestSyncAnchor = newCounterValue;
		[self didChangeValueForKey:@"latestSyncAnchor"];

		if (completionHandler != nil)
		{
			completionHandler(error, previousCounterValue, newCounterValue);
		}
	}];
}

#pragma mark - Sync Engine
- (void)performProtectedSyncBlock:(NSError *(^)(void))protectedBlock completionHandler:(void(^)(NSError *))completionHandler
{
	[self.vault.database increaseValueForCounter:OCCoreSyncJournalCounter withProtectedBlock:^NSError *(NSNumber *previousCounterValue, NSNumber *newCounterValue) {
		if (protectedBlock != nil)
		{
			return (protectedBlock());
		}

		return (nil);
	} completionHandler:^(NSError *error, NSNumber *previousCounterValue, NSNumber *newCounterValue) {
		if (completionHandler != nil)
		{
			completionHandler(error);
		}
	}];
}

- (NSProgress *)synchronizeWithServer
{
	return(nil); // Stub implementation
}

#pragma mark - Sync Record Scheduling
- (NSProgress *)_enqueueSyncRecordWithAction:(OCSyncAction *)action allowsRescheduling:(BOOL)allowsRescheduling resultHandler:(OCCoreActionResultHandler)resultHandler
{
	NSProgress *progress = nil;
	OCSyncRecord *syncRecord;

	if (action != nil)
	{
		progress = [NSProgress indeterminateProgress];

		syncRecord = [[OCSyncRecord alloc] initWithAction:action resultHandler:resultHandler];

		syncRecord.progress = progress;
		syncRecord.allowsRescheduling = allowsRescheduling;

		[self submitSyncRecord:syncRecord];
	}

	return(progress);
}

- (void)submitSyncRecord:(OCSyncRecord *)record
{
	OCLogDebug(@"SE: record %@ submitted", record);

	[self performProtectedSyncBlock:^NSError *{
		__block NSError *blockError = nil;

		[self.vault.database addSyncRecords:@[ record ] completionHandler:^(OCDatabase *db, NSError *error) {
			blockError = error;
		}];

		OCLogDebug(@"SE: record %@ added to database with error %@", record, blockError);

		// Pre-flight
		if (blockError == nil)
		{
			OCSyncAction *syncAction;

			if ((syncAction = record.action) != nil)
			{
				syncAction.core = self;

				if ([syncAction implements:@selector(preflightWithContext:)])
				{
					OCSyncContext *syncContext;

					OCLogDebug(@"SE: record %@ enters preflight", record);

					if ((syncContext = [OCSyncContext preflightContextWithSyncRecord:record]) != nil)
					{
						// Run pre-flight
						[syncAction preflightWithContext:syncContext];

						OCLogDebug(@"SE: record %@ returns from preflight with addedItems=%@, removedItems=%@, updatedItems=%@, refreshPaths=%@, removeRecords=%@, updateStoredSyncRecordAfterItemUpdates=%d, error=%@", record, syncContext.addedItems, syncContext.removedItems, syncContext.updatedItems, syncContext.refreshPaths, syncContext.removeRecords, syncContext.updateStoredSyncRecordAfterItemUpdates, syncContext.error);

						// Perform any preflight-triggered updates
						[self _performUpdatesForAddedItems:syncContext.addedItems removedItems:syncContext.removedItems updatedItems:syncContext.updatedItems refreshPaths:syncContext.refreshPaths];

						if (syncContext.removeRecords != nil)
						{
							[self.vault.database removeSyncRecords:syncContext.removeRecords completionHandler:nil];
						}

						if (syncContext.updateStoredSyncRecordAfterItemUpdates)
						{
							[self.vault.database updateSyncRecords:@[ syncContext.syncRecord ] completionHandler:nil];
						}

						blockError = syncContext.error;
					}
				}
			}
		}

		return (blockError);
	} completionHandler:^(NSError *error) {
		if (error != nil)
		{
			OCLogDebug(@"SE: record %@ returned from preflight with error=%@ - removing record", record, error);

			// Error during pre-flight
			if (record.recordID != nil)
			{
				// Record still has a recordID, so wasn't included in syncContext.removeRecords. Remove now.
				[self.vault.database removeSyncRecords:@[ record ] completionHandler:nil];
			}

			if (record.resultHandler != nil)
			{
				// Call result handler
				record.resultHandler(error, self, record.action.localItem, record);
				record.resultHandler = nil;
			}
		}

		[self setNeedsToProcessSyncRecords];
	}];
}

- (NSError *)_rescheduleSyncRecord:(OCSyncRecord *)syncRecord withUpdates:(NSError *(^)(OCSyncRecord *record))applyUpdates
{
	__block NSError *error = nil;

	if (applyUpdates != nil)
	{
		error = applyUpdates(syncRecord);
	}

	OCLogDebug(@"SE: rescheduling record %@ with updates (returning error=%@)", syncRecord, error);

	if (error == nil)
	{
		syncRecord.inProgressSince = nil;
		syncRecord.state = OCSyncRecordStatePending;

		[self.vault.database updateSyncRecords:@[syncRecord] completionHandler:^(OCDatabase *db, NSError *updateError) {
			error = updateError;
		}];
	}

	return (error);
}

- (void)rescheduleSyncRecord:(OCSyncRecord *)syncRecord withUpdates:(NSError *(^)(OCSyncRecord *record))applyUpdates
{
	if (syncRecord==nil) { return; }

	[self performProtectedSyncBlock:^NSError *{
		return ([self _rescheduleSyncRecord:syncRecord withUpdates:applyUpdates]);
	} completionHandler:^(NSError *error) {
		if (error != nil)
		{
			OCLogError(@"SE: error %@ rescheduling sync record %@", OCLogPrivate(error), OCLogPrivate(syncRecord));
		}
	}];
}

- (NSError *)_descheduleSyncRecord:(OCSyncRecord *)syncRecord invokeResultHandler:(BOOL)invokeResultHandler resultHandlerError:(NSError *)resultHandlerError
{
	__block NSError *error = nil;
	OCSyncAction *syncAction;

	if (syncRecord==nil) { return(OCError(OCErrorInsufficientParameters)); }

	OCLogDebug(@"SE: descheduling record %@ (invokeResultHandler=%d, error=%@)", syncRecord, invokeResultHandler, resultHandlerError);

	[self.vault.database removeSyncRecords:@[syncRecord] completionHandler:^(OCDatabase *db, NSError *removeError) {
		error = removeError;
	}];

	if ((syncAction = syncRecord.action) != nil)
	{
		syncAction.core = self;

		if ([syncAction implements:@selector(descheduleWithContext:)])
		{
			OCSyncContext *syncContext;

			if ((syncContext = [OCSyncContext descheduleContextWithSyncRecord:syncRecord]) != nil)
			{
				OCLogDebug(@"SE: record %@ enters post-deschedule", syncRecord);

				// Run descheduler
				[syncAction descheduleWithContext:syncContext];

				OCLogDebug(@"SE: record %@ returns from post-deschedule with addedItems=%@, removedItems=%@, updatedItems=%@, refreshPaths=%@, removeRecords=%@, updateStoredSyncRecordAfterItemUpdates=%d, error=%@", syncRecord, syncContext.addedItems, syncContext.removedItems, syncContext.updatedItems, syncContext.refreshPaths, syncContext.removeRecords, syncContext.updateStoredSyncRecordAfterItemUpdates, syncContext.error);

				// Perform any descheduler-triggered updates
				[self _performUpdatesForAddedItems:syncContext.addedItems removedItems:syncContext.removedItems updatedItems:syncContext.updatedItems refreshPaths:syncContext.refreshPaths];

				error = syncContext.error;
			}
		}
	}

	if (invokeResultHandler)
	{
		if (syncRecord.resultHandler != nil)
		{
			syncRecord.resultHandler(resultHandlerError, self, syncRecord.action.localItem, syncRecord);
		}
	}

	return (error);
}

- (void)descheduleSyncRecord:(OCSyncRecord *)syncRecord invokeResultHandler:(BOOL)invokeResultHandler resultHandlerError:(NSError *)resultHandlerError
{
	if (syncRecord==nil) { return; }

	[self performProtectedSyncBlock:^NSError *{
		return ([self _descheduleSyncRecord:syncRecord invokeResultHandler:invokeResultHandler resultHandlerError:resultHandlerError]);
	} completionHandler:^(NSError *error) {
		if (error != nil)
		{
			OCLogError(@"SE: error %@ descheduling sync record %@", OCLogPrivate(error), OCLogPrivate(syncRecord));
		}
	}];
}

#pragma mark - Sync Engine Processing
- (void)setNeedsToProcessSyncRecords
{
	OCLogDebug(@"SE: setNeedsToProcessSyncRecords");

	@synchronized(self)
	{
		_needsToProcessSyncRecords = YES;
	}

	[self _processSyncRecordsIfNeeded];
}

- (void)_processSyncRecordsIfNeeded
{
	[self queueBlock:^{
		BOOL needsToProcessSyncRecords;

		OCLogDebug(@"SE: _processSyncRecordsIfNeeded");

		if (self.reachabilityMonitor.available)
		{
			@synchronized(self)
			{
				needsToProcessSyncRecords = self->_needsToProcessSyncRecords;
				self->_needsToProcessSyncRecords = NO;
			}

			if (needsToProcessSyncRecords)
			{
				[self _processSyncRecords];
			}
		}
	}];
}

- (void)_processSyncRecords
{
	[self beginActivity:@"process sync records"];

	[self performProtectedSyncBlock:^NSError *{
		__block NSError *error = nil;
		__block BOOL couldSchedule = NO;
		__block OCSyncRecord *scheduleSyncRecord = nil;

		OCLogDebug(@"SE: processing sync records");

		[self.vault.database retrieveSyncRecordsForPath:nil action:nil inProgressSince:nil completionHandler:^(OCDatabase *db, NSError *dbError, NSArray<OCSyncRecord *> *syncRecords) {
			NSMutableArray <OCConnectionIssue *> *issues = [NSMutableArray new];

			if (dbError != nil)
			{
				error = dbError;
				return;
			}

			for (OCSyncRecord *syncRecord in syncRecords)
			{
				NSError *scheduleError = nil;

				OCLogDebug(@"SE: record %@ enters processing", syncRecord);

				// Remove cancelled sync records
				if (syncRecord.progress.cancelled)
				{
					OCLogDebug(@"SE: record %@ has been cancelled - removing", syncRecord);

					// Deschedule & call resultHandler
					[self _descheduleSyncRecord:syncRecord invokeResultHandler:YES resultHandlerError:OCError(OCErrorCancelled)];
					continue;
				}

				// Handle sync records that are already in processing
				if (syncRecord.inProgressSince != nil)
				{
					if (syncRecord.blockedByDifferentCopyOfThisProcess && syncRecord.allowsRescheduling)
					{
						OCLogDebug(@"SE: record %@ in progress since %@ detected as hung - rescheduling", syncRecord, syncRecord.inProgressSince);

						// Unblock (and process hereafter) record hung in waiting for a user interaction in another copy of the same app (i.e. happens if this app crashed or was terminated)
						[self _rescheduleSyncRecord:syncRecord withUpdates:nil];
					}
					else
					{
						// Wait until that sync record has finished processing
						OCLogDebug(@"SE: record %@ in progress since %@ - waiting for its completion", syncRecord, syncRecord.inProgressSince);
						break;
					}
				}

				// Skip sync records without an ID
				if (syncRecord.recordID == nil)
				{
					OCLogWarning(@"SE: skipping sync record without recordID: %@", OCLogPrivate(syncRecord));
					continue;
				}

				// Schedule actions
				{
					OCSyncAction *syncAction;

					if ((syncAction = syncRecord.action) != nil)
					{
						syncAction.core = self;

						// Schedule the record using the route for its sync action
						OCSyncContext *syncContext = [OCSyncContext schedulerContextWithSyncRecord:syncRecord];

						scheduleSyncRecord = syncRecord;

						OCLogDebug(@"SE: record %@ will be scheduled", OCLogPrivate(syncRecord));

						couldSchedule = [syncAction scheduleWithContext:syncContext];

						if (syncContext.issues.count != 0)
						{
							[issues addObjectsFromArray:syncContext.issues];
						}

						scheduleError = syncContext.error;

						OCLogDebug(@"SE: record %@ scheduled with error %@", OCLogPrivate(syncRecord), OCLogPrivate(scheduleError));
					}
					else
					{
						// No route for scheduling this sync record => sync action not implementd
						scheduleError = OCError(OCErrorFeatureNotImplemented);
					}
				}

				OCLogDebug(@"SE: record %@ couldSchedule=%d with error %@", OCLogPrivate(syncRecord), couldSchedule, OCLogPrivate(scheduleError));

				// Update database if scheduling was successful
				if (couldSchedule)
				{
					syncRecord.inProgressSince = [NSDate date];
					syncRecord.state = OCSyncRecordStateScheduled;

					OCLogDebug(@"SE: record %@ updated in database", OCLogPrivate(syncRecord));

					[db updateSyncRecords:@[ syncRecord ] completionHandler:^(OCDatabase *db, NSError *dbError) {
						error = dbError;
					}];
				}

				if (scheduleError != nil)
				{
					OCLogError(@"SE: error scheduling %@: %@", OCLogPrivate(syncRecord), scheduleError);
					error = scheduleError;

					if (!couldSchedule && (issues.count == 0))
					{
						// The sync record failed scheduling with an error, but provides no issue to dismiss it
						// [_] create issue for sync scheduling error that allows dismissing the actionIdentifier
						//     [issues addObject:[self _issueForCancellationAndDeschedulingSyncRecord:syncRecord title:[NSString stringWithFormat:OCLocalized(@"Sync actionIdentifier %@ failed"), syncRecord.actionIdentifier] description:error.localizedDescription]];
						// [x] let Sync Engine retry the next time it is called, make sure all actions create issues if needed
					}
				}

				// Don't schedule more than one record at a time, don't run later records ahead of time if the first unscheduled one failed scheduling
				break;
			}

			// Handle issues
			error = [self _handleIssues:issues forSyncRecord:scheduleSyncRecord syncStep:@"scheduling" priorActionSuccess:couldSchedule error:error];
		}];

		return (error);
	} completionHandler:^(NSError *error) {
		[self endActivity:@"process sync records"];
	}];
}

#pragma mark - Sync event handling
- (void)_handleSyncEvent:(OCEvent *)event sender:(id)sender
{
	[self beginActivity:@"handle sync event"];

	[self performProtectedSyncBlock:^NSError *{
		__block NSError *error = nil;
		__block OCSyncRecord *syncRecord = nil;
		OCSyncRecordID syncRecordID;
		BOOL syncRecordActionCompleted = NO;
		NSMutableArray <OCConnectionIssue *> *issues = [NSMutableArray new];

		// Fetch sync record
		if ((syncRecordID = event.userInfo[@"syncRecordID"]) != nil)
		{
			OCLogDebug(@"SE: handling sync event %@", OCLogPrivate(event));

			[self.vault.database retrieveSyncRecordForID:syncRecordID completionHandler:^(OCDatabase *db, NSError *retrieveError, OCSyncRecord *retrievedSyncRecord) {
				syncRecord = retrievedSyncRecord;
				error = retrieveError;
			}];

			OCLogDebug(@"SE: record %@ received an event %@", OCLogPrivate(syncRecord), OCLogPrivate(event));

			if (error != nil)
			{
				OCLogWarning(@"SE: could not fetch sync record for ID %@ because of error %@. Dropping event %@ from %@ unhandled.", syncRecordID, error, event, sender);
				return(error);
			}

			if (syncRecord == nil)
			{
				OCLogWarning(@"SE: could not fetch sync record for ID %@. Dropping event %@ from %@ unhandled.", syncRecordID, error, event, sender);
				return (nil);
			}
		}

		// Handle event for sync record
		if ((syncRecord != nil) && (syncRecord.action != nil))
		{
			OCSyncAction *syncAction = nil;
			OCSyncContext *syncContext = nil;

			// Dispatch to result handlers
			if ((syncAction = syncRecord.action) != nil)
			{
				syncAction.core = self;

				syncContext = [OCSyncContext resultHandlerContextWith:syncRecord event:event issues:issues];

				OCLogDebug(@"SE: record %@ enters event handling %@", OCLogPrivate(syncRecord), OCLogPrivate(event));

				syncRecordActionCompleted = [syncAction handleResultWithContext:syncContext];

				error = syncContext.error;
			}

			OCLogDebug(@"SE: record %@ passed event handling: syncAction=%@, syncRecordActionCompleted=%d, error=%@", OCLogPrivate(syncRecord), syncAction, syncRecordActionCompleted, error);

			// Handle result handler return values
			if (syncRecordActionCompleted)
			{
				// Sync record action completed
				if (error != nil)
				{
					OCLogWarning(@"SE: record %@ will be removed despite error: %@", syncRecord, error);
				}

				// - Indicate "done" to progress object
				syncRecord.progress.totalUnitCount = 1;
				syncRecord.progress.completedUnitCount = 1;

				// - Remove sync record from database
				[self.vault.database removeSyncRecords:@[ syncRecord ] completionHandler:^(OCDatabase *db, NSError *deleteError) {
					error = deleteError;
				}];

				// - Perform updates for added/changed/removed items and refresh paths
				[self _performUpdatesForAddedItems:syncContext.addedItems removedItems:syncContext.removedItems updatedItems:syncContext.updatedItems refreshPaths:syncContext.refreshPaths];

				OCLogDebug(@"SE: record %@ returned from event handling post-processing with addedItems=%@, removedItems=%@, updatedItems=%@, refreshPaths=%@, removeRecords=%@, error=%@", syncRecord, syncContext.addedItems, syncContext.removedItems, syncContext.updatedItems, syncContext.refreshPaths, syncContext.removeRecords, syncContext.error);
			}

			// Handle issues
			error = [self _handleIssues:issues forSyncRecord:syncRecord syncStep:@"event handling" priorActionSuccess:syncRecordActionCompleted error:error];
		}
		else
		{
			OCLogWarning(@"Unhandled sync event %@ from %@", OCLogPrivate(event), sender);
		}

		return (error);
	} completionHandler:^(NSError *error) {
		if (error != nil)
		{
			OCLogError(@"Sync Engine: error processing event %@ from %@: %@", OCLogPrivate(event), sender, error);
		}

		// Trigger handling of any remaining sync records
		[self setNeedsToProcessSyncRecords];

		[self endActivity:@"handle sync event"];
	}];
}

- (void)performUpdatesForAddedItems:(NSArray<OCItem *> *)addedItems removedItems:(NSArray<OCItem *> *)removedItems updatedItems:(NSArray<OCItem *> *)updatedItems refreshPaths:(NSArray <OCPath> *)refreshPaths
{
	[self beginActivity:@"perform item updates"];

	[self performProtectedSyncBlock:^NSError *{
		[self _performUpdatesForAddedItems:addedItems removedItems:removedItems updatedItems:updatedItems refreshPaths:refreshPaths];
		return (nil);
	} completionHandler:^(NSError *error) {
		[self endActivity:@"perform item updates"];
	}];
}

- (void)_performUpdatesForAddedItems:(NSArray<OCItem *> *)addedItems removedItems:(NSArray<OCItem *> *)removedItems updatedItems:(NSArray<OCItem *> *)updatedItems refreshPaths:(NSArray <OCPath> *)refreshPaths
{
	// - Update metaData table and queries
	if ((addedItems.count > 0) || (removedItems.count > 0) || (updatedItems.count > 0))
	{
		__block OCSyncAnchor syncAnchor = nil;

		// Update metaData table with changes from the parameter set
		[self incrementSyncAnchorWithProtectedBlock:^NSError *(OCSyncAnchor previousSyncAnchor, OCSyncAnchor newSyncAnchor) {
			__block NSError *updateError = nil;

			if (addedItems.count > 0)
			{
				[self.vault.database addCacheItems:addedItems syncAnchor:newSyncAnchor completionHandler:^(OCDatabase *db, NSError *error) {
					if (error != nil) { updateError = error; }
				}];
			}

			if (removedItems.count > 0)
			{
				[self.vault.database removeCacheItems:removedItems syncAnchor:newSyncAnchor completionHandler:^(OCDatabase *db, NSError *error) {
					if (error != nil) { updateError = error; }
				}];
			}

			if (updatedItems.count > 0)
			{
				[self.vault.database updateCacheItems:updatedItems syncAnchor:newSyncAnchor completionHandler:^(OCDatabase *db, NSError *error) {
					if (error != nil) { updateError = error; }
				}];
			}

			syncAnchor = newSyncAnchor;

			return (updateError);
		} completionHandler:^(NSError *error, OCSyncAnchor previousSyncAnchor, OCSyncAnchor newSyncAnchor) {
			if (error != nil)
			{
				OCLogError(@"SE: error updating metaData database after sync engine result handler pass: %@", error);
			}
		}];

		// Update queries
		[self beginActivity:@"handle sync event - update queries"];

		[self queueBlock:^{
			OCCoreItemList *addedItemList   = ((addedItems.count>0)   ? [OCCoreItemList itemListWithItems:addedItems]   : nil);
			OCCoreItemList *removedItemList = ((removedItems.count>0) ? [OCCoreItemList itemListWithItems:removedItems] : nil);
			OCCoreItemList *updatedItemList = ((updatedItems.count>0) ? [OCCoreItemList itemListWithItems:updatedItems] : nil);
			NSMutableArray <OCItem *> *addedUpdatedRemovedItemList = nil;

			for (OCQuery *query in self->_queries)
			{
				// Queries targeting directories
				if (query.queryPath != nil)
				{
					// Only update queries that have already gone through their complete, initial content update
					if (query.state == OCQueryStateIdle)
					{
						__block NSMutableArray <OCItem *> *updatedFullQueryResults = nil;
						__block OCCoreItemList *updatedFullQueryResultsItemList = nil;

						void (^GetUpdatedFullResultsReady)(void) = ^{
							if (updatedFullQueryResults == nil)
							{
								NSMutableArray <OCItem *> *fullQueryResults;

								if ((fullQueryResults = query.fullQueryResults) != nil)
								{
									updatedFullQueryResults = [fullQueryResults mutableCopy];
								}
								else
								{
									updatedFullQueryResults = [NSMutableArray new];
								}
							}

							if (updatedFullQueryResultsItemList == nil)
							{
								updatedFullQueryResultsItemList = [OCCoreItemList itemListWithItems:updatedFullQueryResults];
							}
						};

						if ((addedItemList != nil) && (addedItemList.itemsByParentPaths[query.queryPath].count > 0))
						{
							// Items were added in the target path of this query
							GetUpdatedFullResultsReady();

							for (OCItem *item in addedItemList.itemsByParentPaths[query.queryPath])
							{
								[updatedFullQueryResults addObject:item];
							}
						}

						if (removedItemList != nil)
						{
							if (removedItemList.itemsByParentPaths[query.queryPath].count > 0)
							{
								// Items were removed in the target path of this query
								GetUpdatedFullResultsReady();

								for (OCItem *item in removedItemList.itemsByParentPaths[query.queryPath])
								{
									if (item.path != nil)
									{
										OCItem *removeItem;

										if ((removeItem = updatedFullQueryResultsItemList.itemsByPath[item.path]) != nil)
										{
											[updatedFullQueryResults removeObject:removeItem];
										}
									}
								}
							}

							if (removedItemList.itemsByPath[query.queryPath] != nil)
							{
								// The target of this query was removed
								updatedFullQueryResults = [NSMutableArray new];
								query.state = OCQueryStateTargetRemoved;
							}
						}

						if ((updatedItemList != nil) && (query.state != OCQueryStateTargetRemoved))
						{
							OCItem *updatedRootItem = nil;

							if (updatedItemList.itemsByParentPaths[query.queryPath].count > 0)
							{
								// Items were updated
								GetUpdatedFullResultsReady();

								for (OCItem *item in updatedItemList.itemsByParentPaths[query.queryPath])
								{
									if (item.path != nil)
									{
										OCItem *removeItem;

										if ((removeItem = updatedFullQueryResultsItemList.itemsByPath[item.path]) != nil)
										{
											[updatedFullQueryResults removeObject:removeItem];
										}

										[updatedFullQueryResults addObject:item];
									}
								}
							}

							if ((updatedRootItem = updatedItemList.itemsByPath[query.queryPath]) != nil)
							{
								// Root item of query was updated
								query.rootItem = updatedRootItem;

								if (query.includeRootItem)
								{
									OCItem *removeItem;

									if ((removeItem = updatedFullQueryResultsItemList.itemsByPath[query.queryPath]) != nil)
									{
										[updatedFullQueryResults removeObject:removeItem];
									}

									[updatedFullQueryResults addObject:updatedRootItem];
								}
							}
						}

						if (updatedFullQueryResults != nil)
						{
							query.fullQueryResults = updatedFullQueryResults;
						}
					}
				}

				// Queries targeting items
				if (query.queryItem != nil)
				{
					// Only update queries that have already gone through their complete, initial content update
					if (query.state == OCQueryStateIdle)
					{
						OCPath queryItemPath = query.queryItem.path;
						OCItem *newQueryItem = nil;

						if (addedItemList!=nil)
						{
							if ((newQueryItem = addedItemList.itemsByPath[queryItemPath]) != nil)
							{
								query.fullQueryResults = [NSMutableArray arrayWithObject:newQueryItem];
							}
						}

						if (updatedItemList!=nil)
						{
							if ((newQueryItem = updatedItemList.itemsByPath[queryItemPath]) != nil)
							{
								query.fullQueryResults = [NSMutableArray arrayWithObject:newQueryItem];
							}
						}

						if (removedItemList!=nil)
						{
							if ((newQueryItem = updatedItemList.itemsByPath[queryItemPath]) != nil)
							{
								query.fullQueryResults = [NSMutableArray new];
								query.state = OCQueryStateTargetRemoved;
							}
						}
					}
				}

				// Queries targeting sync anchors
				if ((query.querySinceSyncAnchor != nil) && (syncAnchor!=nil))
				{
					if (addedUpdatedRemovedItemList==nil)
					{
						addedUpdatedRemovedItemList = [NSMutableArray arrayWithCapacity:(addedItemList.items.count + updatedItemList.items.count + removedItemList.items.count)];

						if (addedItemList!=nil)
						{
							[addedUpdatedRemovedItemList addObjectsFromArray:addedItemList.items];
						}

						if (updatedItemList!=nil)
						{
							[addedUpdatedRemovedItemList addObjectsFromArray:updatedItemList.items];
						}

						if (removedItemList!=nil)
						{
							[addedUpdatedRemovedItemList addObjectsFromArray:removedItemList.items];
						}
					}

					query.state = OCQueryStateWaitingForServerReply;

					[query mergeItemsToFullQueryResults:addedUpdatedRemovedItemList syncAnchor:syncAnchor];

					query.state = OCQueryStateIdle;

					[query setNeedsRecomputation];
				}
			}

			// Signal file provider
			if (self.postFileProviderNotifications)
			{
				NSMutableArray <OCItem *> *changedItems = [NSMutableArray new];

				if (addedItemList.items != nil)
				{
					[changedItems addObjectsFromArray:addedItemList.items];
				}

				if (updatedItemList.items != nil)
				{
					[changedItems addObjectsFromArray:updatedItemList.items];
				}

				if (removedItemList.items != nil)
				{
					[changedItems addObjectsFromArray:removedItemList.items];
				}

				[self signalChangesForItems:changedItems];
			}

			[self endActivity:@"handle sync event - update queries"];
		}];
	}

	// - Fetch updated directory contents as needed
	if (refreshPaths.count > 0)
	{
		for (OCPath path in refreshPaths)
		{
			OCPath refreshPath = path;

			if (![refreshPath hasSuffix:@"/"])
			{
				refreshPath = [refreshPath stringByAppendingString:@"/"];
			}

			[self startItemListTaskForPath:refreshPath];
		}
	}
}

#pragma mark - Sync issues utilities
- (OCConnectionIssue *)_addIssueForCancellationAndDeschedulingToContext:(OCSyncContext *)syncContext title:(NSString *)title description:(NSString *)description invokeResultHandler:(BOOL)invokeResultHandler resultHandlerError:(NSError *)resultHandlerError
{
	OCConnectionIssue *issue;
	OCSyncRecord *syncRecord = syncContext.syncRecord;

	issue = [self _issueForCancellationAndDeschedulingSyncRecord:syncRecord title:title description:description invokeResultHandler:invokeResultHandler resultHandlerError:resultHandlerError];

	[syncContext addIssue:issue];

	return (issue);
}

- (OCConnectionIssue *)_issueForCancellationAndDeschedulingSyncRecord:(OCSyncRecord *)syncRecord title:(NSString *)title description:(NSString *)description invokeResultHandler:(BOOL)invokeResultHandler resultHandlerError:(NSError *)resultHandlerError
{
	OCConnectionIssue *issue;

	issue =	[OCConnectionIssue issueForMultipleChoicesWithLocalizedTitle:title localizedDescription:description choices:@[

			[OCConnectionIssueChoice choiceWithType:OCConnectionIssueChoiceTypeCancel label:nil handler:^(OCConnectionIssue *issue, OCConnectionIssueChoice *choice) {
				// Drop sync record
				[self descheduleSyncRecord:syncRecord invokeResultHandler:invokeResultHandler resultHandlerError:(resultHandlerError != nil) ? resultHandlerError : (invokeResultHandler ? OCError(OCErrorCancelled) : nil)];
			}],

		] completionHandler:nil];

	return (issue);
}

- (NSError *)_handleIssues:(NSArray <OCConnectionIssue *> *)issues forSyncRecord:(OCSyncRecord *)syncRecord syncStep:(NSString *)syncStepName priorActionSuccess:(BOOL)actionSuccess error:(NSError *)startError
{
	__block NSError *error = startError;

	// Handle issues
	if (issues.count > 0)
	{
		OCLogDebug(@"SE: record %@, %@ reported issues: %@", OCLogPrivate(syncRecord), syncStepName, issues);

		if ([self.delegate respondsToSelector:@selector(core:handleError:issue:)])
		{
			// Mark the state as awaiting user interaction
			syncRecord.state = OCSyncRecordStateAwaitingUserInteraction;

			if (syncRecord.inProgressSince == nil)
			{
				// Mark sync record as in-progress (important when coming from scheduling and scheduling didn't succeed but created issues. Otherwise will loop forever.)
				syncRecord.inProgressSince = [NSDate new];
			}

			[self.vault.database updateSyncRecords:@[ syncRecord ] completionHandler:^(OCDatabase *db, NSError *updateError) {
				if (updateError != nil)
				{
					error = updateError;
				}
			}];

			if (actionSuccess)
			{
				OCLogWarning(@"SE: record %@, %@ reported the issues despite success: %@", OCLogPrivate(syncRecord), syncStepName, issues);
			}

			// Relay issues
			for (OCConnectionIssue *issue in issues)
			{
				[self.delegate core:self handleError:error issue:issue];
			}
		}
		else
		{
			if (!actionSuccess)
			{
				OCLogDebug(@"SE: record %@, %@ success=%d, allowsRescheduling=%d", OCLogPrivate(syncRecord), syncStepName, actionSuccess, syncRecord.allowsRescheduling);

				// Delegate can't handle it, so check if we can reschedule it right away
				if (syncRecord.allowsRescheduling)
				{
					// Reschedule
					NSError *rescheduleError;

					if ((rescheduleError = [self _rescheduleSyncRecord:syncRecord withUpdates:nil]) != nil)
					{
						error = rescheduleError;
					}
				}
				else
				{
					// Cancel operation
					for (OCConnectionIssue *issue in issues)
					{
						[issue cancel];
					}
				}
			}
		}
	}

	return (error);
}

- (BOOL)_isConnectivityError:(NSError *)error;
{
	if ([error.domain isEqualToString:NSURLErrorDomain])
	{
		switch (error.code)
		{
			case NSURLErrorNotConnectedToInternet:
			case NSURLErrorNetworkConnectionLost:
			case NSURLErrorCannotConnectToHost:
				return (YES);
			break;
		}
	}

	return (NO);
}

#pragma mark - Sync action utilities
- (OCEventTarget *)_eventTargetWithSyncRecord:(OCSyncRecord *)syncRecord userInfo:(NSDictionary *)userInfo ephermal:(NSDictionary *)ephermalUserInfo
{
	NSDictionary *syncRecordUserInfo = @{ @"syncRecordID" : syncRecord.recordID };

	if (userInfo != nil)
	{
		NSMutableDictionary *mergedDict = [[NSMutableDictionary alloc] initWithDictionary:syncRecordUserInfo];

		[mergedDict addEntriesFromDictionary:userInfo];

		syncRecordUserInfo = mergedDict;
	}

	return ([OCEventTarget eventTargetWithEventHandlerIdentifier:self.eventHandlerIdentifier userInfo:syncRecordUserInfo ephermalUserInfo:ephermalUserInfo]);
}

- (OCEventTarget *)_eventTargetWithSyncRecord:(OCSyncRecord *)syncRecord
{
	return ([self _eventTargetWithSyncRecord:syncRecord userInfo:nil ephermal:nil]);
}

#pragma mark - Sync debugging
- (void)dumpSyncJournal
{
	OCSyncExec(journalDump, {
		[self.database retrieveSyncRecordsForPath:nil action:nil inProgressSince:nil completionHandler:^(OCDatabase *db, NSError *error, NSArray<OCSyncRecord *> *syncRecords) {
			NSLog(@"Sync Journal Dump:");
			NSLog(@"==================");

			for (OCSyncRecord *record in syncRecords)
			{
				NSLog(@"%@ | %@ | %@", 	[[record.recordID stringValue] rightPaddedMinLength:5],
							[record.actionIdentifier leftPaddedMinLength:20],
							[[record.inProgressSince description] leftPaddedMinLength:20]);
			}

			OCSyncExecDone(journalDump);
		}];
	});
}

@end
