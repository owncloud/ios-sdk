//
//  OCDataSourceSubscription.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 15.03.22.
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
#import "OCDataSourceSnapshot.h"

@class OCDataSourceSnapshot;
@class OCDataSourceSubscription;

NS_ASSUME_NONNULL_BEGIN

typedef void(^OCDataSourceSubscriptionUpdateHandler)(OCDataSourceSubscription *subscription);

@interface OCDataSourceSubscription : NSObject
{
	NSMutableArray<OCDataItemReference> *_itemRefs;
	NSMutableSet<OCDataItemReference> *_addedItemRefs;
	NSMutableSet<OCDataItemReference> *_updatedItemRefs;
	NSMutableSet<OCDataItemReference> *_removedItemRefs;

	BOOL _needsUpdateHandling;
}

@property(class,strong,readonly,nonatomic) dispatch_queue_t defaultUpdateQueue;

@property(weak,nullable) OCDataSource *source;

@property(strong,nullable) dispatch_queue_t updateQueue;
@property(copy,nullable) OCDataSourceSubscriptionUpdateHandler updateHandler;

@property(assign) BOOL trackDifferences;

@property(assign) BOOL terminated;

- (instancetype)initWithSource:(OCDataSource *)source trackDifferences:(BOOL)trackDifferences itemReferences:(nullable NSArray<OCDataItemReference> *)itemRefs updateHandler:(OCDataSourceSubscriptionUpdateHandler)updateHandler onQueue:(nullable dispatch_queue_t)updateQueue;

- (BOOL)hasChangesSinceLastTrackingReset; //!< Returns YES if changes have occured since the last snapshot with change tracking reset. Returns NO otherwise. Will always return NO if .trackDifferences = NO or .terminated = YES.
- (OCDataSourceSnapshot *)snapshotResettingChangeTracking:(BOOL)resetChangeTracking; //!< Returns a snapshot. Added/Updated/Removed items are only filled if .trackDifferences = YES. Pass YES for resetChangeTracking to reset the change tracking. If you pass NO, changes will continue to accumulate.
- (void)terminate; //!< Terminates the subscription. When this call returns, .updateHandler will no longer be called.

@end

NS_ASSUME_NONNULL_END
