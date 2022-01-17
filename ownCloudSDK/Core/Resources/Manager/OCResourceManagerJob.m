//
//  OCResourceManagerJob.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 04.01.22.
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

#import "OCResourceManagerJob.h"
#import "OCResourceManager.h"
#import "OCResourceRequest.h"
#import "OCResourceSource.h"
#import "OCLogger.h"

@implementation OCResourceManagerJob

- (instancetype)initWithPrimaryRequest:(OCResourceRequest *)primaryRequest forManager:(OCResourceManager *)manager;
{
	if ((self = [super init]) != nil)
	{
		_primaryRequest = primaryRequest;
		_manager = manager;

		_requests = [NSHashTable weakObjectsHashTable];
		_sources = [NSMutableArray new];

		[self addRequest:primaryRequest];
	}

	return (self);
}

- (OCResourceRequest *)primaryRequest
{
	@synchronized(self)
	{
		if (_primaryRequest == nil)
		{
			_primaryRequest = [[_requests allObjects] firstObject];
		}

		return (_primaryRequest);
	}
}

- (void)_computeMinimumQuality
{
	OCResourceQuality minimumQuality = OCResourceQualityMaximum;

	for (OCResourceRequest *request in _requests)
	{
		if (request.minimumQuality < minimumQuality)
		{
			minimumQuality = request.minimumQuality;
		}
	}

	_minimumQuality = minimumQuality;
}

- (void)addRequest:(OCResourceRequest *)request
{
	@synchronized(self)
	{
		request.job = self;
		[_requests addObject:request];

		if (request.lifetime != OCResourceRequestLifetimeUntilDeallocation)
		{
			if (_managedRequests == nil)
			{
				_managedRequests = [NSMutableArray new];
			}

			[_managedRequests addObject:request];
		}

		[self _computeMinimumQuality];
	}
}

- (void)replacePrimaryRequestWith:(OCResourceRequest *)request
{
	@synchronized(self)
	{
		[self addRequest:request];

		_primaryRequest = request;

		_state = OCResourceManagerJobStateNew;

		_sources = nil;
		_sourcesCursorPosition = nil;

		_seed++;
	}

	[self _callCancellationHandlerAndResetIt];
}

- (void)setCancelled:(BOOL)cancelled
{
	if (cancelled != _cancelled)
	{
		_cancelled = cancelled;

		if (cancelled)
		{
			[self _callCancellationHandlerAndResetIt];
		}
	}
}

- (void)_callCancellationHandlerAndResetIt
{
	OCResourceManagerJobCancellationHandler cancellationHandler = nil;

	@synchronized(self)
	{
		cancellationHandler = _cancellationHandler;
		_cancellationHandler = nil;
	}

	if (cancellationHandler != nil)
	{
		cancellationHandler();
	}
}

- (void)removeRequest:(OCResourceRequest *)request
{
	BOOL cancelled = YES;

	@synchronized(self)
	{
		[_requests removeObject:request];
		[_managedRequests removeObject:request];

		for (OCResourceRequest *request in _requests)
		{
			if ((request != nil) && !request.cancelled)
			{
				cancelled = NO;
				break;
			}
		}

		[self _computeMinimumQuality];
	}

	if (cancelled)
	{
		self.cancelled = YES;
	}
}

- (void)removeRequestsWithLifetime:(OCResourceRequestLifetime)lifetime
{
	@synchronized(self)
	{
		if (_managedRequests != nil)
		{
			NSMutableIndexSet *removeIndexes = nil;
			NSUInteger idx = 0;

			for (OCResourceRequest *request in _managedRequests)
			{
				if (request.lifetime == lifetime)
				{
					if ((removeIndexes = [NSMutableIndexSet new]) != nil)
					{
						[removeIndexes addIndex:idx];
					}
				}

				idx++;
			}

			if (removeIndexes != nil)
			{
				[_managedRequests removeObjectsAtIndexes:removeIndexes];
			}
		}
	}
}

@end
