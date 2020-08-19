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
#import "NSString+OCPath.h"
#import "OCQuery+Internal.h"
#import "OCSyncContext.h"
#import "OCCore+FileProvider.h"
#import "OCCore+ItemList.h"
#import "NSString+OCFormatting.h"
#import "OCCore+ItemUpdates.h"
#import "OCIssue+SyncIssue.h"
#import "OCWaitCondition.h"
#import "OCProcessManager.h"
#import "OCSyncLane.h"
#import "OCSyncRecordActivity.h"
#import "OCEventRecord.h"
#import "OCEventQueue.h"
#import "OCSQLiteTransaction.h"
#import "OCBackgroundManager.h"

OCIPCNotificationName OCIPCNotificationNameProcessSyncRecordsBase = @"org.owncloud.process-sync-records";
OCIPCNotificationName OCIPCNotificationNameUpdateSyncRecordsBase = @"org.owncloud.update-sync-records";

OCKeyValueStoreKey OCKeyValueStoreKeyOCCoreSyncEventsQueue = @"syncEventsQueue";
static OCKeyValueStoreKey OCKeyValueStoreKeyActiveProcessCores = @"activeProcessCores";

@implementation OCCore (SyncEngine)

#pragma mark - Setup & shutdown
- (OCIPCNotificationName)notificationNameForProcessSyncRecordsTriggerForProcessSession:(OCProcessSession *)processSession
{
	return ([OCIPCNotificationNameProcessSyncRecordsBase stringByAppendingFormat:@":%@;%@", self.bookmark.uuid.UUIDString, processSession.bundleIdentifier]);
}

- (OCIPCNotificationName)notificationNameForProcessSyncRecordsTriggerAcknowledgementForProcessSession:(OCProcessSession *)processSession
{
	return ([OCIPCNotificationNameProcessSyncRecordsBase stringByAppendingFormat:@":%@;%@;ack", self.bookmark.uuid.UUIDString, processSession.bundleIdentifier]);
}

- (OCIPCNotificationName)notificationNameForSyncRecordsUpdate
{
	return ([OCIPCNotificationNameUpdateSyncRecordsBase stringByAppendingFormat:@":%@", self.bookmark.uuid.UUIDString]);
}

- (void)setupSyncEngine
{
	OCIPCNotificationName processRecordsNotificationName = [self notificationNameForProcessSyncRecordsTriggerForProcessSession:OCProcessManager.sharedProcessManager.processSession];
	OCIPCNotificationName updateRecordsNotificationName = [self notificationNameForSyncRecordsUpdate];

	_remoteSyncEngineTriggerAcknowledgements = [NSMutableDictionary new];
	_remoteSyncEngineTimedOutSyncRecordIDs = [NSMutableSet new];

	[self renewActiveProcessCoreRegistration];

	[OCIPNotificationCenter.sharedNotificationCenter addObserver:self forName:processRecordsNotificationName withHandler:^(OCIPNotificationCenter * _Nonnull notificationCenter, OCCore * _Nonnull core, OCIPCNotificationName  _Nonnull notificationName) {
		[notificationCenter postNotificationForName:[core notificationNameForProcessSyncRecordsTriggerAcknowledgementForProcessSession:OCProcessManager.sharedProcessManager.processSession] ignoreSelf:YES];
		[core setNeedsToProcessSyncRecords];
	}];

	[OCIPNotificationCenter.sharedNotificationCenter addObserver:self forName:updateRecordsNotificationName withHandler:^(OCIPNotificationCenter * _Nonnull notificationCenter, OCCore * _Nonnull core, OCIPCNotificationName  _Nonnull notificationName) {
		[core updatePublishedSyncRecordActivities];
	}];

	[self updatePublishedSyncRecordActivities];
}

- (void)shutdownSyncEngine
{
	OCIPCNotificationName processRecordsNotificationName = [self notificationNameForProcessSyncRecordsTriggerForProcessSession:OCProcessManager.sharedProcessManager.processSession];
	OCIPCNotificationName updateRecordsNotificationName = [self notificationNameForSyncRecordsUpdate];

	[OCIPNotificationCenter.sharedNotificationCenter removeObserver:self forName:processRecordsNotificationName];
	[OCIPNotificationCenter.sharedNotificationCenter removeObserver:self forName:updateRecordsNotificationName];

	[self.vault.keyValueStore updateObjectForKey:OCKeyValueStoreKeyActiveProcessCores usingModifier:^NSMutableSet<OCIPCNotificationName> * _Nullable(NSMutableSet<OCIPCNotificationName> *  _Nullable activeProcessCoreIDs, BOOL * _Nonnull outDidModify) {

		// Remove this bookmark/process combination as active core
		[activeProcessCoreIDs removeObject:[self notificationNameForProcessSyncRecordsTriggerForProcessSession:OCProcessManager.sharedProcessManager.processSession]];

		*outDidModify = YES;

		return (activeProcessCoreIDs);
	}];

	for (NSString *remoteSyncEngineTriggerAckNotificationName in _remoteSyncEngineTriggerAcknowledgements)
	{
		[OCIPNotificationCenter.sharedNotificationCenter removeObserver:self forName:remoteSyncEngineTriggerAckNotificationName];
	}

	[_remoteSyncEngineTriggerAcknowledgements removeAllObjects];
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

- (OCItem *)retrieveLatestVersionAtPathOfItem:(OCItem *)item withError:(NSError * __autoreleasing *)outError
{
	__block OCItem *latestItem = nil;

	OCSyncExec(databaseRetrieval, {
		[self beginActivity:@"Retrieve latest version of item"];

		[self.database retrieveCacheItemsAtPath:item.path itemOnly:YES completionHandler:^(OCDatabase *db, NSError *error, OCSyncAnchor syncAnchor, NSArray<OCItem *> *items) {
			if (outError != NULL)
			{
				*outError = error;
			}

			latestItem = items.firstObject;

			OCSyncExecDone(databaseRetrieval);

			[self endActivity:@"Retrieve latest version of item"];
		}];
	});

	return (latestItem);
}

- (OCItem *)retrieveLatestVersionForLocalIDOfItem:(OCItem *)item withError:(NSError * __autoreleasing *)outError
{
	__block OCItem *latestItem = nil;

	OCSyncExec(databaseRetrieval, {
		[self beginActivity:@"Retrieve latest version of item by localID"];

		[self.database retrieveCacheItemForLocalID:item.localID completionHandler:^(OCDatabase *db, NSError *error, OCSyncAnchor syncAnchor, OCItem *item) {
			if (outError != NULL)
			{
				*outError = error;
			}

			latestItem = item;

			OCSyncExecDone(databaseRetrieval);

			[self endActivity:@"Retrieve latest version of item by localID"];
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

#pragma mark - Sync Lanes
- (OCSyncLane *)laneForTags:(NSSet <OCSyncLaneTag> *)tags readOnly:(BOOL)readOnly
{
	BOOL updatedLanes = NO;
	OCSyncLane *lane;

	lane = [self.database laneForTags:tags updatedLanes:&updatedLanes readOnly:readOnly];

	if (updatedLanes)
	{
		[self setNeedsToProcessSyncRecords];
	}

	return (lane);
}

#pragma mark - Sync Record Scheduling
- (NSProgress *)_enqueueSyncRecordWithAction:(OCSyncAction *)action cancellable:(BOOL)cancellable resultHandler:(OCCoreActionResultHandler)resultHandler
{
	return ([self _enqueueSyncRecordWithAction:action cancellable:cancellable preflightResultHandler:nil resultHandler:resultHandler]);
}

- (NSProgress *)_enqueueSyncRecordWithAction:(OCSyncAction *)action cancellable:(BOOL)cancellable preflightResultHandler:(nullable OCCoreCompletionHandler)preflightResultHandler resultHandler:(OCCoreActionResultHandler)resultHandler
{
	NSProgress *progress = nil;
	OCSyncRecord *syncRecord;

	if (action != nil)
	{
		syncRecord = [[OCSyncRecord alloc] initWithAction:action resultHandler:resultHandler];

		if (syncRecord.progress == nil)
		{
			progress = [NSProgress indeterminateProgress];

			syncRecord.progress = [[OCProgress alloc] initWithPath:@[] progress:progress];
		}
		else
		{
			progress = syncRecord.progress.progress;
		}

		syncRecord.progress.cancellable = cancellable;
		progress.cancellable = cancellable;

		[self submitSyncRecord:syncRecord withPreflightResultHandler:preflightResultHandler];
	}

	return(progress);
}

- (void)submitSyncRecord:(OCSyncRecord *)record withPreflightResultHandler:(OCCoreCompletionHandler)preflightResultHandler
{
	OCLogDebug(@"record %@ submitted", record);

	[self performProtectedSyncBlock:^NSError *{
		__block NSError *blockError = nil;

		// Add sync record to database (=> ensures it is persisted and has a recordID)
		[self addSyncRecords:@[ record ] completionHandler:^(OCDatabase *db, NSError *error) {
			blockError = error;
		}];

		OCLogDebug(@"record %@ added to database with error %@", record, blockError);

		// Set sync record's progress path
		record.progress.path = @[OCCoreGlobalRootPath, self.bookmark.uuid.UUIDString, OCCoreSyncRecordPath, [record.recordID stringValue]];

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

		// Assign to lane
		if (blockError == nil)
		{
			OCSyncLane *lane;

			if ((lane = [self laneForTags:record.laneTags readOnly:NO]) != nil)
			{
				record.laneID = lane.identifier;

				[self updateSyncRecords:@[ record ] completionHandler:^(OCDatabase *db, NSError *error) {
					if (error != nil)
					{
						OCLogError(@"Error %@ updating sync record %@ after assigning lane", error, record);
						blockError = error;
					}
				}];
			}

			if (blockError == nil)
			{
				OCLogDebug(@"record %@ added to lane %@", record, lane);
			}
		}

		// Handle errors during pre-flight
		if (blockError != nil)
		{
			OCLogDebug(@"record %@ completed preflight with error=%@", record, blockError);

			if (record.recordID != nil)
			{
				// Record still has a recordID, so wasn't included in syncContext.removeRecords. Remove now.
				[self removeSyncRecords:@[ record ] completionHandler:nil];
			}
		}

		return (blockError);
	} completionHandler:^(NSError *error) {

		if (error != nil)
		{
			// Call result handler
			[record completeWithError:error core:self item:record.action.localItem parameter:record];
		}

		if (preflightResultHandler != nil)
		{
			// Call preflight handler on a different thread to avoid dead-locks
			dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
				preflightResultHandler(error);
			});
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

- (NSError *)_descheduleSyncRecord:(OCSyncRecord *)syncRecord completeWithError:(NSError *)completionError parameter:(nullable id)parameter
{
	__block NSError *error = nil;
	OCSyncAction *syncAction;

	if (syncRecord==nil) { return(OCError(OCErrorInsufficientParameters)); }

	OCLogDebug(@"descheduling record %@ (parameter=%@, error=%@)", syncRecord, parameter, completionError);

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

				// Sync record is about to be removed, so no need to try updating it
				syncContext.updateStoredSyncRecordAfterItemUpdates = NO;

				// Perform any descheduler-triggered updates
				[self performSyncContextActions:syncContext];

				error = syncContext.error;
			}
		}
	}

	[self removeSyncRecords:@[syncRecord] completionHandler:^(OCDatabase *db, NSError *removeError) {
		if (removeError != nil)
		{
			OCLogError(@"Error removing sync record %@ from database: %@", syncRecord, removeError);

			if (error == nil)
			{
				error = removeError;
			}
		}
	}];

	[syncRecord completeWithError:completionError core:self item:syncRecord.action.localItem parameter:parameter];

	[self setNeedsToProcessSyncRecords];

	return (error);
}

- (void)descheduleSyncRecord:(OCSyncRecord *)syncRecord completeWithError:(nullable NSError *)completionError parameter:(nullable id)parameter
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

//		if (OCBackgroundManager.sharedBackgroundManager.isBackgrounded && (OCBackgroundManager.sharedBackgroundManager.backgroundTimeRemaining < 3.0))
//		{
//			OCLogDebug(@"processSyncRecordsIfNeeded skipped because backgroundTimeRemaining=%f", OCBackgroundManager.sharedBackgroundManager.backgroundTimeRemaining);
//			__weak OCCore *weakSelf = self;
//
//			[OCBackgroundManager.sharedBackgroundManager scheduleBlock:^{
//				[weakSelf processSyncRecordsIfNeeded];
//			} inBackground:NO];
//		}
//		else
		{
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
				OCLogDebug(@"processSyncRecordsIfNeeded skipped because connectionStatus=%lu", self.connectionStatus);
			}
		}

		[self endActivity:@"process sync records if needed"];
	}];
}

#pragma mark - Sync Engine Processing
- (void)processSyncRecords
{
	[self beginActivity:@"process sync records"];

	// Renew active process core registration
	[self renewActiveProcessCoreRegistration];

	// Transfer incoming OCEvents from KVS to the OCCore database
	OCWaitInitAndStartTask(transferIncomingEvents);

	[self.database.sqlDB executeTransaction:[OCSQLiteTransaction transactionWithBlock:^NSError * _Nullable(OCSQLiteDB * _Nonnull db, OCSQLiteTransaction * _Nonnull transaction) {
		// Read incoming OCEvents from KVS and add them to the database if they don't already exist there
		// Note how we do just read the value here instead of entering a full lock of the KVS. Since the removal of events also
		// occurs only inside Sync Engine global lock protection, we're not in danger of re-adding an event that's just been removed.
		// On the other end, even if an event is added right after reading it, the addition of the event will trigger a new run of
		// processSyncRecords, at which time the event will be transfered over to the database
		OCEventQueue *eventQueue = [self.vault.keyValueStore readObjectForKey:OCKeyValueStoreKeyOCCoreSyncEventsQueue];

		for (OCEventRecord *eventRecord in eventQueue.records)
		{
			// Avoid double-transfer
			if (![self.database queueContainsEvent:eventRecord.event])
			{
				// Add to database
				OCTLogDebug(@[@"EventRecord"], @"Queuing in the database: %@", eventRecord.event);

				[self.database queueEvent:eventRecord.event
					  forSyncRecordID:eventRecord.syncRecordID
					   processSession:eventRecord.processSession
					completionHandler:^(OCDatabase *db, NSError *error) {
					if (error != nil)
					{
						OCTLogError(@[@"EventRecord"], @"Error queuing event %@: %@", eventRecord.event, error);
					}
				}];
			}
			else
			{
				OCTLogWarning(@[@"EventRecord"], @"Skipping duplicate event - not inserting into the database: %@", eventRecord.event);
			}
		}

		return (nil);
	} type:OCSQLiteTransactionTypeExclusive completionHandler:^(OCSQLiteDB * _Nonnull db, OCSQLiteTransaction * _Nonnull transaction, NSError * _Nullable error) {
		OCWaitDidFinishTask(transferIncomingEvents);
	}]];

	OCWaitForCompletion(transferIncomingEvents);

	// Process sync records
	OCWaitInitAndStartTask(processSyncRecords);

	[self dumpSyncJournalWithTags:@[@"BeforeProc"]];

	[self performProtectedSyncBlock:^NSError *{
		__block NSArray <OCSyncLane *> *lanes = nil;
		NSMutableSet<OCSyncLaneID> *activeLaneIDs = [NSMutableSet new];
		NSUInteger activeLanes = 0;
		NSDictionary<OCSyncActionCategory, NSNumber *> *actionBudgetsByCategory = [self classSettingForOCClassSettingsKey:OCCoreActionConcurrencyBudgets];
		NSMutableDictionary<OCSyncActionCategory, NSNumber *> *runningActionsByCategory = [NSMutableDictionary new];
		void (^UpdateRunningActionCategories)(NSArray <OCSyncActionCategory> *categories, NSInteger change) = ^(NSArray <OCSyncActionCategory> *categories, NSInteger change) {
			for (OCSyncActionCategory category in categories)
			{
				runningActionsByCategory[category] = @(runningActionsByCategory[category].integerValue + change);
			}
		};
		BOOL (^ShouldRunInActionCategories)(NSArray <OCSyncActionCategory> *categories) = ^(NSArray <OCSyncActionCategory> *categories){
			for (OCSyncActionCategory category in categories)
			{
				NSUInteger totalBudget = actionBudgetsByCategory[category].integerValue;

				if ((totalBudget > 0) && (runningActionsByCategory[category].integerValue >= totalBudget))
				{
					OCLogDebug(@"Budget limit of %lu reached for action category: %@", totalBudget, category);
					return (NO);
				}
			}

			return (YES);
		};

		[self.database retrieveSyncLanesWithCompletionHandler:^(OCDatabase *db, NSError *error, NSArray<OCSyncLane *> *syncLanes) {
			if (error != nil)
			{
				OCLogError(@"Error retrieving sync lanes: %@", error);
			}
			else
			{
				lanes = syncLanes;
			}
		}];

		for (OCSyncLane *lane in lanes)
		{
			[activeLaneIDs addObject:lane.identifier];
		}

		for (OCSyncLane *lane in lanes)
		{
			__block BOOL stopProcessing = NO;
			__block OCSyncRecordID lastSyncRecordID = nil;
			__block NSUInteger recordsOnLane = 0;
			__block NSError *error = nil;

			OCLogDebug(@"processing sync records on lane %@", lane);

			if (lane.afterLanes.count > 0)
			{
				// Check if all preceding lanes this lane depends on have finished
				if ([activeLaneIDs intersectsSet:lane.afterLanes])
				{
					// Preceding lanes still active => skip
					if ([OCLogger logsForLevel:OCLogLevelDebug])
					{
						NSMutableSet *blockingLaneIDs = [NSMutableSet setWithSet:activeLaneIDs];
						[blockingLaneIDs intersectSet:lane.afterLanes];

						OCLogDebug(@"skipping lane %@ because lanes it is waiting for are still active: %@", lane, blockingLaneIDs);
					}

					continue;
				}
			}

			while (!stopProcessing)
			{
				// Fetch next sync record
				[self.database retrieveSyncRecordAfterID:lastSyncRecordID onLaneID:lane.identifier completionHandler:^(OCDatabase *db, NSError *dbError, OCSyncRecord *syncRecord) {
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

					recordsOnLane++;

					// Check available action category budget
					NSArray <OCSyncActionCategory> *actionCategories = syncRecord.action.categories;

					if (syncRecord.state == OCSyncRecordStateReady)
					{
						if (!ShouldRunInActionCategories(actionCategories))
						{
							OCLogDebug(@"Skipping processing sync record %@ due to lack of available budget in %@", syncRecord.recordID, actionCategories);
							stopProcessing = YES;
							return;
						}
					}

					// Update budget usage
					UpdateRunningActionCategories(actionCategories, 1);

					// Process sync record
					nextInstruction = [self processSyncRecord:syncRecord error:&error];

					OCLogDebug(@"Processing of sync record finished with nextInstruction=%lu", nextInstruction);

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

						case OCCoreSyncInstructionStopAndSideline:
							// Stop processing
							stopProcessing = YES;

							// Update budget usage to allow execution of actions on other lanes in the meantime
							UpdateRunningActionCategories(actionCategories, -1);

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

							if (error == nil)
							{
								recordsOnLane--;
							}

							// Update budget usage
							UpdateRunningActionCategories(actionCategories, -1);

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

			OCLogDebug(@"done processing sync records on lane %@", lane);

			if ((recordsOnLane > 0) || (error != nil))
			{
				activeLanes++;

				if ((activeLanes > self.maximumSyncLanes) && (self.maximumSyncLanes != 0))
				{
					// Enforce active lane limit
					break;
				}
			}

			if (error != nil)
			{
				// Make sure not to proceed to removing seemingly empty lane on errors
				continue;
			}

			if (recordsOnLane == 0)
			{
				__block BOOL laneIsEmpty = NO;

				// Double-verify there are no records left on lane
				[self.database numberOfSyncRecordsOnSyncLaneID:lane.identifier completionHandler:^(OCDatabase *db, NSError *error, NSNumber *count) {
					laneIsEmpty = ((count.integerValue == 0) && (error == nil));
				}];

				// Remove lane if empty
				if (laneIsEmpty)
				{
					OCLogDebug(@"Removing empty lane %@", lane);

					[activeLaneIDs removeObject:lane.identifier];

					[self.database removeSyncLane:lane completionHandler:^(OCDatabase *db, NSError *error) {
						if (error != nil)
						{
							OCLogError(@"Error removing lane %@: %@", lane, error);
						}
					}];
				}
			}
		}

		return (nil);
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

- (BOOL)processWaitConditionsOfSyncRecord:(OCSyncRecord *)syncRecord error:(NSError **)outError
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
							updateSyncRecordInDB = YES;
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

					OCLogDebug(@"evaluated wait condition %@ with state=%lu, error=%@, canContinue=%d", OCLogPrivate(waitCondition), waitConditionState, waitConditionError, canContinue);
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
	// (ensures that completionHandlers and progress objects provided in/by that process can be called - and that sync issues are delivered first on the originating process)
	if (syncRecord.originProcessSession != nil)
	{
		// Check that the record has not been exempt from origin process session checks
	 	if ((syncRecord.recordID != nil) && ![_remoteSyncEngineTimedOutSyncRecordIDs containsObject:syncRecord.recordID])
	 	{
			OCProcessSession *processSession = syncRecord.originProcessSession;
			BOOL doProcess = YES;

			// Only perform processSession validity check if bundleIDs differ
			if (![OCProcessManager.sharedProcessManager isSessionWithCurrentProcessBundleIdentifier:processSession])
			{
				// Don't process sync records originating from other processes that are running
				doProcess = ![OCProcessManager.sharedProcessManager isAnyInstanceOfSessionProcessRunning:processSession];
			}

			// Check that the other process also has an active core for this bookmark
			if (!doProcess)
			{
				NSMutableSet<OCIPCNotificationName> *activeProcessCores = [self.vault.keyValueStore readObjectForKey:OCKeyValueStoreKeyActiveProcessCores];
				OCIPCNotificationName triggerNotificationName = nil;

				if ((triggerNotificationName = [self notificationNameForProcessSyncRecordsTriggerForProcessSession:processSession]) != nil)
				{
					if (![activeProcessCores containsObject:triggerNotificationName])
					{
						// No matching bookmark/process core registered => remote process may run, but will likely not care about our notification
						// => process this record locally
						doProcess = YES;
					}
				}
			}

			if (!doProcess)
			{
				// Stop processing and notify other process to start processing the sync record queue
				OCLogDebug(@"skip processing sync record %@: originated in %@, for which a valid processSession exists: triggering remote sync engine", OCLogPrivate(syncRecord), syncRecord.originProcessSession.bundleIdentifier);

				[self triggerRemoteSyncEngineForSyncRecord:syncRecord processSession:processSession];

				return (OCCoreSyncInstructionStop);
			}
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
			// Remove from KVS (if exists), now that we can be sure the OCEvent is in the database
			[self.vault.keyValueStore updateObjectForKey:OCKeyValueStoreKeyOCCoreSyncEventsQueue usingModifier:^id _Nullable(OCEventQueue * _Nullable eventQueue, BOOL * _Nonnull outDidModify) {
 				BOOL didRemove;

 				didRemove = [eventQueue removeEventRecordForEventUUID:event.uuid];

				OCTLogDebug(@[@"EventRecord"], @"Removing from KVS (didRemove=%d): %@", didRemove, event);

				*outDidModify = didRemove;

				return (eventQueue);
			}];

			// Process event
			OCSyncContext *syncContext;

			OCTLogDebug(@[@"EventRecord"], @"Handling event %@", event);

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
						OCLogDebug(@"event instruction %lu overwritten with %lu by later event=%@", eventInstruction, instruction, event);
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
		OCLogDebug(@"record %@ has been cancelled - notifying", OCLogPrivate(syncRecord));

		if (syncRecord.action != nil)
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
	if (![self processWaitConditionsOfSyncRecord:syncRecord error:outError])
	{
		OCLogDebug(@"record %@, waitConditions=%@ blocking further Sync Journal processing", OCLogPrivate(syncRecord), syncRecord.waitConditions);

		// Stop processing
		return (OCCoreSyncInstructionStopAndSideline);
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

				OCLogDebug(@"record %@ scheduled with scheduleInstruction=%lu, error=%@", OCLogPrivate(syncRecord), scheduleInstruction, OCLogPrivate(scheduleError));
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
			OCLogWarning(@"record %@ has completed and will be removed", syncRecord);

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

#pragma mark - Sync engine: remote status check
- (void)renewActiveProcessCoreRegistration
{
	[self.vault.keyValueStore updateObjectForKey:OCKeyValueStoreKeyActiveProcessCores usingModifier:^NSMutableSet<OCIPCNotificationName> * _Nullable(NSMutableSet<OCIPCNotificationName> *  _Nullable activeProcessCoreIDs, BOOL * _Nonnull outDidModify) {
		OCIPCNotificationName triggerNotificationName = [self notificationNameForProcessSyncRecordsTriggerForProcessSession:OCProcessManager.sharedProcessManager.processSession];

		if (activeProcessCoreIDs == nil)
		{
			activeProcessCoreIDs = [NSMutableSet new];
		}

		// Check in this bookmark/process combination as active core
		if (![activeProcessCoreIDs containsObject:triggerNotificationName])
		{
			[activeProcessCoreIDs addObject:triggerNotificationName];
			*outDidModify = YES;
		}

		return (activeProcessCoreIDs);
	}];
}

- (void)triggerRemoteSyncEngineForSyncRecord:(OCSyncRecord *)syncRecord processSession:(OCProcessSession *)processSession
{
	// Listen for acknowledgement response from remote sync engine
	OCIPCNotificationName ackNotificationName = nil;
	OCIPCNotificationName triggerNotificationName = [self notificationNameForProcessSyncRecordsTriggerForProcessSession:processSession];

	if ((ackNotificationName = [self notificationNameForProcessSyncRecordsTriggerAcknowledgementForProcessSession:processSession]) != nil)
	{
		__weak OCCore *weakSelf = self;

		// Install ack listener if needed
		if (_remoteSyncEngineTriggerAcknowledgements[ackNotificationName] == nil)
		{
			_remoteSyncEngineTriggerAcknowledgements[ackNotificationName] = NSNull.null;

			[OCIPNotificationCenter.sharedNotificationCenter addObserver:self forName:ackNotificationName withHandler:^(OCIPNotificationCenter * _Nonnull notificationCenter, OCCore *core, OCIPCNotificationName  _Nonnull notificationName) {
				OCWTLogDebug(nil, @"Received acknowledgement from remote sync engine: %@", notificationName);
				core->_remoteSyncEngineTriggerAcknowledgements[notificationName] = [NSDate new];
			}];
		}

		// Start timeout for acknowledgement
		NSDate *triggerDate = [NSDate new];

		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
			[weakSelf checkRemoteSyncEngineTriggerAckForSyncRecordID:syncRecord.recordID processSession:processSession triggerDate:triggerDate];
		});
	}

	// Trigger remote sync engine
	[OCIPNotificationCenter.sharedNotificationCenter postNotificationForName:triggerNotificationName ignoreSelf:YES];
}

- (void)checkRemoteSyncEngineTriggerAckForSyncRecordID:(OCSyncRecordID)syncRecordID processSession:(OCProcessSession *)processSession triggerDate:(NSDate *)triggerDate
{
	[self beginActivity:@"check remote sync engine acknowledgement"];

	[self queueBlock:^{
		OCIPCNotificationName ackNotificationName = nil;

		if ((ackNotificationName = [self notificationNameForProcessSyncRecordsTriggerAcknowledgementForProcessSession:processSession]) != nil)
		{
			NSDate *ackDate = nil;
			BOOL didTimeout = YES;

			// Check for acknowledgement newer than the triggerDate
			if ((ackDate = OCTypedCast(self->_remoteSyncEngineTriggerAcknowledgements[ackNotificationName], NSDate)) != nil)
			{
				didTimeout = ([ackDate timeIntervalSinceDate:triggerDate] <= 0);
			}

			if (didTimeout)
			{
				OCLogDebug(@"Timeout waiting for acknowledgement from remote sync engine: %@ - exempting sync record %@ and removing remote process from activeProcessCores", ackNotificationName, syncRecordID);

				// Add recordID to timed out set, so it becomes exempt from originProcessSession checks
				if (syncRecordID != nil)
				{
					[self->_remoteSyncEngineTimedOutSyncRecordIDs addObject:syncRecordID];
				}

				// Remove entry for bookmark/process combination from active process cores
				[self.vault.keyValueStore updateObjectForKey:OCKeyValueStoreKeyActiveProcessCores usingModifier:^NSMutableSet<OCIPCNotificationName> * _Nullable(NSMutableSet<OCIPCNotificationName> *  _Nullable activeProcessCoreIDs, BOOL * _Nonnull outDidModify) {

					[activeProcessCoreIDs removeObject:[self notificationNameForProcessSyncRecordsTriggerForProcessSession:processSession]];
					*outDidModify = YES;

					return (activeProcessCoreIDs);
				}];

				// Make sure sync engine will enter processing
				[self setNeedsToProcessSyncRecords];
			}
		}

		[self endActivity:@"check remote sync engine acknowledgement"];
	}];
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

#pragma mark - Sync event queueing
- (void)queueSyncEvent:(OCEvent *)event sender:(id)sender
{
	// Sync Events arriving here typically arrive through OCHTTPPipeline -> OCConnection -> OCCore.handleEvent() - and
	// OCHTTPPipeline drops the request after this method returns. Therefore it's essential to ensure the OCEvent can't
	// be lost and it is stored safely before this method returns.

	/*
		Methodology:
		1) HTTP Pipeline -> OCConnection -> OCCore Event Handling
		-> save event to KVS
			- makes sure the event is persisted on disk before returning
			- use request.identifier as event.uuid, so that, if the process is terminated after saving to KVS, but before removal from OCHTTP, it can be recognized as duplicate
			- simple, fast storage operation - decoupled from the load and tasks carried by OCDatabase' SQLite db (avoiding dead-locks)

		2) KVS -> OCCore Event Queue DB
		- needs to be stored in OCCore DB before processing to maintain a consistent view of the entire database (changes caused by a processed event could be dropped otherwise, f.ex. if a process termination occurs mid-transaction)
		- goal: avoid dropping events and processing events multiple time even when process is terminated mid-transaction
		- strategy:
			- each OCEvent has a unique UUID

			- transfer HTTP Pipeline -> KVS
				- re-use HTTP RequestID as event UUID
				- in KVS context
					- check that an event with the same UUID doesn't already exist in the queue and is not among the UUIDs of the last 100 events removed from the queue (so an event doesn't get added multiple times if the process was terminated after the event was added to KVS, but before removal from the HTTP Pipeline)
				- remove from HTTP Pipeline DB after KVS call returns

			- transfer KVS -> DB:
				- db transaction begin
					- KVS context
						- read events, check if event with same UUID already exists in db, add to db otherwise
						- leave events in KVS unchanged (so they aren't lost if the transaction is rolled back due to a process termination)
				- db transaction commits

			- removal from KVS:
				- in sync event processing
					- event is retrieved from database
						- we now have the certainty that the event arrived in the db
					- in KVS context: remove event from KVS
						- if the process is terminated here, the event will still be in the db, unprocessed
						- if KVS operation completes, the event is still in the database, but removed from KVS so there can't be a duplicate
					- process event
						- only reaches this point after event is guaranteed in database and guaranteed to no longer be in KVS
						- by existing in the DB up to this point, it ensured that no event could be transfered twice from KVS

		3) Integration into existing structures
			- OCCore receives event for queueing:
				- save to KVS
				- call setNeedsToProcessSyncRecords

			- in OCCore.processSyncRecords:
				- before entering db transaction protected context: transfer KVS -> DB
				- in db transaction protected context: iterate events, removal from KVS before processing event
	 */

	OCSyncRecordID recordID;

	if ((recordID = OCTypedCast(event.userInfo[OCEventUserInfoKeySyncRecordID], NSNumber)) != nil)
	{
		[self beginActivity:@"Queuing sync event"];

		// Store in KVS
		OCTLogDebug(@[@"EventRecord"], @"Queuing in KVS: %@", event);
		[self.vault.keyValueStore updateObjectForKey:OCKeyValueStoreKeyOCCoreSyncEventsQueue usingModifier:^id _Nullable(OCEventQueue * _Nullable eventQueue, BOOL * _Nonnull outDidModify) {
			OCEventRecord *eventRecord;

			if (eventQueue == nil) { eventQueue = [OCEventQueue new]; }

			if ((eventRecord = [[OCEventRecord alloc] initWithEvent:event syncRecordID:recordID]) != nil)
			{
				// Checks for duplicate entries (in case process was terminated after the OCEvent was saved in KVS, but before the HTTP request was removed from the pipeline db)
				if ([eventQueue addEventRecord:eventRecord])
				{
					*outDidModify = YES;
					OCTLogDebug(@[@"EventRecord"], @"Added to KVS: %@", event);
				}
				else
				{
					OCTLogDebug(@[@"EventRecord"], @"Not adding to KVS (duplicate event): %@", event);
				}
			}
			else
			{
				OCTLogError(@[@"EventRecord"], @"Allocation of OCEventRecord failed");
			}

			return (eventQueue);
		}];

		[self setNeedsToProcessSyncRecords];

		[self endActivity:@"Queuing sync event"];
	}
	else
	{
		OCTLogError(@[@"EventRecord"], @"Can't handle event %@ from sender %@ due to missing recordID", event, sender);
	}
}

#pragma mark - Sync issue handling
- (void)resolveSyncIssue:(OCSyncIssue *)issue withChoice:(OCSyncIssueChoice *)choice userInfo:(NSDictionary<OCEventUserInfoKey, id> *)userInfo completionHandler:(nullable OCCoreSyncIssueResolutionResultHandler)completionHandler
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

#pragma mark - Sync Record wakeup
- (void)wakeupSyncRecord:(OCSyncRecordID)syncRecordID waitCondition:(nullable OCWaitCondition *)waitCondition userInfo:(nullable NSDictionary<OCEventUserInfoKey, id> *)userInfo result:(nullable id)result
{
	if (userInfo == nil)
	{
		if (waitCondition.uuid != nil)
		{
			userInfo = @{
				OCEventUserInfoKeySyncRecordID      : syncRecordID,
				OCEventUserInfoKeyWaitConditionUUID : waitCondition.uuid
			};
		}
		else
		{
			userInfo = @{ OCEventUserInfoKeySyncRecordID : syncRecordID };
		}
	}
	else
	{
		userInfo = [[NSMutableDictionary alloc] initWithDictionary:userInfo];
		((NSMutableDictionary *)userInfo)[OCEventUserInfoKeySyncRecordID] = syncRecordID;

		if (waitCondition.uuid != nil)
		{
			((NSMutableDictionary *)userInfo)[OCEventUserInfoKeyWaitConditionUUID] = waitCondition.uuid;
		}
	}

	[self handleEvent:[OCEvent eventWithType:OCEventTypeWakeupSyncRecord userInfo:userInfo ephermalUserInfo:nil result:result] sender:self];
}

#pragma mark - Sync issues utilities
- (NSError *)handleSyncRecord:(OCSyncRecord *)syncRecord error:(NSError *)error
{
	if (error != nil)
	{
		[self sendError:error issue:nil];
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
- (OCEventTarget *)_eventTargetWithSyncRecord:(OCSyncRecord *)syncRecord userInfo:(nullable NSDictionary *)userInfo ephermal:(nullable NSDictionary *)ephermalUserInfo
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
- (void)addSyncRecords:(NSArray <OCSyncRecord *> *)syncRecords completionHandler:(nullable OCDatabaseCompletionHandler)completionHandler
{
	[self.database addSyncRecords:syncRecords completionHandler:completionHandler];

	for (OCSyncRecord *syncRecord in syncRecords)
	{
		[self.activityManager update:[OCActivityUpdate publishingActivityFor:syncRecord]];
	}

	[self setNeedsToBroadcastSyncRecordActivityUpdate];
}

- (void)updateSyncRecords:(NSArray <OCSyncRecord *> *)syncRecords completionHandler:(nullable OCDatabaseCompletionHandler)completionHandler;
{
	for (OCSyncRecord *syncRecord in syncRecords)
	{
		NSProgress *progress;

		if (((progress = syncRecord.progress.progress) != nil) || (syncRecord.waitConditions.count > 0))
		{
	 		[self.activityManager update:[[[OCActivityUpdate updatingActivityFor:syncRecord] withSyncRecord:syncRecord] withProgress:progress]];
		}
	}

	[self.database updateSyncRecords:syncRecords completionHandler:completionHandler];

	[self setNeedsToBroadcastSyncRecordActivityUpdate];
}

- (void)removeSyncRecords:(NSArray <OCSyncRecord *> *)syncRecords completionHandler:(nullable OCDatabaseCompletionHandler)completionHandler;
{
	for (OCSyncRecord *syncRecord in syncRecords)
	{
 		[self.activityManager update:[OCActivityUpdate unpublishActivityFor:syncRecord]];
	}

	[self.database removeSyncRecords:syncRecords completionHandler:completionHandler];

	[self setNeedsToBroadcastSyncRecordActivityUpdate];
}

- (void)updatePublishedSyncRecordActivities
{
	[self.database retrieveSyncRecordsForPath:nil action:nil inProgressSince:nil completionHandler:^(OCDatabase *db, NSError *error, NSArray<OCSyncRecord *> *syncRecords) {
		NSMutableSet <OCSyncRecordID> *removedSyncRecordIDs = [[NSMutableSet alloc] initWithSet:self->_publishedActivitySyncRecordIDs];

		for (OCSyncRecord *syncRecord in syncRecords)
		{
			OCSyncRecordID recordID = syncRecord.recordID;

			syncRecord.action.core = self;

			if (recordID != nil)
			{
				[removedSyncRecordIDs removeObject:recordID];

				if ([self->_publishedActivitySyncRecordIDs containsObject:syncRecord.recordID])
				{
					// Update published activities
					NSProgress *progress = [syncRecord.progress resolveWith:nil];

					if (progress == nil)
					{
						progress = [NSProgress indeterminateProgress];
						progress.cancellable = NO;
					}

			 		[self.activityManager update:[[[OCActivityUpdate updatingActivityFor:syncRecord] withSyncRecord:syncRecord] withProgress:progress]];
				}
				else
				{
					// Publish new activities
					[self.activityManager update:[OCActivityUpdate publishingActivityFor:syncRecord]];
					[self->_publishedActivitySyncRecordIDs addObject:recordID];

					syncRecord.action.core = self;
					[syncRecord.action restoreProgressRegistrationForSyncRecord:syncRecord];
				}
			}
		}

		// Unpublish ended activities
		for (OCSyncRecordID syncRecordID in removedSyncRecordIDs)
		{
			[self.activityManager update:[OCActivityUpdate unpublishActivityForIdentifier:[OCSyncRecord activityIdentifierForSyncRecordID:syncRecordID]]];
		}

		[self->_publishedActivitySyncRecordIDs minusSet:removedSyncRecordIDs];
	}];
}

- (void)setNeedsToBroadcastSyncRecordActivityUpdate
{
	BOOL scheduleBroadcast = NO;

	@synchronized(self)
	{
		if (!_needsToBroadcastSyncRecordActivityUpdates)
		{
			_needsToBroadcastSyncRecordActivityUpdates = YES;
			scheduleBroadcast = YES;
		}
	}

	if (scheduleBroadcast)
	{
		[self beginActivity:@"Broadcast activity updates"];

		// Throttle broadcasts to 10 per second
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), _queue, ^{
			BOOL performBroadcast = NO;

			@synchronized(self)
			{
				performBroadcast = self->_needsToBroadcastSyncRecordActivityUpdates;
				self->_needsToBroadcastSyncRecordActivityUpdates = NO;
			}

			if (performBroadcast)
			{
				[OCIPNotificationCenter.sharedNotificationCenter postNotificationForName:[self notificationNameForSyncRecordsUpdate] ignoreSelf:YES];
			}

			[self endActivity:@"Broadcast activity updates"];
		});
	}
}

#pragma mark - Sync debugging
- (void)dumpSyncJournalWithTags:(NSArray <OCLogTagName> *)tags
{
	if ([OCLogger logsForLevel:OCLogLevelDebug])
	{
		OCSyncExec(journalDump, {
			[self.database retrieveSyncRecordsForPath:nil action:nil inProgressSince:nil completionHandler:^(OCDatabase *db, NSError *error, NSArray<OCSyncRecord *> *syncRecords) {
				OCTLogDebug(tags, @"Sync Journal Dump:");
				OCTLogDebug(tags, @"==================");

				for (OCSyncRecord *record in syncRecords)
				{
					OCTLogDebug(tags, @"%@ | %@ | %@ | %@", [[record.recordID stringValue] rightPaddedMinLength:5],
										[[record.laneID stringValue] leftPaddedMinLength:5],
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

OCProgressPathElementIdentifier OCCoreGlobalRootPath = @"_core";
OCProgressPathElementIdentifier OCCoreSyncRecordPath = @"_syncRecord";
