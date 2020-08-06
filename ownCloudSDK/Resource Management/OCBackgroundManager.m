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
	NSMutableDictionary <NSNumber *, NSMutableArray<dispatch_block_t> *> *_queuedBlocksByBackground;
	BOOL _isBackgrounded;
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

		_queuedBlocksByBackground = [NSMutableDictionary new];
		_queuedBlocksByBackground[@(NO)] = [NSMutableArray new];
		_queuedBlocksByBackground[@(YES)] = [NSMutableArray new];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_applicationStateChanged:) name:UIApplicationDidEnterBackgroundNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_applicationStateChanged:) name:UIApplicationDidBecomeActiveNotification object:nil];
	}

	return(self);
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];

	self.delegate = nil;
}

#pragma mark - Accessors
- (void)setDelegate:(id<OCBackgroundManagerDelegate>)delegate
{
	_delegate = delegate;

	[self updateIsBackgrounded];
}

#pragma mark - Determining state
- (BOOL)_isBackgroundedComputed
{
	if (OCProcessManager.isProcessExtension)
	{
		// Handle extensions as if they're never in the background
		return (NO);
	}

	if (_delegate != nil)
	{
		return ([_delegate applicationState] == UIApplicationStateBackground);
	}

	return (NO);
}

- (void)updateIsBackgrounded
{
	dispatch_async(dispatch_get_main_queue(), ^{
		[self _updateIsBackgrounded];
	});
}

- (void)_updateIsBackgrounded
{
	BOOL isBackgrounded = [self _isBackgroundedComputed];

	if (isBackgrounded != _isBackgrounded)
	{
		NSMutableArray <dispatch_block_t> *runBlocks = nil;

		[self willChangeValueForKey:@"isBackgrounded"];
		_isBackgrounded = isBackgrounded;
		[self didChangeValueForKey:@"isBackgrounded"];

		OCLogDebug(@"Process moved to the %@", (isBackgrounded ? @"background" : @"foreground"));

		@synchronized(_queuedBlocksByBackground)
		{
			NSMutableArray <dispatch_block_t> *queuedBlocks = _queuedBlocksByBackground[@(isBackgrounded)];

			if (queuedBlocks.count > 0)
			{
				runBlocks = [[NSMutableArray alloc] initWithArray:_queuedBlocksByBackground[@(isBackgrounded)]];
				[queuedBlocks removeAllObjects];
			}
		}

		if (runBlocks != nil)
		{
			OCLogDebug(@"Running %lu queued %@ blocks", runBlocks.count, (isBackgrounded ? @"background" : @"foreground"));

			dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{

				while (YES)
				{
					dispatch_block_t runBlock;

					@autoreleasepool {
						if ((runBlock = runBlocks.firstObject) != nil)
						{
							OCLogDebug(@"Running queued %@ block %@", (isBackgrounded ? @"background" : @"foreground"), runBlock);
							runBlock();

							[runBlocks removeObjectAtIndex:0]; // Release immediately after execution in order to trigger the end of any observing OCBackgroundTask
						}
						else
						{
							break;
						}
					}
				};
			});
		}
	}
}

- (void)_applicationStateChanged:(NSNotification *)notification
{
	if ([notification.name isEqualToString:UIApplicationDidBecomeActiveNotification] ||
	    [notification.name isEqualToString:UIApplicationDidEnterBackgroundNotification])
	{
		[self updateIsBackgrounded];
	}
}

- (void)scheduleBlock:(dispatch_block_t)block inBackground:(BOOL)inBackground
{
	if (block == nil) { return; }

	if (self.delegate != nil)
	{
		if (self.isBackgrounded == inBackground)
		{
			OCLogDebug(@"Running %@ block (%@)", (inBackground ? @"background" : @"foreground"), block);
			block();
		}
		else
		{
			block = [block copy];

			if (inBackground)
			{
				// Wrap background blocks into a background task to ensure background execution (app may otherwise be suspended beforehand)
				[[[OCBackgroundTask backgroundTaskWithName:@"scheduled block" expirationHandler:^(OCBackgroundTask * _Nonnull task) {
					[task end];
				}] start] endWhenDeallocating:block];
			}

			OCLogDebug(@"Queuing %@ block %@", (inBackground ? @"background" : @"foreground"), block);

			@synchronized(_queuedBlocksByBackground)
			{
				[_queuedBlocksByBackground[@(inBackground)] addObject:block];
			}
		}
	}
	else
	{
		OCLogDebug(@"Running %@ block (%@) immediately: process has no concept of background/foreground", (inBackground ? @"background" : @"foreground"), block);
		block();
	}
}

#pragma mark - Remaining time
- (NSTimeInterval)backgroundTimeRemaining
{
	if (_delegate != nil)
	{
		return ([_delegate backgroundTimeRemaining]);
	}

	return (NSTimeIntervalSince1970);
}

#pragma mark - Start and end background tasks
- (BOOL)startTask:(OCBackgroundTask *)task
{
	BOOL taskStarted = NO;

	@synchronized(self)
	{
		if (([_tasks indexOfObjectIdenticalTo:task] == NSNotFound) && (_delegate != nil))
		{
			task.started = YES;
			[_tasks addObject:task];

			OCLogDebug(@"Starting background task '%@' (delegate=%@)", task.name, _delegate);

			UIBackgroundTaskIdentifier taskID;

			taskID = [_delegate beginBackgroundTaskWithName:task.name expirationHandler:^{
				if (task.expirationHandler != nil)
				{
					task.expirationHandler(task);
				}
				else
				{
					[self endTask:task];
				}
			}];


			if (taskID != UIBackgroundTaskInvalid)
			{
				task.identifier = taskID;
				taskStarted = YES;
			}
			else
			{
				task.started = NO;
				[_tasks removeObjectIdenticalTo:task];
			}
		}
		else if (_delegate == nil)
		{
			// Task not managed, so can't expire and we can drop the expiration handler
			[task clearExpirationHandler];
		}
	}

	return (taskStarted);
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
