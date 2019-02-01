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
#import "OCIssue+SyncIssue.h"
#import "OCWaitCondition.h"
#import "OCProcessManager.h"
#import "OCSyncRecordActivity.h"

OCIPCNotificationName OCIPCNotificationNameProcessSyncRecordsBase = @"org.owncloud.process-sync-records";

@implementation OCCore (SyncEngine)

#pragma mark - Setup & shutdown
- (OCIPCNotificationName)notificationNameForProcessSyncRecordsTriggerForProcessSession:(OCProcessSession *)processSession
{
	return ([OCIPCNotificationNameProcessSyncRecordsBase stringByAppendingFormat:@":%@;%@", self.bookmark.uuid.UUIDString, processSession.bundleIdentifier]);
}

- (void)setupSyncEngine
{
	OCIPCNotificationName notificationName = [self notificationNameForProcessSyncRecordsTriggerForProcessSession:OCProcessManager.sharedProcessManager.processSession];

	[OCIPNotificationCenter.sharedNotificationCenter addObserver:self forName:notificationName withHandler:^(OCIPNotificationCenter * _Nonnull notificationCenter, OCCore * _Nonnull core, OCIPCNotificationName  _Nonnull notificationName) {
		[core setNeedsToProcessSyncRecords];
	}];

	[self publishInitialSyncRecordActivities];
}

- (void)shutdownSyncEngine
{
	OCIPCNotificationName notificationName = [self notificationNameForProcessSyncRecordsTriggerForProcessSession:OCProcessManager.sharedProcessManager.processSession];

	[OCIPNotificationCenter.sharedNotificationCenter removeObserver:self forName:notificationName];
}

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
		[self beginActivity:@"Retrieve latest version of item"];

		[self.database retrieveCacheItemsAtPath:item.path itemOnly:YES completionHandler:^(OCDatabase *db, NSError *error, OCSyncAnchor syncAnchor, NSArray<OCItem *> *items) {
			if (outError != NULL)
			{
				*outError = error;
			}

			latestItem = items[0];

			OCSyncExecDone(databaseRetrieval);

			[self endActivity:@"Retrieve latest version of item"];
		}];
	});

	return (latestItem);
}

- (void)incrementSyncAnchorWithProtectedBlock:(NSError *(^)(OCSyncAnchor previousSyncAnchor, OCSyncAnchor newSyncAnchor))protectedBlock completionHandler:(void(^)(NSError *error, OCSyncAnchor previousSyncAnchor, OCSyncAnchor newSyncAnchor))completionHandler
{
//	OCLogDebug(@"-incrementSyncAnchorWithProtectedBlock callstack: %@", [NSThread callStackSymbols]);

	[self.vault.database increaseValueForCounter:OCCoreSyncAnchorCounter withProtectedBlock:^NSError *(NSNumber *previousCounterValue, NSNumber *newCounterValue) {
		// Check for expected latestSyncAnchor
		if (![previousCounterValue isEqual:self->_latestSyncAnchor])
		{
			// => changes have been happening outside this process => replay to update queries
			self->_latestSyncAnchor = previousCounterValue;
			[self _replayChangesSinceSyncAnchor:self->_latestSyncAnchor];
		}

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

		[self postIPCChangeNotification];
	}];
}

- (NSProgress *)synchronizeWithServer
{
	return(nil); // Stub implementation
}

#pragma mark - Sync Record Scheduling
- (NSProgress *)_enqueueSyncRecordWithAction:(OCSyncAction *)action resultHandler:(OCCoreActionResultHandler)resultHandler
{
	NSProgress *progress = nil;
	OCSyncRecord *syncRecord;

	if (action != nil)
	{
		progress = [NSProgress indeterminateProgress];
		progress.cancellable = NO;

		syncRecord = [[OCSyncRecord alloc] initWithAction:action resultHandler:resultHandler];

		syncRecord.progress = progress;

		[self submitSyncRecord:syncRecord];
	}

	return(progress);
}

- (void)submitSyncRecord:(OCSyncRecord *)record
{
	OCLogDebug(@"record %@ submitted", record);

	[self performProtectedSyncBlock:^NSError *{
		__block NSError *blockError = nil;

		// Add sync record to database (=> ensures it is persisted and has a recordID)
		[self addSyncRecords:@[ record ] completionHandler:^(OCDatabase *db, NSError *error) {
			blockError = error;
		}];

		OCLogDebug(@"record %@ added to database with error %@", record, blockError);

		// Pre-flight
		if (blockError == nil)
		{
			OCSyncAction *syncAction;

			if ((syncAction = record.action) != nil)
			{
				OCSyncContext *syncContext;

				OCLogDebug(@"record %@ enters preflight", record);

				if ((syncContext = [OCSyncContext preflightContextWithSyncRecord:record]) != nil)
				{
					// Run pre-flight
					blockError = [self processWithContext:syncContext block:^NSError *(OCSyncAction *action) {
						if ([syncAction implements:@selector(preflightWithContext:)])
						{
							[action preflightWithContext:syncContext];
						}

						if (syncContext.error == nil)
						{
							// Pre-flight successful, so this can progress to ready
							[syncContext transitionToState:OCSyncRecordStateReady withWaitConditions:nil];
						}

						return (syncContext.error);
					}];

					OCLogDebug(@"record %@ returns from preflight with addedItems=%@, removedItems=%@, updatedItems=%@, refreshPaths=%@, removeRecords=%@, updateStoredSyncRecordAfterItemUpdates=%d, error=%@", record, syncContext.addedItems, syncContext.removedItems, syncContext.updatedItems, syncContext.refreshPaths, syncContext.removeRecords, syncContext.updateStoredSyncRecordAfterItemUpdates, syncContext.error);
				}
			}
			else
			{
				// Records needs to contain an action
				blockError = OCError(OCErrorInsufficientParameters);
			}
		}

		return (blockError);
	} completionHandler:^(NSError *error) {
		OCLogDebug(@"record %@ completed preflight with error=%@", record, error);

		if (error != nil)
		{
			// Error during pre-flight
			if (record.recordID != nil)
			{
				// Record still has a recordID, so wasn't included in syncContext.removeRecords. Remove now.
				[self removeSyncRecords:@[ record ] completionHandler:nil];
			}

			// Call result handler
			[record completeWithError:error core:self item:record.action.localItem parameter:record];
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
		[syncRecord transitionToState:OCSyncRecordStateReady withWaitConditions:nil];

		[self updateSyncRecords:@[syncRecord] completionHandler:^(OCDatabase *db, NSError *updateError) {
			error = updateError;
		}];

		[self setNeedsToProcessSyncRecords];
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

- (NSError *)_descheduleSyncRecord:(OCSyncRecord *)syncRecord completeWithError:(NSError *)completionError parameter:(id)parameter
{
	__block NSError *error = nil;
	OCSyncAction *syncAction;

	if (syncRecord==nil) { return(OCError(OCErrorInsufficientParameters)); }

	OCLogDebug(@"descheduling record %@ (parameter=%@, error=%@)", syncRecord, parameter, completionError);

	[self removeSyncRecords:@[syncRecord] completionHandler:^(OCDatabase *db, NSError *removeError) {
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
				[self performSyncContextActions:syncContext];

				error = syncContext.error;
			}
		}
	}

	[syncRecord completeWithError:completionError core:self item:syncRecord.action.localItem parameter:parameter];

	[self setNeedsToProcessSyncRecords];

	return (error);
}

- (void)descheduleSyncRecord:(OCSyncRecord *)syncRecord completeWithError:(NSError *)completionError parameter:(id)parameter
{
	if (syncRecord==nil) { return; }

	[self performProtectedSyncBlock:^NSError *{
		return ([self _descheduleSyncRecord:syncRecord completeWithError:completionError parameter:parameter]);
	} completionHandler:^(NSError *error) {
		if (error != nil)
		{
			OCLogError(@"error %@ descheduling sync record %@", OCLogPrivate(error), OCLogPrivate(syncRecord));
		}
	}];
}

#pragma mark - Sync Engine Processing Optimization
- (void)setNeedsToProcessSyncRecords
{
	OCLogDebug(@"setNeedsToProcessSyncRecords");

	@synchronized(self)
	{
		_needsToProcessSyncRecords = YES;
	}

	[self processSyncRecordsIfNeeded];
}

- (void)processSyncRecordsIfNeeded
{
	[self beginActivity:@"process sync records if needed"];

	[self queueBlock:^{
		BOOL needsToProcessSyncRecords = NO;

		if (self.connectionStatus == OCCoreConnectionStatusOnline)
		{
			@synchronized(self)
			{
				needsToProcessSyncRecords = self->_needsToProcessSyncRecords;
				self->_needsToProcessSyncRecords = NO;
			}

			OCLogDebug(@"processSyncRecordsIfNeeded (needed=%d)", needsToProcessSyncRecords);

			if (needsToProcessSyncRecords)
			{
				[self processSyncRecords];
			}
		}
		else
		{
			OCLogDebug(@"processSyncRecordsIfNeeded skipped because connectionStatus=%d", self.connectionStatus);
		}

		[self endActivity:@"process sync records if needed"];
	}];
}

#pragma mark - Sync Engine Processing
- (void)processSyncRecords
{
	[self beginActivity:@"process sync records"];

	OCWaitInitAndStartTask(processSyncRecords);

	[self dumpSyncJournalWithTags:@[@"BeforeProc"]];

	[self performProtectedSyncBlock:^NSError *{
		__block NSError *error = nil;
		__block BOOL stopProcessing = NO;
		__block OCSyncRecordID lastSyncRecordID = nil;

		OCLogDebug(@"processing sync records");

		while (!stopProcessing)
		{
			// Fetch next sync record
			[self.database retrieveSyncRecordAfterID:lastSyncRecordID completionHandler:^(OCDatabase *db, NSError *dbError, OCSyncRecord *syncRecord) {
				OCCoreSyncInstruction nextInstruction;

				if (syncRecord == nil)
				{
					// There's no next sync record => we're done
					stopProcessing = YES;
					return;
				}

				if (dbError != nil)
				{
					error = dbError;
					stopProcessing = YES;
					return;
				}

				// Process sync record
				nextInstruction = [self processSyncRecord:syncRecord error:&error];

				OCLogDebug(@"Processing of sync record finished with nextInstruction=%d", nextInstruction);

				[self dumpSyncJournalWithTags:@[@"PostProc"]];

				// Perform sync record result instruction
				switch (nextInstruction)
				{
					case OCCoreSyncInstructionNone:
						// Invalid instruction here
						OCLogError(@"Invalid instruction \"none\" after processing syncRecord=%@", syncRecord);

						stopProcessing = YES;

						return;
					break;

					case OCCoreSyncInstructionStop:
						// Stop processing
						stopProcessing = YES;
						return;
					break;

					case OCCoreSyncInstructionRepeatLast:
						// Repeat processing of record
						return;
					break;

					case OCCoreSyncInstructionDeleteLast:
						// Delete record
						[self removeSyncRecords:@[ syncRecord ] completionHandler:^(OCDatabase *db, NSError *dbError) {
							if (dbError != nil)
							{
								error = dbError;
								stopProcessing = YES;
							}
						}];

						// Process next
						lastSyncRecordID = syncRecord.recordID;
					break;

					case OCCoreSyncInstructionProcessNext:
						// Process next
						lastSyncRecordID = syncRecord.recordID;
					break;
				}

				// Log error
				if (error != nil)
				{
					OCLogError(@"Error processing sync records: %@", error);
				}
			}];
		};

		return (error);
	} completionHandler:^(NSError *error) {
//		// Ensure outstanding events are delivered
//		if ((self->_eventsBySyncRecordID.count > 0) && !self->_needsToProcessSyncRecords)
//		{
//			OCLogWarning(@"Outstanding events after completing sync record processing while sync records need to be processed");
//		}

		OCWaitDidFinishTask(processSyncRecords);

		[self endActivity:@"process sync records"];
	}];

	OCWaitForCompletion(processSyncRecords);

	[self dumpSyncJournalWithTags:@[@"AfterProc"]];
}

- (BOOL)processWaitRecordsOfSyncRecord:(OCSyncRecord *)syncRecord error:(NSError **)outError
{
	__block BOOL canContinue = YES;
	__block NSError *error = nil;

	if (syncRecord.waitConditions.count > 0)
	{
		NSArray <OCWaitCondition *> *waitConditions;

		if (((waitConditions = syncRecord.waitConditions) != nil) && (waitConditions.count > 0))
		{
			// Evaluate waiting conditions
			__block BOOL repeatEvaluation = NO;
			__block BOOL updateSyncRecordInDB = NO;

			do
			{
				canContinue = YES;

				if (repeatEvaluation)
				{
					waitConditions = syncRecord.waitConditions;
					repeatEvaluation = NO;
				}

				[waitConditions enumerateObjectsUsingBlock:^(OCWaitCondition * _Nonnull waitCondition, NSUInteger idx, BOOL * _Nonnull stop) {
					OCWaitConditionOptions options;
					__block OCWaitConditionState waitConditionState = OCWaitConditionStateWait;
					__block NSError *waitConditionError = nil;

					options = @{
						OCWaitConditionOptionCore 				: self,
						OCWaitConditionOptionSyncRecord 			: syncRecord
					};

					OCSyncExec(waitResolution, {
						[waitCondition evaluateWithOptions:options completionHandler:^(OCWaitConditionState state, BOOL conditionUpdated, NSError * _Nullable error) {
							waitConditionState = state;
							waitConditionError = error;

							OCSyncExecDone(waitResolution);
						}];
					});

					switch (waitConditionState)
					{
						case OCWaitConditionStateWait:
							// Continue to wait
							// + continue evaluating the wait conditions (because any may have failed)

							canContinue = NO;
						break;

						case OCWaitConditionStateProceed:
							// The wait condition no longer blocks and can be removed
							[syncRecord removeWaitCondition:waitCondition];
							updateSyncRecordInDB = YES;
						break;

						case OCWaitConditionStateFail:
							// Ask action to recover from wait condition failure
							{
								OCSyncContext *syncContext;
								__block BOOL couldRecover = NO;

								if ((syncContext = [OCSyncContext waitConditionRecoveryContextWith:syncRecord]) != nil)
								{
									error = [self processWithContext:syncContext block:^NSError *(OCSyncAction *action) {
										if ((couldRecover = [action recoverFromWaitCondition:waitCondition failedWithError:waitConditionError context:syncContext]) == NO)
										{
											OCLogError(@"Recovery from waitCondition=%@ failed for syncRecord=%@", waitCondition, syncRecord);
										}

										return (waitConditionError);
									}];
								}
								else
								{
									canContinue = NO;
								}

								// Wait condition failure => stop evaluation of the remaining ones
								*stop = YES;
								canContinue = NO;

								// Wait condition failure => repeat evaluation if the sync action could recover from it
								repeatEvaluation = couldRecover;

								updateSyncRecordInDB = YES;
							}
						break;
					}

					OCLogDebug(@"evaluated wait condition %@ with state=%d, error=%@, canContinue=%d", OCLogPrivate(waitCondition), waitConditionState, waitConditionError, canContinue);
				}];

				if (updateSyncRecordInDB)
				{
					[self updateSyncRecords:@[ syncRecord ] completionHandler:^(OCDatabase *db, NSError *dbError) {
						error = dbError;
					}];
				}
			} while (repeatEvaluation);
		}
	}

	return (canContinue);
}

- (OCCoreSyncInstruction)processSyncRecord:(OCSyncRecord *)syncRecord error:(NSError **)outError
{
	__block NSError *error = nil;
	__block OCCoreSyncInstruction doNext = OCCoreSyncInstructionProcessNext;

	OCLogDebug(@"processing sync record %@", OCLogPrivate(syncRecord));

	// Setup action
	syncRecord.action.core = self;

	// Check originating process session
	if (syncRecord.originProcessSession != nil)
	{
		OCProcessSession *processSession = syncRecord.originProcessSession;
		BOOL doProcess = YES;

		// Only perform processSession validity check if bundleIDs differ
		if (![OCProcessManager.sharedProcessManager isSessionWithCurrentProcessBundleIdentifier:processSession])
		{
			// Don't process sync records originating from other processes that are running
			doProcess = ![OCProcessManager.sharedProcessManager isAnyInstanceOfSessionProcessRunning:processSession];
		}

		if (!doProcess)
		{
			// Stop processing and notify other process to start processing the sync record queue
			[OCIPNotificationCenter.sharedNotificationCenter postNotificationForName:[self notificationNameForProcessSyncRecordsTriggerForProcessSession:processSession] ignoreSelf:YES];
			return (OCCoreSyncInstructionStop);
		}
	}

	// Skip sync records without an ID (should never happen, actually)
	if (syncRecord.recordID == nil)
	{
		OCLogWarning(@"skipping sync record without recordID: %@", OCLogPrivate(syncRecord));
		return (OCCoreSyncInstructionProcessNext);
	}

	// Deliver pending events
	{
		OCCoreSyncInstruction eventInstruction = OCCoreSyncInstructionNone;
		OCEvent *event = nil;
		OCSyncRecordID syncRecordID = syncRecord.recordID;

		while ((event = [self.database nextEventForSyncRecordID:syncRecordID afterEventID:nil]) != nil)
		{
			// Process event
			OCSyncContext *syncContext;

			if ((syncContext = [OCSyncContext eventHandlingContextWith:syncRecord event:event]) != nil)
			{
				__block OCCoreSyncInstruction instruction = OCCoreSyncInstructionNone;
				NSError *eventHandlingError = nil;

				OCLogDebug(@"record %@ handling event %@", syncRecord, event);

				eventHandlingError = [self processWithContext:syncContext block:^NSError *(OCSyncAction *action) {
					instruction = [action handleEventWithContext:syncContext];
					return (syncContext.error);
				}];

				OCLogDebug(@"record %@ finished handling event %@ with error=%@", syncRecord, event, eventHandlingError);

				if (instruction != OCCoreSyncInstructionNone)
				{
					if (eventInstruction != OCCoreSyncInstructionNone)
					{
						OCLogDebug(@"event instruction %d overwritten with %d by later event=%@", eventInstruction, instruction, event);
					}

					eventInstruction = instruction;
				}
			}

			[self.database removeEvent:event];
		}

		if (eventInstruction != OCCoreSyncInstructionNone)
		{
			// Return here
			return (eventInstruction);
		}
	}

	// Process sync record cancellation
	if (syncRecord.progress.cancelled)
	{
		OCSyncAction *syncAction;

		OCLogDebug(@"record %@ has been cancelled - notifying", OCLogPrivate(syncRecord));

		if ((syncAction = syncRecord.action) != nil)
		{
			OCSyncContext *syncContext = [OCSyncContext descheduleContextWithSyncRecord:syncRecord];

			OCLogDebug(@"record %@ will be cancelled", OCLogPrivate(syncRecord));

			syncContext.error = OCError(OCErrorCancelled); // consumed by -cancelWithContext:

			error = [self processWithContext:syncContext block:^NSError *(OCSyncAction *action) {
				doNext = [action cancelWithContext:syncContext];
				return(nil);
			}];

			OCLogDebug(@"record %@ cancelled with error %@", OCLogPrivate(syncRecord), OCLogPrivate(syncContext.error));
		}
		else
		{
			// Deschedule & call resultHandler
			[self _descheduleSyncRecord:syncRecord completeWithError:OCError(OCErrorCancelled) parameter:nil];
		}

		return (doNext);
	}

	// Process sync record's wait conditions
	if (![self processWaitRecordsOfSyncRecord:syncRecord error:outError])
	{
		OCLogDebug(@"record %@, waitConditions=%@ blocking further Sync Journal processing", OCLogPrivate(syncRecord), syncRecord.waitConditions);

		// Stop processing
		return (OCCoreSyncInstructionStop);
	}

	// Process sync record
	switch (syncRecord.state)
	{
		case OCSyncRecordStatePending:
			// Sync record has not yet passed preflight => continue with next syncRecord
			// (this, actually should never happen, as a sync record is either updated to OCSyncRecordStateReady if preflight succeeds -
			//  or removed completely in the same transaction that it was added in if preflight fails)
			OCLogWarning(@"Sync Engine encountered pending syncRecord=%@, which actually should never happen", syncRecord);

			return (OCCoreSyncInstructionProcessNext);
		break;

		case OCSyncRecordStateReady: {
			// Sync record is ready to be scheduled
			OCSyncAction *syncAction;
			__block OCCoreSyncInstruction scheduleInstruction = OCCoreSyncInstructionNone;
			NSError *scheduleError = nil;

			if ((syncAction = syncRecord.action) != nil)
			{
				// Schedule the record using the route for its sync action
				OCSyncContext *syncContext = [OCSyncContext schedulerContextWithSyncRecord:syncRecord];

				OCLogDebug(@"record %@ will be scheduled", OCLogPrivate(syncRecord));

				scheduleError = [self processWithContext:syncContext block:^NSError *(OCSyncAction *action) {
					scheduleInstruction = [syncAction scheduleWithContext:syncContext];

					return (syncContext.error);
				}];

				if (syncRecord.waitConditions.count > 0) // Sync Record contains wait conditions
				{
					// Make sure updates are saved and wait conditions are then processed at least once
					[self setNeedsToProcessSyncRecords];
				}

				OCLogDebug(@"record %@ scheduled with scheduleInstruction=%d, error=%@", OCLogPrivate(syncRecord), scheduleInstruction, OCLogPrivate(scheduleError));
			}
			else
			{
				// No action for this sync record
				scheduleError = OCError(OCErrorInsufficientParameters);
				scheduleInstruction = OCCoreSyncInstructionProcessNext;

				OCLogDebug(@"record %@ not scheduled due to error=%@", OCLogPrivate(syncRecord), OCLogPrivate(scheduleError));
			}

			if (scheduleError != nil)
			{
				OCLogError(@"error scheduling %@: %@", OCLogPrivate(syncRecord), scheduleError);
				error = scheduleError;
			}

			doNext = scheduleInstruction;
		}
		break;

		case OCSyncRecordStateProcessing:
			// Handle sync records that are already in processing

			// Wait until that sync record has finished processing
			OCLogDebug(@"record %@ in progress since %@: waiting for completion", OCLogPrivate(syncRecord), syncRecord.inProgressSince);

			// Stop processing
			doNext = OCCoreSyncInstructionStop;
		break;

		case OCSyncRecordStateCompleted:
			// Sync record has completed => continue with next syncRecord
			OCLogWarning(@"record %@ has completed and will be removed: %@", syncRecord);

			doNext = OCCoreSyncInstructionDeleteLast;
		break;

		case OCSyncRecordStateFailed:
			// Sync record has failed => continue with next syncRecord
			doNext = OCCoreSyncInstructionProcessNext;
		break;
	}

	// Return error
	if ((error != nil) && (outError != NULL))
	{
		*outError = error;
	}

	return (doNext);
}

- (NSError *)processWithContext:(OCSyncContext *)context block:(NSError *(^)(OCSyncAction *action))block
{
	// Sync record is ready to be scheduled
	OCSyncAction *syncAction;
	NSError *error = nil;

	if ((syncAction = context.syncRecord.action) != nil)
	{
		syncAction.core = self;

		error = block(syncAction);

		[self handleSyncRecord:context.syncRecord error:context.error];
		[self performSyncContextActions:context];
	}
	else
	{
		// No action for this sync record
		error = OCError(OCErrorInsufficientParameters);
	}

	return (error);
}

#pragma mark - Sync context handling
- (void)performSyncContextActions:(OCSyncContext *)syncContext
{
	OCCoreItemUpdateAction beforeQueryUpdateAction = nil;

	if ((syncContext.removeRecords != nil) || (syncContext.updateStoredSyncRecordAfterItemUpdates))
	{
		beforeQueryUpdateAction = ^(dispatch_block_t completionHandler){
			if (syncContext.removeRecords != nil)
			{
				[self removeSyncRecords:syncContext.removeRecords completionHandler:nil];
			}

			if (syncContext.updateStoredSyncRecordAfterItemUpdates)
			{
				[self updateSyncRecords:@[ syncContext.syncRecord ] completionHandler:nil];
			}

			completionHandler();
		};
	}

	[self performUpdatesForAddedItems:syncContext.addedItems removedItems:syncContext.removedItems updatedItems:syncContext.updatedItems refreshPaths:syncContext.refreshPaths newSyncAnchor:nil beforeQueryUpdates:beforeQueryUpdateAction afterQueryUpdates:nil queryPostProcessor:nil skipDatabase:NO];
}

#pragma mark - Sync event handling
- (void)_handleSyncEvent:(OCEvent *)event sender:(id)sender
{
	OCSyncRecordID recordID;

	if ((recordID = OCTypedCast(event.userInfo[OCEventUserInfoKeySyncRecordID], NSNumber)) != nil)
	{
		[self beginActivity:@"Queuing sync event"];

		[self.database queueEvent:event forSyncRecordID:recordID completionHandler:^(OCDatabase *db, NSError *error) {
			[self setNeedsToProcessSyncRecords];

			[self endActivity:@"Queuing sync event"];
		}];
	}
	else
	{
		OCLogError(@"Can't handle event %@ from sender %@ due to missing recordID", event, sender);
	}
}

#pragma mark - Sync issue handling
- (void)resolveSyncIssue:(OCSyncIssue *)issue withChoice:(OCSyncIssueChoice *)choice userInfo:(NSDictionary<OCEventUserInfoKey, id> *)userInfo completionHandler:(OCCoreSyncIssueResolutionResultHandler)completionHandler
{
	if (userInfo == nil)
	{
		userInfo = @{ OCEventUserInfoKeySyncIssue : issue };
	}
	else
	{
		userInfo = [[NSMutableDictionary alloc] initWithDictionary:userInfo];
		((NSMutableDictionary *)userInfo)[OCEventUserInfoKeySyncIssue] = issue;
	}

	[self handleEvent:[OCEvent eventWithType:OCEventTypeIssueResponse userInfo:userInfo ephermalUserInfo:nil result:choice] sender:self];
}

#pragma mark - Sync issues utilities
- (OCSyncIssue *)_addIssueForCancellationAndDeschedulingToContext:(OCSyncContext *)syncContext title:(NSString *)title description:(NSString *)description impact:(OCSyncIssueChoiceImpact)impact
{
	OCSyncIssue *issue;
	OCSyncRecord *syncRecord = syncContext.syncRecord;

	issue = [OCSyncIssue issueForSyncRecord:syncRecord level:OCIssueLevelError title:title description:description metaData:nil choices:@[
		[OCSyncIssueChoice cancelChoiceWithImpact:impact]
	]];

	[syncContext addSyncIssue:issue];

	return (issue);
}

- (NSError *)handleSyncRecord:(OCSyncRecord *)syncRecord error:(NSError *)error
{
	if (error != nil)
	{
		if ([self.delegate respondsToSelector:@selector(core:handleError:issue:)])
		{
			[self.delegate core:self handleError:error issue:nil];
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
	NSDictionary *syncRecordUserInfo = @{ OCEventUserInfoKeySyncRecordID : syncRecord.recordID };

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

#pragma mark - Sync record persistence
- (void)addSyncRecords:(NSArray <OCSyncRecord *> *)syncRecords completionHandler:(OCDatabaseCompletionHandler)completionHandler
{
	[self.database addSyncRecords:syncRecords completionHandler:completionHandler];

	for (OCSyncRecord *syncRecord in syncRecords)
	{
		[self.activityManager update:[OCActivityUpdate publishingActivityFor:syncRecord]];
	}
}

- (void)updateSyncRecords:(NSArray <OCSyncRecord *> *)syncRecords completionHandler:(OCDatabaseCompletionHandler)completionHandler;
{
	for (OCSyncRecord *syncRecord in syncRecords)
	{
 		[self.activityManager update:[[[OCActivityUpdate updatingActivityFor:syncRecord] withRecordState:syncRecord.state] withProgress:syncRecord.progress]];
	}

	[self.database updateSyncRecords:syncRecords completionHandler:completionHandler];
}

- (void)removeSyncRecords:(NSArray <OCSyncRecord *> *)syncRecords completionHandler:(OCDatabaseCompletionHandler)completionHandler;
{
	for (OCSyncRecord *syncRecord in syncRecords)
	{
 		[self.activityManager update:[OCActivityUpdate unpublishActivityFor:syncRecord]];
	}

	[self.database removeSyncRecords:syncRecords completionHandler:completionHandler];
}

- (void)publishInitialSyncRecordActivities
{
	[self.database retrieveSyncRecordsForPath:nil action:nil inProgressSince:nil completionHandler:^(OCDatabase *db, NSError *error, NSArray<OCSyncRecord *> *syncRecords) {
		for (OCSyncRecord *syncRecord in syncRecords)
		{
			syncRecord.action.core = self;
			[self.activityManager update:[OCActivityUpdate publishingActivityFor:syncRecord]];
		}
	}];
}

#pragma mark - Sync debugging
- (void)dumpSyncJournalWithTags:(NSArray <OCLogTagName> *)tags
{
	if (OCLogger.logLevel <= OCLogLevelDebug)
	{
		OCSyncExec(journalDump, {
			[self.database retrieveSyncRecordsForPath:nil action:nil inProgressSince:nil completionHandler:^(OCDatabase *db, NSError *error, NSArray<OCSyncRecord *> *syncRecords) {
				OCTLogDebug(tags, @"Sync Journal Dump:");
				OCTLogDebug(tags, @"==================");

				for (OCSyncRecord *record in syncRecords)
				{
					OCTLogDebug(tags, @"%@ | %@ | %@", 	[[record.recordID stringValue] rightPaddedMinLength:5],
										[record.actionIdentifier leftPaddedMinLength:20],
										[[record.inProgressSince description] leftPaddedMinLength:20]);
				}

				OCSyncExecDone(journalDump);
			}];
		});
	}
}

@end

OCEventUserInfoKey OCEventUserInfoKeySyncRecordID = @"syncRecordID";

