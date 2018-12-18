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
#import "OCCore+ItemUpdates.h"

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
//	OCLogDebug(@"-incrementSyncAnchorWithProtectedBlock callstack: %@", [NSThread callStackSymbols]);

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
	__weak OCCore *weakSelf = self;

	[self.vault.database increaseValueForCounter:OCCoreSyncJournalCounter withProtectedBlock:^NSError *(NSNumber *previousCounterValue, NSNumber *newCounterValue) {
		if (protectedBlock != nil)
		{
			return (protectedBlock());
		}

		return (nil);
	} completionHandler:^(NSError *error, NSNumber *previousCounterValue, NSNumber *newCounterValue) {
		OCCore *strongSelf = weakSelf;

		if (completionHandler != nil)
		{
			completionHandler(error);
		}

		[strongSelf postIPCChangeNotification];
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
	OCLogDebug(@"record %@ submitted", record);

	[self performProtectedSyncBlock:^NSError *{
		__block NSError *blockError = nil;

		[self.vault.database addSyncRecords:@[ record ] completionHandler:^(OCDatabase *db, NSError *error) {
			blockError = error;
		}];

		OCLogDebug(@"record %@ added to database with error %@", record, blockError);

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

					OCLogDebug(@"record %@ enters preflight", record);

					if ((syncContext = [OCSyncContext preflightContextWithSyncRecord:record]) != nil)
					{
						// Run pre-flight
						[syncAction preflightWithContext:syncContext];

						OCLogDebug(@"record %@ returns from preflight with addedItems=%@, removedItems=%@, updatedItems=%@, refreshPaths=%@, removeRecords=%@, updateStoredSyncRecordAfterItemUpdates=%d, error=%@", record, syncContext.addedItems, syncContext.removedItems, syncContext.updatedItems, syncContext.refreshPaths, syncContext.removeRecords, syncContext.updateStoredSyncRecordAfterItemUpdates, syncContext.error);

						// Perform any preflight-triggered updates
						[self performUpdatesForAddedItems:syncContext.addedItems removedItems:syncContext.removedItems updatedItems:syncContext.updatedItems refreshPaths:syncContext.refreshPaths newSyncAnchor:nil preflightAction:^(dispatch_block_t completionHandler){
							if (syncContext.removeRecords != nil)
							{
								[self.vault.database removeSyncRecords:syncContext.removeRecords completionHandler:nil];
							}

							if (syncContext.updateStoredSyncRecordAfterItemUpdates)
							{
								[self.vault.database updateSyncRecords:@[ syncContext.syncRecord ] completionHandler:nil];
							}

							completionHandler();
						} postflightAction:nil queryPostProcessor:nil];

						// Tunnel error outside
						blockError = syncContext.error;
					}
				}
			}
		}

		return (blockError);
	} completionHandler:^(NSError *error) {
		if (error != nil)
		{
			OCLogDebug(@"record %@ returned from preflight with error=%@ - removing record", record, error);

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

	OCLogDebug(@"rescheduling record %@ with updates (returning error=%@)", syncRecord, error);

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
			OCLogError(@"error %@ rescheduling sync record %@", OCLogPrivate(error), OCLogPrivate(syncRecord));
		}
	}];
}

- (NSError *)_descheduleSyncRecord:(OCSyncRecord *)syncRecord invokeResultHandler:(BOOL)invokeResultHandler withParameter:(id)parameter resultHandlerError:(NSError *)resultHandlerError
{
	__block NSError *error = nil;
	OCSyncAction *syncAction;

	if (syncRecord==nil) { return(OCError(OCErrorInsufficientParameters)); }

	OCLogDebug(@"descheduling record %@ (invokeResultHandler=%d, error=%@)", syncRecord, invokeResultHandler, resultHandlerError);

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
				OCLogDebug(@"record %@ enters post-deschedule", syncRecord);

				// Run descheduler
				[syncAction descheduleWithContext:syncContext];

				OCLogDebug(@"record %@ returns from post-deschedule with addedItems=%@, removedItems=%@, updatedItems=%@, refreshPaths=%@, removeRecords=%@, updateStoredSyncRecordAfterItemUpdates=%d, error=%@", syncRecord, syncContext.addedItems, syncContext.removedItems, syncContext.updatedItems, syncContext.refreshPaths, syncContext.removeRecords, syncContext.updateStoredSyncRecordAfterItemUpdates, syncContext.error);

				// Perform any descheduler-triggered updates
				[self performUpdatesForAddedItems:syncContext.addedItems removedItems:syncContext.removedItems updatedItems:syncContext.updatedItems refreshPaths:syncContext.refreshPaths newSyncAnchor:nil preflightAction:nil postflightAction:nil queryPostProcessor:nil];

				error = syncContext.error;
			}
		}
	}

	if (invokeResultHandler)
	{
		if (syncRecord.resultHandler != nil)
		{
			syncRecord.resultHandler(resultHandlerError, self, syncRecord.action.localItem, parameter);
		}
	}

	return (error);
}

- (void)descheduleSyncRecord:(OCSyncRecord *)syncRecord invokeResultHandler:(BOOL)invokeResultHandler withParameter:(id)parameter resultHandlerError:(NSError *)resultHandlerError
{
	if (syncRecord==nil) { return; }

	[self performProtectedSyncBlock:^NSError *{
		return ([self _descheduleSyncRecord:syncRecord invokeResultHandler:invokeResultHandler withParameter:parameter resultHandlerError:resultHandlerError]);
	} completionHandler:^(NSError *error) {
		if (error != nil)
		{
			OCLogError(@"error %@ descheduling sync record %@", OCLogPrivate(error), OCLogPrivate(syncRecord));
		}
	}];
}

#pragma mark - Sync Engine Processing
- (void)setNeedsToProcessSyncRecords
{
	OCLogDebug(@"setNeedsToProcessSyncRecords");

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

		OCLogDebug(@"_processSyncRecordsIfNeeded");

		if (self.connectionStatus == OCCoreConnectionStatusOnline)
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

		OCLogDebug(@"processing sync records");

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

				OCLogDebug(@"record %@ enters processing", syncRecord);

				// Remove cancelled sync records
				if (syncRecord.progress.cancelled)
				{
					OCLogDebug(@"record %@ has been cancelled - removing", syncRecord);

					// Deschedule & call resultHandler
					[self _descheduleSyncRecord:syncRecord invokeResultHandler:YES withParameter:nil resultHandlerError:OCError(OCErrorCancelled)];
					continue;
				}

				// Handle sync records that are already in processing
				if (syncRecord.inProgressSince != nil)
				{
					if (syncRecord.blockedByDifferentCopyOfThisProcess && syncRecord.allowsRescheduling)
					{
						OCLogDebug(@"record %@ in progress since %@ detected as hung - rescheduling", syncRecord, syncRecord.inProgressSince);

						// Unblock (and process hereafter) record hung in waiting for a user interaction in another copy of the same app (i.e. happens if this app crashed or was terminated)
						[self _rescheduleSyncRecord:syncRecord withUpdates:nil];
					}
					else
					{
						// Wait until that sync record has finished processing
						OCLogDebug(@"record %@ in progress since %@ - waiting for its completion", syncRecord, syncRecord.inProgressSince);
						break;
					}
				}

				// Skip sync records without an ID
				if (syncRecord.recordID == nil)
				{
					OCLogWarning(@"skipping sync record without recordID: %@", OCLogPrivate(syncRecord));
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

						OCLogDebug(@"record %@ will be scheduled", OCLogPrivate(syncRecord));

						couldSchedule = [syncAction scheduleWithContext:syncContext];

						if (syncContext.issues.count != 0)
						{
							[issues addObjectsFromArray:syncContext.issues];
						}

						scheduleError = syncContext.error;

						OCLogDebug(@"record %@ scheduled with error %@", OCLogPrivate(syncRecord), OCLogPrivate(scheduleError));
					}
					else
					{
						// No route for scheduling this sync record => sync action not implementd
						scheduleError = OCError(OCErrorFeatureNotImplemented);
					}
				}

				OCLogDebug(@"record %@ couldSchedule=%d with error %@", OCLogPrivate(syncRecord), couldSchedule, OCLogPrivate(scheduleError));

				// Update database if scheduling was successful
				if (couldSchedule)
				{
					syncRecord.inProgressSince = [NSDate date];
					syncRecord.state = OCSyncRecordStateScheduled;

					OCLogDebug(@"record %@ updated in database", OCLogPrivate(syncRecord));

					[db updateSyncRecords:@[ syncRecord ] completionHandler:^(OCDatabase *db, NSError *dbError) {
						error = dbError;
					}];
				}

				if (scheduleError != nil)
				{
					OCLogError(@"error scheduling %@: %@", OCLogPrivate(syncRecord), scheduleError);
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
			OCLogDebug(@"handling sync event %@", OCLogPrivate(event));

			[self.vault.database retrieveSyncRecordForID:syncRecordID completionHandler:^(OCDatabase *db, NSError *retrieveError, OCSyncRecord *retrievedSyncRecord) {
				syncRecord = retrievedSyncRecord;
				error = retrieveError;
			}];

			OCLogDebug(@"record %@ received an event %@", OCLogPrivate(syncRecord), OCLogPrivate(event));

			if (error != nil)
			{
				OCLogWarning(@"could not fetch sync record for ID %@ because of error %@. Dropping event %@ from %@ unhandled.", syncRecordID, error, event, sender);
				return(error);
			}

			if (syncRecord == nil)
			{
				OCLogWarning(@"could not fetch sync record for ID %@. Dropping event %@ from %@ unhandled.", syncRecordID, error, event, sender);
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

				OCLogDebug(@"record %@ enters event handling %@", OCLogPrivate(syncRecord), OCLogPrivate(event));

				syncRecordActionCompleted = [syncAction handleResultWithContext:syncContext];

				error = syncContext.error;
			}

			OCLogDebug(@"record %@ passed event handling: syncAction=%@, syncRecordActionCompleted=%d, error=%@", OCLogPrivate(syncRecord), syncAction, syncRecordActionCompleted, error);

			// Handle result handler return values
			if (syncRecordActionCompleted)
			{
				// Sync record action completed
				if (error != nil)
				{
					OCLogWarning(@"record %@ will be removed despite error: %@", syncRecord, error);
				}

				// - Indicate "done" to progress object
				syncRecord.progress.totalUnitCount = 1;
				syncRecord.progress.completedUnitCount = 1;

				// - Remove sync record from database
				[self.vault.database removeSyncRecords:@[ syncRecord ] completionHandler:^(OCDatabase *db, NSError *deleteError) {
					error = deleteError;
				}];

				// - Perform updates for added/changed/removed items and refresh paths
				[self performUpdatesForAddedItems:syncContext.addedItems removedItems:syncContext.removedItems updatedItems:syncContext.updatedItems refreshPaths:syncContext.refreshPaths newSyncAnchor:nil preflightAction:nil postflightAction:nil queryPostProcessor:nil];

				OCLogDebug(@"record %@ returned from event handling post-processing with addedItems=%@, removedItems=%@, updatedItems=%@, refreshPaths=%@, removeRecords=%@, error=%@", syncRecord, syncContext.addedItems, syncContext.removedItems, syncContext.updatedItems, syncContext.refreshPaths, syncContext.removeRecords, syncContext.error);
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
				[self descheduleSyncRecord:syncRecord invokeResultHandler:invokeResultHandler withParameter:nil resultHandlerError:(resultHandlerError != nil) ? resultHandlerError : (invokeResultHandler ? OCError(OCErrorCancelled) : nil)];
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
		OCLogDebug(@"record %@, %@ reported issues: %@", OCLogPrivate(syncRecord), syncStepName, issues);

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
				OCLogWarning(@"record %@, %@ reported the issues despite success: %@", OCLogPrivate(syncRecord), syncStepName, issues);
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
				OCLogDebug(@"record %@, %@ success=%d, allowsRescheduling=%d", OCLogPrivate(syncRecord), syncStepName, actionSuccess, syncRecord.allowsRescheduling);

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
			OCLogDebug(@"Sync Journal Dump:");
			OCLogDebug(@"==================");

			for (OCSyncRecord *record in syncRecords)
			{
				OCLogDebug(@"%@ | %@ | %@", 	[[record.recordID stringValue] rightPaddedMinLength:5],
								[record.actionIdentifier leftPaddedMinLength:20],
								[[record.inProgressSince description] leftPaddedMinLength:20]);
			}

			OCSyncExecDone(journalDump);
		}];
	});
}

@end
