//
//  OCResourceManager.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 21.12.21.
//  Copyright © 2021 ownCloud GmbH. All rights reserved.
//

#import "OCResourceManager.h"
#import "OCCache.h"
#import "OCResourceManagerJob.h"
#import "OCResourceSourceStorage.h"
#import "OCLogger.h"

@interface OCResourceManager ()
{
	OCCache *_cache;

	NSMutableDictionary<OCResourceType, NSMutableArray<OCResourceSource *> *> *_sourcesByType;
	NSMutableArray<OCResourceManagerJob *> *_jobs;

	dispatch_queue_t _queue;
	BOOL _needsScheduling;
}
@end

@implementation OCResourceManager

- (instancetype)initWithStorage:(id<OCResourceStorage>)storage
{
	if ((self = [super init]) != nil)
	{
		_storage = storage;
		_sourcesByType = [NSMutableDictionary new];
		_jobs = [NSMutableArray new];

		_cache = [[OCCache alloc] init];

		_queue = dispatch_queue_create("OCResourceManager", DISPATCH_QUEUE_SERIAL);

		[self addSource:[OCResourceSourceStorage new]];
	}

	return (self);
}

- (void)setMemoryConfiguration:(OCCoreMemoryConfiguration)memoryConfiguration
{
	_memoryConfiguration = memoryConfiguration;

	switch (_memoryConfiguration)
	{
		case OCCoreMemoryConfigurationDefault:
			_cache.countLimit = OCCacheLimitNone;
		break;

		case OCCoreMemoryConfigurationMinimum:
			_cache.countLimit = 1;
		break;
	}
}

#pragma mark - Sources
- (void)addSource:(OCResourceSource *)source
{
	@synchronized(_sourcesByType)
	{
		NSMutableArray<OCResourceSource *> *sources;

		source.manager = self;

		if ((sources = _sourcesByType[source.type]) == nil)
		{
			sources = [NSMutableArray new];
			_sourcesByType[source.type] = sources;

			// For any sources not of type any, add all sources for any upon initialization
			if (![source.type isEqual:OCResourceTypeAny])
			{
				NSMutableArray<OCResourceSource *> *anySources;

				if ((anySources = _sourcesByType[OCResourceTypeAny]) != nil)
				{
					[sources addObjectsFromArray:anySources];
				}
			}
		}

		if ([source.type isEqual:OCResourceTypeAny])
		{
			// Add sources of type any to all source types
			for (OCResourceType type in _sourcesByType)
			{
				if (![type isEqual:OCResourceTypeAny])
				{
					[_sourcesByType[type] addObject:source];
					[self _sortSourcesForType:type];
				}
			}
		}

		[sources addObject:source];

		if (![source.type isEqual:OCResourceTypeAny]) // Sources for type any need no sorting as they are not used directly
		{
			[self _sortSourcesForType:source.type];
		}
	}
}

- (void)_sortSourcesForType:(OCResourceType)type
{
	[_sourcesByType[type] sortUsingComparator:^NSComparisonResult(OCResourceSource * _Nonnull source1, OCResourceSource * _Nonnull source2) {
		OCResourceSourcePriority source1Priority = [source1 priorityForType:type];
		OCResourceSourcePriority source2Priority = [source2 priorityForType:type];

		if (source1Priority == source2Priority)
		{
			return (NSOrderedSame);
		}

		return ((source1Priority > source2Priority) ? NSOrderedAscending : NSOrderedDescending); // Rank highest priorities first
	}];
}

- (void)removeSource:(OCResourceSource *)source
{
	@synchronized(_sourcesByType)
	{
		NSMutableArray<OCResourceSource *> *sources;

		if ((sources = _sourcesByType[source.type]) != nil)
		{
			[sources removeObject:source];
		}

		if ([source.type isEqual:OCResourceTypeAny])
		{
			for (OCResourceType type in _sourcesByType)
			{
				if (![type isEqual:OCResourceTypeAny])
				{
					[_sourcesByType[type] removeObject:source];
				}
			}
		}

		source.manager = nil;
	}
}

#pragma mark - Requests
- (void)startRequest:(OCResourceRequest *)request
{
	dispatch_async(_queue, ^{
		[self _startRequest:request];
	});
}

- (void)_startRequest:(OCResourceRequest *)request // RUNS ON _QUEUE
{
	BOOL isNewRequest = YES;

	for (OCResourceManagerJob *job in _jobs)
	{
		OCResourceRequest *otherRequest;

		if ((otherRequest = job.primaryRequest) != nil)
		{
			OCResourceRequestRelation relation = [request relationWithRequest:otherRequest];

			switch (relation)
			{
				case OCResourceRequestRelationDistinct:
				break;

				case OCResourceRequestRelationGroupWith:
					isNewRequest = NO;
					[job addRequest:request];
				break;

				case OCResourceRequestRelationReplace:
					isNewRequest = NO;
					[job replacePrimaryRequestWith:request];
				break;
			}
		}

		if (!isNewRequest) { break; }
	}

	if (isNewRequest)
	{
		// Add new job for request
		OCResourceManagerJob *job;

		if ((job = [[OCResourceManagerJob alloc] initWithPrimaryRequest:request forManager:self]) != nil)
		{
			[_jobs addObject:job];
		}

		[self setNeedsScheduling];
	}
}

- (void)stopRequest:(OCResourceRequest *)request
{
	dispatch_async(_queue, ^{
		request.cancelled = YES;
		[self _stopRequest:request];
	});
}

- (void)_stopRequest:(OCResourceRequest *)request // RUNS ON _QUEUE
{
	[request.job removeRequest:request];

	[self setNeedsScheduling];
}

#pragma mark - Scheduling
- (void)setNeedsScheduling
{
	BOOL doSchedule = NO;

	@synchronized(self)
	{
		if (!_needsScheduling)
		{
			_needsScheduling = YES;
			doSchedule = YES;
		}
	}

	if (doSchedule)
	{
		dispatch_async(_queue, ^{
			@synchronized(self)
			{
				self->_needsScheduling = NO;
			}

			[self schedule];
		});
	}
}

- (void)schedule // RUNS ON _QUEUE
{
	NSMutableArray<OCResourceManagerJob *> *removeJobs = nil;

	for (OCResourceManagerJob *job in _jobs)
	{
		BOOL removeJob = NO;

		OCResourceRequest *primaryRequest;

		if (((primaryRequest = job.primaryRequest) != nil) && !job.cancelled)
		{
			if (job.state == OCResourceManagerJobStateNew)
			{
				OCResourceType resourceType;

				// Copy pre-sorted array of sources for this resourse type
				if ((resourceType = primaryRequest.type) != nil)
				{
					job.sources = [_sourcesByType[resourceType] copy];
				}

				// Start going through sources
				job.state = OCResourceManagerJobStateInProgress;
			}

			if (job.state == OCResourceManagerJobStateInProgress)
			{
				if (job.sources.count == 0)
				{
					// Jobs without sources are immediately "complete"
					job.state = OCResourceManagerJobStateComplete;
				}
				else
				{
					// Start iterating
					if (job.sourcesCursorPosition == nil)
					{
						[self _queryNextSourceForJob:job];
					}
				}
			}

			if (job.state == OCResourceManagerJobStateComplete)
			{
				// Job complete

				// Store in database
				if ((job.latestResource != nil) &&
				    (job.latestResource.quality >= OCResourceQualityNormal) && // require "normal" as minimum quality
				    (job.lastStoredResource != job.latestResource)) // ensure we don't save the same resource instance twice
				{
					OCResource *resource;

					if ((resource = job.latestResource) != nil)
					{
						job.lastStoredResource = resource;

						if (![resource.originSourceIdentifier isEqual:OCResourceSourceIdentifierStorage]) // Avoid writing back what was also retrieved from storage
						{
							[self storeResource:job.latestResource completionHandler:^(NSError * _Nullable error) {
								if (error != nil)
								{
									OCTLogError(@[@"ResMan"], @"Error %@ storing resource %@", error, resource);
								}
							}];
						}
					}
				}

				// Remove "single-run" requests
				[job removeRequestsWithLifetime:OCResourceRequestLifetimeSingleRun];

				// Remove "empty" jobs
				if (job.primaryRequest == nil)
				{
					removeJob = YES;
				}
			}
		}
		else
		{
			// Remove jobs without primary request or that were cancelled
			removeJob = YES;
		}

		if (removeJob)
		{
			if (removeJobs == nil) { removeJobs = [NSMutableArray new]; }
			[removeJobs addObject:job];
		}
	}

	if (removeJobs.count > 0)
	{
		[_jobs removeObjectsInArray:removeJobs];
	}
}

- (void)_queryNextSourceForJob:(OCResourceManagerJob *)job // RUNS ON _QUEUE
{
	OCResourceRequest *primaryRequest;

	if ((primaryRequest = job.primaryRequest) == nil)
	{
		// Jobs without request are complete
 		job.state = OCResourceManagerJobStateComplete;
	}

	if ((job.state != OCResourceManagerJobStateComplete) && (primaryRequest != nil))
	{
		// Find next source:
		// a) no source yet -> first suitable source
		// b) no resource yet -> pick next source that suggests it could provide the resource
		// c) existing resource -> find next source that suggests it can provide the resource at a higher quality

		NSNumber *nextCursorPosition = nil;

		primaryRequest = job.primaryRequest;

		NSUInteger srcIdx = ((job.sourcesCursorPosition == nil) ?
			0 : // start with first suitable source
			job.sourcesCursorPosition.unsignedIntegerValue + 1); // find next suitable source

		while (srcIdx < job.sources.count)
		{
			OCResourceQuality sourceQuality = [job.sources[srcIdx] qualityForRequest:job.primaryRequest];

			if ((sourceQuality != OCResourceQualityNone) && // Source can provide resource
			    (sourceQuality >= job.minimumQuality) && // Source can provide resource in required quality
			    ((sourceQuality > job.latestResource.quality) || // Source can provide resource in higher quality than existing resource
			     (job.latestResource == nil))) // Or no resource yet
			{
				nextCursorPosition = @(srcIdx);
				break;
			}

			srcIdx++;
		};

		// If no next source could be found, job is complete
		if (nextCursorPosition == nil)
		{
			job.state = OCResourceManagerJobStateComplete;
		}
		else
		{
			job.sourcesCursorPosition = nextCursorPosition;
		}
	}

	if ((job.state != OCResourceManagerJobStateComplete) && (primaryRequest != nil))
	{
		if (job.sourcesCursorPosition.unsignedIntegerValue < job.sources.count)
		{
			OCResourceSource *source = job.sources[job.sourcesCursorPosition.unsignedIntegerValue];

			OCResourceManagerJobSeed jobSeed = job.seed;

			[source provideResourceForRequest:primaryRequest resultHandler:^(NSError * _Nullable error, OCResource * _Nullable resource) {
				dispatch_async(self->_queue, ^{
					[self _handleError:error resource:resource forJob:job seed:jobSeed from:source];
				});
			}];
		}
		else
		{
			job.state = OCResourceManagerJobStateComplete;
		}
	}

	[self setNeedsScheduling];
}

- (void)_handleError:(nullable NSError *)error resource:(nullable OCResource *)resource forJob:(OCResourceManagerJob *)job seed:(OCResourceManagerJobSeed)originalSeed from:(OCResourceSource *)source // RUNS ON _QUEUE
{
	OCTLogDebug(@[@"ResMan"], @"Source %@ returned resource=%@, error=%@", source.identifier, resource, error);

	if ((resource != nil) && // A resource must have been returned
	    (originalSeed == job.seed) && // The seed must match (otherwise the returned resource has to be considered outdated)
	    ((job.latestResource == nil) || ((job.latestResource != nil) && (job.latestResource.quality < resource.quality)))) // First resource for job - or resource has higher quality than existing one
	{
		job.latestResource = resource;

		NSArray<OCResourceRequest *> *jobRequests = job.requests.allObjects; // Make a copy to preserve requests for the duration of the iteration and to prevent exceptions caused by possible mutations

		for (OCResourceRequest *request in jobRequests)
		{
			request.resource = resource; // Updates the resource of the request, which will notify its changeHandler
		}
	}

	[self _queryNextSourceForJob:job];
}

#pragma mark - Storage abstraction
- (void)retrieveResourceForRequest:(OCResourceRequest *)request completionHandler:(OCResourceRetrieveCompletionHandler)completionHandler
{
	NSString *cacheKey = [request.type stringByAppendingFormat:@":%@", request.identifier];
	OCResource *cachedResource;

	// Retrieve resource from cache
	if ((cachedResource = [_cache objectForKey:cacheKey]) != nil)
	{
		// Check that it meets the requirements of the request
		if ([request satisfiedByResource:cachedResource])
		{
			// Serve from cache
			OCTLogDebug(@[@"ResMan"], @"🚀 Serving request %@ with resource from memory cache: %@", request, cachedResource);
			completionHandler(nil, cachedResource);
			return;
		}
	}

	// Retrieve resource from storage
	[self.storage retrieveResourceForRequest:request completionHandler:^(NSError * _Nullable error, OCResource * _Nullable resource) {
		// Store resource in cache
		if (resource != nil)
		{
			[self->_cache setObject:resource forKey:cacheKey];
		}

		// Return to completion handler
		OCTLogDebug(@[@"ResMan"], @"💾 Serving request %@ with resource from database: %@", request, resource);
		completionHandler(error, resource);
	}];
}

- (void)storeResource:(OCResource *)resource completionHandler:(OCResourceStoreCompletionHandler)completionHandler
{
	// Store resource in cache
	NSString *cacheKey = [resource.type stringByAppendingFormat:@":%@", resource.identifier];
	[_cache setObject:resource forKey:cacheKey];

	// Store resource in storage
	[self.storage storeResource:resource completionHandler:completionHandler];
}

@end
