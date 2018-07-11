//
//  OCMockManager.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 11.07.18.
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

#import "OCMockManager.h"

@implementation OCMockManager

+ (OCMockManager *)sharedMockManager
{
	static dispatch_once_t onceToken;
	static OCMockManager *sharedMockManager;

	dispatch_once(&onceToken, ^{
		sharedMockManager = [OCMockManager new];
	});

	return (sharedMockManager);
}

#pragma mark - Init & Dealloc
- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_mockBlocksByLocation = [NSMutableDictionary new];
	}

	return(self);
}

- (void)addMockingBlocks:(NSDictionary <OCMockLocation, id> *)mockingBlocks
{
	if (mockingBlocks != nil)
	{
		@synchronized(self)
		{
			[_mockBlocksByLocation addEntriesFromDictionary:mockingBlocks];
		}
	}
}

- (void)removeMockingBlockAtLocation:(OCMockLocation)mockLocation
{
	if (mockLocation != nil)
	{
		@synchronized(self)
		{
			[_mockBlocksByLocation removeObjectForKey:mockLocation];
		}
	}
}

- (void)removeMockingBlocksForClass:(Class)aClass
{
	NSString *className = NSStringFromClass(aClass);

	if (className != nil)
	{
		NSMutableArray <OCMockLocation> *removalLocations = [NSMutableArray new];
		NSString *classNamePrefix = [className stringByAppendingString:@"."];

		@synchronized(self)
		{
			for (OCMockLocation mockLocation in _mockBlocksByLocation)
			{
				if ([mockLocation hasPrefix:classNamePrefix])
				{
					[removalLocations addObject:mockLocation];
				}
			}

			[_mockBlocksByLocation removeObjectsForKeys:removalLocations];
		}
	}
}

- (id)mockingBlockForLocation:(OCMockLocation)mockLocation
{
	if (mockLocation == nil) { return(nil); }

	@synchronized(self)
	{
		return (_mockBlocksByLocation[mockLocation]);
	}
}


@end
