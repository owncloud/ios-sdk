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
#import "NSString+OCParentPath.h"
#import "OCQuery+Internal.h"
#import "OCCoreSyncContext.h"

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
- (NSProgress *)_enqueueSyncRecordWithAction:(OCSyncAction)action forItem:(OCItem *)item allowNilItem:(BOOL)allowNilItem parameters:(NSDictionary <OCSyncActionParameter, id> *)parameters resultHandler:(OCCoreActionResultHandler)resultHandler
{
	NSProgress *progress = nil;
	OCSyncRecord *syncRecord;

	if (allowNilItem || (!allowNilItem && (item!=nil)))
	{
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

- (NSError *)_rescheduleSyncRecord:(OCSyncRecord *)syncRecord withUpdates:(NSError *(^)(OCSyncRecord *record))applyUpdates
{
	__block NSError *error = nil;

	if (applyUpdates != nil)
	{
		error = applyUpdates(syncRecord);
	}

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
	[self beginActivity:@"process sync records"];

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

					parentPath = [itemPath parentPath];

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
					if (syncRecord.blockedByDifferentCopyOfThisProcess && syncRecord.allowsRescheduling)
					{
						// Unblock (and process hereafter) record hung in waiting for a user interaction in another copy of the same app (i.e. happens if this app crashed or was terminated)
						[self _rescheduleSyncRecord:syncRecord withUpdates:nil];
					}
					else
					{
						// Skip
						continue;
					}
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
						OCCoreSyncContext *parameterSet = [OCCoreSyncContext schedulerSetWithSyncRecord:syncRecord];

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
					syncRecord.state = OCSyncRecordStateScheduled;

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

		// Handle sync record
		if ((syncRecord != nil) && (syncRecord.action != nil))
		{
			OCCoreSyncRoute *syncRoute = nil;
			OCCoreSyncContext *syncContext = nil;

			// Dispatch to result handlers
			if ((syncRoute = _syncRoutesByAction[syncRecord.action]) != nil)
			{
				syncContext = [OCCoreSyncContext resultHandlerSetWith:syncRecord event:event issues:issues];

				syncRecordActionCompleted = syncRoute.resultHandler(self, syncContext);

				if (syncContext.issues != 0)
				{
					[issues addObjectsFromArray:syncContext.issues];
				}

				error = syncContext.error;
			}

			// Handle result handler return values
			if (syncRecordActionCompleted && (error==nil))
			{
				// Sync record action completed

				// - Indicate "done" to progress object
				syncRecord.progress.totalUnitCount = 1;
				syncRecord.progress.completedUnitCount = 1;

				// - Remove sync record from database
				[self.vault.database removeSyncRecords:@[ syncRecord ] completionHandler:^(OCDatabase *db, NSError *deleteError) {
					error = deleteError;
				}];

				// - Update metaData table and queries
				if ((syncContext.addedItems.count > 0) || (syncContext.removedItems.count > 0) || (syncContext.updatedItems.count > 0))
				{
					__block OCSyncAnchor syncAnchor = nil;

					// Update metaData table with changes from the parameter set
					[self incrementSyncAnchorWithProtectedBlock:^NSError *(OCSyncAnchor previousSyncAnchor, OCSyncAnchor newSyncAnchor) {
						__block NSError *updateError = nil;

						if (syncContext.addedItems.count > 0)
						{
							[self.vault.database addCacheItems:syncContext.addedItems syncAnchor:newSyncAnchor completionHandler:^(OCDatabase *db, NSError *error) {
								if (error != nil) { updateError = error; }
							}];
						}

						if (syncContext.removedItems.count > 0)
						{
							[self.vault.database removeCacheItems:syncContext.removedItems syncAnchor:newSyncAnchor completionHandler:^(OCDatabase *db, NSError *error) {
								if (error != nil) { updateError = error; }
							}];
						}

						if (syncContext.updatedItems.count > 0)
						{
							[self.vault.database updateCacheItems:syncContext.updatedItems syncAnchor:newSyncAnchor completionHandler:^(OCDatabase *db, NSError *error) {
								if (error != nil) { updateError = error; }
							}];
						}

						syncAnchor = newSyncAnchor;

						return (updateError);
					} completionHandler:^(NSError *error, OCSyncAnchor previousSyncAnchor, OCSyncAnchor newSyncAnchor) {
						if (error != nil)
						{
							OCLogError(@"Error updating metaData database after sync engine result handler pass: %@", error);
						}
					}];

					// Update queries
					[self beginActivity:@"handle sync event - update queries"];

					[self queueBlock:^{
						OCCoreItemList *addedItemList   = ((syncContext.addedItems.count>0)   ? [OCCoreItemList itemListWithItems:syncContext.addedItems]   : nil);
						OCCoreItemList *removedItemList = ((syncContext.removedItems.count>0) ? [OCCoreItemList itemListWithItems:syncContext.removedItems] : nil);
						OCCoreItemList *updatedItemList = ((syncContext.updatedItems.count>0) ? [OCCoreItemList itemListWithItems:syncContext.updatedItems] : nil);

						for (OCQuery *query in _queries)
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
								NSMutableArray <OCItem *> *addedUpdatedRemovedItemList = [NSMutableArray arrayWithCapacity:(addedItemList.items.count + updatedItemList.items.count + removedItemList.items.count)];

								query.state = OCQueryStateWaitingForServerReply;

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

								[query mergeItemsToFullQueryResults:addedUpdatedRemovedItemList syncAnchor:syncAnchor];

								query.state = OCQueryStateIdle;

								[query setNeedsRecomputation];
							}
						}

						[self endActivity:@"handle sync event - update queries"];
					}];
				}

				// - Fetch updated directory contents as needed
				if (syncContext.refreshPaths.count > 0)
				{
					for (OCPath path in syncContext.refreshPaths)
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

			// In case of issues, mark the state as awaiting user interaction
			if ([self.delegate respondsToSelector:@selector(core:handleError:issue:)])
			{
				if (issues.count > 0)
				{
					syncRecord.state = OCSyncRecordStateAwaitingUserInteraction;

					[self.vault.database updateSyncRecords:@[ syncRecord ] completionHandler:^(OCDatabase *db, NSError *updateError) {
						error = updateError;
					}];

					// Relay issues
					for (OCConnectionIssue *issue in issues)
					{
						[self.delegate core:self handleError:error issue:issue];
					}
				}
			}
			else
			{
				if (!syncRecordActionCompleted)
				{
					// Delegate can't handle it, so check if we can reschedule it right away
					if (syncRecord.allowsRescheduling)
					{
						// Reschedule
						syncRecord.state = OCSyncRecordStatePending;
						syncRecord.inProgressSince = nil;

						[self.vault.database updateSyncRecords:@[ syncRecord ] completionHandler:^(OCDatabase *db, NSError *updateError) {
							error = updateError;
						}];
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
		else
		{
			OCLogWarning(@"Unhandled sync event %@ from %@", OCLogPrivate(event), sender);
		}

		// Trigger handling of any remaining sync events
		[self setNeedsToProcessSyncRecords];

		return (error);
	} completionHandler:^(NSError *error) {
		if (error != nil)
		{
			OCLogError(@"Sync Engine: error processing event %@ from %@: %@", OCLogPrivate(event), sender, error);
		}

		[self endActivity:@"handle sync event"];
	}];
}

#pragma mark - Sync issues utilities
- (OCConnectionIssue *)_addIssueForCancellationAndDeschedulingToContext:(OCCoreSyncContext *)syncContext title:(NSString *)title description:(NSString *)description
{
	OCConnectionIssue *issue;
	OCSyncRecord *syncRecord = syncContext.syncRecord;

	issue =	[OCConnectionIssue issueForMultipleChoicesWithLocalizedTitle:title localizedDescription:description choices:@[

			[OCConnectionIssueChoice choiceWithType:OCConnectionIssueChoiceTypeCancel label:nil handler:^(OCConnectionIssue *issue, OCConnectionIssueChoice *choice) {
				// Drop sync record
				[self descheduleSyncRecord:syncRecord];
			}],

		] completionHandler:nil];

	[syncContext addIssue:issue];

	return (issue);
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

@end
