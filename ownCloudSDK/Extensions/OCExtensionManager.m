//
//  OCExtensionManager.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 15.08.18.
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

#import "OCExtensionManager.h"

@implementation OCExtensionManager

@dynamic extensions;

+ (OCExtensionManager *)sharedExtensionManager
{
	static dispatch_once_t onceToken;
	static OCExtensionManager *sharedExtensionManager;

	dispatch_once(&onceToken, ^{
		sharedExtensionManager = [OCExtensionManager new];
	});

	return (sharedExtensionManager);
}

#pragma mark - Init & Dealloc
- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_extensions = [NSMutableArray new];
	}

	return(self);
}

#pragma mark - Extension management
- (NSArray<OCExtension *> *)extensions
{
	@synchronized(self)
	{
		if (_cachedExtensions == nil)
		{
			_cachedExtensions = [[NSArray alloc] initWithArray:_extensions];
		}

		return (_cachedExtensions);
	}
}

- (void)addExtension:(OCExtension *)extension
{
	@synchronized(self)
	{
		_cachedExtensions = nil;

		[_extensions addObject:extension];
	}
}

- (void)removeExtension:(OCExtension *)extension
{
	@synchronized(self)
	{
		_cachedExtensions = nil;

		[_extensions removeObjectIdenticalTo:extension];
	}
}

#pragma mark - Matching
- (NSArray <OCExtensionMatch *> *)provideExtensionsForContext:(OCExtensionContext *)context error:(NSError **)outError
{
	NSMutableArray <OCExtensionMatch *> *matches = nil;

	@synchronized(self)
	{
		for (OCExtension *extension in _extensions)
		{
			OCExtensionPriority priority;

			if ((priority = [extension matchesContext:context]) != OCExtensionPriorityNoMatch)
			{
				OCExtensionMatch *match;

				if ((match = [[OCExtensionMatch alloc] initWithExtension:extension priority:priority]) != nil)
				{
					if (matches == nil) {  matches = [NSMutableArray new]; }
					[matches addObject:match];
				}
			}
		}

		// Make matches with higher priority rank first
		[matches sortedArrayUsingDescriptors:@[ [NSSortDescriptor sortDescriptorWithKey:@"priority" ascending:NO]]];
	}

	return (matches);
}

- (void)provideExtensionsForContext:(OCExtensionContext *)context completionHandler:(void(^)(NSError *error, OCExtensionContext *context, NSArray <OCExtensionMatch *> *))completionHandler
{
	dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
		NSError *error = nil;
		NSArray <OCExtensionMatch *> *matches = nil;

		matches = [self provideExtensionsForContext:context error:&error];

		completionHandler(error, context, matches);
	});
}

@end
