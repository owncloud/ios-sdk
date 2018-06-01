//
//  OCCoreItemListTask.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 02.04.18.
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

#import <Foundation/Foundation.h>
#import "OCTypes.h"
#import "OCItem.h"
#import "OCCoreItemList.h"

@class OCCore;
@class OCCoreItemListTask;

typedef NS_ENUM(NSUInteger, OCCoreTaskMergeStatus)
{
	OCCoreTaskMergeStatusWaiting,
	OCCoreTaskMergeStatusMerged
};

typedef void(^OCCoreItemListTaskChangeHandler)(OCCore *core, OCCoreItemListTask *task);

@interface OCCoreItemListTask : NSObject

@property(weak) OCCore *core;
@property(strong) OCPath path;

@property(strong) OCCoreItemList *cachedSet;
@property(strong) OCCoreItemList *retrievedSet;

@property(assign) OCCoreTaskMergeStatus mergeStatus;

@property(strong) NSNumber *syncAnchorAtStart;

@property(copy) OCCoreItemListTaskChangeHandler changeHandler;

- (instancetype)initWithCore:(OCCore *)core path:(OCPath)path;

- (void)update;

- (void)forceUpdateCacheSet;
- (void)forceUpdateRetrievedSet;

@end
