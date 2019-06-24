//
//  OCCoreItemListTask.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 02.04.18.
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

#import "OCCoreItemListTask.h"
#import "OCCore.h"
#import "OCCore+Internal.h"
#import "OCCore+SyncEngine.h"
#import "NSString+OCPath.h"
#import "OCLogger.h"
#import "NSError+OCDAVError.h"
#import "OCCore+ConnectionStatus.h"
#import "OCCore+ItemList.h"
#import "OCMacros.h"
#import "NSProgress+OCExtensions.h"
#import "OCCoreDirectoryUpdateJob.h"

@interface OCCoreItemListTask ()
{
	OCActivityIdentifier _activityIdentifier;
}

@end

@implementation OCCoreItemListTask

#pragma mark - Init & Dealloc
- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_cachedSet = [OCCoreItemList new];
		_retrievedSet = [OCCoreItemList new];
	}

	return(self);
}

- (instancetype)initWithCore:(OCCore *)core path:(OCPath)path updateJob:(OCCoreDirectoryUpdateJob *)updateJob
{
	if ((self = [self init]) != nil)
	{
		self.core = core;
		self.path = path;
		self.updateJob = updateJob;
	}

	return (self);
}

- (void)update
{
	[_core queueBlock:^{ // Update inside the core's serial queue to make sure we never change the data while the core is also working on it
		[self _update];
	}];
}

- (void)forceUpdateCacheSet
{
	[_core queueBlock:^{
		[self _updateCacheSet];
	}];
}

- (void)_updateCacheSet
{
	// Retrieve items from cache
	if (_core != nil)
	{
		[_core beginActivity:@"update cache set"];

		_cachedSet.state = OCCoreItemListStateStarted;

		[self _cacheUpdateInline:NO notifyChange:YES completionHandler:^{
			[self->_core endActivity:@"update cache set"];
		}];
	}
}

- (void)_cacheUpdateInline:(BOOL)doInline notifyChange:(BOOL)notifyChange completionHandler:(dispatch_block_t)completionHandler
{
	[_core.vault.database retrieveCacheItemsAtPath:self.path itemOnly:NO completionHandler:^(OCDatabase *db, NSError *error, OCSyncAnchor syncAnchor, NSArray<OCItem *> *items) {
		OCSyncAnchor latestAnchorAtRetrieval = [self->_core retrieveLatestSyncAnchorWithError:NULL];

		dispatch_block_t workBlock = ^{ // Update inside the core's serial queue to make sure we never change the data while the core is also working on it
			self->_syncAnchorAtStart = latestAnchorAtRetrieval;

			[self->_cachedSet updateWithError:error items:items];

			if (notifyChange && ((self->_cachedSet.state == OCCoreItemListStateSuccess) || (self->_cachedSet.state == OCCoreItemListStateFailed)))
			{
				if (self.changeHandler != nil)
				{
					self.changeHandler(self->_core, self);
				}
				else
				{
					OCLogWarning(@"OCCoreItemListTask: no changeHandler specified");
				}
			}

			completionHandler();
		};

		if (doInline)
		{
			workBlock();
		}
		else
		{
			[self->_core queueBlock:workBlock];
		}
	}];
}

- (void)forceUpdateRetrievedSet
{
	[_core queueBlock:^{
		[self _updateRetrievedSet];
	}];
}

- (void)_updateRetrievedSet
{
	// Request item list from server
	if (_core != nil)
	{
		[_core beginActivity:@"update retrieved set"];

		_retrievedSet.state = OCCoreItemListStateStarted;

		void (^RetrieveItems)(OCItem *parentDirectoryItem) = ^(OCItem *parentDirectoryItem){
			[self->_core queueConnectivityBlock:^{
				[self->_core queueRequestJob:^(dispatch_block_t completionHandler) {
					NSProgress *retrievalProgress;

					retrievalProgress = [self->_core.connection retrieveItemListAtPath:self.path depth:1 options:((self.groupID != nil) ? @{ OCConnectionOptionGroupIDKey : self.groupID } : nil) completionHandler:^(NSError *error, NSArray<OCItem *> *items) {
						[self->_core queueBlock:^{
							// Update inside the core's serial queue to make sure we never change the data while the core is also working on it
							OCSyncAnchor latestSyncAnchor = [self.core retrieveLatestSyncAnchorWithError:NULL];

							if ((latestSyncAnchor != nil) && (![latestSyncAnchor isEqualToNumber:self.syncAnchorAtStart]))
							{
								OCTLogDebug(@[@"ItemListTask"], @"Sync anchor changed before task finished: latestSyncAnchor=%@ != task.syncAnchorAtStart=%@, path=%@ -> updating inline", latestSyncAnchor, self.syncAnchorAtStart, self.path);

								// Cache set is outdated - update now to avoid unnecessary requests
								OCSyncExec(inlineUpdate, {
									[self _cacheUpdateInline:YES notifyChange:NO completionHandler:^{
										OCSyncExecDone(inlineUpdate);
									}];
								});
							}

							// Check for maintenance mode errors
							if ((error==nil) || (error.isDAVException))
							{
								if (error.davError == OCDAVErrorServiceUnavailable)
								{
									[self->_core reportResponseIndicatingMaintenanceMode];
								}
							}

							// Update
							[self->_retrievedSet updateWithError:error items:items];

							if (self->_retrievedSet.state == OCCoreItemListStateSuccess)
							{
								// Update all items with root item
								if (self.path != nil)
								{
									OCItem *rootItem;
									OCItem *cachedRootItem;

									if ((rootItem = self->_retrievedSet.itemsByPath[self.path]) != nil)
									{
										if ((cachedRootItem = self->_cachedSet.itemsByFileID[rootItem.fileID]) == nil)
										{
											cachedRootItem = self->_cachedSet.itemsByPath[self.path];
										}

										if (cachedRootItem != nil)
										{
											rootItem.localID = cachedRootItem.localID;
										}

										if ((rootItem.type == OCItemTypeCollection) && (items.count > 1))
										{
											for (OCItem *item in items)
											{
												if (item != rootItem)
												{
													item.parentFileID = rootItem.fileID;
													item.parentLocalID = rootItem.localID;
												}
											}
										}

										if (rootItem.parentFileID == nil)
										{
											rootItem.parentFileID = parentDirectoryItem.fileID;
										}

										if (parentDirectoryItem.parentLocalID == nil)
										{
											rootItem.parentLocalID = parentDirectoryItem.localID;
										}
									}
								}

								self.changeHandler(self->_core, self);
							}

							if (self->_retrievedSet.state == OCCoreItemListStateFailed)
							{
								self.changeHandler(self->_core, self);
							}

							[self->_core endActivity:@"update retrieved set"];

							completionHandler();
						}];
					}];

					if (retrievalProgress != nil)
					{
						[self.core.activityManager update:[[OCActivityUpdate updatingActivityFor:self] withProgress:retrievalProgress]];
					}
				}];
			}];
		};

		if ([self.path isEqual:@"/"])
		{
			RetrieveItems(nil);
		}
		else
		{
			[_core queueBlock:^{ // Update inside the core's serial queue to make sure we never change the data while the core is also working on it
				__block OCItem *parentItem = nil;
				__block NSError *dbError = nil;
				NSArray <OCItem *> *items = nil;

				// Retrieve parent item from cache.
				items = [self->_core.vault.database retrieveCacheItemsSyncAtPath:[self.path parentPath] itemOnly:YES error:&dbError syncAnchor:NULL];

				if (dbError != nil)
				{
					[self->_retrievedSet updateWithError:dbError items:nil];
				}
				else
				{
					parentItem = items.firstObject;

					if (parentItem == nil)
					{
						// No parent item found - and not the root folder. If the SDK is used to discover directories and request their
						// contents after discovery, this should never happen. However, for direct requests to directories, this may happen.
						// In that case, the parent directory(s) need to be requested first, so that their parent item(s) are known and in
						// the database.
						OCQuery *parentDirectoryQuery = [OCQuery queryForPath:[self.path parentPath]];

						parentDirectoryQuery.changesAvailableNotificationHandler = ^(OCQuery *query) {
							// Remove query once the response from the server arrived
							if (query.state == OCQueryStateIdle)
							{
								// Use root item as parent item
								RetrieveItems(query.rootItem);

								// Remove query from core
								[self->_core stopQuery:query];
							}
						};

						[self->_core startQuery:parentDirectoryQuery];
					}
					else
					{
						// Parent item found in the database
						RetrieveItems(parentItem);
					}
				}
			}];
		}
	}
}

- (void)_update
{
	[_core beginActivity:@"update unstarted sets"];

	if (_cachedSet.state != OCCoreItemListStateStarted)
	{
		// Retrieve items from cache
		[self _updateCacheSet];
	}

	if (_retrievedSet.state != OCCoreItemListStateStarted)
	{
		// Request item list from server
		[self _updateRetrievedSet];
	}

	[_core endActivity:@"update unstarted sets"];
}

#pragma mark - Activity source
- (OCActivityIdentifier)activityIdentifier
{
	if (_activityIdentifier == nil)
	{
		_activityIdentifier = [@"ItemListTask:" stringByAppendingString:NSUUID.UUID.UUIDString];
	}

	return (_activityIdentifier);
}

- (OCActivity *)provideActivity
{
	OCActivity *activity = [OCActivity withIdentifier:self.activityIdentifier description:[NSString stringWithFormat:@"Retrieving items for %@", self.path] statusMessage:nil ranking:0];

	activity.progress = NSProgress.indeterminateProgress;

	return (activity);
}

@end
