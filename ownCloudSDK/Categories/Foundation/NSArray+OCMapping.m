//
//  NSArray+OCMapping.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 17.05.22.
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

#import "NSArray+OCMapping.h"

@implementation NSArray (OCMapping)

- (NSMutableDictionary *)dictionaryUsingMapper:(OCObjectToKeyMapper)mapper
{
	NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithCapacity:self.count];

	for (id obj in self)
	{
		id objKey;

		if ((objKey = mapper(obj)) != nil)
		{
			[dict setObject:obj forKey:objKey];
		}
	}

	return (dict);
}

- (NSMutableSet *)setUsingMapper:(OCObjectToObjectMapper)mapper;
{
	NSMutableSet *set = [[NSMutableSet alloc] initWithCapacity:self.count];

	for (id obj in self)
	{
		id objKey;

		if ((objKey = mapper(obj)) != nil)
		{
			[set addObject:objKey];
		}
	}

	return (set);
}

- (NSMutableArray *)arrayUsingMapper:(OCObjectToObjectMapper)mapper
{
	NSMutableArray *array = [[NSMutableArray alloc] initWithCapacity:self.count];

	for (id obj in self)
	{
		id objKey;

		if ((objKey = mapper(obj)) != nil)
		{
			[array addObject:objKey];
		}
	}

	return (array);
}

@end
