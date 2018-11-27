//
//  OCCoreManager.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 08.06.18.
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
#import "OCCore.h"

typedef void(^OCCoreManagerOfflineOperation)(OCBookmark *bookmark, dispatch_block_t completionHandler); //!< Block performing an operation while no OCCore uses the bookmark. Call completionHandler when done.

@interface OCCoreManager : NSObject
{
	NSMutableDictionary <NSUUID *, OCCore *> *_coresByUUID;
	NSMutableDictionary <NSUUID *, NSNumber *> *_requestCountByUUID;

	NSMutableDictionary <NSUUID *, NSMutableArray<OCCoreManagerOfflineOperation> *> *_queuedOfflineOperationsByUUID;
	NSMutableDictionary <NSUUID *, NSNumber *> *_runningOfflineOperationByUUID;

	BOOL _postFileProviderNotifications;
}

#pragma mark - Shared instance
@property(class, readonly, strong, nonatomic) OCCoreManager *sharedCoreManager;

@property(assign) BOOL postFileProviderNotifications;
@property(assign,nonatomic) OCCoreMemoryConfiguration memoryConfiguration;

#pragma mark - Requesting and returning cores
- (OCCore *)requestCoreForBookmark:(OCBookmark *)bookmark completionHandler:(void (^)(OCCore *core, NSError *error))completionHandler; //!< Request the core for this bookmark. The core is started as the first user requests it. The core has completed starting once the completionHandler was called.

- (void)returnCoreForBookmark:(OCBookmark *)bookmark completionHandler:(dispatch_block_t)completionHandler; //!< Return the core for this bookmark. If all users have returned the core, it is stopped.

#pragma mark - Background session recovery
- (void)handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(dispatch_block_t)completionHandler; //!< Call this from -[UIApplicationDelegate application:handleEventsForBackgroundURLSession:completionHandler:].

#pragma mark - Scheduling offline operations on cores
- (void)scheduleOfflineOperation:(OCCoreManagerOfflineOperation)offlineOperation forBookmark:(OCBookmark *)bookmark; //!< Schedules an offline operation on a bookmark. Executed only when no core is using the bookmark.

@end
