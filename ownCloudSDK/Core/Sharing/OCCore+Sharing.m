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
#import "NSError+OCHTTPStatus.h"
#import "NSArray+OCFiltering.h"
#import "OCMacros.h"

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
			if (error != nil)
			{
				// Output error only if not due to status 404
				if (![error isHTTPStatusErrorWithCode:OCHTTPStatusCodeNOT_FOUND])
				{
					OCLogError(@"Error retrieving shares of scope %ld for %@: %@", scope, item, error);
				}
			}

			[core beginActivity:@"Updating retrieved shares"];

			[core queueBlock:^{
				OCCore *core = weakCore;

				if (core != nil)
				{
					for (OCShareQuery *query in core->_shareQueries)
					{
						[query _updateWithRetrievedShares:((error == nil) ? shares : @[]) forItem:item scope:scope];
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
			if (removedShare.itemLocation.parentLocation != nil)
			{
				[self scheduleItemListTaskForLocation:removedShare.itemLocation.parentLocation forDirectoryUpdateJob:nil withMeasurement:nil];
			}
		}
		else if (updatedShare != nil)
		{
			if ([updatedShare.state isEqual:OCShareStateDeclined])
			{
				// Update parent path of removed items to quickly bring the item back in sync
				if (updatedShare.itemLocation.parentLocation != nil)
				{
					[self scheduleItemListTaskForLocation:updatedShare.itemLocation.parentLocation forDirectoryUpdateJob:nil withMeasurement:nil];
				}
			}
			else
			{
				// Update item metadata to quickly bring the item up-to-date
				[self scheduleItemListTaskForLocation:updatedShare.itemLocation forDirectoryUpdateJob:nil withMeasurement:nil];
			}
		}
		else if (addedShare != nil)
		{
			// Retrieve item metadata to quickly bring the item up-to-date
			if ([addedShare.owner isEqual:self->_connection.loggedInUser])
			{
				// Shared by user
				[self scheduleItemListTaskForLocation:addedShare.itemLocation forDirectoryUpdateJob:nil withMeasurement:nil];
			}
			else
			{
				// Shared with user (typically added to root dir. Should it ever not, will still trigger retrieval of updates.)
				[self scheduleItemListTaskForLocation:[[OCLocation alloc] initWithDriveID:addedShare.itemLocation.driveID path:@"/"] forDirectoryUpdateJob:nil withMeasurement:nil];
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
					share.state = accept ? OCShareStateAccepted : OCShareStateDeclined;
					[self _updateShareQueriesWithAddedShare:nil updatedShare:share removedShare:nil limitScope:@(OCShareScopeSharedWithUser)];
				break;

				case OCShareTypeRemote: {
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

					// Accepting a share can change a share's path (f.ex. if an item with the same name already exists in the target folder), so directly perform a refresh
					if (accept)
					{
						OCShareQuery *acceptedCloudSharesQuery = self->_acceptedCloudSharesQuery;
						if (acceptedCloudSharesQuery != nil)
						{
							[self reloadQuery:acceptedCloudSharesQuery];
						}

						OCShareQuery *pendingCloudSharesQuery = self->_pendingCloudSharesQuery;
						if (pendingCloudSharesQuery != nil)
						{
							[self reloadQuery:pendingCloudSharesQuery];
						}
					}
				}
				break;

				default: break;
			}
		}

		completionHandler(event.error);
	} userInfo:nil ephermalUserInfo:nil]];

	return (progress.progress);
}

#pragma mark - Roles
- (nullable NSArray<OCShareRole *> *)availableShareRolesForType:(OCShareType)shareType location:(OCLocation *)location
{
	NSArray<OCShareRole *> *roles = nil;
	OCLocationType locationType = location.type;
	OCShareTypesMask shareTypeMask = [OCShare maskForType:shareType];
	BOOL resharingSupported = !self.useDrives;

	if (locationType == OCLocationTypeUnknown)
	{
		return(nil);
	}

	@synchronized(_shareRoles)
	{
		if (_shareRoles.count == 0)
		{
			// Roles as described in
			// - https://github.com/owncloud/ocis/issues/4848#issuecomment-1283678879
			// - https://github.com/owncloud/web/blob/master/packages/web-client/src/helpers/share/role.ts
			[_shareRoles addObjectsFromArray:@[
				// # USERS & GROUPS
				// ## Viewer
				// - files, folders
				[[OCShareRole alloc] initWithType:OCShareRoleTypeViewer
						       shareTypes:OCShareTypesMaskUserShare|OCShareTypesMaskGroupShare
						     permissions:OCSharePermissionsMaskRead|(resharingSupported ? OCSharePermissionsMaskShare : 0)
					 customizablePermissions:OCSharePermissionsMaskNone
						       locations:OCLocationTypeFile|OCLocationTypeFolder
						      symbolName:@"eye.fill"
						   localizedName:OCLocalizedString(@"Viewer",nil)
					    localizedDescription:OCLocalizedString(resharingSupported ? @"Download, preview and share" : @"Download and preview", nil)],

				// - drives
				[[OCShareRole alloc] initWithType:OCShareRoleTypeViewer
						       shareTypes:OCShareTypesMaskUserShare|OCShareTypesMaskGroupShare
						     permissions:OCSharePermissionsMaskRead
					 customizablePermissions:OCSharePermissionsMaskNone
						       locations:OCLocationTypeDrive
						      symbolName:@"eye.fill"
						   localizedName:OCLocalizedString(@"Viewer", nil)
					    localizedDescription:OCLocalizedString(@"Download and preview", nil)],

				// ## Editor
				// - files
				[[OCShareRole alloc] initWithType:OCShareRoleTypeEditor
						       shareTypes:OCShareTypesMaskUserShare|OCShareTypesMaskGroupShare
						     permissions:OCSharePermissionsMaskRead|OCSharePermissionsMaskUpdate|(resharingSupported ? OCSharePermissionsMaskShare : 0)
					 customizablePermissions:OCSharePermissionsMaskNone
						       locations:OCLocationTypeFile
						      symbolName:@"pencil"
						   localizedName:OCLocalizedString(@"Editor", nil)
					    localizedDescription:OCLocalizedString(resharingSupported ? @"Edit, download, preview and share" : @"Edit, download and preview", nil)],

				// - folders
				[[OCShareRole alloc] initWithType:OCShareRoleTypeEditor
						       shareTypes:OCShareTypesMaskUserShare|OCShareTypesMaskGroupShare
						     permissions:OCSharePermissionsMaskRead|OCSharePermissionsMaskUpdate|OCSharePermissionsMaskCreate|OCSharePermissionsMaskDelete|(resharingSupported ? OCSharePermissionsMaskShare : 0)
					 customizablePermissions:OCSharePermissionsMaskNone
						       locations:OCLocationTypeFolder
						      symbolName:@"pencil"
						   localizedName:OCLocalizedString(@"Editor", nil)
					    localizedDescription:OCLocalizedString(resharingSupported ? @"Upload, edit, delete, download, preview and share" : @"Upload, edit, delete, download and preview",nil)],

				// - drives
				[[OCShareRole alloc] initWithType:OCShareRoleTypeEditor
						       shareTypes:OCShareTypesMaskUserShare|OCShareTypesMaskGroupShare
						     permissions:OCSharePermissionsMaskRead|OCSharePermissionsMaskUpdate|OCSharePermissionsMaskCreate|OCSharePermissionsMaskDelete
					 customizablePermissions:OCSharePermissionsMaskNone
						       locations:OCLocationTypeDrive
						      symbolName:@"pencil"
						   localizedName:OCLocalizedString(@"Editor", nil)
					    localizedDescription:OCLocalizedString(@"Upload, edit, delete, download and preview", nil)],

				// ## Manager
				// - drives
				[[OCShareRole alloc] initWithType:OCShareRoleTypeManager
						       shareTypes:OCShareTypesMaskUserShare|OCShareTypesMaskGroupShare
						     permissions:OCSharePermissionsMaskRead|OCSharePermissionsMaskUpdate|OCSharePermissionsMaskCreate|OCSharePermissionsMaskDelete|(resharingSupported ? OCSharePermissionsMaskShare : 0)
					 customizablePermissions:OCSharePermissionsMaskNone
						       locations:OCLocationTypeDrive
						      symbolName:@"person.fill"
						   localizedName:OCLocalizedString(@"Manager", nil)
					    localizedDescription:OCLocalizedString(resharingSupported ? @"Upload, edit, delete, download, preview and share" : @"Upload, edit, delete, download and preview", nil)],

				// ## Custom
				// - files
				[[OCShareRole alloc] initWithType:OCShareRoleTypeCustom
						       shareTypes:OCShareTypesMaskUserShare|OCShareTypesMaskGroupShare
						     permissions:OCSharePermissionsMaskRead|OCSharePermissionsMaskUpdate|(resharingSupported ? OCSharePermissionsMaskShare : 0)
					 customizablePermissions:OCSharePermissionsMaskUpdate|(resharingSupported ? OCSharePermissionsMaskShare : 0)
						       locations:OCLocationTypeFile
						      symbolName:@"gearshape.fill"
						   localizedName:OCLocalizedString(@"Custom", nil)
					    localizedDescription:OCLocalizedString(@"Set detailed permissions", nil)],

				// - folders, drives
				[[OCShareRole alloc] initWithType:OCShareRoleTypeCustom
						       shareTypes:OCShareTypesMaskUserShare|OCShareTypesMaskGroupShare
						     permissions:OCSharePermissionsMaskRead|OCSharePermissionsMaskUpdate|OCSharePermissionsMaskCreate|OCSharePermissionsMaskDelete|(resharingSupported ? OCSharePermissionsMaskShare : 0)
					 customizablePermissions:OCSharePermissionsMaskUpdate|OCSharePermissionsMaskCreate|OCSharePermissionsMaskDelete|(resharingSupported ? OCSharePermissionsMaskShare : 0)
						       locations:OCLocationTypeFolder|OCLocationTypeDrive
						      symbolName:@"gearshape.fill"
						   localizedName:OCLocalizedString(@"Custom", nil)
					    localizedDescription:OCLocalizedString(@"Set detailed permissions", nil)],
			]];

			// # LINKS
			if (self.useDrives)
			{
				// ## Internal
				// - files, folders
				[_shareRoles addObjectsFromArray:@[
					[[OCShareRole alloc] initWithType:OCShareRoleTypeInternal
							       shareTypes:OCShareTypesMaskLink
							     permissions:OCSharePermissionsMaskInternal
						 customizablePermissions:OCSharePermissionsMaskNone
							       locations:OCLocationTypeFile|OCLocationTypeFolder
							      symbolName:@"person.fill"
							   localizedName:OCLocalizedString(@"Invited persons", nil)
						    localizedDescription:OCLocalizedString(@"Only invited persons have access. Login required.", nil)]
				]];
			}

			[_shareRoles addObjectsFromArray:@[
				// ## Viewer
				// - files, folders
				[[OCShareRole alloc] initWithType:OCShareRoleTypeViewer
						       shareTypes:OCShareTypesMaskLink
						     permissions:OCSharePermissionsMaskRead
					 customizablePermissions:OCSharePermissionsMaskNone
						       locations:OCLocationTypeFile|OCLocationTypeFolder
						      symbolName:@"eye.fill"
						   localizedName:OCLocalizedString(@"Viewer", nil)
					    localizedDescription:OCLocalizedString(@"Recipients can view and download contents.", nil)],

				// ## Uploader
				// - folders
				[[OCShareRole alloc] initWithType:OCShareRoleTypeUploader
						       shareTypes:OCShareTypesMaskLink
						     permissions:OCSharePermissionsMaskCreate
					 customizablePermissions:OCSharePermissionsMaskNone
						       locations:OCLocationTypeFolder
						      symbolName:@"arrow.up.circle.fill"
						   localizedName:OCLocalizedString(@"Uploader", nil)
					    localizedDescription:OCLocalizedString(@"Recipients can upload but existing contents are not revealed.", nil)],

				// ## Contributor
				// - folders
				[[OCShareRole alloc] initWithType:OCShareRoleTypeContributor
						       shareTypes:OCShareTypesMaskLink
						     permissions:OCSharePermissionsMaskRead|OCSharePermissionsMaskCreate
					 customizablePermissions:OCSharePermissionsMaskNone
						       locations:OCLocationTypeFolder
						      symbolName:@"person.2"
						   localizedName:OCLocalizedString(@"Contributor", nil)
					    localizedDescription:OCLocalizedString(@"Recipients can view, download and upload contents.", nil)],

				// ## Editor
				// - files
				[[OCShareRole alloc] initWithType:OCShareRoleTypeEditor
						       shareTypes:OCShareTypesMaskLink
						     permissions:OCSharePermissionsMaskRead|OCSharePermissionsMaskUpdate
					 customizablePermissions:OCSharePermissionsMaskNone
						       locations:OCLocationTypeFile
						      symbolName:@"pencil"
						   localizedName:OCLocalizedString(@"Editor", nil)
					    localizedDescription:OCLocalizedString(@"Recipients can view, download and edit contents.", nil)],

				// - folders
				[[OCShareRole alloc] initWithType:OCShareRoleTypeEditor
						       shareTypes:OCShareTypesMaskLink
						     permissions:OCSharePermissionsMaskRead|OCSharePermissionsMaskUpdate|OCSharePermissionsMaskCreate|OCSharePermissionsMaskDelete
					 customizablePermissions:OCSharePermissionsMaskNone
						       locations:OCLocationTypeFolder
						      symbolName:@"pencil"
						   localizedName:OCLocalizedString(@"Editor", nil)
					    localizedDescription:OCLocalizedString(@"Recipients can view, download, edit, delete and upload contents.", nil)]
			]];
		}

		roles = [_shareRoles filteredArrayUsingBlock:^BOOL(OCShareRole * _Nonnull role, BOOL * _Nonnull stop) {
			return (
				// Role supports location
				((role.locations & locationType) != 0) &&

				// Role supports share type
			        ((role.shareTypes & shareTypeMask) == shareTypeMask)
			);
		}];
	}

	return (roles);
}

- (nullable OCShareRole *)matchingShareRoleForShare:(OCShare *)share
{
	NSArray<OCShareRole *> *roles = [self availableShareRolesForType:share.type location:share.itemLocation];
	OCShareRole *customRole = nil;
	OCShareRole *exactMatchingRole = nil;

	for (OCShareRole *role in roles)
	{
		if (exactMatchingRole == nil)
		{
			if (role.permissions == share.permissions)
			{
				exactMatchingRole = role;
			}
		}

		if (customRole == nil)
		{
			if ((share.permissions & role.permissions) == share.permissions)
			{
				if ([role.type isEqual:OCShareRoleTypeCustom])
				{
					customRole = role;
				}
			}
		}
	}

	if (exactMatchingRole == nil)
	{
		return (customRole);
	}

	return (exactMatchingRole);
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
	OCFileIDUniquePrefix idPart;
	BOOL isPrefix = YES;
	NSProgress *retrieveProgress = nil;

	// Try to extract a FileID from the private link
	if ((idPart = [privateLink fileIDUniquePrefixFromPrivateLinkInCore:self isPrefix:&isPrefix]) != nil)
	{
		// Try resolution from database first
		retrieveProgress = [NSProgress indeterminateProgress];

		void (^HandleRetrievalResult)(OCItem *item) = [^(OCItem *item) {
			if (item != nil) 
			{
				OCLogDebug(@"Resolved private link %@ locally - using fileID %@ - to item %@", OCLogPrivate(privateLink), OCLogPrivate(idPart), OCLogPrivate(item));
				completionHandler(nil, item);
			}
			else
			{
				OCLogDebug(@"Resolving private link %@ locally - using fileID %@ - failed: resolving via server…", OCLogPrivate(privateLink), OCLogPrivate(idPart));
				NSProgress *progress = [self _retrieveItemForPrivateLink:privateLink completionHandler:completionHandler];
				[retrieveProgress addChild:progress withPendingUnitCount:0];
			}
		} copy];

		if (isPrefix)
		{
			// ID Part is OC10-style File ID prefix
			[self.database retrieveCacheItemForFileIDUniquePrefix:idPart includingRemoved:NO completionHandler:^(OCDatabase *db, NSError *error, OCSyncAnchor syncAnchor, OCItem *item) {
				HandleRetrievalResult(item);
			}];
		}
		else
		{
			// ID Part is File ID
			[self.database retrieveCacheItemForFileID:(OCFileID)idPart completionHandler:^(OCDatabase *db, NSError *error, OCSyncAnchor syncAnchor, OCItem *item) {
				HandleRetrievalResult(item);
			}];
		}
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
	NSProgress *progress = [_connection retrievePathForPrivateLink:privateLink completionHandler:^(NSError * _Nullable error, OCLocation * _Nullable location) {
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

			if ((tracking = [self trackItemAtLocation:location trackingHandler:^(NSError * _Nullable error, OCItem * _Nullable item, BOOL isInitial) {
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
