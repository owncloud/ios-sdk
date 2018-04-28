//
//  OCCache.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 27.04.18.
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

#import <UIKit/UIKit.h>
#import "OCCache.h"

@implementation OCCache

@synthesize countLimit = _countLimit;
@synthesize totalCostLimit = _totalCostLimit;

#pragma mark - Init & Dealloc
- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_valuesByKey = [NSMutableDictionary new];
		_recentlyUsedKeys = [NSMutableArray new];
		_costByKey = [NSMutableDictionary new];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_receivedMemoryWarning:) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
	}

	return(self);
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
}

#pragma mark - Retrieval
- (id)objectForKey:(id)key
{
	if (key == nil) { return(nil); }

	@synchronized(self)
	{
		id object;

		if ((object = [_valuesByKey objectForKey:key]) != nil)
		{
			[_recentlyUsedKeys removeObject:key];
			[_recentlyUsedKeys addObject:key];
		}

		return (object);
	}
}

#pragma mark - Modification
- (void)setObject:(id)obj forKey:(id)key
{
	if (key == nil) { return; }

	@synchronized(self)
	{
		[_recentlyUsedKeys removeObject:key];
		[_recentlyUsedKeys addObject:key];

		[_valuesByKey setObject:obj forKey:key];

		[self _cleanCache];
	}
}

- (void)setObject:(id)obj forKey:(id)key cost:(NSUInteger)cost
{
	if (key == nil) { return; }

	@synchronized(self)
	{
		NSNumber *previousCost;

		[_recentlyUsedKeys removeObject:key];
		[_recentlyUsedKeys addObject:key];

		[_valuesByKey setObject:obj forKey:key];

		_currentCost += cost;

		if ((previousCost = [_costByKey objectForKey:key]) != nil)
		{
			_currentCost -= [previousCost unsignedIntegerValue];
		}

		[_costByKey setObject:@(cost) forKey:key];

		[self _cleanCache];
	}
}

- (void)setCost:(NSUInteger)cost forKey:(id)key
{
	if (key == nil) { return; }

	@synchronized(self)
	{
		NSNumber *previousCost;

		_currentCost += cost;

		if ((previousCost = [_costByKey objectForKey:key]) != nil)
		{
			_currentCost -= [previousCost unsignedIntegerValue];
		}

		[_costByKey setObject:@(cost) forKey:key];

		[self _cleanCache];
	}
}

- (void)removeObjectForKey:(id)key
{
	@synchronized(self)
	{
		[self _removeObjectForKey:key];
	}
}

- (void)_removeObjectForKey:(id)key
{
	NSNumber *previousCost;

	if (key == nil) { return; }

	if ((previousCost = [_costByKey objectForKey:key]) != nil)
	{
		_currentCost -= [previousCost unsignedIntegerValue];

		[_costByKey removeObjectForKey:key];
	}

	[_valuesByKey removeObjectForKey:key];
	[_recentlyUsedKeys removeObject:key];
}

#pragma mark - Cache Cleaning
- (void)_receivedMemoryWarning:(NSNotification *)notification
{
	// Received memory warning - release the maximum amount of memory possible
	@synchronized(self)
	{
		[_valuesByKey removeAllObjects];
		[_costByKey removeAllObjects];
		[_recentlyUsedKeys removeAllObjects];

		_currentCost = 0;
	}
}

- (void)_cleanCache
{
	if ((_countLimit != OCCacheLimitNone) || (_totalCostLimit != OCCacheLimitNone))
	{
		NSUInteger currentCount = _valuesByKey.count;

		while (((_countLimit != OCCacheLimitNone) && (currentCount > _countLimit)) || 	    // Count limit
		       ((_totalCostLimit != OCCacheLimitNone) && (_currentCost > _totalCostLimit))) // Cost limit
		{
			id leastRecentlyUsedKey;

			if ((leastRecentlyUsedKey = _recentlyUsedKeys.firstObject) != nil)
			{
				[self _removeObjectForKey:leastRecentlyUsedKey];
				currentCount--;
			}
			else
			{
				break;
			}
		};
	}
}

@end
