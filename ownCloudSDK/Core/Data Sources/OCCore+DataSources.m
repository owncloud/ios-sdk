//
//  OCCore+DataSources.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 28.03.22.
//  Copyright © 2022 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2022, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCCore+DataSources.h"
#import "OCCore+Internal.h"

@implementation OCCore (DataSources)

- (OCDataSource *)drivesDataSource
{
	return (_drivesDataSource);
}

- (OCDataSource *)subscribedDrivesDataSource
{
	return (_subscribedDrivesDataSource);
}

- (OCDataSource *)personalAndSharedDrivesDataSource
{
	return (_personalAndSharedDrivesDataSource);
}

- (OCDataSource *)projectDrivesDataSource
{
	return (_projectDrivesDataSource);
}

- (OCDataSource *)sharedWithMeDataSource
{
	// Needs implementation
	return (_sharedWithMeDataSource);
}

- (OCDataSource *)sharedWithMePendingDataSource
{
	// Needs implementation
	return (_sharedWithMePendingDataSource);
}

- (OCDataSource *)sharedWithMeAcceptedDataSource
{
	// Needs implementation
	return (_sharedWithMeAcceptedDataSource);
}

- (OCDataSource *)sharedWithMeDeclinedDataSource
{
	// Needs implementation
	return (_sharedWithMeDeclinedDataSource);
}

- (OCDataSource *)sharedByMeDataSource
{
	// Needs implementation
	return (_sharedByMeDataSource);
}

- (OCDataSource *)sharedByLinkDataSource
{
	// Needs implementation
	return (_sharedByLinkDataSource);
}

#pragma mark - Favorites
- (OCDataSource *)favoritesDataSource
{
	@synchronized(self)
	{
		if (_favoritesDataSource == nil)
		{
			_favoritesDataSource = [[OCDataSourceComposition alloc] initWithSources:@[] applyCustomizations:nil];

			[_favoritesDataSource addSubscriptionObserver:^(OCDataSource * _Nonnull source, id<NSObject>  _Nonnull owner, BOOL hasSubscribers) {
				OCCore *core = (OCCore *)owner;

				@synchronized(core)
				{
					core->_favoritesDataSourceHasSubscribers = hasSubscribers;
				}

				[core beginActivity:@"Update favorites data source"];

				[core queueBlock:^{
					[core _setFavoritesDataSourceSubscriptionHasUpdate];
					[core endActivity:@"Update favorites data source"];
				}];
			} withOwner:self performInitial:YES];
		}
	}

	return (_favoritesDataSource);
}

- (void)_setFavoritesDataSourceSubscriptionHasUpdate // Performed on core queue, which acts as lock
{
	BOOL favoritesDataSourceHasSubscribers;

	@synchronized(self)
	{
		favoritesDataSourceHasSubscribers = _favoritesDataSourceHasSubscribers;
	}

	if (favoritesDataSourceHasSubscribers == (_favoritesQuery != nil))
	{
		// Nothing to do
		return;
	}

	if (favoritesDataSourceHasSubscribers)
	{
		// Create favorites query, add results as data source and start query
		if (_favoritesQuery == nil)
		{
			OCQuery *query = [OCQuery queryWithCondition:[OCQueryCondition where:OCItemPropertyNameIsFavorite isEqualTo:@(YES)] inputFilter:nil];
			OCDataSource *queryDatasource = query.queryResultsDataSource;

			if ((query != nil) && (queryDatasource != nil))
			{
				_favoritesQuery = query;
				[_favoritesDataSource addSources:@[ queryDatasource ]];

				[self startQuery:_favoritesQuery];

				if (!self.useDrives)
				{
					// Only OC10 requires polling for favorites - ocis propagates the change via regular PROPFIND update scanning
					[self subscribeToPollingDatasourcesTimer:OCCoreDataSourcePollTypeFavorites];
				}
			}
		}
	}
	else
	{
		// Remove favorites query results data source and stop query
		OCQuery *query = _favoritesQuery;
		OCDataSource *queryDatasource = query.queryResultsDataSource;

		if (queryDatasource != nil)
		{
			[_favoritesDataSource removeSources:@[ queryDatasource ]];

			if (!self.useDrives)
			{
				// Only OC10 requires polling for favorites - ocis propagates the change via regular PROPFIND update scanning
				[self unsubscribeFromPollingDatasourcesTimer:OCCoreDataSourcePollTypeFavorites withForcedStop:NO];
			}
		}

		if (query != nil)
		{
			[self stopQuery:query];
			_favoritesQuery = nil;
		}
	}
}

#pragma mark - Available Offline: Item Policies
- (OCDataSource *)availableOfflineItemPoliciesDataSource
{
	@synchronized(self)
	{
		if (_availableOfflineItemPoliciesDataSource == nil)
		{
			_availableOfflineItemPoliciesDataSource = [[OCDataSourceArray alloc] initWithItems:@[]];

			[_availableOfflineItemPoliciesDataSource addSubscriptionObserver:^(OCDataSource * _Nonnull source, id<NSObject>  _Nonnull owner, BOOL hasSubscribers) {
				OCCore *core = (OCCore *)owner;

				@synchronized(core)
				{
					core->_availableOfflineItemPoliciesDataSourceHasSubscribers = hasSubscribers;
				}

				[core beginActivity:@"Update offline item policies data source"];

				[core queueBlock:^{
					[core _setOfflineItemPoliciesDataSourceSubscriptionHasUpdate];
					[core endActivity:@"Update offline item policies data source"];
				}];
			} withOwner:self performInitial:YES];
		}
	}

	return (_availableOfflineItemPoliciesDataSource);
}

- (void)_setOfflineItemPoliciesDataSourceSubscriptionHasUpdate
{
	OCItemPolicyProcessor *availableOfflinePolicyProcessor;
	BOOL availableOfflineItemPoliciesDataSourceHasSubscribers;

	@synchronized(self)
	{
		availableOfflineItemPoliciesDataSourceHasSubscribers = _availableOfflineItemPoliciesDataSourceHasSubscribers;
	}

	if (availableOfflineItemPoliciesDataSourceHasSubscribers == _observesOfflineItemPolicies)
	{
		// Nothing to do
		return;
	}

	if ((availableOfflinePolicyProcessor = [self itemPolicyProcessorForKind:OCItemPolicyKindAvailableOffline]) != nil)
	{
		_observesOfflineItemPolicies = availableOfflineItemPoliciesDataSourceHasSubscribers;

		if (availableOfflineItemPoliciesDataSourceHasSubscribers)
		{
			[self _reloadOfflineItemDataPoliciesIntoDataSource];

			[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(_reloadOfflineItemDataPoliciesIntoDataSource) name:OCCoreItemPolicyProcessorUpdated object:availableOfflinePolicyProcessor];
		}
		else
		{
			[NSNotificationCenter.defaultCenter removeObserver:self name:OCCoreItemPolicyProcessorUpdated object:availableOfflinePolicyProcessor];
		}
	}
}

- (void)_reloadOfflineItemDataPoliciesIntoDataSource
{
	[self retrievePoliciesOfKind:OCItemPolicyKindAvailableOffline affectingItem:nil includeInternal:NO completionHandler:^(NSError * _Nullable error, NSArray<OCItemPolicy *> * _Nullable policies) {
		NSArray<OCItemPolicy *> *sortedPolicies = [policies sortedArrayUsingComparator:^NSComparisonResult(OCItemPolicy *policy1, OCItemPolicy *policy2) {
			OCPath policy1Path = policy1.location.path, policy2Path = policy2.location.path;

			if ((policy1Path != nil) && (policy2Path != nil))
			{
				return ([policy1.location.path localizedStandardCompare:policy2.location.path]);
			}

			return (NSOrderedDescending);
		}];

		[self->_availableOfflineItemPoliciesDataSource setVersionedItems:sortedPolicies];
	}];
}

#pragma mark - Available Offline: Files
- (OCDataSource *)availableOfflineFilesDataSource
{
	@synchronized(self)
	{
		if (_availableOfflineFilesDataSource == nil)
		{
			_availableOfflineFilesDataSource = [[OCDataSourceComposition alloc] initWithSources:@[] applyCustomizations:nil];

			[_availableOfflineFilesDataSource addSubscriptionObserver:^(OCDataSource * _Nonnull source, id<NSObject>  _Nonnull owner, BOOL hasSubscribers) {
				OCCore *core = (OCCore *)owner;

				@synchronized(core)
				{
					core->_availableOfflineFilesDataSourceHasSubscribers = hasSubscribers;
				}

				[core beginActivity:@"Update favorites data source"];

				[core queueBlock:^{
					[core _setAvailableOfflineFilesDataSourceSubscriptionHasUpdate];
					[core endActivity:@"Update favorites data source"];
				}];
			} withOwner:self performInitial:YES];
		}
	}

	return (_availableOfflineFilesDataSource);
}

- (void)_setAvailableOfflineFilesDataSourceSubscriptionHasUpdate // Performed on core queue, which acts as lock
{
	BOOL availableOfflineFilesDataSourceHasSubscribers;

	@synchronized(self)
	{
		availableOfflineFilesDataSourceHasSubscribers = _availableOfflineFilesDataSourceHasSubscribers;
	}

	if (availableOfflineFilesDataSourceHasSubscribers == (_availableOfflineFilesQuery != nil))
	{
		// Nothing to do
		return;
	}

	if (availableOfflineFilesDataSourceHasSubscribers)
	{
		// Create favorites query, add results as data source and start query
		if (_availableOfflineFilesQuery == nil)
		{
			OCQuery *query = [OCQuery queryWithCondition:[OCQueryCondition where:OCItemPropertyNameDownloadTrigger isEqualTo:OCItemDownloadTriggerIDAvailableOffline] inputFilter:nil];
			OCDataSource *queryDatasource = query.queryResultsDataSource;

			if ((query != nil) && (queryDatasource != nil))
			{
				_availableOfflineFilesQuery = query;
				[_availableOfflineFilesDataSource addSources:@[ queryDatasource ]];

				[self startQuery:_availableOfflineFilesQuery];
			}
		}
	}
	else
	{
		// Remove favorites query results data source and stop query
		OCQuery *query = _availableOfflineFilesQuery;
		OCDataSource *queryDatasource = query.queryResultsDataSource;

		if (queryDatasource != nil)
		{
			[_availableOfflineFilesDataSource removeSources:@[ queryDatasource ]];
		}

		if (query != nil)
		{
			[self stopQuery:query];
			_availableOfflineFilesQuery = nil;
		}
	}
}


#pragma mark - Polling timer
- (void)subscribeToPollingDatasourcesTimer:(OCCoreDataSourcePollType)pollType
{
	BOOL start = NO;

	@synchronized (self)
	{
		_pollingDataSourcesSubscribers += 1;

		if (_pollingDataSourcesSubscribers == 1)
		{
			start = YES;
		}
	}

	if (start)
	{
		_pollingDataSourcesTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _queue);

		__weak __auto_type weakSelf = self;
		dispatch_source_set_event_handler(_pollingDataSourcesTimer, ^{
			[weakSelf _pollSubscribedDataSource:OCCoreDataSourcePollTypeAll];
		});

		int64_t pollIntervalSec = 30;
		dispatch_source_set_timer(_pollingDataSourcesTimer, dispatch_time(DISPATCH_TIME_NOW, pollIntervalSec * NSEC_PER_SEC), pollIntervalSec * NSEC_PER_SEC, NSEC_PER_SEC);
		dispatch_resume(_pollingDataSourcesTimer);

		[self _pollSubscribedDataSource:pollType];
	}
}

- (void)unsubscribeFromPollingDatasourcesTimer:(OCCoreDataSourcePollType)pollType withForcedStop:(BOOL)force
{
	BOOL stop = force;

	@synchronized (self)
	{
		if (_pollingDataSourcesSubscribers > 0)
		{
			_pollingDataSourcesSubscribers -= 1;
		}

		if (_pollingDataSourcesSubscribers == 0)
		{
			stop = YES;
		}
	}

	if (stop)
	{
		dispatch_source_cancel(_pollingDataSourcesTimer);
		_pollingDataSourcesTimer = NULL;
	}
}

- (void)_performPollForDataSource:(void(^)(dispatch_block_t completionHandler))pollRoutine
{
	__block BOOL didFinish = NO;
	__weak OCCore *weakSelf = self;

	@synchronized(self)
	{
		_pollingDataSourcesOutstandingRequests += 1;
	}

	pollRoutine([^{
		if (!didFinish)
		{
			didFinish = YES;

			OCCore *core;

			if ((core = weakSelf) != nil)
			{
				@synchronized(core)
				{
					core->_pollingDataSourcesOutstandingRequests -= 1;
				}
			}
		}
	} copy]);
}

#pragma mark - Perform polling
- (void)_pollSubscribedDataSource:(OCCoreDataSourcePollType)pollType
{
	__weak OCCore *weakSelf = self;

	if ((self.state == OCCoreStateStopping) || (self.state == OCCoreStateStopped))
	{
		// Skip when the core is stopping or stopped
		return;
	}

	if (self.state != OCCoreStateRunning)
	{
		// Only perform when the core is running
		return;
	}

	BOOL pollFavorites = NO;

	@synchronized(self)
	{
		if ((_pollingDataSourcesOutstandingRequests > 0) && (pollType == OCCoreDataSourcePollTypeAll))
		{
			// Do not perform next polling before the previous polling isn't done
			return;
		}

		// Determine what to poll
		pollFavorites = _favoritesDataSourceHasSubscribers && ((pollType == OCCoreDataSourcePollTypeAll) || (pollType == OCCoreDataSourcePollTypeFavorites));
	}

	if (pollFavorites)
	{
		[self _performPollForDataSource:^(dispatch_block_t completionHandler) {
			[weakSelf refreshFavoritesWithCompletionHandler:^(NSError * _Nullable error, NSArray<OCItem *> * _Nullable favoritedItems) {
				completionHandler();
			}];
		}];
	}
}

@end
