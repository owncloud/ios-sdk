//
//  NSArray+OCFiltering.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 04.04.22.
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

#import "NSArray+OCFiltering.h"

@implementation NSArray (OCFiltering)

- (NSArray *)filteredArrayUsingBlock:(BOOL(^)(id object, BOOL *stop))filter
{
	NSMutableIndexSet *selectedIndexSet = [NSMutableIndexSet new];

	[self enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
		if (filter(obj, stop))
		{
			[selectedIndexSet addIndex:idx];
		}
	}];

	return ([self objectsAtIndexes:selectedIndexSet]);
}

- (nullable id)firstObjectMatching:(BOOL(^)(id object))matcher
{
	for (id object in self)
	{
		if (matcher(object))
		{
			return (object);
		}
	}

	return (nil);
}

@end
