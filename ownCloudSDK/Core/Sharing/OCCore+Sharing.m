//
//  OCCore+Sharing.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 13.03.19.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2019, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCCore.h"
#import "OCCore+Internal.h"
#import "OCCore+ItemList.h"
#import "OCShareQuery+Internal.h"
#import "OCRecipientSearchController.h"
#import "NSString+OCPath.h"
#import "NSURL+OCPrivateLink.h"
#import "NSProgress+OCExtensions.h"
#import "OCLogger.h"

@implementation OCCore (Sharing)

#pragma mark - Share Query management
- (void)startShareQuery:(OCShareQuery *)shareQuery
{
	[self queueBlock:^{
		[self->_shareQueries addObject:shareQuery];

		[self reloadShareQuery:shareQuery];

		[self _pollNextShareQuery];
	}];
}

- (void)reloadShareQuery:(OCShareQuery *)shareQuery
{
	[self queueBlock:^{
		shareQuery.lastRefreshStarted = [NSDate new];

		[self _pollForSharesWithScope:shareQuery.scope item:shareQuery.item completionHandler:nil];
	}];
}

- (void)stopShareQuery:(OCShareQuery *)shareQuery
{
	[self queueBlock:^{
		[self->_shareQueries removeObject:shareQuery];
	}];
}

#pragma mark - Automatic polling
- (void)_pollNextShareQuery
{
	if (self.state != OCCoreStateRunning)
	{
		return;
	}

	[self beginActivity:@"Poll next share query"];

	[self queueBlock:^{
		if ((self->_pollingQuery == nil) && (self.state == OCCoreStateRunning))
		{
			NSDate *earliestRefresh = nil;

			for (OCShareQuery *shareQuery in self->_shareQueries)
			{
				if (shareQuery.refreshInterval > 0)
				{
					if ((((shareQuery.lastRefreshed!=nil) && ((-shareQuery.lastRefreshed.timeIntervalSinceNow) > shareQuery.refreshInterval)) || (shareQuery.lastRefreshed == nil)) &&
					    ((-shareQuery.lastRefreshStarted.timeIntervalSinceNow) > shareQuery.refreshInterval))
					{
						shareQuery.lastRefreshStarted = [NSDate new];

						self->_pollingQuery = shareQuery;

						[self beginActivity:@"Polling for shares"];

						[self _pollForSharesWithScope:shareQuery.scope item:shareQuery.item completionHandler:^{
							[self queueBlock:^{
								self->_pollingQuery = nil;

								[self _pollNextShareQuery];

								[self endActivity:@"Polling for shares"];
							}];
						}];

						earliestRefresh = nil;

						break;
					}
					else
					{
						NSDate *latestRefreshActivity=nil, *nextRefresh=nil;

						if ((shareQuery.lastRefreshed != nil) || (shareQuery.lastRefreshStarted != nil))
						{
							latestRefreshActivity = (shareQuery.lastRefreshed.timeIntervalSinceReferenceDate > shareQuery.lastRefreshStarted.timeIntervalSinceReferenceDate) ? shareQuery.lastRefreshed : shareQuery.lastRefreshStarted;
							nextRefresh = [latestRefreshActivity dateByAddingTimeInterval:shareQuery.refreshInterval];
						}
						else
						{
							nextRefresh = [NSDate dateWithTimeIntervalSinceNow:shareQuery.refreshInterval];
						}

						if ((nextRefresh != nil) && ((earliestRefresh==nil) || ((earliestRefresh!=nil) && (nextRefresh.timeIntervalSinceReferenceDate < earliestRefresh.timeIntervalSinceReferenceDate))))
						{
							earliestRefresh = nextRefresh;
						}
					}
				}
			}

			if (earliestRefresh != nil)
			{
				__weak OCCore *weakSelf = self;
				NSTimeInterval nextRefreshFromNow = earliestRefresh.timeIntervalSinceNow;

				if (nextRefreshFromNow < 0)
				{
					nextRefreshFromNow = 1.0;
				}

				dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(nextRefreshFromNow * ((NSTimeInterval)NSEC_PER_SEC))), self->_queue, ^{
					OCCore *strongSelf;

					if (((strongSelf = weakSelf) != nil) &&  (strongSelf.state == OCCoreStateRunning))
					{
						[weakSelf _pollNextShareQuery];
					}
				});
			}
		}

		[self endActivity:@"Poll next share query"];
	}];
}

#pragma mark - Updating share queries
- (void)_pollForSharesWithScope:(OCShareScope)scope item:(OCItem *)item completionHandler:(dispatch_block_t)completionHandler
{
	__weak OCCore *weakCore = self;

	[self.connection retrieveSharesWithScope:scope forItem:item options:nil completionHandler:^(NSError * _Nullable error, NSArray<OCShare *> * _Nullable shares) {
		OCCore *core = weakCore;

		if (core != nil)
		{
			if (error == nil)
			{
				[core beginActivity:@"Updating retrieved shares"];

				[core queueBlock:^{
					OCCore *core = weakCore;

					if (core != nil)
					{
						for (OCShareQuery *query in core->_shareQueries)
						{
							[query _updateWithRetrievedShares:shares forItem:item scope:scope];
						}
					}

					if (completionHandler != nil)
					{
						completionHandler();
					}

					[core endActivity:@"Updating retrieved shares"];
				}];
			}
			else
			{
				if (completionHandler != nil)
				{
					completionHandler();
				}
			}
		}
		else
		{
			if (completionHandler != nil)
			{
				completionHandler();
			}
		}
	}];
}

- (void)_updateShareQueriesWithAddedShare:(nullable OCShare *)addedShare updatedShare:(nullable OCShare *)updatedShare removedShare:(nullable OCShare *)removedShare limitScope:(NSNumber *)scopeNumber
{
	[self queueBlock:^{
		for (OCShareQuery *query in self->_shareQueries)
		{
			if ((scopeNumber == nil) || ((scopeNumber != nil) && (scopeNumber.integerValue == query.scope)))
			{
				[query _updateWithAddedShare:addedShare updatedShare:updatedShare removedShare:removedShare];
			}
		}

		// Update OCItem representing item
		if (removedShare != nil)
		{
			// Update parent path of removed items to quickly bring the item back in sync
			if (removedShare.itemPath.parentPath != nil)
			{
				[self scheduleItemListTaskForPath:removedShare.itemPath.parentPath forDirectoryUpdateJob:nil withMeasurement:nil];
			}
		}
		else if (updatedShare != nil)
		{
			if ([updatedShare.state isEqual:OCShareStateRejected])
			{
				// Update parent path of removed items to quickly bring the item back in sync
				if (updatedShare.itemPath.parentPath != nil)
				{
					[self scheduleItemListTaskForPath:updatedShare.itemPath.parentPath forDirectoryUpdateJob:nil withMeasurement:nil];
				}
			}
			else
			{
				// Update item metadata to quickly bring the item up-to-date
				[self scheduleItemListTaskForPath:updatedShare.itemPath forDirectoryUpdateJob:nil withMeasurement:nil];
			}
		}
		else if (addedShare != nil)
		{
			// Retrieve item metadata to quickly bring the item up-to-date
			if ([addedShare.owner isEqual:self->_connection.loggedInUser])
			{
				// Shared by user
				[self scheduleItemListTaskForPath:addedShare.itemPath forDirectoryUpdateJob:nil withMeasurement:nil];
			}
			else
			{
				// Shared with user (typically added to root dir. Should it ever not, will still trigger retrieval of updates.)
				[self scheduleItemListTaskForPath:@"/" forDirectoryUpdateJob:nil withMeasurement:nil];
			}
		}
	}];
}

#pragma mark - Share management
- (nullable NSProgress *)createShare:(OCShare *)share options:(nullable OCShareOptions)options completionHandler:(void(^)(NSError * _Nullable error, OCShare * _Nullable newShare))completionHandler
{
	OCProgress *progress;

	progress = [self.connection createShare:share options:options resultTarget:[OCEventTarget eventTargetWithEphermalEventHandlerBlock:^(OCEvent * _Nonnull event, id  _Nonnull sender) {
		if ((event.result != nil) && (event.error == nil))
		{
			[self _updateShareQueriesWithAddedShare:(OCShare *)event.result updatedShare:nil removedShare:nil limitScope:nil];
		}

		completionHandler(event.error, (OCShare *)event.result);
	} userInfo:nil ephermalUserInfo:nil]];

	return (progress.progress);
}

- (nullable NSProgress *)updateShare:(OCShare *)share afterPerformingChanges:(void(^)(OCShare *share))performChanges completionHandler:(void(^)(NSError * _Nullable error, OCShare * _Nullable updatedShare))completionHandler
{
	OCProgress *progress;

	progress = [self.connection updateShare:share afterPerformingChanges:performChanges resultTarget:[OCEventTarget eventTargetWithEphermalEventHandlerBlock:^(OCEvent * _Nonnull event, id  _Nonnull sender) {
		if ((event.result != nil) && (event.error == nil))
		{
			[self _updateShareQueriesWithAddedShare:nil updatedShare:(OCShare *)event.result removedShare:nil limitScope:nil];
		}

		completionHandler(event.error, (OCShare *)event.result);
	} userInfo:nil ephermalUserInfo:nil]];

	return (progress.progress);
}

- (nullable NSProgress *)deleteShare:(OCShare *)share completionHandler:(void(^)(NSError * _Nullable error))completionHandler
{
	OCProgress *progress;

	progress = [self.connection deleteShare:share resultTarget:[OCEventTarget eventTargetWithEphermalEventHandlerBlock:^(OCEvent * _Nonnull event, id  _Nonnull sender) {
		if (event.error == nil)
		{
			[self _updateShareQueriesWithAddedShare:nil updatedShare:nil removedShare:share limitScope:nil];
		}

		completionHandler(event.error);
	} userInfo:nil ephermalUserInfo:nil]];

	return (progress.progress);
}

- (nullable NSProgress *)makeDecisionOnShare:(OCShare *)share accept:(BOOL)accept completionHandler:(void(^)(NSError * _Nullable error))completionHandler
{
	OCProgress *progress;

	progress = [self.connection makeDecisionOnShare:share accept:accept resultTarget:[OCEventTarget eventTargetWithEphermalEventHandlerBlock:^(OCEvent * _Nonnull event, id  _Nonnull sender) {
		if (event.error == nil)
		{
			switch (share.type)
			{
				case OCShareTypeUserShare:
				case OCShareTypeGroupShare:
					share.state = accept ? OCShareStateAccepted : OCShareStateRejected;
					[self _updateShareQueriesWithAddedShare:nil updatedShare:share removedShare:nil limitScope:@(OCShareScopeSharedWithUser)];
				break;

				case OCShareTypeRemote:
					share.accepted = @(accept);

					if (accept)
					{
						[self _updateShareQueriesWithAddedShare:share updatedShare:nil removedShare:nil limitScope:@(OCShareScopeAcceptedCloudShares)];
						[self _updateShareQueriesWithAddedShare:nil updatedShare:nil removedShare:share limitScope:@(OCShareScopePendingCloudShares)];
					}
					else
					{
						[self _updateShareQueriesWithAddedShare:nil updatedShare:nil removedShare:share limitScope:@(OCShareScopeAcceptedCloudShares)];
						[self _updateShareQueriesWithAddedShare:nil updatedShare:nil removedShare:share limitScope:@(OCShareScopePendingCloudShares)];
					}
				break;

				default: break;
			}
		}

		completionHandler(event.error);
	} userInfo:nil ephermalUserInfo:nil]];

	return (progress.progress);
}

#pragma mark - Recipient access
- (OCRecipientSearchController *)recipientSearchControllerForItem:(OCItem *)item
{
	return ([[OCRecipientSearchController alloc] initWithCore:self item:item]);
}

#pragma mark - Private link
- (nullable NSProgress *)retrievePrivateLinkForItem:(OCItem *)item completionHandler:(void(^)(NSError * _Nullable error, NSURL * _Nullable privateLink))completionHandler
{
	return ([_connection retrievePrivateLinkForItem:item completionHandler:completionHandler]);
}

- (nullable NSProgress *)retrieveItemForPrivateLink:(NSURL *)privateLink completionHandler:(void(^)(NSError * _Nullable error, OCItem * _Nullable item))completionHandler
{
	OCFileIDUniquePrefix fileIDUniquePrefix;
	NSProgress *retrieveProgress = nil;

	// Try to extract a FileID from the private link
	if ((fileIDUniquePrefix = [privateLink fileIDUniquePrefixFromPrivateLinkInCore:self]) != nil)
	{
		// Try resolution from database first
		retrieveProgress = [NSProgress indeterminateProgress];

		[self.database retrieveCacheItemForFileIDUniquePrefix:fileIDUniquePrefix includingRemoved:NO completionHandler:^(OCDatabase *db, NSError *error, OCSyncAnchor syncAnchor, OCItem *item) {
			if (item != nil)
			{
				OCLogDebug(@"Resolved private link %@ locally - using fileID %@ - to item %@", OCLogPrivate(privateLink), OCLogPrivate(fileIDUniquePrefix), OCLogPrivate(item));
				completionHandler(nil, item);
			}
			else
			{
				OCLogDebug(@"Resolving private link %@ locally - using fileID %@ - failed: resolving via server…", OCLogPrivate(privateLink), OCLogPrivate(fileIDUniquePrefix));
				NSProgress *progress = [self _retrieveItemForPrivateLink:privateLink completionHandler:completionHandler];
				[retrieveProgress addChild:progress withPendingUnitCount:0];
			}
		}];
	}
	else
	{
		// Resolve via server
		OCLogDebug(@"Resolving private link %@ via server…", OCLogPrivate(privateLink));
		retrieveProgress = [self _retrieveItemForPrivateLink:privateLink completionHandler:completionHandler];
	}

	return (retrieveProgress);
}

- (nullable NSProgress *)_retrieveItemForPrivateLink:(NSURL *)privateLink completionHandler:(void(^)(NSError * _Nullable error, OCItem * _Nullable item))completionHandler
{
	NSProgress *progress = [_connection retrievePathForPrivateLink:privateLink completionHandler:^(NSError * _Nullable error, NSString * _Nullable path) {
		if (error != nil)
		{
			// Forward error
			completionHandler(error, nil);
		}
		else
		{
			// Resolve to item
			__block NSMutableArray<OCCoreItemTracking> *trackings = [NSMutableArray new];
			__block BOOL trackingCompleted = NO;
			OCCoreItemTracking tracking;

			if ((tracking = [self trackItemAtPath:path trackingHandler:^(NSError * _Nullable error, OCItem * _Nullable item, BOOL isInitial) {
				BOOL endTracking = NO;

				if (trackingCompleted)
				{
					return;
				}

				if (error != nil)
				{
					// An error occured
					trackingCompleted = YES;
					completionHandler(error, nil);
					endTracking = YES;
				}
				else if (item != nil)
				{
					trackingCompleted = YES;
					completionHandler(nil, item);
					endTracking = YES;
				}

				if (endTracking)
				{
					// Remove "tracking" so it is released and the tracking ends
					@synchronized(trackings)
					{
						[trackings removeAllObjects];
					}
				}
			}]) != nil)
			{
				// Make sure "tracking" isn't released until the item was resolved
				@synchronized(trackings)
				{
					[trackings addObject:tracking];
				}
			}
		}
	}];

	return (progress);
}

@end
