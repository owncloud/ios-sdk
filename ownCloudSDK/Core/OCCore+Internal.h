//
//  OCCore+Internal.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 04.04.18.
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

#import "OCCore.h"
#import "OCCoreItemListTask.h"
#import "OCShareQuery.h"

@interface OCCore (Internal)

#pragma mark - Managed
- (void)setIsManaged:(BOOL)isManaged;

#pragma mark - Queue
- (void)queueBlock:(dispatch_block_t)block;
- (void)queueBlock:(dispatch_block_t)block allowInlining:(BOOL)allowInlining;
- (void)queueConnectivityBlock:(dispatch_block_t)block;

#pragma mark - Busy count
- (void)beginActivity:(NSString *)description; //!< Indicates an activity has been started that needs to finish before the core can be stopped (description only for debugging purposes, should match the one in -endActivity:)
- (void)endActivity:(NSString *)description; //!< Indicates an activity has stopped that needed to be finished before the core could be stopped (description only for debugging purposes, should match the one in -beginActivity:)

#pragma mark - Convenience
- (OCDatabase *)database;

#pragma mark - Sync Engine
- (void)queueSyncEvent:(OCEvent *)event sender:(id)sender;

#pragma mark - Event target tools
- (OCEventTarget *)_eventTargetWithCoreSelector:(SEL)selector userInfo:(NSDictionary *)userInfo ephermalUserInfo:(NSDictionary *)ephermalUserInfo;

#pragma mark - Attempt Connect
- (void)_attemptConnect;

#pragma mark - Inter-Process change notification/handling
- (void)postIPCChangeNotification;
- (void)_checkForChangesByOtherProcessesAndUpdateQueries;
- (void)_replayChangesSinceSyncAnchor:(OCSyncAnchor)fromSyncAnchor;

#pragma mark - Share queries
- (void)startShareQuery:(OCShareQuery *)shareQuery;
- (void)reloadShareQuery:(OCShareQuery *)shareQuery;
- (void)stopShareQuery:(OCShareQuery *)shareQuery;

- (void)_pollNextShareQuery;

@end
