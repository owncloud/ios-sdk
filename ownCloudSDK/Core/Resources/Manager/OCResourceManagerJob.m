//
//  OCResourceManagerJob.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 04.01.22.
//  Copyright © 2022 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2021, ownCloud GmbH.
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
#import "OCResourceRequest+Internal.h"
#import "OCResourceSource.h"

@implementation OCResourceManagerJob

- (instancetype)initWithPrimaryRequest:(OCResourceRequest *)primaryRequest forManager:(OCResourceManager *)manager;
{
	if ((self = [super init]) != nil)
	{
		_primaryRequest = primaryRequest;
		_manager = manager;

		_requests = [NSHashTable weakObjectsHashTable];
		_sources = [NSMutableArray new];

		[_requests addObject:primaryRequest];
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

- (void)addRequest:(OCResourceRequest *)request
{
	@synchronized(self)
	{
		request.job = self;
		[_requests addObject:request];
	}
}

- (void)replacePrimaryRequestWith:(OCResourceRequest *)request
{
	@synchronized(self)
	{
		request.job = self;

		[_requests addObject:request];
		_primaryRequest = request;

		_state = OCResourceManagerJobStateNew;

		_sources = nil;
		_sourcesCursorPosition = nil;

		_seed++;
	}
}

@end
