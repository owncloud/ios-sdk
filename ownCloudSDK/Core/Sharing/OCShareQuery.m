//
//  OCShareQuery.m
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

#import "OCShareQuery.h"
#import "OCShareQuery+Internal.h"
#import "OCLogger.h"

@interface OCShareQuery ()
{
	NSMutableDictionary <OCShareID, OCShare *> *_sharesByID;
	NSMutableArray <OCShare *> *_shares;
	NSArray <OCShare *> *_queryResults;
}

@end

@implementation OCShareQuery

#pragma mark - Convenience initializers
+ (instancetype)queryWithScope:(OCShareScope)scope item:(OCItem *)item
{
	OCShareQuery *query = [self new];

	query.scope = scope;

	switch (scope)
	{
		case OCShareScopeSharedByUser:
		case OCShareScopeSharedWithUser:
		case OCShareScopePendingCloudShares:
		case OCShareScopeAcceptedCloudShares:
			if (item != nil)
			{
				OCLogWarning(@"Item %@ provided to create share query with scope that doesn't support an item", item);
			}
		break;

		case OCShareScopeItem:
		case OCShareScopeItemWithReshares:
		case OCShareScopeSubItems:
			if (item == nil)
			{
				OCLogError(@"No item provided to create share query with a scope that requires one");
				return (nil);
			}

			query.item = item;
		break;
	}

	return (query);
}

#pragma mark - Init & Dealloc
- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_sharesByID = [NSMutableDictionary new];
		_shares = [NSMutableArray new];
	}

	return(self);
}

- (void)updateQueryResultsWithBlock:(dispatch_block_t)updateBlock
{
	[self willChangeValueForKey:@"queryResults"];
	@synchronized (self)
	{
		_queryResults = nil;

		if (updateBlock != nil)
		{
			updateBlock();
		}
	}
	[self didChangeValueForKey:@"queryResults"];

	if (_changesAvailableNotificationHandler != nil)
	{
		_changesAvailableNotificationHandler(self);
	}
}

- (void)_updateWithRetrievedShares:(NSArray <OCShare *> *)newShares forItem:(OCItem *)item scope:(OCShareScope)scope
{
	// Replace if item and scope match and differences in the objects were found
	if ((([self.item.path isEqual:item.path]) || (self.item == item)) && (scope == self.scope))
	{
		BOOL hasDifferences;

		self.lastRefreshed = [NSDate new];

		@synchronized(self)
		{
			// Compare counts
			hasDifferences = (_shares.count != newShares.count);

			// Compare share objects
			if (!hasDifferences)
			{
				for (OCShare *share in newShares)
				{
					OCShareID shareID;

					if ((shareID = share.identifier) != nil)
					{
						OCShare *existingShare;

						if ((existingShare = _sharesByID[shareID]) != nil)
						{
							// Existing and new share are not identical
							if (![existingShare isEqual:share])
							{
								hasDifferences = YES;
								break;
							}
						}
						else
						{
							// New share not found
							hasDifferences = YES;
							break;
						}
					}
				}
			}
		}

		if (hasDifferences)
		{
			[self updateQueryResultsWithBlock:^{
				[self->_sharesByID removeAllObjects];

				if (newShares.count > 0)
				{
					[self->_shares setArray:newShares];

					for (OCShare *share in newShares)
					{
						OCShareID shareID;

						if ((shareID = share.identifier) != nil)
						{
							self->_sharesByID[shareID] = share;
						}
					}
				}
				else
				{
					[self->_shares removeAllObjects];
				}
			}];
		}

		if (self.initialPopulationHandler != nil)
		{
			self.initialPopulationHandler(self);
			self.initialPopulationHandler = nil;
		}
	}
}

- (void)_updateWithAddedShare:(nullable OCShare *)addedShare updatedShare:(nullable OCShare *)updatedShare removedShare:(nullable OCShare *)removedShare
{
	if (addedShare != nil)
	{
		BOOL doAdd = NO;

		switch (_scope)
		{
			case OCShareScopePendingCloudShares:
				doAdd = (addedShare.type == OCShareTypeRemote) && (addedShare.accepted!=nil) && (!addedShare.accepted.boolValue);
			break;

			case OCShareScopeAcceptedCloudShares:
				doAdd = (addedShare.type == OCShareTypeRemote) && (addedShare.accepted!=nil) && addedShare.accepted.boolValue;
			break;

			case OCShareScopeSharedByUser:
				doAdd = YES;
			break;

			case OCShareScopeSharedWithUser:
				// Additions are "handled" by full replacements and never come from the user's own actions (mind the "shared WITH"), so don't add items here
			break;

			case OCShareScopeItem:
			case OCShareScopeItemWithReshares:
				if (_item.path != nil)
				{
					doAdd = [addedShare.itemPath isEqual:_item.path];
				}
			break;

			case OCShareScopeSubItems:
				if (_item.path != nil)
				{
					doAdd = [addedShare.itemPath hasPrefix:_item.path];
				}
			break;
		}

		if (doAdd)
		{
			[self updateQueryResultsWithBlock:^{
				[self->_shares addObject:addedShare];

				if (addedShare.identifier != nil)
				{
					self->_sharesByID[addedShare.identifier] = addedShare;
				}
			}];
		}
	}

	if (updatedShare != nil)
	{
		@synchronized(self)
		{
			if (updatedShare.identifier != nil)
			{
				OCShare *existingShare;

				if ((existingShare = _sharesByID[updatedShare.identifier]) != nil)
				{
					NSUInteger replaceLocation;

					if ((replaceLocation = [_shares indexOfObjectIdenticalTo:existingShare]) != NSNotFound)
					{
						[self updateQueryResultsWithBlock:^{
							[self->_shares replaceObjectAtIndex:replaceLocation withObject:updatedShare];
							self->_sharesByID[updatedShare.identifier] = updatedShare;
						}];
					}
				}
			}
		}
	}

	if (removedShare != nil)
	{
		@synchronized(self)
		{
			if (removedShare.identifier != nil)
			{
				if (_sharesByID[removedShare.identifier] != nil)
				{
					[self updateQueryResultsWithBlock:^{
						[self->_sharesByID removeObjectForKey:removedShare.identifier];
						[self->_shares removeObject:removedShare];
					}];
				}
			}
		}
	}
}

- (NSArray<OCShare *> *)queryResults
{
	NSArray<OCShare *> *queryResults = nil;

	@synchronized(self)
	{
		if ((queryResults = _queryResults) == nil)
		{
			_queryResults = [[NSArray alloc] initWithArray:_shares];
			queryResults = _queryResults;
		}
	}

	return (queryResults);
}

@end
