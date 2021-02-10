//
//  OCLockManager.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 04.02.21.
//  Copyright © 2021 ownCloud GmbH. All rights reserved.
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

#import "OCLockManager.h"
#import "OCLockRequest.h"
#import "OCAppIdentity.h"

#pragma mark - Database helper

@interface OCLockDatabase : NSObject <NSSecureCoding>
@property(strong) NSMutableDictionary<OCLockResourceIdentifier, OCLock *> *lockByResourceIdentifier;
@end

@implementation OCLockDatabase

- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_lockByResourceIdentifier = [NSMutableDictionary new];
	}

	return (self);
}

+ (BOOL)supportsSecureCoding
{
	return (YES);
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
	if ((self = [super init]) != nil)
	{
		_lockByResourceIdentifier = [coder decodeObjectOfClasses:[NSSet setWithObjects:NSString.class, NSDictionary.class, OCLock.class, nil] forKey:@"lockByResourceIdentifier"];
	}

	return (self);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:_lockByResourceIdentifier forKey:@"lockByResourceIdentifier"];
}

@end

#pragma mark - Lock manager

@interface OCLockManager ()
{
	OCKeyValueStore *_keyValueStore;

	NSMutableArray<OCLockRequest *> *_requests;

	NSMutableArray<OCLock *> *_locks;
	NSMutableArray<OCLockIdentifier> *_lockIdentifiers;
	NSMutableArray<OCLockIdentifier> *_releasedLockIdentifiers;

	dispatch_queue_t _lockQueue;
	BOOL _needsUpdate;

	BOOL _keepAliveScheduled;
}
@end

@implementation OCLockManager

+ (OCLockManager *)sharedLockManager
{
	static dispatch_once_t onceToken;
	static OCLockManager *sharedLockManager = nil;

	dispatch_once(&onceToken, ^{
		NSURL *lockStoreURL;
		OCKeyValueStore *keyValueStore = nil;

		if ((lockStoreURL = [OCAppIdentity.sharedAppIdentity.appGroupContainerURL URLByAppendingPathComponent:@"lockManager.db"]) != nil)
		{
			keyValueStore = [[OCKeyValueStore alloc] initWithURL:lockStoreURL identifier:@"OCLockManager"];
		}

		sharedLockManager = [[OCLockManager alloc] initWithKeyValueStore:keyValueStore];
	});

	return (sharedLockManager);
}

- (instancetype)initWithKeyValueStore:(OCKeyValueStore *)keyValueStore
{
	if ((self = [super init]) != nil)
	{
		_requests = [NSMutableArray new];

		_locks = [NSMutableArray new];
		_lockIdentifiers = [NSMutableArray new];
		_releasedLockIdentifiers = [NSMutableArray new];

		_lockQueue = dispatch_queue_create("OCLockManager serial queue", DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL);

		// Set up KVS
		_keyValueStore = keyValueStore;

		// Register classes for OCKeyValueStoreKeyManagedLocks
		[_keyValueStore registerClasses:[NSSet setWithObjects: OCLockDatabase.class, OCLock.class, NSDictionary.class, NSString.class, NSArray.class, nil] forKey:OCKeyValueStoreKeyManagedLocks];

		// Add observer for changes to OCKeyValueStoreKeyManagedLocks
		[_keyValueStore addObserver:^(OCKeyValueStore * _Nonnull store, id  _Nullable owner, OCKeyValueStoreKey  _Nonnull key, id  _Nullable newValue) {
			[(OCLockManager *)owner setNeedsLockUpdate];
		} forKey:OCKeyValueStoreKeyManagedLocks withOwner:self initial:NO];
	}

	return (self);
}

- (void)dealloc
{
	OCLogDebug(@"Dealloc %@", self);
}

- (void)requestLock:(OCLockRequest *)lockRequest
{
	@synchronized(_requests)
	{
		[_requests addObject:lockRequest];
	}

	[self setNeedsLockUpdate];
}

- (void)releaseLock:(OCLock *)lock
{
	@synchronized(_locks)
	{
		[_releasedLockIdentifiers addObject:lock.identifier];
		[_lockIdentifiers removeObject:lock.identifier];
		[_locks removeObject:lock];
	}

	[self setNeedsLockUpdate];
}

- (void)setNeedsLockUpdate
{
	BOOL needsUpdate = NO;

	@synchronized(self)
	{
		if (!_needsUpdate)
		{
			_needsUpdate = YES;
			needsUpdate = YES;
		}
	}

	if (needsUpdate)
	{
		dispatch_async(_lockQueue, ^{
			@synchronized(self)
			{
				self->_needsUpdate = NO;
			}

			[self _updateLocks];
		});
	}
}

- (void)_updateLocks
{
	__block NSMutableArray<OCLockRequest *> *processedRequests = nil;
	__block NSDate *nextRelevantExpirationDate = nil;
	NSMutableArray<OCLockIdentifier> *invalidatedLockIdentifiers = nil;

	@synchronized (_locks)
	{
		invalidatedLockIdentifiers = [_lockIdentifiers mutableCopy];
	}

	[_keyValueStore updateObjectForKey:OCKeyValueStoreKeyManagedLocks usingModifier:^id _Nullable(id  _Nullable existingObject, BOOL * _Nonnull outDidModify) {
		OCLockDatabase *database = existingObject;

		if (database == nil)
		{
			database = [OCLockDatabase new];
			*outDidModify = YES;
		}

		OCLogVerbose(@"%@:\n- database: %@\n- requests: %@", self, database.lockByResourceIdentifier, self->_requests);

		// Purge locks
		__block NSMutableArray<OCLockResourceIdentifier> *invalidatedResourceIdentifiers = nil;
		NSMutableArray<OCLockIdentifier> *releasedLockIdentifiers = nil;

		@synchronized(self->_locks)
		{
			if (self->_releasedLockIdentifiers.count > 0)
			{
				releasedLockIdentifiers = self->_releasedLockIdentifiers;
				self->_releasedLockIdentifiers = [NSMutableArray new];
			}
		}

		[database.lockByResourceIdentifier enumerateKeysAndObjectsUsingBlock:^(OCLockResourceIdentifier resourceIdentifier, OCLock *lock, BOOL *stop) {
			BOOL isLocalLock = NO;
			BOOL shouldReleaseLock = NO;

			@synchronized (self->_locks)
			{
				isLocalLock = [self->_lockIdentifiers containsObject:lock.identifier];
			}

			shouldReleaseLock = [releasedLockIdentifiers containsObject:lock.identifier];

			OCLogVerbose(@"Lock for %@ isValid=%d, isLocalLock=%d, shouldReleaseLock=%d", resourceIdentifier, lock.isValid, isLocalLock, shouldReleaseLock);

			if ((!lock.isValid && // Lock is no longer valid ..
			     !isLocalLock) || // .. and none of ours (for which we can then simply do a keepalive, so no need to invalidate)
				// - OR -
			    shouldReleaseLock) // Lock was released
			{
				// Remove from database
				[invalidatedLockIdentifiers addObject:lock.identifier];

				if (invalidatedResourceIdentifiers == nil) { invalidatedResourceIdentifiers = [NSMutableArray new]; }
				[invalidatedResourceIdentifiers addObject:lock.resourceIdentifier];
			}
			else
			{
				// Lock not invalid, if it is one of our own, keep it alive
				if ([invalidatedLockIdentifiers containsObject:lock.identifier])
				{
					if ([lock keepAlive:*outDidModify]) // Force keep alive if any other change has already occured, otherwise use -keepAlive default logic
					{
						*outDidModify = YES;
					}

					[invalidatedLockIdentifiers removeObject:lock.identifier];
				}
			}
		}];

		if (invalidatedResourceIdentifiers != nil)
		{
			[database.lockByResourceIdentifier removeObjectsForKeys:invalidatedResourceIdentifiers];
			*outDidModify = YES;
		}

		// Fulfill requests
		@synchronized(self->_requests)
		{
			for (OCLockRequest *request in self->_requests)
			{
				OCLock *lock = database.lockByResourceIdentifier[request.resourceIdentifier];

				if (lock == nil)
				{
					if (request.invalidated || ((request.lockNeededHandler != nil) && !request.lockNeededHandler(request)))
					{
						// Request processed, schedule for removal
						if (processedRequests == nil) { processedRequests = [NSMutableArray new]; }
						[processedRequests addObject:request];
					}
					else
					{
						// Create lock
						lock = [[OCLock alloc] initWithIdentifier:request.resourceIdentifier];
						lock.manager = self;

						// Add to database
						database.lockByResourceIdentifier[request.resourceIdentifier] = lock;

						// Store in request
						request.lock = lock;

						// Schedule requests for notification and removal
						if (processedRequests == nil) { processedRequests = [NSMutableArray new]; }
						[processedRequests addObject:request];

						*outDidModify = YES;
					}
				}
				else
				{
					if ((nextRelevantExpirationDate == nil) || ((nextRelevantExpirationDate != nil) && (lock.expirationDate.timeIntervalSinceReferenceDate < nextRelevantExpirationDate.timeIntervalSinceReferenceDate)))
					{
						nextRelevantExpirationDate = lock.expirationDate;
					}
				}
			}
		}

		OCLogVerbose(@"Did modify: %d", *outDidModify);

		return (database);
	}];

	// Process request results
	if (processedRequests.count > 0)
	{
		// Remove from requests
		@synchronized (_requests)
		{
			[_requests removeObjectsInArray:processedRequests];
		}

		// Track lock
		@synchronized (_locks)
		{
			for (OCLockRequest *request in processedRequests)
			{
				if (request.lock != nil)
				{
					[_locks addObject:request.lock];
					[_lockIdentifiers addObject:request.lock.identifier];
				}
			}
		}

		// Notify requesters
		for (OCLockRequest *request in processedRequests)
		{
			if ((request.lock != nil) && (request.acquiredHandler != nil))
			{
				request.acquiredHandler(nil, request.lock);
				request.acquiredHandler = nil;
			}
		}
	}

	// Invalidated locks
	BOOL hasLocks = NO;

	@synchronized(_locks)
	{
		if (invalidatedLockIdentifiers.count > 0)
		{
			NSMutableArray<OCLock *> *invalidatedLocks = [NSMutableArray new];

			// Determine invalidated locks
			for (OCLock *lock in _locks)
			{
				if ([invalidatedLockIdentifiers containsObject:lock.identifier])
				{
					[invalidatedLocks addObject:lock];
				}
			}

			// Remove & notify expiration handlers
			for (OCLock *lock in invalidatedLocks)
			{
				if (lock.expirationHandler != nil)
				{
					lock.expirationHandler();
					lock.expirationHandler = nil;
				}

				[_locks removeObject:lock];
				[_lockIdentifiers removeObject:lock.identifier];
			}
		}

		hasLocks = (_locks.count > 0);
	}

	if (nextRelevantExpirationDate != nil)
	{
		NSTimeInterval expirationCheckTimeInterval = nextRelevantExpirationDate.timeIntervalSinceNow;

		if (expirationCheckTimeInterval < 0) { expirationCheckTimeInterval = 0.1; }

		__weak OCLockManager *weakSelf = self;

		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(expirationCheckTimeInterval * NSEC_PER_SEC)), _lockQueue, ^{
			OCWLogVerbose(@"Checking for locks due to expire at %@", nextRelevantExpirationDate);
			[weakSelf setNeedsLockUpdate];
		});
	}

	if (hasLocks)
	{
		@synchronized(self)
		{
			if (!_keepAliveScheduled)
			{
				_keepAliveScheduled = YES;

				__weak OCLockManager *weakSelf = self;

				// Schedule a keep-alive after half the time to expiration
				dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((OCLockExpirationInterval / 2.0) * NSEC_PER_SEC)), _lockQueue, ^{
					OCLockManager *strongSelf;

					if ((strongSelf = weakSelf) != nil)
					{
						BOOL doUpdate = NO;

						@synchronized(strongSelf)
						{
							strongSelf->_keepAliveScheduled = NO;

							if (!strongSelf->_needsUpdate) // Do not update locks if an update is imminent anyway
							{
								doUpdate = YES;
							}
						}

						OCWLogVerbose(@"Keeping locks alive: %d", doUpdate);

						if (doUpdate)
						{
							[strongSelf _updateLocks];
						}
					}
				});
			}
		}
	}
}

@end

OCKeyValueStoreKey OCKeyValueStoreKeyManagedLocks = @"managedLocks";
