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

#pragma mark - Drive selections

- (OCDataSource *)drivesDataSource
{
	return (_drivesDataSource);
}

- (OCDataSource *)subscribedDrivesDataSource
{
	return (_subscribedDrivesDataSource);
}

- (OCDataSource *)personalDriveDataSource
{
	return (_personalDriveDataSource);
}

- (OCDataSource *)shareJailDriveDataSource
{
	return (_shareJailDriveDataSource);
}

- (OCDataSource *)projectDrivesDataSource
{
	return (_projectDrivesDataSource);
}

#pragma mark - Shared sort comparator
+ (NSComparator)sharesSortComparator
{
	static dispatch_once_t onceToken;
	static NSComparator sharesSortComparator;

	dispatch_once(&onceToken, ^{
		sharesSortComparator =  [^NSComparisonResult(OCShare *  _Nonnull share1, OCShare *  _Nonnull share2) {
			NSString *name1, *name2;

			name1 = share1.itemLocation.lastPathComponent;
			name2 = share2.itemLocation.lastPathComponent;

			if ([name1 isEqual:name2])
			{
				name1 = share1.recipient.displayName;
				name2 = share2.recipient.displayName;
			}

			if ((name1 != nil) && (name2 != nil))
			{
				return ([name1 localizedCaseInsensitiveCompare:name2]);
			}

			return (NSOrderedDescending);
		} copy];
	});

	return (sharesSortComparator);
}

#pragma mark - Shared with me
/*
		// Shared with user
		shareQueryWithUser = OCShareQuery(scope: .sharedWithUser, item: nil)

		if let shareQueryWithUser = shareQueryWithUser {
			shareQueryWithUser.refreshInterval = 60

			shareQueryWithUser.initialPopulationHandler = { [weak self] (_) in
				self?.updateSharedWithYouResult()
				self?.updatePendingSharesResult()
			}
			shareQueryWithUser.changesAvailableNotificationHandler = shareQueryWithUser.initialPopulationHandler

			start(query: shareQueryWithUser)
		}

		if core?.connection.capabilities?.federatedSharingSupported == true {
			// Accepted cloud shares
			shareQueryAcceptedCloudShares = OCShareQuery(scope: .acceptedCloudShares, item: nil)

			if let shareQueryAcceptedCloudShares = shareQueryAcceptedCloudShares {
				shareQueryAcceptedCloudShares.refreshInterval = 60

				shareQueryAcceptedCloudShares.initialPopulationHandler = { [weak self] (_) in
					self?.updateSharedWithYouResult()
					self?.updatePendingSharesResult()
				}
				shareQueryAcceptedCloudShares.changesAvailableNotificationHandler = shareQueryAcceptedCloudShares.initialPopulationHandler

				start(query: shareQueryAcceptedCloudShares)
			}

			// Pending cloud shares
			shareQueryPendingCloudShares = OCShareQuery(scope: .pendingCloudShares, item: nil)

			if let shareQueryPendingCloudShares = shareQueryPendingCloudShares {
				shareQueryPendingCloudShares.refreshInterval = 60

				shareQueryPendingCloudShares.initialPopulationHandler = { [weak self] (query) in
					if let library = self {
						library.pendingCloudSharesCounter = query.queryResults.count
						self?.updatePendingSharesResult()
					}
				}
				shareQueryPendingCloudShares.changesAvailableNotificationHandler = shareQueryPendingCloudShares.initialPopulationHandler

				start(query: shareQueryPendingCloudShares)
			}
		}

		// Shared by user
		shareQueryByUser = OCShareQuery(scope: .sharedByUser, item: nil)

		if let shareQueryByUser = shareQueryByUser {
			shareQueryByUser.refreshInterval = 60

			shareQueryByUser.initialPopulationHandler = { [weak self] (_) in
				self?.updateSharedByUserResults()
			}
			shareQueryByUser.changesAvailableNotificationHandler = shareQueryByUser.initialPopulationHandler

			start(query: shareQueryByUser)
		}
*/

- (void)_updateSharedWithMeQueryForceStop:(BOOL)forceStop
{
	BOOL hasSubscribers;

	@synchronized (self)
	{
		hasSubscribers = _sharedWithMeSubscribingDataSources > 0;
	}

	if (hasSubscribers && !forceStop)
	{
		BOOL startQuery = NO;

		@synchronized(self)
		{
			if (_sharedWithMeQuery == nil)
			{
				NSMutableArray<OCDataSource *> *sources = [NSMutableArray new];
				OCDataSource *source;
				dispatch_group_t synchronizationGroup = [self _sharedWithMeDataSource].synchronizationGroup;

				_sharedWithMeQuery = [OCShareQuery queryWithScope:OCShareScopeSharedWithUser item:nil];
				_sharedWithMeQuery.refreshInterval = 10;

				if ((source = _sharedWithMeQuery.dataSource) != nil)
				{
					source.synchronizationGroup = synchronizationGroup;
					[sources addObject:source];
				}

				if (_connection.capabilities.federatedSharingSupported)
				{
					_pendingCloudSharesQuery = [OCShareQuery queryWithScope:OCShareScopePendingCloudShares item:nil];
					_pendingCloudSharesQuery.refreshInterval = 10;
					if ((source = _pendingCloudSharesQuery.dataSource) != nil)
					{
						source.synchronizationGroup = synchronizationGroup;
						[sources addObject:source];
					}

					_acceptedCloudSharesQuery = [OCShareQuery queryWithScope:OCShareScopeAcceptedCloudShares item:nil];
					_acceptedCloudSharesQuery.refreshInterval = 10;
					if ((source = _acceptedCloudSharesQuery.dataSource) != nil)
					{
						source.synchronizationGroup = synchronizationGroup;
						[sources addObject:source];
					}
				}

				[[self _sharedWithMeDataSource] setSources:sources];

				startQuery = YES;
			}
		}

		if (startQuery)
		{
			[self startQuery:_sharedWithMeQuery];

			if (_acceptedCloudSharesQuery != nil)
			{
				[self startQuery:_acceptedCloudSharesQuery];
			}

			if (_pendingCloudSharesQuery != nil)
			{
				[self startQuery:_pendingCloudSharesQuery];
			}
		}
	}
	else
	{
		OCShareQuery *shareQuery = nil, *acceptedCloudShareQuery = nil, *pendingCloudShareQuery = nil;
		OCQuery *sharesJailQuery = nil;

		@synchronized(self)
		{
			if (_sharedWithMeQuery != nil)
			{
				shareQuery = _sharedWithMeQuery;
				_sharedWithMeQuery = nil;
			}

			if (_acceptedCloudSharesQuery != nil)
			{
				acceptedCloudShareQuery = _acceptedCloudSharesQuery;
				_acceptedCloudSharesQuery = nil;
			}

			if (_pendingCloudSharesQuery != nil)
			{
				pendingCloudShareQuery = _pendingCloudSharesQuery;
				_pendingCloudSharesQuery = nil;
			}

			if ((_sharesJailQuery != nil) && forceStop)
			{
				sharesJailQuery = _sharesJailQuery;
				_sharesJailQuery = nil;
			}

			[_sharedWithMeDataSource setSources:@[]];
		}

		if (shareQuery != nil)
		{
			[self stopQuery:shareQuery];
		}

		if (acceptedCloudShareQuery != nil)
		{
			[self stopQuery:acceptedCloudShareQuery];
		}

		if (pendingCloudShareQuery != nil)
		{
			[self stopQuery:pendingCloudShareQuery];
		}

		if (sharesJailQuery != nil)
		{
			[self stopQuery:sharesJailQuery];
		}
	}
}

- (OCDataSourceComposition *)_sharedWithMeDataSource
{
	@synchronized(self)
	{
		if (_sharedWithMeDataSource == nil)
		{
			_sharedWithMeDataSource = [[OCDataSourceComposition alloc] initWithSources:@[] applyCustomizations:nil];
			_sharedWithMeDataSource.synchronizationGroup = dispatch_group_create(); // Ensure consistency of derived data sources

			[_sharedWithMeDataSource setSortComparator:^NSComparisonResult(OCDataSource * _Nonnull source1, OCDataItemReference  _Nonnull itemRef1, OCDataSource * _Nonnull source2, OCDataItemReference  _Nonnull itemRef2) {
				id obj1 = [source1 recordForItemRef:itemRef1 error:NULL].item;
				id obj2 = [source2 recordForItemRef:itemRef2 error:NULL].item;

				return (OCCore.sharesSortComparator(obj1, obj2));
			}];
		}
	}

	return (_sharedWithMeDataSource);
}

- (void)_sharedWithMeSubscriberChange:(NSInteger)subscriberChange
{
	@synchronized(self)
	{
		_sharedWithMeSubscribingDataSources += subscriberChange;
	}

	[self beginActivity:@"Update shared with me query"];

	[self queueBlock:^{
		[self _updateSharedWithMeQueryForceStop:NO];
		[self endActivity:@"Update shared with me query"];
	}];
}

- (OCDataSourceComposition *)_compositionDataSourceForShareState:(OCShareState)shareState
{
	OCDataSource *sharedWithMeDataSource = self._sharedWithMeDataSource;
	dispatch_group_t synchronizationGroup = sharedWithMeDataSource.synchronizationGroup;

	return ([[OCDataSourceComposition alloc] initWithSources:@[ sharedWithMeDataSource ] applyCustomizations:^(OCDataSourceComposition *dataSource) {
		dataSource.synchronizationGroup = synchronizationGroup;

		[dataSource setFilter:^BOOL(OCDataSource * _Nonnull source, OCDataItemReference  _Nonnull itemRef) {
			OCDataItemRecord *record;

			if ((record = [source recordForItemRef:itemRef error:NULL]) != nil)
			{
				OCShare *share;

				if ((share = OCTypedCast(record.item, OCShare)) != nil)
				{
					return ([share.effectiveState isEqual:shareState]);
				}
			}

			return (NO);
		}];
	}]);
}

- (OCDataSource *)sharedWithMePendingDataSource
{
	@synchronized(self)
	{
		if (_sharedWithMePendingDataSource == nil)
		{
			_sharedWithMePendingDataSource = [self _compositionDataSourceForShareState:OCShareStatePending];

			[_sharedWithMePendingDataSource addSubscriptionObserver:^(OCDataSource * _Nonnull source, id<NSObject>  _Nonnull owner, BOOL hasSubscribers) {
				[(OCCore *)owner _sharedWithMeSubscriberChange:(hasSubscribers ? 1 : -1)];
			} withOwner:self performInitial:NO];
		}
	}

	return (_sharedWithMePendingDataSource);
}

- (OCDataSource *)sharedWithMeAcceptedDataSource
{
	@synchronized(self)
	{
		if (_sharedWithMeAcceptedDataSource == nil)
		{
//			if (self.useDrives)
//			{
//				// Provide contents of share jail drive
//				_sharedWithMeAcceptedDataSource = [[OCDataSourceComposition alloc] initWithSources:@[] applyCustomizations:nil];
//
//				[_sharedWithMeAcceptedDataSource addSubscriptionObserver:^(OCDataSource * _Nonnull source, id<NSObject>  _Nonnull owner, BOOL hasSubscribers) {
//					OCCore *core = (OCCore *)owner;
//					OCDataSourceComposition *dataSource = (OCDataSourceComposition *)source;
//
//					if (hasSubscribers)
//					{
//						if (core->_sharesJailQuery == nil)
//						{
//							OCQuery *query = [OCQuery queryForLocation:[[OCLocation alloc] initWithDriveID:OCDriveIDSharesJail path:@"/"]];
//							OCDataSource *queryResultsDataSource = query.queryResultsDataSource;
//							if (queryResultsDataSource != nil)
//							{
//								[dataSource addSources:@[ queryResultsDataSource ]];
//							}
//
//							core->_sharesJailQuery = query;
//
//							if (core->_shareJailQueryCustomizer != nil)
//							{
//								core->_shareJailQueryCustomizer(query);
//							}
//
//							[core startQuery:query];
//						}
//					}
//					else
//					{
//						OCQuery *query;
//
//						if ((query = core->_sharesJailQuery) != nil)
//						{
//							OCDataSource *queryResultsDataSource;
//
//							if ((queryResultsDataSource = query.queryResultsDataSource) != nil)
//							{
//								[dataSource removeSources:@[ queryResultsDataSource ]];
//							}
//
//							[core stopQuery:query];
//
//							core->_sharesJailQuery = nil;
//						}
//					}
//				} withOwner:self performInitial:NO];
//			}
//			else
			{
				// Provide applicable results from sharedWithMe data source
				_sharedWithMeAcceptedDataSource = [self _compositionDataSourceForShareState:OCShareStateAccepted];

				[_sharedWithMeAcceptedDataSource addSubscriptionObserver:^(OCDataSource * _Nonnull source, id<NSObject>  _Nonnull owner, BOOL hasSubscribers) {
					[(OCCore *)owner _sharedWithMeSubscriberChange:(hasSubscribers ? 1 : -1)];
				} withOwner:self performInitial:NO];
			}
		}
	}

	return (_sharedWithMeAcceptedDataSource);
}

- (OCDataSource *)sharedWithMeDeclinedDataSource
{
	@synchronized(self)
	{
		if (_sharedWithMeDeclinedDataSource == nil)
		{
			_sharedWithMeDeclinedDataSource = [self _compositionDataSourceForShareState:OCShareStateDeclined];

			[_sharedWithMeDeclinedDataSource addSubscriptionObserver:^(OCDataSource * _Nonnull source, id<NSObject>  _Nonnull owner, BOOL hasSubscribers) {
				[(OCCore *)owner _sharedWithMeSubscriberChange:(hasSubscribers ? 1 : -1)];
			} withOwner:self performInitial:NO];
		}
	}

	return (_sharedWithMeDeclinedDataSource);
}


- (void)setShareJailQueryCustomizer:(OCCoreShareJailQueryCustomizer)shareJailQueryCustomizer
{
	_shareJailQueryCustomizer = [shareJailQueryCustomizer copy];

	if (_shareJailQueryCustomizer != nil)
	{
		if (_sharesJailQuery != nil)
		{
			_shareJailQueryCustomizer(_sharesJailQuery);
		}
	}
}

- (OCCoreShareJailQueryCustomizer)shareJailQueryCustomizer
{
	return (_shareJailQueryCustomizer);
}


#pragma mark - Shared by me
- (void)_updateAllSharedByMeQueryForceStop:(BOOL)forceStop
{
	BOOL hasSubscribers;

	@synchronized (self)
	{
		hasSubscribers = _allSharedByMeSubscribingDataSources > 0;
	}

	if (hasSubscribers && !forceStop)
	{
		BOOL startQuery = NO;

		@synchronized(self)
		{
			if (_allSharedByMeQuery == nil)
			{
				__weak OCCore *weakSelf = self;

				_allSharedByMeQuery = [OCShareQuery queryWithScope:OCShareScopeSharedByUser item:nil];
				_allSharedByMeQuery.refreshInterval = 10;

				_allSharedByMeQuery.changesAvailableNotificationHandler = ^(OCShareQuery * _Nonnull query) {
					OCWLogDebug(@"SharedByMe: %@", query.queryResults);

					// Group shares
					NSArray<OCShare *> *allSharedByMeShares = query.queryResults;
					NSMutableDictionary<OCLocation *, OCShare *> *sharesByLocation = [NSMutableDictionary new];
					NSMutableArray<OCShare *> *primaryShares = [NSMutableArray new];
					NSMutableArray<OCShare *> *flatShares = [NSMutableArray new];
					NSMutableArray<OCShare *> *linkShares = [NSMutableArray new];

					for (OCShare *share in allSharedByMeShares)
					{
						OCLocation *shareLocation;

						if (share.type == OCShareTypeLink)
						{
							// Separate link shares so they can't become hidden by / hide non-link shares
							[linkShares addObject:share];
						}
						else
						{
							[flatShares addObject:share];

							// Group shares by location, add additional shares to .otherItemShares of non-link share of same location
							if ((shareLocation = share.itemLocation) != nil)
							{
								OCShare *existingShare;

								if ((existingShare = sharesByLocation[shareLocation]) != nil)
								{
									NSMutableArray<OCShare *> *otherItemShares;

									if ((otherItemShares = (NSMutableArray *)existingShare.otherItemShares) == nil)
									{
										otherItemShares = [NSMutableArray new];
										existingShare.otherItemShares = otherItemShares;
									}

									[otherItemShares addObject:share];
								}
								else
								{
									sharesByLocation[shareLocation] = share;
									[primaryShares addObject:share];
								}
							}
						}
					}

					// Add link shares to primary shares
					[primaryShares addObjectsFromArray:linkShares];

					// Sort by name
					NSComparator sharesComparator = OCCore.sharesSortComparator;

					[primaryShares sortUsingComparator:sharesComparator];
					[flatShares sortUsingComparator:sharesComparator];

					// Update data sources
					[[weakSelf _allSharedByMeDataSource] setVersionedItems:primaryShares];

					OCCore *strongSelf;
					if ((strongSelf = weakSelf) != nil)
					{
						[strongSelf->_sharedByMeDataSource setVersionedItems:flatShares];
					}
				};

				startQuery = YES;
			}
		}

		if (startQuery)
		{
			[self startQuery:_allSharedByMeQuery];
		}
	}
	else
	{
		OCShareQuery *shareQuery = nil;

		@synchronized(self)
		{
			if (_allSharedByMeQuery != nil)
			{
				shareQuery = _allSharedByMeQuery;
				_allSharedByMeQuery = nil;
			}
		}

		if (shareQuery != nil)
		{
			[self stopQuery:shareQuery];
		}
	}
}

- (OCDataSourceArray *)_allSharedByMeDataSource
{
	@synchronized(self)
	{
		if (_allSharedByMeDataSource == nil)
		{
			_allSharedByMeDataSource = [[OCDataSourceArray alloc] initWithItems:nil];
			_allSharedByMeDataSource.synchronizationGroup = dispatch_group_create(); // Ensure consistency of derived data sources
			_allSharedByMeDataSource.trackItemVersions = YES; // Track item versions, so changes in status can be detected as actual changes
		}
	}

	return (_allSharedByMeDataSource);
}

- (void)_allSharedByMeSubscriberChange:(NSInteger)subscriberChange
{
	@synchronized(self)
	{
		_allSharedByMeSubscribingDataSources += subscriberChange;
	}

	[self beginActivity:@"Update shared by me query"];

	[self queueBlock:^{
		[self _updateAllSharedByMeQueryForceStop:NO];
		[self endActivity:@"Update shared by me query"];
	}];
}

- (OCDataSourceComposition *)_compositionDataSourceForShareTypeLink:(BOOL)shareTypeLink
{
	OCDataSource *allSharedByMeDataSource = [self _allSharedByMeDataSource];
	dispatch_group_t synchronizationGroup = allSharedByMeDataSource.synchronizationGroup;

	return ([[OCDataSourceComposition alloc] initWithSources:@[ allSharedByMeDataSource ] applyCustomizations:^(OCDataSourceComposition *dataSource) {
		dataSource.synchronizationGroup = synchronizationGroup;

		[dataSource setFilter:^BOOL(OCDataSource * _Nonnull source, OCDataItemReference  _Nonnull itemRef) {
			OCDataItemRecord *record;

			if ((record = [source recordForItemRef:itemRef error:NULL]) != nil)
			{
				OCShare *share;

				if ((share = OCTypedCast(record.item, OCShare)) != nil)
				{
					return ((share.type == OCShareTypeLink) == shareTypeLink);
				}
			}

			return (NO);
		}];
	}]);
}

#pragma mark - Shared by me (to other users)
- (OCDataSource *)sharedByMeDataSource
{
	@synchronized(self)
	{
		if (_sharedByMeDataSource == nil)
		{
			NSArray<OCShare *> *flatSharedByMe = nil;

			if (_allSharedByMeQuery != nil)
			{
				flatSharedByMe = [_allSharedByMeQuery.queryResults filteredArrayUsingBlock:^BOOL(OCShare * _Nonnull share, BOOL * _Nonnull stop) {
					return (share.type != OCShareTypeLink);
				}];
			}

			_sharedByMeDataSource = [[OCDataSourceArray alloc] initWithItems:flatSharedByMe];
			_sharedByMeDataSource.synchronizationGroup = [self _allSharedByMeDataSource].synchronizationGroup;

			[_sharedByMeDataSource addSubscriptionObserver:^(OCDataSource * _Nonnull source, id<NSObject>  _Nonnull owner, BOOL hasSubscribers) {
				[(OCCore *)owner _allSharedByMeSubscriberChange:(hasSubscribers ? 1 : -1)];
			} withOwner:self performInitial:NO];
		}
	}

	return (_sharedByMeDataSource);
}

- (OCDataSource *)sharedByMeGroupedDataSource
{
	@synchronized(self)
	{
		if (_sharedByMeGroupedDataSource == nil)
		{
			_sharedByMeGroupedDataSource = [self _compositionDataSourceForShareTypeLink:NO];

			[_sharedByMeGroupedDataSource addSubscriptionObserver:^(OCDataSource * _Nonnull source, id<NSObject>  _Nonnull owner, BOOL hasSubscribers) {
				[(OCCore *)owner _allSharedByMeSubscriberChange:(hasSubscribers ? 1 : -1)];
			} withOwner:self performInitial:NO];
		}
	}

	return (_sharedByMeGroupedDataSource);
}

#pragma mark - Shared by link
- (OCDataSource *)sharedByLinkDataSource
{
	@synchronized(self)
	{
		if (_sharedByLinkDataSource == nil)
		{
			_sharedByLinkDataSource = [self _compositionDataSourceForShareTypeLink:YES];

			[_sharedByLinkDataSource addSubscriptionObserver:^(OCDataSource * _Nonnull source, id<NSObject>  _Nonnull owner, BOOL hasSubscribers) {
				[(OCCore *)owner _allSharedByMeSubscriberChange:(hasSubscribers ? 1 : -1)];
			} withOwner:self performInitial:NO];
		}
	}

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
			} withOwner:self performInitial:NO];
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
			} withOwner:self performInitial:NO];
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
			} withOwner:self performInitial:NO];
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
		if (_pollingDataSourcesTimer != NULL)
		{
			dispatch_source_cancel(_pollingDataSourcesTimer);
			_pollingDataSourcesTimer = NULL;
		}
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
