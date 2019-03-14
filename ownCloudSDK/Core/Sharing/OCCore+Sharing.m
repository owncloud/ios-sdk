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
#import "OCShareQuery+Internal.h"
#import "OCRecipientSearchController.h"

@implementation OCCore (Sharing)

#pragma mark - Share Query management
- (void)startShareQuery:(OCShareQuery *)shareQuery
{
	[self queueBlock:^{
		[self->_shareQueries addObject:shareQuery];

		[self reloadShareQuery:shareQuery];
	}];
}

- (void)reloadShareQuery:(OCShareQuery *)shareQuery
{
	[self _pollForSharesWithScope:shareQuery.scope item:shareQuery.item];
}

- (void)stopShareQuery:(OCShareQuery *)shareQuery
{
	[self queueBlock:^{
		[self->_shareQueries removeObject:shareQuery];
	}];
}

#pragma mark - Updating share queries
- (void)_pollForSharesWithScope:(OCShareScope)scope item:(OCItem *)item
{
	[self.connection retrieveSharesWithScope:scope forItem:item options:nil completionHandler:^(NSError * _Nullable error, NSArray<OCShare *> * _Nullable shares) {
		if (error == nil)
		{
			[self queueBlock:^{
				for (OCShareQuery *query in self->_shareQueries)
				{
					[query _updateWithRetrievedShares:shares forItem:item scope:scope];
				}
			}];
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
			share.accepted = @(accept);
			[self _updateShareQueriesWithAddedShare:share updatedShare:nil removedShare:nil limitScope:(accept ? @(OCShareScopeAcceptedCloudShares) : @(OCShareScopePendingCloudShares))];
			[self _updateShareQueriesWithAddedShare:nil updatedShare:nil removedShare:share limitScope:(accept ? @(OCShareScopePendingCloudShares) :  @(OCShareScopeAcceptedCloudShares))];
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

@end
