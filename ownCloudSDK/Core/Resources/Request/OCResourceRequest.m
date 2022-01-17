//
//  OCResourceRequest.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 30.09.20.
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

#import "OCResourceRequest.h"
#import "OCResourceManagerJob.h"
#import "OCResource.h"
#import "OCLogger.h"

@implementation OCResourceRequest

- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_minimumQuality = OCResourceQualityFallback;
	}

	return (self);
}

- (instancetype)initWithType:(OCResourceType)type identifier:(OCResourceIdentifier)identifier
{
	if ((self = [self init]) != nil)
	{
		_type = type;
		_identifier= identifier;
	}

	return (self);
}

- (void)dealloc
{
	[self endRequest];
	OCTLogDebug(@[@"ResMan"], @"Deallocating OCResourceRequest");
}

- (OCResourceRequestRelation)relationWithRequest:(OCResourceRequest *)otherRequest
{
	return (OCResourceRequestRelationDistinct);
}

- (BOOL)satisfiedByResource:(OCResource *)resource
{
	if ([self.type isEqual:resource.type] &&
	    [self.identifier isEqual:resource.identifier] &&
	    [self.version isEqual:resource.version] &&
	    [self.structureDescription isEqual:resource.structureDescription])
	{
		return (YES);
	}

	return (NO);
}

- (void)setResource:(OCResource *)resource
{
	OCResource *previousResource = _resource;

	_resource = resource;

	[self notifyWithError:nil isOngoing:YES previousResource:previousResource newResource:resource];
}

- (void)notifyWithError:(NSError *)error isOngoing:(BOOL)isOngoing previousResource:(OCResource *)previousResource newResource:(OCResource *)newResource
{
	if (_delegate != nil)
	{
		[_delegate resourceRequest:self didChangeWithError:error isOngoing:isOngoing previousResource:previousResource newResource:newResource];
	}

	if (_changeHandler != nil)
	{
		_changeHandler(self, error, isOngoing, previousResource, newResource);
	}
}

- (CGSize)maxPixelSize
{
	CGSize pointSize = self.maxPointSize;
	CGFloat scale = self.scale;

	if (scale == 0)
	{
		scale = 1.0;
	}

	return (CGSizeMake(pointSize.width * scale, pointSize.height * scale));
}

- (void)setCancelled:(BOOL)cancelled
{
	_cancelled = cancelled;

	if (cancelled)
	{
		[self endRequest];
	}
}

- (void)endRequest
{
	OCResourceRequestChangeHandler changeHandler = nil;
	OCResource *resource = nil;

	[self willChangeValueForKey:@"ended"];

	@synchronized(self)
	{
		changeHandler = _changeHandler;
		resource = _resource;

		_changeHandler = nil;
		_ended = YES;
	}

	[self didChangeValueForKey:@"ended"];

	if (changeHandler != nil)
	{
		OCTLogDebug(@[@"ResMan"], @"Ending OCResourceRequest %@", self);
		changeHandler(self, nil, NO, resource, resource);
	}

	[self notifyWithError:nil isOngoing:NO previousResource:resource newResource:resource]; // only notifies delegate here, as _changeHandler is nil at this point
}

@end
