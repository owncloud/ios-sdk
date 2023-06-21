/*
 *
 * Based on ISRunLoopThread, as found at https://gist.github.com/felix-schwarz/9fa9055b6ade900f1f21
 *
 */

//
//  ISRunLoopThread.m
//
//  Created by Felix Schwarz on 13.09.14.
//  Copyright (c) 2014 IOSPIRIT GmbH. All rights reserved.
//

#import "OCRunLoopThread.h"
#import <pthread/pthread.h>

static NSString *kISRunLoopThreadNameMain = @"__main__";
static NSString *kISRunLoopThreadUUIDKey = @"_runLoopThreadUUID";

@implementation OCRunLoopThread

@synthesize name;

@synthesize thread;
@synthesize runLoop;

@synthesize uuid = _uuid;

+ (NSMutableDictionary *)_runLoopThreadsByNameDict
{
	static dispatch_once_t onceToken;
	static NSMutableDictionary *sISRunLoopThreadsByName;

	dispatch_once(&onceToken, ^{
		sISRunLoopThreadsByName = [[NSMutableDictionary alloc] init];
	});

	return (sISRunLoopThreadsByName);
}

+ (instancetype)mainRunLoopThread
{
	return ([self runLoopThreadNamed:kISRunLoopThreadNameMain]);
}

+ (instancetype)currentRunLoopThread
{
	OCRunLoopThread *currentRunLoopThread  = nil;

	if ([NSThread isMainThread])
	{
		return ([self mainRunLoopThread]);
	}
	else
	{
		@synchronized(self)
		{
			NSMutableDictionary *threadsByNameDict = [self _runLoopThreadsByNameDict];
			NSThread *currentThread = [NSThread currentThread];
			NSUUID *currentThreadUUID = currentThread.threadDictionary[kISRunLoopThreadUUIDKey];

			for (NSString *name in threadsByNameDict)
			{
				OCRunLoopThread *runLoopThread;

				runLoopThread = [threadsByNameDict objectForKey:name];

				if ((runLoopThread.thread == currentThread) || [currentThreadUUID isEqual:runLoopThread.uuid] || [runLoopThread.thread isEqual:currentThread])
				{
					return (runLoopThread);
				}
			}

			if ((currentRunLoopThread = [[OCRunLoopThread alloc] initWithName:[NSString stringWithFormat:@"%p",currentThread] thread:currentThread runLoop:[NSRunLoop currentRunLoop]]) != nil)
			{
				[threadsByNameDict setObject:currentRunLoopThread forKey:currentRunLoopThread.name];

				[currentRunLoopThread release];
			}
		}
	}

	return (currentRunLoopThread);
}

+ (instancetype)runLoopThreadNamed:(NSString *)runLoopThreadName
{
	OCRunLoopThread *runLoopThread = nil;

	if (runLoopThreadName==nil) { return(nil); }

	@synchronized(self)
	{
		runLoopThread = [[self _runLoopThreadsByNameDict] objectForKey:runLoopThreadName];

		if (runLoopThread == nil)
		{
			if ([runLoopThreadName isEqual:kISRunLoopThreadNameMain])
			{
				runLoopThread = [[self alloc] initWithMainThread];
			}
			else
			{
				runLoopThread = [[self alloc] initWithName:runLoopThreadName];
			}

			if (runLoopThread != nil)
			{
				[[self _runLoopThreadsByNameDict] setObject:runLoopThread forKey:runLoopThreadName];
				[runLoopThread autorelease];
			}
		}
	}

	return (runLoopThread);
}

- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_syncSemaphore = dispatch_semaphore_create(0);
		_uuid = [NSUUID new];
	}

	return (self);
}

- (instancetype)initWithMainThread
{
	if ((self = [self init]) != nil)
	{
		self.name = kISRunLoopThreadNameMain;

		runLoop = [NSRunLoop mainRunLoop];
		thread = [[NSThread mainThread] retain];
	}

	return (self);
}

- (instancetype)initWithName:(NSString *)aName
{
	if ((self = [self init]) != nil)
	{
		self.name = aName;

		runLoop = nil;
		thread = [[NSThread alloc] initWithTarget:self selector:@selector(_threadMain:) object:nil];
		thread.qualityOfService = NSQualityOfServiceUserInitiated;

		[thread start];

		// Wait for thread's runloop to become available
		dispatch_semaphore_wait(_syncSemaphore,DISPATCH_TIME_FOREVER);
	}

	return (self);
}

- (instancetype)initWithName:(NSString *)aName thread:(NSThread *)aThread runLoop:(NSRunLoop *)aRunLoop
{
	if ((self = [self init]) != nil)
	{
		self.name = aName;
		thread = [aThread retain];
		runLoop = aRunLoop;
	}

	return (self);
}

- (void)dealloc
{
	[name release];
	name = nil;

	[thread release];
	thread = nil;

	[_syncSemaphore release];
	_syncSemaphore = nil;

	[_uuid release];
	_uuid = nil;

	[super dealloc];
}

- (void)_threadMain:(id)sender
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

        // Set thread name
	NSString *runLoopThreadName = [NSString stringWithFormat:@"ISRunLoopThread:%@",name];

	pthread_setname_np([runLoopThreadName UTF8String]);
	[[NSThread currentThread] setName:runLoopThreadName];

	thread.threadDictionary[kISRunLoopThreadUUIDKey] = _uuid;

	// Get runloop
	runLoop = [NSRunLoop currentRunLoop];

	// Signal init
	dispatch_semaphore_signal(_syncSemaphore);

	// Run runloop
	do
	{
		NSDate *runUntil;

		if ((runUntil = [[NSDate alloc] initWithTimeIntervalSinceNow:5.0]) != nil)
		{
			[[NSRunLoop currentRunLoop] runUntilDate:runUntil];

			[runUntil release];
		}

	}while(![thread isCancelled]);

	// Clean up thread
	runLoop = nil;

	[pool drain];
}

- (void)dispatchBlockToRunLoopAsync:(dispatch_block_t)block
{
	if (block != nil)
	{
		dispatch_block_t jobBlock;

		if ((jobBlock = [block copy]) != nil)
		{
			[self performSelector:@selector(_executeBlock:) onThread:thread withObject:jobBlock waitUntilDone:NO];

			[jobBlock release];
		}
	}
}

- (void)terminate
{
	@synchronized([self class])
	{
		[thread cancel];

		if (name != nil)
		{
			[[[self class] _runLoopThreadsByNameDict] removeObjectForKey:name];
		}
	}
}

- (void)_executeBlock:(dispatch_block_t)block
{
	if (block != nil)
	{
		block();
	}
}

- (BOOL)isCurrentThread
{
	NSThread *currentThread = NSThread.currentThread;

	return (
		(currentThread == thread) || // Thread pointers identical
		[currentThread.threadDictionary[kISRunLoopThreadUUIDKey] isEqual:_uuid] || // UUID identical
		[currentThread isEqual:thread] // Thread objects equal
	);
}

@end
