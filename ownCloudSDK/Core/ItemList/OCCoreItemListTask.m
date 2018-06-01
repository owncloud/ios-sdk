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

		[_core.vault.database retrieveCacheItemsAtPath:self.path completionHandler:^(OCDatabase *db, NSError *error, NSArray<OCItem *> *items) {
			[_core queueBlock:^{ // Update inside the core's serial queue to make sure we never change the data while the core is also working on it
				[_cachedSet updateWithError:error items:items];

				if ((_cachedSet.state == OCCoreItemListStateSuccess) || (_cachedSet.state == OCCoreItemListStateFailed))
				{
					self.changeHandler(_core, self);
				}

				[_core endActivity:@"update cache set"];
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

		[_core queueConnectivityBlock:^{
			[_core.connection retrieveItemListAtPath:self.path completionHandler:^(NSError *error, NSArray<OCItem *> *items) {
				[_core queueBlock:^{ // Update inside the core's serial queue to make sure we never change the data while the core is also working on it
					[_retrievedSet updateWithError:error items:items];

					if ((_retrievedSet.state == OCCoreItemListStateSuccess) || (_retrievedSet.state == OCCoreItemListStateFailed))
					{
						self.changeHandler(_core, self);
					}

					[_core endActivity:@"update retrieved set"];
				}];
			}];
		}];
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
