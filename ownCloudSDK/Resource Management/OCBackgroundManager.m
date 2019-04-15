//
//  OCBackgroundManager.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 15.04.19.
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

#import "OCBackgroundManager.h"
#import "OCBackgroundTask.h"
#import "OCProcessManager.h"
#import "OCLogTag.h"
#import "OCLogger.h"

@interface OCBackgroundManager () <OCLogTagging>
{
	NSMutableArray <OCBackgroundTask *> *_tasks;
}

@end

@implementation OCBackgroundManager

+ (instancetype)sharedBackgroundManager
{
	static dispatch_once_t onceToken;
	static OCBackgroundManager *sharedBackgroundManager;

	dispatch_once(&onceToken, ^{
		sharedBackgroundManager = [OCBackgroundManager new];

		if (![OCProcessManager isProcessExtension])
		{
			// Use UIApplication as delegate where available
			Class uiApplicationClass = NSClassFromString(@"UIApplication");
			sharedBackgroundManager.delegate = [uiApplicationClass valueForKey:@"sharedApplication"];
		}
	});

	return (sharedBackgroundManager);
}

#pragma mark - Init
- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_tasks = [NSMutableArray new];
	}

	return(self);
}

- (void)startTask:(OCBackgroundTask *)task
{
	@synchronized(self)
	{
		if ([_tasks indexOfObjectIdenticalTo:task] == NSNotFound)
		{
			task.started = YES;
			[_tasks addObject:task];

			OCLogDebug(@"Starting background task '%@' (delegate=%@)", task.name, _delegate);

			if (_delegate != nil)
			{
				[_delegate beginBackgroundTaskWithName:task.name expirationHandler:^{
					if (task.expirationHandler != nil)
					{
						task.expirationHandler(task);
					}
					else
					{
						[self endTask:task];
					}
				}];
			}
		}
	}
}

- (void)endTask:(OCBackgroundTask *)task
{
	@synchronized(self)
	{
		NSUInteger taskIndex;

		if ((taskIndex = [_tasks indexOfObjectIdenticalTo:task]) != NSNotFound)
		{
			[_tasks removeObjectAtIndex:taskIndex];
			task.started = NO;

			OCLogDebug(@"Ending background task '%@' (delegate=%@)", task.name, _delegate);

			if (_delegate != nil)
			{
				[_delegate endBackgroundTask:task.identifier];
			}
		}
	}
}

#pragma mark - Tagging
+ (NSArray<OCLogTagName> *)logTags
{
	return (@[@"BGMAN"]);
}

- (NSArray<OCLogTagName> *)logTags
{
	return (@[@"BGMAN"]);
}

@end
