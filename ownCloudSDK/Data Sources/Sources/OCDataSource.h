//
//  OCDataSource.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 08.03.22.
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

#import <Foundation/Foundation.h>
#import "OCDataTypes.h"
#import "OCDataSourceSubscription.h"
#import "OCDataItemRecord.h"
#import "OCCache.h"

NS_ASSUME_NONNULL_BEGIN

typedef OCDataItemRecord * _Nullable (^OCDataSourceItemRecordForReferenceProvider)(OCDataSource *source, OCDataItemReference itemRef, NSError * _Nullable * _Nullable error);

typedef void(^OCDataSourceItemForReferenceCompletionHandler)(NSError * _Nullable error, OCDataItemRecord * _Nullable record);
typedef void(^OCDataSourceItemForReferenceProvider)(OCDataSource *source, OCDataItemReference itemRef, OCDataItemRecord * _Nullable reuseRecord, OCDataSourceItemForReferenceCompletionHandler completionHandler);

typedef OCDataSource * _Nullable (^OCDataSourceChildDataSourceProvider)(OCDataSource *source, OCDataItemReference itemRef);

typedef void(^OCDataSourceSubscriptionObserver)(OCDataSource *source, id<NSObject> owner, BOOL hasSubscribers);

typedef NS_ENUM(NSInteger, OCDataSourceState)
{
	OCDataSourceStateLoading,
	OCDataSourceStateIdle
};

@interface OCDataSource : NSObject
{
	NSMutableArray<OCDataItemReference> *_itemReferences;
	NSMutableArray<OCDataSourceSubscription *> *_subscriptions;
}

@property(strong) OCDataSourceUUID uuid;
@property(strong,nullable) OCDataSourceType type;

@property(assign) OCDataSourceState state;

@property(readonly,nonatomic) NSUInteger numberOfItems;
@property(strong,nullable) NSDictionary<OCDataSourceSpecialItem, id<OCDataItem>> *specialItems; //!< Headers, Footers, … - !! please note setting this alone does not currently trigger an update, only changes to the data sources itemReferences !! If this is needed in the future, subscriptions also need to track specialItems and their updates. Therefore, if specialItems change alongside content, make sure to update .specialItems BEFORE updating the content.

#pragma mark - Item retrieval
@property(copy,nullable) OCDataSourceItemRecordForReferenceProvider itemRecordForReferenceProvider;
@property(copy,nullable) OCDataSourceItemForReferenceProvider itemForReferenceProvider;

- (nullable OCDataItemRecord *)recordForItemRef:(OCDataItemReference)itemRef error:(NSError * _Nullable * _Nullable)error;
- (void)retrieveItemForRef:(OCDataItemReference)reference reusingRecord:(nullable OCDataItemRecord *)reuseRecord completionHandler:(OCDataSourceItemForReferenceCompletionHandler)completionHandler;

#pragma mark - Caching
- (void)cacheItem:(id<OCDataItem>)item forItemRef:(OCDataItemReference)reference;
- (nullable id<OCDataItem>)cachedItemForItemRef:(OCDataItemReference)reference;

- (void)invalidateCacheForItemRef:(OCDataItemReference)reference;
- (void)invalidateCache;

#pragma mark - Children
@property(copy,nullable) OCDataSourceChildDataSourceProvider childDataSourceProvider;
- (nullable OCDataSource *)dataSourceForChildrenOfItemReference:(OCDataItemReference)itemRef;

#pragma mark - Managing subscriptions
- (OCDataSourceSubscription *)subscribeWithUpdateHandler:(OCDataSourceSubscriptionUpdateHandler)updateHandler onQueue:(nullable dispatch_queue_t)updateQueue trackDifferences:(BOOL)trackDifferences performIntialUpdate:(BOOL)performIntialUpdate; //!< Subscribes for updates to the datasource. The subscription needs to be explicitely terminated when no longer used. The subscription does NOT auto-terminate by the release of all strong references to it.
- (OCDataSourceSubscription *)associateWithUpdateHandler:(OCDataSourceSubscriptionUpdateHandler)updateHandler onQueue:(dispatch_queue_t)updateQueue trackDifferences:(BOOL)trackDifferences performIntialUpdate:(BOOL)performIntialUpdate; //!< Like subscribeWithUpdateHandler, but for subscriptions feeding other data sources. Do not use this API unless you implement a new data source type.
- (void)terminateSubscription:(OCDataSourceSubscription *)subscription; //!< Terminates a subscription. Calling OCDataSourceSubscription.terminate() is preferred.

#pragma mark - Observing subscriptions
- (void)addSubscriptionObserver:(OCDataSourceSubscriptionObserver)subscriptionObserver withOwner:(id)owner performInitial:(BOOL)performInitial; //!< Observes the subscription status of the data source and calls the provided block with the result of (subscriberCount > 0) when ever that result changes
- (void)removeSubscriptionObserverForOwner:(id<NSObject>)owner; //!< Removes the subscription observer for the owner. Performed automatically when owner is deallocated.

#pragma mark - Managing content
- (void)setItemReferences:(nullable NSArray<OCDataItemReference> *)itemRefs updated:(nullable NSSet<OCDataItemReference> *)updatedItemRefs;
- (void)signalUpdatesForItemReferences:(nullable NSSet<OCDataItemReference> *)updatedItemRefs;

#pragma mark - Synchronization
@property(strong,nullable) dispatch_group_t synchronizationGroup; //!< If the contents of several data sources should be updated "atomically", notifications need to be withheld until the last data source has completed updating. Providing this dispatch group allows synchronization of change notifications across data sources. The synchronizationGroup is only used for subscriptions with an .updateQueue. A warning is logged otherwise.

@end

extern OCDataSourceSpecialItem OCDataSourceSpecialItemHeader;
extern OCDataSourceSpecialItem OCDataSourceSpecialItemFooter;

extern OCDataSourceSpecialItem OCDataSourceSpecialItemRootItem;
extern OCDataSourceSpecialItem OCDataSourceSpecialItemFolderStatistics;

NS_ASSUME_NONNULL_END

