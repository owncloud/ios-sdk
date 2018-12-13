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
#import "NSString+OCParentPath.h"
#import "OCLogger.h"
#import "NSError+OCDAVError.h"
#import "OCCore+ConnectionStatus.h"

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

- (instancetype)initWithCore:(OCCore *)core path:(OCPath)path
{
	if ((self = [self init]) != nil)
	{
		self.core = core;
		self.path = path;
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

		[_core.vault.database retrieveCacheItemsAtPath:self.path itemOnly:NO completionHandler:^(OCDatabase *db, NSError *error, OCSyncAnchor syncAnchor, NSArray<OCItem *> *items) {
			[self->_core queueBlock:^{ // Update inside the core's serial queue to make sure we never change the data while the core is also working on it
				self->_syncAnchorAtStart = [self->_core retrieveLatestSyncAnchorWithError:NULL];

				[self->_cachedSet updateWithError:error items:items];

				if ((self->_cachedSet.state == OCCoreItemListStateSuccess) || (self->_cachedSet.state == OCCoreItemListStateFailed))
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

				[self->_core endActivity:@"update cache set"];
			}];
		}];
	}
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
				[self->_core.connection retrieveItemListAtPath:self.path depth:1 completionHandler:^(NSError *error, NSArray<OCItem *> *items) {
					[self->_core queueBlock:^{ // Update inside the core's serial queue to make sure we never change the data while the core is also working on it
						// Check for maintenance mode errors
						if ((error==nil) || (error.isDAVException))
						{
							if (error.davError == OCDAVErrorServiceUnavailable)
							{
								[self->_core reportReponseIndicatingMaintenanceMode];
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

								if ((rootItem = self->_retrievedSet.itemsByPath[self.path]) != nil)
								{
									if ((rootItem.type == OCItemTypeCollection) && (items.count > 1))
									{
										for (OCItem *item in items)
										{
											if (item != rootItem)
											{
												item.parentFileID = rootItem.fileID;
											}
										}
									}

									if (rootItem.parentFileID == nil)
									{
										rootItem.parentFileID = parentDirectoryItem.fileID;
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
					}];
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

@end
