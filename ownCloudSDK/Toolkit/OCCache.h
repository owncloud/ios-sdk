//
//  OCCache.h
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

#import <Foundation/Foundation.h>

#define OCCacheLimitNone 0

@interface OCCache<K,V> : NSObject
{
	NSMutableDictionary<K, V> *_valuesByKey;
	NSMutableArray<K> *_recentlyUsedKeys;

	NSMutableDictionary<K, NSNumber *> *_costByKey;

	NSUInteger _currentCost;
	NSUInteger _totalCostLimit;

	NSUInteger _countLimit;
}

@property(assign) NSUInteger countLimit;	//!< Impose limit on the maximum number of key-value pairs. If the limit is exceeded, least recently used key-value pairs are removed first. A value of OCCacheLimitNone (default) means no limit.
@property(assign) NSUInteger totalCostLimit;	//!< Impose limit on the maximum cost of key-value pairs. If the limit is exceeded, least recently used key-value pairs are removed first. A value of OCCacheLimitNone (default) means no limit.

#pragma mark - Retrieval
- (V)objectForKey:(K)key;

#pragma mark - Modification
- (void)setObject:(V)obj forKey:(K)key;

- (void)setObject:(V)obj forKey:(K)key cost:(NSUInteger)cost;
- (void)setCost:(NSUInteger)cost forKey:(K)key;

- (void)removeObjectForKey:(K)key;

@end
