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
	[self beginActivity:@"Poll next share query"];

	[self queueBlock:^{
		if ((self->_pollingQuery == nil) && (self.state == OCCoreStateRunning))
		{
			NSDate *earliestRefresh = nil;

			for (OCShareQuery *shareQuery in self->_shareQueries)
			{
				if (shareQuery.refreshInterval > 0)
				{
					if (((-shareQuery.lastRefreshed.timeIntervalSinceNow) > shareQuery.refreshInterval) &&
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
				dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(earliestRefresh.timeIntervalSinceNow * ((NSTimeInterval)NSEC_PER_SEC))), self->_queue, ^{
					[self _pollNextShareQuery];
				});
			}
		}

		[self endActivity:@"Poll next share query"];
	}];
}

#pragma mark - Updating share queries
- (void)_pollForSharesWithScope:(OCShareScope)scope item:(OCItem *)item completionHandler:(dispatch_block_t)completionHandler
{
	[self.connection retrieveSharesWithScope:scope forItem:item options:nil completionHandler:^(NSError * _Nullable error, NSArray<OCShare *> * _Nullable shares) {
		if (error == nil)
		{
			[self queueBlock:^{
				for (OCShareQuery *query in self->_shareQueries)
				{
					[query _updateWithRetrievedShares:shares forItem:item scope:scope];
				}

				if (completionHandler != nil)
				{
					completionHandler();
				}
			}];
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
		OCShare *share = ((addedShare != nil) ? addedShare : ((updatedShare != nil) ? updatedShare : removedShare));

		if (share != nil)
		{
			[self scheduleItemListTaskForPath:share.itemPath forQuery:YES];
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
					[self _updateShareQueriesWithAddedShare:share updatedShare:nil removedShare:nil limitScope:(accept ? @(OCShareScopeAcceptedCloudShares) : @(OCShareScopePendingCloudShares))];
					[self _updateShareQueriesWithAddedShare:nil updatedShare:nil removedShare:share limitScope:(accept ? @(OCShareScopePendingCloudShares) :  @(OCShareScopeAcceptedCloudShares))];
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

@end
