//
//  OCCoreItemList.m
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

#import "OCCoreItemList.h"

@implementation OCCoreItemList

@synthesize state = _state;

@synthesize items = _items;
@synthesize itemsByPath = _itemsByPath;
@synthesize itemPathsSet = _itemPathsSet;

@synthesize error = _error;

- (void)updateWithError:(NSError *)error items:(NSArray <OCItem *> *)items
{
	self.error = error;

	if (error != nil)
	{
		self.state = OCCoreItemListStateFailed;
	}
	else
	{
		self.state = OCCoreItemListStateSuccess;
		self.items = items;
	}
}

- (void)setItems:(NSArray<OCItem *> *)items
{
	_itemsByPath = nil;
	_itemPathsSet = nil;
	_items = items;
}

- (NSMutableDictionary<OCPath,OCItem *> *)itemsByPath
{
	if (_itemsByPath == nil)
	{
		_itemsByPath = [NSMutableDictionary new];

		for (OCItem *item in self.items)
		{
			if (item.path != nil)
			{
				_itemsByPath[item.path] = item;
			}
		}
	}

	return (_itemsByPath);
}

- (NSSet<OCPath> *)itemPathsSet
{
	if (_itemPathsSet == nil)
	{
		NSArray<OCPath> *itemPaths;

		if ((itemPaths = [self.itemsByPath allKeys]) != nil)
		{
			_itemPathsSet = [[NSSet alloc] initWithArray:itemPaths];
		}
		else
		{
			_itemPathsSet = [NSSet new];
		}
	}

	return (_itemPathsSet);
}

@end
