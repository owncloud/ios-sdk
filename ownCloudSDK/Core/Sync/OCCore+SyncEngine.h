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
#import "OCSyncIssueChoice.h"

@class OCSyncContext;

NS_ASSUME_NONNULL_BEGIN

typedef void(^OCCoreSyncIssueResolutionResultHandler)(OCSyncIssueChoice *choice);

@interface OCCore (SyncEngine)

#pragma mark - Setup & shutdown
- (void)setupSyncEngine;
- (void)shutdownSyncEngine;

#pragma mark - Sync Anchor
- (void)retrieveLatestSyncAnchorWithCompletionHandler:(void(^)(NSError * _Nullable error, OCSyncAnchor latestSyncAnchor))completionHandler;
- (OCSyncAnchor)retrieveLatestSyncAnchorWithError:(NSError * _Nullable __autoreleasing *)outError;

- (OCItem *)retrieveLatestVersionAtPathOfItem:(OCItem *)item withError:(NSError * _Nullable __autoreleasing *)outError;
- (OCItem *)retrieveLatestVersionForLocalIDOfItem:(OCItem *)item withError:(NSError * __autoreleasing *)outError;

- (void)incrementSyncAnchorWithProtectedBlock:(NSError * _Nullable (^)(OCSyncAnchor previousSyncAnchor, OCSyncAnchor newSyncAnchor))protectedBlock completionHandler:(void(^)(NSError * _Nullable error, OCSyncAnchor _Nullable previousSyncAnchor, OCSyncAnchor _Nullable newSyncAnchor))completionHandler;

#pragma mark - Sync Issue handling
- (void)resolveSyncIssue:(OCSyncIssue *)issue withChoice:(OCSyncIssueChoice *)choice userInfo:(nullable NSDictionary<OCEventUserInfoKey, id> *)userInfo completionHandler:(nullable OCCoreSyncIssueResolutionResultHandler)completionHandler;

#pragma mark - Sync Record wakeup
- (void)wakeupSyncRecord:(OCSyncRecordID)syncRecordID waitCondition:(nullable OCWaitCondition *)waitCondition userInfo:(nullable NSDictionary<OCEventUserInfoKey, id> *)userInfo result:(nullable id)result;

#pragma mark - Sync Engine
- (void)performProtectedSyncBlock:(NSError * _Nullable (^)(void))protectedBlock completionHandler:(void(^ _Nullable)(NSError * _Nullable))completionHandler;

#pragma mark - Sync Record Scheduling
- (void)setNeedsToProcessSyncRecords;

- (void)submitSyncRecord:(OCSyncRecord *)record withPreflightResultHandler:(nullable OCCoreCompletionHandler)preflightResultHandler;
- (void)rescheduleSyncRecord:(OCSyncRecord *)syncRecord withUpdates:(NSError * _Nullable (^ _Nullable)(OCSyncRecord *record))applyUpdates;
- (void)descheduleSyncRecord:(OCSyncRecord *)syncRecord completeWithError:(nullable NSError *)completionError parameter:(nullable id)parameter;

@end

@interface OCCore (SyncPrivate)

#pragma mark - Sync issues utilities
- (OCSyncIssue *)_addIssueForCancellationAndDeschedulingToContext:(OCSyncContext *)syncContext title:(NSString *)title description:(NSString *)description impact:(OCSyncIssueChoiceImpact)impact;
- (BOOL)_isConnectivityError:(NSError *)error;

#pragma mark - Sync enqueue utilities
- (nullable NSProgress *)_enqueueSyncRecordWithAction:(OCSyncAction *)action cancellable:(BOOL)cancellable resultHandler:(nullable OCCoreActionResultHandler)resultHandler;
- (nullable NSProgress *)_enqueueSyncRecordWithAction:(OCSyncAction *)action cancellable:(BOOL)cancellable preflightResultHandler:(nullable OCCoreCompletionHandler)preflightResultHandler resultHandler:(nullable OCCoreActionResultHandler)resultHandler;

#pragma mark - Sync action utilities
- (OCEventTarget *)_eventTargetWithSyncRecord:(OCSyncRecord *)syncRecord userInfo:(nullable NSDictionary *)userInfo ephermal:(nullable NSDictionary *)ephermalUserInfo;
- (OCEventTarget *)_eventTargetWithSyncRecord:(OCSyncRecord *)syncRecord;

#pragma mark - Sync record scheduling
- (nullable NSError *)_descheduleSyncRecord:(OCSyncRecord *)syncRecord completeWithError:(nullable NSError *)completionError parameter:(nullable id)parameter;
- (nullable NSError *)_rescheduleSyncRecord:(OCSyncRecord *)syncRecord withUpdates:(NSError * _Nullable (^ _Nullable)(OCSyncRecord *record))applyUpdates;

#pragma mark - Sync record persistence
- (void)addSyncRecords:(NSArray <OCSyncRecord *> *)syncRecords completionHandler:(nullable OCDatabaseCompletionHandler)completionHandler;
- (void)updateSyncRecords:(NSArray <OCSyncRecord *> *)syncRecords completionHandler:(nullable OCDatabaseCompletionHandler)completionHandler;
- (void)removeSyncRecords:(NSArray <OCSyncRecord *> *)syncRecords completionHandler:(nullable OCDatabaseCompletionHandler)completionHandler;
- (void)updatePublishedSyncRecordActivities;

@end

extern OCEventUserInfoKey OCEventUserInfoKeySyncRecordID;

extern OCProgressPathElementIdentifier OCCoreGlobalRootPath;
extern OCProgressPathElementIdentifier OCCoreSyncRecordPath;

extern OCKeyValueStoreKey OCKeyValueStoreKeyOCCoreSyncEventsQueue;

NS_ASSUME_NONNULL_END
