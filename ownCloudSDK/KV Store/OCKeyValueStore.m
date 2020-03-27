//
//  OCKeyValueStore.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 22.08.19.
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

#import <UIKit/UIKit.h>

#import "OCMacros.h"
#import "OCKeyValueStore.h"
#import "OCKeyValueRecord.h"
#import "OCLogger.h"
#import "OCIPNotificationCenter.h"
#import "OCRateLimiter.h"
#import "OCKeyValueStack.h"
#import "OCBackgroundTask.h"

typedef NSMutableDictionary<OCKeyValueStoreKey, OCKeyValueRecord *> * OCKeyValueStoreDictionary;

@interface OCKeyValueStore ()
{
	NSMutableDictionary<OCKeyValueStoreKey, NSSet<Class> *> *_classesForKey;
	NSMutableDictionary<OCKeyValueStoreKey, NSMapTable<id, OCKeyValueStoreObserver> *> *_observersByOwnerByKey;

	OCKeyValueStoreDictionary _recordsByKey;

	NSFileCoordinator *_coordinator;
	NSOperationQueue *_coordinationQueue;

	OCRateLimiter *_rateLimiter;

	NSString *_cachedKeyUpdateNotificationName;
}
@end

@implementation OCKeyValueStore

#pragma mark - Fallback
+ (NSSet<Class> *)fallbackClasses
{
	static dispatch_once_t onceToken;
	static NSSet<Class> *fallbackClasses;
	dispatch_once(&onceToken, ^{
		fallbackClasses = [[NSSet alloc] initWithObjects:
			[NSArray class],
			[NSDictionary class],
			[NSSet class],

			[NSString class],
			[NSNumber class],
			[NSDate class],
			[NSData class],
		nil];
	});

	return (fallbackClasses);
}

+ (NSMutableDictionary<OCKeyValueStoreKey, NSSet<Class> *> *)_sharedRegisteredClassesForKey
{
	static NSMutableDictionary<OCKeyValueStoreKey, NSSet<Class> *> *sharedRegisteredClassesForKey;
	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		sharedRegisteredClassesForKey= [NSMutableDictionary new];
	});

	return (sharedRegisteredClassesForKey);
}

+ (NSSet<Class> *)registeredClassesForKey:(OCKeyValueStoreKey)key
{
	NSMutableDictionary<OCKeyValueStoreKey, NSSet<Class> *> *sharedRegisteredClassesForKey = [self _sharedRegisteredClassesForKey];

	@synchronized(sharedRegisteredClassesForKey)
	{
		return (sharedRegisteredClassesForKey[key]);
	}
}

+ (void)registerClass:(Class)objectClass forKey:(OCKeyValueStoreKey)key
{
	NSMutableDictionary<OCKeyValueStoreKey, NSSet<Class> *> *sharedRegisteredClassesForKey = [self _sharedRegisteredClassesForKey];

	@synchronized(sharedRegisteredClassesForKey)
	{
		sharedRegisteredClassesForKey[key] = [NSSet setWithObject:objectClass];
	}
}

+ (void)registerClasses:(NSSet<Class> *)classes forKey:(OCKeyValueStoreKey)key
{
	NSMutableDictionary<OCKeyValueStoreKey, NSSet<Class> *> *sharedRegisteredClassesForKey = [self _sharedRegisteredClassesForKey];

	@synchronized(sharedRegisteredClassesForKey)
	{
		sharedRegisteredClassesForKey[key] = classes;
	}
}

#pragma mark - Init
- (instancetype)initWithURL:(NSURL *)url identifier:(nullable OCKeyValueStoreIdentifier)identifier
{
	if ((self = [self init]) != nil)
	{
		if ((url!=nil) && (![[NSFileManager defaultManager] fileExistsAtPath:url.path]))
		{
			[[NSKeyedArchiver archivedDataWithRootObject:[NSMutableDictionary new]] writeToURL:url atomically:YES];
		}

		_url = url;
		_identifier = identifier;

		_classesForKey = [NSMutableDictionary new];
		_observersByOwnerByKey = [NSMutableDictionary new];
		_recordsByKey = [NSMutableDictionary new];

		// Listen for changes
		_coordinationQueue = [[NSOperationQueue alloc] init];
		_coordinationQueue.maxConcurrentOperationCount = 1;

		OCBackgroundTask *backgroundTask = [[OCBackgroundTask backgroundTaskWithName:@"OCKeyValueStore initial read" expirationHandler:^(OCBackgroundTask * _Nonnull task) {
			OCLogWarning(@"%@ background task expired", task.name);
			[task end];
		}] start];

		OCSyncExec(waitForCoordinator, {
			[_coordinationQueue addOperationWithBlock:^{
				self->_coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];

				[self->_coordinator coordinateReadingItemAtURL:self->_url options:0 error:NULL byAccessor:^(NSURL * _Nonnull newURL) {
					// Initial load
					OCKeyValueStoreDictionary recordsByKey;

					if ((recordsByKey = [self _readStoreContentsAtURL:newURL]) != nil)
					{
						self->_recordsByKey = recordsByKey;
					}

					OCSyncExecDone(waitForCoordinator);
				}];
			}];
		});

		[backgroundTask end];

		// See https://developer.apple.com/documentation/foundation/nsfilepresenter (File Presenters and iOS): file presenters needs to removed and re-added to prevent deadlocks in other apps
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];

		[self _setupUpdateNotifications];
	}

	return (self);
}

- (void)dealloc
{
	[self _teardownUpdateNotifications];

	[[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];
}

#pragma mark - Class registration
- (void)registerClasses:(NSSet<Class> *)classes forKey:(OCKeyValueStoreKey)key
{
	@synchronized(self)
	{
		[_classesForKey setObject:classes forKey:key];
	}
}

- (void)registerClass:(Class)objectClass forKey:(OCKeyValueStoreKey)key
{
	[self registerClasses:[NSSet setWithObject:objectClass] forKey:key];
}

- (NSSet<Class> *)registeredClassesForKey:(OCKeyValueStoreKey)key
{
	@synchronized(self)
	{
		return ([_classesForKey objectForKey:key]);
	}
}

#pragma mark - Storing plain values
- (void)_updateObjectForKey:(OCKeyValueStoreKey)key usingModifier:(nullable id _Nullable(^)(id _Nullable existingObject, BOOL * _Nullable outDidModify))modifier object:(nullable id<NSSecureCoding>)newObject
{
	OCWaitInitAndStartTask(waitForUpdateToFinish);

	[self updateStoreContentsWithModifications:^(OCKeyValueStoreDictionary storeContents) {
		OCKeyValueRecord *record = storeContents[key];
		id object = newObject;
		BOOL didModify = YES;

		if (modifier != nil)
		{
			object = [record decodeObjectWithClasses:[self _classesForKey:key]];
			didModify = NO;

			object = modifier(object, &didModify);
		}

		if (didModify)
		{
			if (object != nil)
			{
				if (record != nil)
				{
					// Update existing record
					[record updateWithObject:object];
				}
				else
				{
					// Add new record
					storeContents[key] = [[OCKeyValueRecord alloc] initWithValue:object];
				}
			}
			else
			{
				// Remove record
				storeContents[key] = nil;
			}
		}

		return (didModify);
	} completionHandler:^{
		OCWaitDidFinishTask(waitForUpdateToFinish);
	}];

	OCWaitForCompletion(waitForUpdateToFinish);
}

- (void)storeObject:(nullable id<NSSecureCoding>)object forKey:(OCKeyValueStoreKey)key
{
	[self _updateObjectForKey:key usingModifier:nil object:object];
}

- (void)updateObjectForKey:(OCKeyValueStoreKey)key usingModifier:(id _Nullable(^)(id _Nullable existingObject, BOOL *outDidModify))modifier
{
	[self _updateObjectForKey:key usingModifier:modifier object:nil];
}

#pragma mark - Storing values in stacks
- (void)pushObject:(nullable id<NSSecureCoding>)object onStackForKey:(OCKeyValueStoreKey)key withClaim:(OCClaim *)claim
{
	NSData *objectData = (object != nil) ? [NSKeyedArchiver archivedDataWithRootObject:object] : nil;

	OCWaitInitAndStartTask(waitForUpdateToFinish);

	[self updateStoreContentsWithModifications:^BOOL(OCKeyValueStoreDictionary storeContents) {
		OCKeyValueRecord *record = nil;
		OCKeyValueStack *stack;

		if ((record = storeContents[key]) == nil)
		{
			record = [[OCKeyValueRecord alloc] initWithKeyValueStack];
			storeContents[key] = record;
		}

		if ((record != nil) && (record.type == OCKeyValueRecordTypeStack) &&
		    ((stack = (OCKeyValueStack *)[record decodeObjectWithClasses:[NSSet setWithObject:[OCKeyValueStack class]]]) != nil))
		{
			[stack pushObject:objectData withClaim:claim];
			[record updateWithObject:stack];
			return (YES);
		}
		else
		{
			OCLogError(@"Failed to push object on stack for key=%@", key);
		}

		return (NO);
	} completionHandler:^{
		OCWaitDidFinishTask(waitForUpdateToFinish);
	}];

	OCWaitForCompletion(waitForUpdateToFinish);
}

- (void)popObjectWithClaimID:(OCClaimIdentifier)claimIdentifier fromStackForKey:(OCKeyValueStoreKey)key
{
	OCWaitInitAndStartTask(waitForUpdateToFinish);

	[self updateStoreContentsWithModifications:^BOOL(OCKeyValueStoreDictionary storeContents) {
		OCKeyValueRecord *record = storeContents[key];
		OCKeyValueStack *stack;

		if ((record != nil) && (record.type == OCKeyValueRecordTypeStack) && ((stack = (OCKeyValueStack *)[record decodeObjectWithClasses:[NSSet setWithObject:[OCKeyValueStack class]]]) != nil))
		{
			[stack popObjectWithClaimID:claimIdentifier];
			[record updateWithObject:stack];
			return (YES);
		}

		return (NO);
	} completionHandler:^{
		OCWaitDidFinishTask(waitForUpdateToFinish);
	}];

	OCWaitForCompletion(waitForUpdateToFinish);
}

- (void)flushStackForKey:(OCKeyValueStoreKey)key
{
	[self storeObject:nil forKey:key];
}

#pragma mark - Reading values
- (NSSet<Class> *)_classesForKey:(OCKeyValueStoreKey)key
{
	@synchronized(self)
	{
		NSSet<Class> *keyClasses = _classesForKey[key];

		if (keyClasses == nil)
		{
			keyClasses = [OCKeyValueStore registeredClassesForKey:key];
		}

		if (keyClasses == nil)
		{
			keyClasses = [OCKeyValueStore fallbackClasses];
		}

		return (keyClasses);
	}
}

- (nullable id)readObjectForKey:(OCKeyValueStoreKey)key
{
	@synchronized(self)
	{
		OCKeyValueRecord *record = _recordsByKey[key];

		switch (record.type)
		{
			case OCKeyValueRecordTypeValue:
				return ([record decodeObjectWithClasses:[self _classesForKey:key]]);
			break;

			case OCKeyValueRecordTypeStack: {
				OCKeyValueStack *stack;

				if ((stack = (OCKeyValueStack *)[record decodeObjectWithClasses:[NSSet setWithObject:[OCKeyValueStack class]]]) != nil)
				{
					id firstValidObjectData = nil;
					BOOL removedInvalidEntries = NO;
					BOOL hasValidEntry = NO;

					hasValidEntry = [stack determineFirstValidObject:&firstValidObjectData claimIdentifier:nil removedInvalidEntries:&removedInvalidEntries];

					if (removedInvalidEntries)
					{
						[self updateStoreContentsWithModifications:^BOOL(OCKeyValueStoreDictionary storeContents) {
							OCKeyValueRecord *record = storeContents[key];

							if (record != nil)
							{
								OCKeyValueStack *stack;

								if ((stack = (OCKeyValueStack *)[record decodeObjectWithClasses:[NSSet setWithObject:[OCKeyValueStack class]]]) != nil)
								{
									BOOL removedInvalidEntries = NO;

									if ([stack determineFirstValidObject:NULL claimIdentifier:NULL removedInvalidEntries:&removedInvalidEntries])
									{
										// Update the stack if one or more entries have become invalid
										if (removedInvalidEntries)
										{
											// Update stored record, so all observers get notifies with the latest value, too
											return (YES);
										}
									}
									else
									{
										// Remove stack that no longer has any valid entries
										storeContents[key] = nil;
										return (YES);
									}
								}
							}

							return (NO);
						}  completionHandler:nil];
					}

					if (hasValidEntry && (firstValidObjectData != nil))
					{
						return ([NSKeyedUnarchiver unarchivedObjectOfClasses:[self _classesForKey:key] fromData:firstValidObjectData error:NULL]);
					}
				}
			}
			break;
		}
	}

	return (nil);
}

#pragma mark - Observation
- (void)addObserver:(OCKeyValueStoreObserver)observer forKey:(OCKeyValueStoreKey)key withOwner:(id)owner initial:(BOOL)initial
{
	NSMapTable<id, OCKeyValueStoreObserver> *observersByOwner;

	@synchronized(self)
	{
		if ((observersByOwner = _observersByOwnerByKey[key]) == nil)
		{
			observersByOwner = [NSMapTable weakToStrongObjectsMapTable];
			_observersByOwnerByKey[key] = observersByOwner;
		}

		[observersByOwner setObject:[observer copy] forKey:owner];
	}

	if (initial)
	{
		observer(self, owner, key, [self readObjectForKey:key]);
	}
}

- (void)removeObserverForOwner:(id)owner forKey:(OCKeyValueStoreKey)key
{
	@synchronized(self)
	{
		[_observersByOwnerByKey[key] removeObjectForKey:owner];
	}
}

- (void)notifyObserversOfNewValueForKey:(OCKeyValueStoreKey)key
{
	NSMapTable<id, OCKeyValueStoreObserver> *observersByOwner;

	@synchronized(self)
	{
		if ((observersByOwner = _observersByOwnerByKey[key]) != nil)
		{
			id newValue = [self readObjectForKey:key];

			observersByOwner = [observersByOwner copy];

			for (id owner in observersByOwner)
			{
				OCKeyValueStoreObserver observer;

				if ((observer = [observersByOwner objectForKey:owner]) != nil)
				{
					observer(self, owner, key, newValue);
				}
			}
		}
	}
}

#pragma mark - App state tracking
- (void)applicationDidEnterBackground:(NSNotification *)notification
{
}

- (void)applicationWillEnterForeground:(NSNotification *)notification
{
	[self updateFromStoreContentsAtURL:self.url];
}

#pragma mark - Update notifications
- (NSString *)_updateNotificationName
{
	if (_cachedKeyUpdateNotificationName == nil)
	{
		_cachedKeyUpdateNotificationName = [@"com.owncloud.keyvalueupdate." stringByAppendingString:self.identifier];
	}

	return (_cachedKeyUpdateNotificationName);
}

- (void)_setupUpdateNotifications
{
	NSString *updateNotificationName;

	if ((updateNotificationName = [self _updateNotificationName]) != nil)
	{
		// App notifications
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_handleUpdateNotification:) name:updateNotificationName object:nil];

		// IPC notifications
		_rateLimiter = [[OCRateLimiter alloc] initWithMinimumTime:0.05];

		[[OCIPNotificationCenter sharedNotificationCenter] addObserver:self forName:updateNotificationName withHandler:^(OCIPNotificationCenter * _Nonnull notificationCenter, OCKeyValueStore *keyValueStore, OCIPCNotificationName  _Nonnull notificationName) {
			[keyValueStore updateFromStoreContentsAtURL:keyValueStore.url];
		}];
	}
}

- (void)_teardownUpdateNotifications
{
	NSString *updateNotificationName;

	if ((updateNotificationName = [self _updateNotificationName]) != nil)
	{
		// IPC notifications
		[[OCIPNotificationCenter sharedNotificationCenter] removeObserver:self forName:updateNotificationName];

		// App notifications
		[[NSNotificationCenter defaultCenter] removeObserver:self name:updateNotificationName object:nil];
	}
}

- (void)_postUpdateNotifications
{
	NSString *updateNotificationName;

	if ((updateNotificationName = [self _updateNotificationName]) != nil)
	{
		// App notifications
		[[NSNotificationCenter defaultCenter] postNotificationName:updateNotificationName object:self];

		// IPC notifications
		[_rateLimiter runRateLimitedBlock:^{
			[[OCIPNotificationCenter sharedNotificationCenter] postNotificationForName:updateNotificationName ignoreSelf:YES];
		}];
	}
}

- (void)_handleUpdateNotification:(NSNotification *)notification
{
	if (notification.object != self)
	{
		[self updateFromStoreContentsAtURL:self.url];
	}
}

#pragma mark - Read and modify store
- (OCKeyValueStoreDictionary)_readStoreContentsAtURL:(NSURL *)url
{
	OCKeyValueStoreDictionary storeContents = nil;

	if (url != nil)
	{
		NSData *data;

		if ((data = [[NSData alloc] initWithContentsOfURL:url]) != nil)
		{
			NSError *error = nil;
			storeContents = [NSKeyedUnarchiver unarchivedObjectOfClasses:[[NSSet alloc] initWithObjects:[NSMutableDictionary class], [OCKeyValueRecord class], [NSString class], nil] fromData:data error:&error];

			// ~~ Temporarily remove secure coding checks until all secure coding compliant OC classes have unit tests verifiying their secure coding implementations does not loose any data ~~
			// storeContents = [NSKeyedUnarchiver unarchiveTopLevelObjectWithData:data error:&error];
			//
			// if ((storeContents != nil) && ![storeContents isKindOfClass:[NSMutableDictionary class]])
			// {
			// 	OCLogError(@"Store contents not a NSMutableDictionary, but instead a %@", NSStringFromClass(storeContents.class));
			// 	storeContents = [NSMutableDictionary new];
			// }

			if (storeContents == nil)
			{
				OCLogError(@"Error deserializing store contents: %@", error);
			}
		}
	}

	return (storeContents);
}

- (void)_updateFromStoreContents:(OCKeyValueStoreDictionary)latestStoreContents
{
	if (latestStoreContents != nil)
	{
		NSMutableArray<OCKeyValueStoreKey> *changedKeys = nil;
		NSMutableArray<OCKeyValueStoreKey> *removedKeys = nil;

		// Find updated and new keys
		for (OCKeyValueStoreKey key in latestStoreContents)
		{
			OCKeyValueRecord *latestRecord = latestStoreContents[key];
			OCKeyValueRecord *currentRecord;
			BOOL changed = NO;

			if ((currentRecord = _recordsByKey[key]) != nil)
			{
				if ([currentRecord updateFromRecord:latestRecord])
				{
					// record for key was updated
					changed = YES;
				}
			}
			else
			{
				// record for new key was added
				_recordsByKey[key] = latestRecord;

				changed = YES;
			}

			if (changed)
			{
				if (changedKeys == nil) { changedKeys = [NSMutableArray new]; }
				[changedKeys addObject:key];
			}
		}

		// Find removed keys
		for (OCKeyValueStoreKey key in _recordsByKey)
		{
			if (latestStoreContents[key] == nil)
			{
				if (changedKeys == nil) { changedKeys = [NSMutableArray new]; }
				[changedKeys addObject:key];

				if (removedKeys == nil) { removedKeys = [NSMutableArray new]; }
				[removedKeys addObject:key];
			}
		}

		if (removedKeys != nil)
		{
			[_recordsByKey removeObjectsForKeys:removedKeys];
		}

		// Notify observers
		for (OCKeyValueStoreKey key in changedKeys)
		{
			[self notifyObserversOfNewValueForKey:key];
		}
	}
}

- (void)updateFromStoreContentsAtURL:(NSURL *)url
{
	__weak OCKeyValueStore *weakSelf = self;

	[_coordinationQueue addOperationWithBlock:^{
		NSError *error = nil;
		OCKeyValueStore *strongSelf = weakSelf;

		if (strongSelf == nil) { return; }

		OCBackgroundTask *backgroundTask = [[OCBackgroundTask backgroundTaskWithName:@"OCKeyValueStore updateFromStoreContentsAtURL" expirationHandler:^(OCBackgroundTask * _Nonnull task) {
			OCLogWarning(@"%@ background task expired", task.name);
			[task end];
		}] start];

		[strongSelf->_coordinator coordinateReadingItemAtURL:url options:0 error:&error byAccessor:^(NSURL * _Nonnull newURL) {
			// OCLogDebug(@"Read from %@", newURL);

			OCKeyValueStore *strongSelf = weakSelf;

			if (strongSelf == nil) { return; }

			if ([[NSFileManager defaultManager] fileExistsAtPath:newURL.path])
			{
				// File exists, read and apply updates
				OCKeyValueStoreDictionary latestStoreContents;

				if ((latestStoreContents = [strongSelf _readStoreContentsAtURL:url]) != nil)
				{
					[strongSelf _updateFromStoreContents:latestStoreContents];
				}
			}
			else
			{
				// No file, initiate a new dictionary
				[strongSelf _updateFromStoreContents:[NSMutableDictionary new]];

				OCWTLogError(nil, @"File doesn't exist at %@", newURL);
			}
		}];

		[backgroundTask end];
	}];
}

- (void)updateStoreContentsWithModifications:(BOOL(^)(OCKeyValueStoreDictionary storeContents))modifier completionHandler:(dispatch_block_t)inCompletionHandler
{
	[_coordinationQueue addOperationWithBlock:^{
		NSError *error = nil;

		OCBackgroundTask *backgroundTask = [[OCBackgroundTask backgroundTaskWithName:@"OCKeyValueStore updateStoreContentsWithModifications" expirationHandler:^(OCBackgroundTask * _Nonnull task) {
			OCLogWarning(@"%@ background task expired", task.name);
			[task end];
		}] start];

		[self->_coordinator coordinateReadingItemAtURL:self.url options:0 writingItemAtURL:self.url options:NSFileCoordinatorWritingForReplacing error:&error byAccessor:^(NSURL * _Nonnull newReadingURL, NSURL * _Nonnull newWritingURL) {
			OCKeyValueStoreDictionary latestStoreContents;
			dispatch_block_t completionHandler = inCompletionHandler;

			// OCLog(@"Read from %@, write to %@", newReadingURL, newWritingURL);

			// Read the latest store contents
			if ((latestStoreContents = [self _readStoreContentsAtURL:newReadingURL]) == nil)
			{
				// Create new one if none exists yet
				latestStoreContents = [NSMutableDictionary new];
			}

			if (latestStoreContents != nil)
			{
				// Apply modification
				if (modifier(latestStoreContents))
				{
					// Save
					NSData *storeContentsData = nil;

					if ((storeContentsData = [NSKeyedArchiver archivedDataWithRootObject:latestStoreContents]) != nil)
					{
						[storeContentsData writeToURL:newWritingURL atomically:YES];
					}

					// Update local copy
					[self _updateFromStoreContents:latestStoreContents];

					dispatch_block_t postCompletionHandler = completionHandler;
					completionHandler = nil;

					[self->_coordinationQueue addOperationWithBlock: ^{
						// OCLogDebug(@"Post notification");
						[self _postUpdateNotifications];

						if (postCompletionHandler != nil)
						{
							postCompletionHandler();
						}
					}];
				}
				else
				{
					// Make sure there's a copy at newWritingURL
					if (![newReadingURL isEqual:newWritingURL])
					{
						NSError *error = nil;

						if (![[NSFileManager defaultManager] copyItemAtURL:newReadingURL toURL:newWritingURL error:&error])
						{
							OCLogError(@"Error copying file after not making changes: %@", error);
						}
					}
				}
			}

			if (completionHandler != nil)
			{
				completionHandler();
			}
		}];

		[backgroundTask end];
	}];
}

#pragma mark - Log tags
+ (NSArray<OCLogTagName> *)logTags
{
	return (@[@"KeyValueStore"]);
}

- (NSArray<OCLogTagName> *)logTags
{
	return (@[@"KeyValueStore"]);
}

@end
