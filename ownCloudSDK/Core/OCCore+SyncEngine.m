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
#import "OCCoreSyncRoute.h"
#import "OCMacros.h"
#import "NSProgress+OCExtensions.h"

@implementation OCCore (SyncEngine)

#pragma mark - Sync Anchor
- (void)retrieveLatestSyncAnchorWithCompletionHandler:(void(^)(NSError *error, OCSyncAnchor latestSyncAnchor))completionHandler
{
	[self.vault.database retrieveValueForCounter:OCCoreSyncAnchorCounter completionHandler:^(NSError *error, NSNumber *counterValue) {
		[self willChangeValueForKey:@"latestSyncAnchor"];
		_latestSyncAnchor = counterValue;
		[self didChangeValueForKey:@"latestSyncAnchor"];

		if (completionHandler != nil)
		{
			completionHandler(error, counterValue);
		}
	}];
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
		_latestSyncAnchor = newCounterValue;
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

#pragma mark - Sync Engine Routes
- (void)registerSyncRoutes
{
	NSArray<OCSyncAction> *syncActions = @[
		OCSyncActionDeleteLocal,
		OCSyncActionDeleteRemote,
		OCSyncActionMove,
		OCSyncActionCopy,
		OCSyncActionCreateFolder,
		OCSyncActionUpload,
		OCSyncActionDownload
	];

	for (OCSyncAction syncAction in syncActions)
	{
		NSString *registrationMethodName = [NSString stringWithFormat:@"register%@%@", [[syncAction substringToIndex:1] uppercaseString], [syncAction substringFromIndex:1]];
		SEL registrationMethodSelector = NSSelectorFromString(registrationMethodName);

		if ([self respondsToSelector:registrationMethodSelector])
		{
			// Below is identical to [self performSelector:registrationMethodSelector], but in an ARC-friendly manner.
			void (*impFunction)(id, SEL) = (void *)[self methodForSelector:registrationMethodSelector];

			if (impFunction != NULL)
			{
				impFunction(self, registrationMethodSelector);
			}
		}
	}
}

- (void)registerSyncRoute:(OCCoreSyncRoute *)syncRoute forAction:(OCSyncAction)syncAction
{
	_syncRoutesByAction[syncAction] = syncRoute;
}

#pragma mark - Sync Record Scheduling
- (NSProgress *)_enqueueSyncRecordWithAction:(OCSyncAction)action forItem:(OCItem *)item parameters:(NSDictionary <OCSyncActionParameter, id> *)parameters resultHandler:(OCCoreActionResultHandler)resultHandler
{
	NSProgress *progress = nil;

	if (item != nil)
	{
		OCSyncRecord *syncRecord;

		progress = [NSProgress indeterminateProgress];

		syncRecord = [[OCSyncRecord alloc] initWithAction:action archivedServerItem:((item.remoteItem != nil) ? item.remoteItem : item) parameters:parameters resultHandler:resultHandler];
		syncRecord.progress = progress;

		[self submitSyncRecord:syncRecord];
	}

	return(progress);
}

- (void)submitSyncRecord:(OCSyncRecord *)record
{
	[self performProtectedSyncBlock:^NSError *{
		__block NSError *blockError = nil;

		[self.vault.database addSyncRecords:@[ record ] completionHandler:^(OCDatabase *db, NSError *error) {
			blockError = error;
		}];

		return (blockError);
	} completionHandler:^(NSError *error) {
		[self setNeedsToProcessSyncRecords];
	}];
}

- (void)rescheduleSyncRecord:(OCSyncRecord *)syncRecord withUpdates:(NSError *(^)(OCSyncRecord *record))applyUpdates
{
	if (syncRecord==nil) { return; }

	[self performProtectedSyncBlock:^NSError *{
		__block NSError *error = nil;

		if (applyUpdates != nil)
		{
			error = applyUpdates(syncRecord);
		}

		if (error == nil)
		{
			syncRecord.inProgressSince = nil;

			[self.vault.database updateSyncRecords:@[syncRecord] completionHandler:^(OCDatabase *db, NSError *updateError) {
				error = updateError;
			}];
		}

		return (error);
	} completionHandler:^(NSError *error) {
		if (error != nil)
		{
			OCLogError(@"Error %@ rescheduling sync record %@", OCLogPrivate(error), OCLogPrivate(syncRecord));
		}
	}];
}

- (void)descheduleSyncRecord:(OCSyncRecord *)syncRecord
{
	if (syncRecord==nil) { return; }

	[self performProtectedSyncBlock:^NSError *{
		__block NSError *error = nil;

		[self.vault.database removeSyncRecords:@[syncRecord] completionHandler:^(OCDatabase *db, NSError *removeError) {
			error = removeError;
		}];

		return (error);
	} completionHandler:^(NSError *error) {
		if (error != nil)
		{
			OCLogError(@"Error %@ descheduling sync record %@", OCLogPrivate(error), OCLogPrivate(syncRecord));
		}
	}];
}

#pragma mark - Sync Engine Processing
- (void)setNeedsToProcessSyncRecords
{
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

		if (self.reachabilityMonitor.available)
		{
			@synchronized(self)
			{
				needsToProcessSyncRecords = _needsToProcessSyncRecords;
				_needsToProcessSyncRecords = NO;
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
	[self performProtectedSyncBlock:^NSError *{
		__block NSError *blockError = nil;

		[self.vault.database retrieveSyncRecordsForPath:nil action:nil inProgressSince:nil completionHandler:^(OCDatabase *db, NSError *error, NSArray<OCSyncRecord *> *syncRecords) {
			NSMutableSet <OCPath> *busyPaths = [NSMutableSet new];

			if (error != nil)
			{
				blockError = error;
				return;
			}

			for (OCSyncRecord *syncRecord in syncRecords)
			{
				BOOL couldSchedule = NO;
				NSError *scheduleError = nil;
				OCPath itemPath;

				// Remove cancelled sync records
				if (syncRecord.progress.cancelled)
				{
					[self.vault.database removeSyncRecords:@[ syncRecord ] completionHandler:^(OCDatabase *db, NSError *error) {
						if (syncRecord.resultHandler != nil)
						{
							syncRecord.resultHandler(OCError(OCErrorCancelled), self, syncRecord.item, syncRecord);
						}

						if (error != nil)
						{
							OCLogError(@"Error %@ removing cancelled sync record %@", OCLogPrivate(error), OCLogPrivate(syncRecord));
						}
					}];
					continue;
				}

				// Check for older sync records that haven't yet been processed
				if ((itemPath = syncRecord.itemPath) != nil)
				{
					OCPath parentPath = nil;

					if ([busyPaths containsObject:itemPath])
					{
						// A previous sync record for the same path exists, skip
						continue;
					}

					[busyPaths addObject:itemPath];

					parentPath = itemPath.stringByDeletingLastPathComponent;

					if ([busyPaths containsObject:parentPath])
					{
						// A previous sync record for the parent directory exists, skip
						continue;
					}

					[busyPaths addObject:parentPath];
				}

				// Skip sync records that are already in processing
				if (syncRecord.inProgressSince != nil)
				{
					continue;
				}

				// Skip sync records without an ID
				if (syncRecord.recordID == nil)
				{
					OCLogWarning(@"Skipping sync record without recordID: %@", OCLogPrivate(syncRecord));
					continue;
				}

				// Schedule actions
				if (syncRecord.action != nil)
				{
					OCCoreSyncRoute *syncRoute;

					if ((syncRoute = _syncRoutesByAction[syncRecord.action]) != nil)
					{
						// Schedule the record using the route for its sync action
						OCCoreSyncParameterSet *parameterSet = [OCCoreSyncParameterSet schedulerSetWithSyncRecord:syncRecord];

						couldSchedule = syncRoute.scheduler(self, parameterSet);

						scheduleError = parameterSet.error;
					}
					else
					{
						// No route for scheduling this sync record => sync action not implementd
						scheduleError = OCError(OCErrorFeatureNotImplemented);
					}
				}
				else
				{
					// Every sync record should have an action, so something went awfully wrong here
					scheduleError = OCError(OCErrorInternal);
				}

				// Update database if scheduling was successful
				if (couldSchedule)
				{
					syncRecord.inProgressSince = [NSDate date];

					[db updateSyncRecords:@[ syncRecord ] completionHandler:^(OCDatabase *db, NSError *error) {
						blockError = error;
					}];
				}

				if (scheduleError != nil)
				{
					OCLogError(@"Error scheduling %@: %@", OCLogPrivate(syncRecord), scheduleError);
				}
			}
		}];

		return (blockError);
	} completionHandler:nil];
}

#pragma mark - Sync event handling
- (void)_handleSyncEvent:(OCEvent *)event sender:(id)sender
{
	[self performProtectedSyncBlock:^NSError *{
		__block NSError *error = nil;
		__block OCSyncRecord *syncRecord = nil;
		OCSyncRecordID syncRecordID;
		BOOL syncRecordActionCompleted = NO;
		NSMutableArray <OCConnectionIssue *> *issues = [NSMutableArray new];

		// Fetch sync record
		if ((syncRecordID = event.userInfo[@"syncRecordID"]) != nil)
		{
			[self.vault.database retrieveSyncRecordForID:syncRecordID completionHandler:^(OCDatabase *db, NSError *retrieveError, OCSyncRecord *retrievedSyncRecord) {
				syncRecord = retrievedSyncRecord;
				error = retrieveError;
			}];

			if (error != nil)
			{
				OCLogWarning(@"Sync Engine: could not fetch sync record for ID %@ because of error %@. Dropping event %@ from %@ unhandled.", syncRecordID, error, event, sender);
				return(error);
			}

			if (syncRecord == nil)
			{
				OCLogWarning(@"Sync Engine: could not fetch sync record for ID %@. Dropping event %@ from %@ unhandled.", syncRecordID, error, event, sender);
				return (nil);
			}
		}

		// Dispatch to result handlers
		if ((syncRecord != nil) && (syncRecord.action != nil))
		{
			OCCoreSyncRoute *syncRoute;

			if ((syncRoute = _syncRoutesByAction[syncRecord.action]) != nil)
			{
				OCCoreSyncParameterSet *syncParameterSet = [OCCoreSyncParameterSet resultHandlerSetWith:syncRecord event:event issues:issues];

				syncRecordActionCompleted = syncRoute.resultHandler(self, syncParameterSet);

				if (syncParameterSet.issues != 0)
				{
					[issues addObjectsFromArray:syncParameterSet.issues];
				}

				error = syncParameterSet.error;
			}
		}
		else
		{
			OCLogWarning(@"Unhandled sync event %@ from %@", OCLogPrivate(event), sender);
		}

		// Remove completed sync records
		if (syncRecordActionCompleted && (error==nil))
		{
			syncRecord.progress.totalUnitCount = 1;
			syncRecord.progress.completedUnitCount = 1;

			[self.vault.database removeSyncRecords:@[ syncRecord ] completionHandler:^(OCDatabase *db, NSError *deleteError) {
				error = deleteError;
			}];

			// Fetch updated parent directory contents
			if (syncRecord.itemPath != nil)
			{
				OCPath parentDirectory = syncRecord.itemPath.stringByDeletingLastPathComponent;

				if (![parentDirectory hasSuffix:@"/"])
				{
					parentDirectory = [parentDirectory stringByAppendingString:@"/"];
				}

				[self startItemListTaskForPath:parentDirectory];
			}
		}

		// Relay issues
		for (OCConnectionIssue *issue in issues)
		{
			[self.delegate core:self handleError:error issue:issue];
		}

		// Trigger handling of any remaining sync events
		[self setNeedsToProcessSyncRecords];

		return (error);
	} completionHandler:^(NSError *error) {
		if (error != nil)
		{
			OCLogError(@"Sync Engine: error processing event %@ from %@: %@", OCLogPrivate(event), sender, error);
		}
	}];
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

@end
