//
//  OCIPNotificationCenter.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 21.10.18.
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

#import "OCIPNotificationCenter.h"
#import "OCLogger.h"

static BOOL sOCIPNotificationCenterLoggingEnabled = NO;

@implementation OCIPNotificationCenter

+ (BOOL)loggingEnabled
{
	return (sOCIPNotificationCenterLoggingEnabled);
}

+ (void)setLoggingEnabled:(BOOL)loggingEnabled
{
	sOCIPNotificationCenterLoggingEnabled = loggingEnabled;
}

#pragma mark - Init / Dealloc / Singleton
+ (OCIPNotificationCenter *)sharedNotificationCenter
{
	static dispatch_once_t onceToken;
	static OCIPNotificationCenter *sharedCenter;

	dispatch_once(&onceToken, ^{
		sharedCenter = [OCIPNotificationCenter new];
	});

	return (sharedCenter);
}

- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		if ((_darwinNotificationCenter = CFNotificationCenterGetDarwinNotifyCenter()) != NULL)
		{
			CFRetain(_darwinNotificationCenter);
		}

		_handlersByObserverByNotificationName = [NSMutableDictionary new];
		_ignoreCountsByNotificationName = [NSMutableDictionary new];
	}

	return(self);
}

- (void)dealloc
{
	if (_darwinNotificationCenter != NULL)
	{
		CFRelease(_darwinNotificationCenter);
		_darwinNotificationCenter = NULL;
	}
}

#pragma mark - Low-level handling
static void OCIPNotificationCenterCallback(CFNotificationCenterRef center, void *observer, CFNotificationName name, const void *object, CFDictionaryRef userInfo)
{
	OCIPNotificationCenter *notificationCenter = (__bridge OCIPNotificationCenter *)observer;

	[notificationCenter deliverNotificationForName:(__bridge OCIPCNotificationName)name];
}

- (void)enable:(BOOL)enable observationForName:(NSString *)name
{
	if (enable)
	{
		CFNotificationCenterAddObserver(_darwinNotificationCenter, (__bridge const void *)self, OCIPNotificationCenterCallback, (__bridge CFStringRef)name, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
	}
	else
	{
		CFNotificationCenterRemoveObserver(_darwinNotificationCenter, (__bridge const void *)self, (__bridge CFStringRef)name, NULL);
	}
}

#pragma mark - Add/Remove notification observers
- (void)addObserver:(id)observer forName:(OCIPCNotificationName)name withHandler:(OCIPNotificationHandler)handler
{
	if (OCIPNotificationCenter.loggingEnabled)
	{
		OCLogDebug(@"Adding observer=%@ for '%@'", OCLogPrivate(observer), name);
	}

	@synchronized(self)
	{
		NSMapTable<id, OCIPNotificationHandler> *handlersByObserver;

		if ((handlersByObserver = _handlersByObserverByNotificationName[name]) == nil)
		{
			handlersByObserver = [NSMapTable weakToStrongObjectsMapTable];
			_handlersByObserverByNotificationName[name] = handlersByObserver;
		}

		[handlersByObserver setObject:[handler copy] forKey:observer];

		if (handlersByObserver.count == 1)
		{
			[self enable:YES observationForName:name];
		}
	}
}

- (void)removeObserver:(id)observer forName:(OCIPCNotificationName)name
{
	if (OCIPNotificationCenter.loggingEnabled)
	{
		OCLogDebug(@"Removing observer=%@ for '%@'", OCLogPrivate(observer), name);
	}

	@synchronized(self)
	{
		NSMapTable<id, OCIPNotificationHandler> *handlersByObserver;

		if ((handlersByObserver = _handlersByObserverByNotificationName[name]) != nil)
		{
			if ([handlersByObserver objectForKey:observer] != nil)
			{
				[handlersByObserver removeObjectForKey:observer];

				if (handlersByObserver.count == 0)
				{
					[self enable:NO observationForName:name];
				}
			}
		}
	}
}

- (void)removeAllObserversForName:(OCIPCNotificationName)name
{
	if (OCIPNotificationCenter.loggingEnabled)
	{
		OCLogDebug(@"Removing all observers for '%@'", name);
	}

	@synchronized(self)
	{
		[_handlersByObserverByNotificationName removeObjectForKey:name];
		[_ignoreCountsByNotificationName removeObjectForKey:name];
	}
}

#pragma mark - Deliver notifications
- (void)deliverNotificationForName:(OCIPCNotificationName)name
{
	NSArray<id> *observers = nil;
	NSMutableArray<dispatch_block_t> *notifyBlocks = nil;

	if (OCIPNotificationCenter.loggingEnabled)
	{
		OCLogDebug(@"Received notification '%@'", name);
	}

	@synchronized(self)
	{
		NSMapTable<id, OCIPNotificationHandler> *handlersByObserver;
		NSNumber *ignoreCountNumber = _ignoreCountsByNotificationName[name];
		NSUInteger ignoreCount;

		if ((ignoreCount = ignoreCountNumber.unsignedIntegerValue) > 0)
		{
			if (ignoreCount > 1)
			{
				_ignoreCountsByNotificationName[name] = @(ignoreCount - 1);
			}
			else
			{
				[_ignoreCountsByNotificationName removeObjectForKey:name];
			}

			return;
		}

		if ((handlersByObserver = _handlersByObserverByNotificationName[name]) != nil)
		{
			observers = NSAllMapTableKeys(handlersByObserver); // Simple enumeration could fail due to mutation while enumeration, so we grab an array of the observers and iterate over that
			notifyBlocks = [NSMutableArray new];

			for (id observer in observers)
			{
				OCIPNotificationHandler notificationHandler;

				if ((notificationHandler = [handlersByObserver objectForKey:observer]) != nil)
				{
					// Queue notification calls for later, to avoid deadlock due to @synchronized()
					[notifyBlocks addObject:^{
						if (OCIPNotificationCenter.loggingEnabled)
						{
							OCLogDebug(@"Delivering notification '%@' to %@", name, OCLogPrivate(observer));
						}

						notificationHandler(self, observer, name);
					}];
				}
			}
		}
	}

	for (dispatch_block_t notificationBlock in notifyBlocks)
	{
		notificationBlock();
	}
}

#pragma mark - Post notifications
- (void)postNotificationForName:(OCIPCNotificationName)name ignoreSelf:(BOOL)ignoreSelf
{
	if (OCIPNotificationCenter.loggingEnabled)
	{
		OCLogDebug(@"Posting notification '%@' (ignoreSelf=%d)", name, ignoreSelf);
	}

	@synchronized (self)
	{
		NSNumber *existingIgnoreCount =  _ignoreCountsByNotificationName[name];

		if (ignoreSelf)
		{
			_ignoreCountsByNotificationName[name] = @([existingIgnoreCount unsignedIntegerValue] + 1);
		}

		CFNotificationCenterPostNotification(_darwinNotificationCenter, (__bridge CFNotificationName)name, NULL, NULL, false);
	}
}

@end

#pragma mark - Log tagging
@interface OCIPNotificationCenter (LogTagging) <OCLogTagging>
@end

@implementation OCIPNotificationCenter (LogTagging)

- (nonnull NSArray<OCLogTagName> *)logTags
{
	return (@[@"IPNC"]);
}

+ (nonnull NSArray<OCLogTagName> *)logTags
{
	return (@[@"IPNC"]);
}

@end
