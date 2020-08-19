//
//  NSArray+OCSegmentedProcessing.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 03.08.20.
//  Copyright © 2020 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2020, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "NSArray+OCSegmentedProcessing.h"

@implementation NSArray (OCSegmentedProcessing)

- (void)enumerateObjectsWithTransformer:(id _Nullable(^)(id obj, NSUInteger idx, BOOL *stop))transformer process:(void(^)(NSArray *transformedObjects, NSUInteger processed, NSUInteger total, BOOL *stop))process segmentSize:(NSUInteger)segmentSize
{
	NSUInteger total = self.count;
	NSMutableArray *transformedObjects = [[NSMutableArray alloc] initWithCapacity:((segmentSize > total) ? total : segmentSize)];

	void (^processTransformedObjects)(NSUInteger idx, BOOL *stop) = ^(NSUInteger idx, BOOL *stop) {
		@autoreleasepool {
			// Process transformed objects
			process(transformedObjects, idx, total, stop);

			// Drain previously transformed objects
			[transformedObjects removeAllObjects];
		}
	};

	// Transform
	[self enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
		id transformedObject;

		if ((transformedObject = transformer(obj, idx, stop)) != nil)
		{
			[transformedObjects addObject:transformedObject];
		}

		// Process segment
		if (((idx+1) % segmentSize) == 0)
		{
			processTransformedObjects(idx+1, stop);
		}
	}];

	if (transformedObjects.count > 0)
	{
		// Process remaining objects
		BOOL stop = NO;
		processTransformedObjects(total, &stop);
	}

	transformedObjects = nil;
}

@end
