//
//  OCHTTPPipelineTaskCache.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 08.02.19.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2019, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCHTTPPipelineTaskCache.h"
#import "OCHTTPPipelineTask.h"

@implementation OCHTTPPipelineTaskCache

- (instancetype)init
{
	if ((self = [self init]) != nil)
	{
		_taskByTaskID = [NSMutableDictionary new];
		_taskByRequestID = [NSMutableDictionary new];
	}

	return (self);
}

- (instancetype)initWithBackend:(OCHTTPPipelineBackend *)backend
{
	if ((self = [self init]) != nil)
	{
		_backend = backend;
		_bundleIdentifier = backend.bundleIdentifier;
	}

	return (self);
}

- (BOOL)taskQualifiesForCaching:(OCHTTPPipelineTask *)task
{
	return ((task.taskID != nil) && ([task.bundleID isEqual:_bundleIdentifier]) && (task.request.identifier != nil));
}

- (void)updateWithTask:(OCHTTPPipelineTask *)task remove:(BOOL)remove
{
	if ([self taskQualifiesForCaching:task])
	{
		@synchronized(_taskByTaskID)
		{
			if (remove)
			{
				[_taskByTaskID removeObjectForKey:task.taskID];
				[_taskByRequestID removeObjectForKey:task.request.identifier];
			}
			else
			{
				_taskByTaskID[task.taskID] = task;
				_taskByRequestID[task.request.identifier] = task;
			}
		}
	}
}

- (OCHTTPPipelineTask *)cachedCopyForTask:(OCHTTPPipelineTask *)task storeIfNew:(BOOL)storeIfNew
{
	if ([self taskQualifiesForCaching:task])
	{
		// Manage cache
		if (task.taskID != nil)
		{
			@synchronized(_taskByTaskID)
			{
				if (_taskByTaskID[task.taskID] != nil)
				{
					// Use copy from cache instead
					task = _taskByTaskID[task.taskID];
				}
				else if (storeIfNew)
				{
					// Save to cache
					_taskByTaskID[task.taskID] = task;
					_taskByRequestID[task.request.identifier] = task;
				}
			}
		}
	}

	return (task);
}

- (nullable OCHTTPPipelineTask *)cachedTaskForPipelineTaskID:(OCHTTPPipelineTaskID)taskID
{
	OCHTTPPipelineTask *task = nil;

	if (taskID != nil)
	{
		@synchronized(_taskByTaskID)
		{
			task = _taskByTaskID[taskID];
		}
	}

	return (task);
}

- (nullable OCHTTPPipelineTask *)cachedTaskForRequestID:(OCHTTPRequestID)requestID
{
	OCHTTPPipelineTask *task = nil;

	if (requestID != nil)
	{
		@synchronized(_taskByTaskID)
		{
			task = _taskByRequestID[requestID];
		}
	}

	return (task);
}

@end
