//
//  OCResourceManager.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 21.12.21.
//  Copyright © 2021 ownCloud GmbH. All rights reserved.
//

#import "OCResourceManager.h"
#import "OCCache.h"

@interface OCResourceManager ()
{
	OCCache *_cache;
	NSMutableDictionary<OCResourceType, NSMutableArray<OCResourceSource *> *> *_sourcesByType;
}
@end

@implementation OCResourceManager

- (instancetype)initWithStorage:(id<OCResourceStorage>)storage
{
	if ((self = [super init]) != nil)
	{
		_storage = storage;
		_sourcesByType = [NSMutableDictionary new];
	}

	return (self);
}

#pragma mark - Sources
- (void)addSource:(OCResourceSource *)source
{
	NSMutableArray<OCResourceSource *> *sources;

	if ((sources = _sourcesByType[source.type]) == nil)
	{
		sources = [NSMutableArray new];
		_sourcesByType[source.type] = sources;
	}

	[sources addObject:source];
}

- (void)removeSource:(OCResourceSource *)source
{
	NSMutableArray<OCResourceSource *> *sources;

	if ((sources = _sourcesByType[source.type]) != nil)
	{
		[sources removeObject:source];
	}
}

#pragma mark - Requests
- (void)startRequest:(OCResourceRequest *)request
{

}

- (void)stopRequest:(OCResourceRequest *)request
{

}

@end
