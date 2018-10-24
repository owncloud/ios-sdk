//
//  OCCore+SyncEngine.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 15.05.18.
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
#import "OCSyncRecord.h"

@class OCSyncContext;

@interface OCCore (SyncEngine)

#pragma mark - Sync Anchor
- (void)retrieveLatestSyncAnchorWithCompletionHandler:(void(^)(NSError *error, OCSyncAnchor latestSyncAnchor))completionHandler;
- (OCSyncAnchor)retrieveLatestSyncAnchorWithError:(NSError * __autoreleasing *)outError;

- (OCItem *)retrieveLatestVersionOfItem:(OCItem *)item withError:(NSError * __autoreleasing *)outError;

- (void)incrementSyncAnchorWithProtectedBlock:(NSError *(^)(OCSyncAnchor previousSyncAnchor, OCSyncAnchor newSyncAnchor))protectedBlock completionHandler:(void(^)(NSError *error, OCSyncAnchor previousSyncAnchor, OCSyncAnchor newSyncAnchor))completionHandler;

#pragma mark - Sync Engine
- (void)performProtectedSyncBlock:(NSError *(^)(void))protectedBlock completionHandler:(void(^)(NSError *))completionHandler;

- (NSProgress *)synchronizeWithServer;

#pragma mark - Sync Record Scheduling
- (void)setNeedsToProcessSyncRecords;

- (void)submitSyncRecord:(OCSyncRecord *)record;
- (void)rescheduleSyncRecord:(OCSyncRecord *)syncRecord withUpdates:(NSError *(^)(OCSyncRecord *record))applyUpdates;
- (void)descheduleSyncRecord:(OCSyncRecord *)syncRecord invokeResultHandler:(BOOL)invokeResultHandler withParameter:(id)parameter resultHandlerError:(NSError *)resultHandlerError;

@end

@interface OCCore (SyncPrivate)

#pragma mark - Sync issues utilities
- (OCConnectionIssue *)_addIssueForCancellationAndDeschedulingToContext:(OCSyncContext *)syncContext title:(NSString *)title description:(NSString *)description invokeResultHandler:(BOOL)invokeResultHandler resultHandlerError:(NSError *)resultHandlerError;
- (BOOL)_isConnectivityError:(NSError *)error;

#pragma mark - Sync enqueue utilities
- (NSProgress *)_enqueueSyncRecordWithAction:(OCSyncAction *)action allowsRescheduling:(BOOL)allowsRescheduling resultHandler:(OCCoreActionResultHandler)resultHandler;

#pragma mark - Sync action utilities
- (OCEventTarget *)_eventTargetWithSyncRecord:(OCSyncRecord *)syncRecord userInfo:(NSDictionary *)userInfo ephermal:(NSDictionary *)ephermalUserInfo;
- (OCEventTarget *)_eventTargetWithSyncRecord:(OCSyncRecord *)syncRecord;

@end
