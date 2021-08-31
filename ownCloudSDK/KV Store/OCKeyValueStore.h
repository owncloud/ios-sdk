//
//  OCKeyValueStore.h
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

/*
	OCKeyValueStore features:
	- extremely lightweight
	- persists values to disk
		- single value: persistant storage
		- protected value updates
			- allows to work on objects in a context protecting against changes from other processes / threads
		- "stacks": allows stacking values conditionally:
			- validity / life-time limited by OCClaim (value is ignored, if OCClaim is no longer valid)
			- only the most recent, valid value is returned
			- allows usage for f.ex. recording process lifetime-bound locks on shared resources
	- keeps values in-sync cross-process
	- allows registering for changes

	Internals:
	- stored as a single file, structured as
		{
			key : {
				lastUpdated : [NSDate],
				seed : [NSUInteger]
				type : [value | stack],

				data : [data of value],
				stack : [ {
					claim : [OCClaim],
					data : [data of value]
 					}
				]
 			}
 		}
	- lastUpdated or seed values are used to indicate and detect changes
	- file observed for changes via NSNotificationCenter/OCIPNotificationCenter (rate-limited), re-read and parsed when a change occurs
	- uses NSFileCoordinator to protect against corruption, to coordinate concurrent changes and allow efficient bulk updates
*/

#import <Foundation/Foundation.h>
#import "OCLogTag.h"
#import "OCClaim.h"

NS_ASSUME_NONNULL_BEGIN

typedef NSString* OCKeyValueStoreIdentifier;
typedef NSString* OCKeyValueStoreKey NS_TYPED_ENUM;
typedef NSString* OCKeyValueStoreCollectionEntryID;

@class OCKeyValueStore;

typedef void(^OCKeyValueStoreObserver)(OCKeyValueStore *store, id _Nullable owner, OCKeyValueStoreKey key, id _Nullable newValue);

@interface OCKeyValueStore : NSObject <OCLogTagging>

@property(strong,readonly,nullable) OCKeyValueStoreIdentifier identifier;
@property(strong,readonly) NSURL *url;

#pragma mark - Fallback
+ (NSSet<Class> *)fallbackClasses; //!< Classes to use for decoding if no class has been registered for a key. Safe "Property List" classes + NSSet by default.

#pragma mark - Global class registrations
+ (NSSet<Class> *)registeredClassesForKey:(OCKeyValueStoreKey)key;
+ (void)registerClass:(Class)objectClass forKey:(OCKeyValueStoreKey)key;
+ (void)registerClasses:(NSSet<Class> *)classes forKey:(OCKeyValueStoreKey)key;

#pragma mark - Init
- (instancetype)initWithURL:(NSURL *)url identifier:(nullable OCKeyValueStoreIdentifier)identifier; //!< Creates a new, independent KVS instance.

+ (instancetype)sharedWithURL:(NSURL *)url identifier:(nullable OCKeyValueStoreIdentifier)identifier owner:(nullable id)owner; //!< Returns a shared instance for the URL + identifier combination and keeps it alive as long as at least one "owner" has not yet been deallocated.
- (void)dropSharedFrom:(id)owner; //!< Drops the reference to the messaged KVS shared instance from owner

#pragma mark - Class registration
- (void)registerClasses:(NSSet<Class> *)classes forKey:(OCKeyValueStoreKey)key;
- (void)registerClass:(Class)objectClass forKey:(OCKeyValueStoreKey)key;
- (nullable NSSet<Class> *)registeredClassesForKey:(OCKeyValueStoreKey)key;

#pragma mark - Storing plain values
- (void)storeObject:(nullable id<NSSecureCoding>)object forKey:(OCKeyValueStoreKey)key;

#pragma mark - Atomic value updates
- (void)updateObjectForKey:(OCKeyValueStoreKey)key usingModifier:(id _Nullable(^)(id _Nullable existingObject, BOOL *outDidModify))modifier;

#pragma mark - Storing values in stacks
- (void)pushObject:(nullable id<NSSecureCoding>)object onStackForKey:(OCKeyValueStoreKey)key withClaim:(OCClaim *)claim;
- (void)popObjectWithClaimID:(OCClaimIdentifier)claimIdentifier fromStackForKey:(OCKeyValueStoreKey)key;
- (void)flushStackForKey:(OCKeyValueStoreKey)key;

#pragma mark - Reading values
- (nullable id)readObjectForKey:(OCKeyValueStoreKey)key;

#pragma mark - Observation
- (void)addObserver:(OCKeyValueStoreObserver)observer forKey:(OCKeyValueStoreKey)key withOwner:(id)owner initial:(BOOL)initial;
- (void)removeObserverForOwner:(id)owner forKey:(OCKeyValueStoreKey)key;

@end

NS_ASSUME_NONNULL_END
