//
//  OCSyncAction.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 06.09.18.
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
#import "OCSyncRecord.h"
#import "OCTypes.h"
#import "OCLogTag.h"
#import "OCSyncIssue.h"
#import "OCWaitCondition.h"

NS_ASSUME_NONNULL_BEGIN

#define OCSyncActionWrapNullableItem(item) ((item != nil) ? item : ((OCItem*)NSNull.null))

@class OCSyncContext;

typedef NS_ENUM(NSUInteger, OCCoreSyncInstruction)
{
	OCCoreSyncInstructionNone,		//!< No instruction (can be used to continue execution - or stop and perform an instruction)

	OCCoreSyncInstructionStop,		//!< Stop processing
	OCCoreSyncInstructionRepeatLast,	//!< Repeat last processing
	OCCoreSyncInstructionDeleteLast,	//!< Delete last processed and process next
	OCCoreSyncInstructionProcessNext	//!< Process next
};

@interface OCSyncAction : NSObject <NSSecureCoding, OCLogTagging, OCLogPrivacyMasking>
{
	OCItem *_archivedServerItem;
	NSData *_archivedServerItemData;
}

#pragma mark - Core properties
@property(weak,nullable) OCCore *core; //!< The core using this sync action.
@property(strong) OCSyncActionIdentifier identifier; //!< Identifier of the action (persisted)
@property(strong) NSArray<OCSyncActionCategory> *categories; //!< Categories this action belongs to.

#pragma mark - Persisted properties
@property(strong) OCItem *localItem; //!< Locally managed OCItem that this action is performed on (persisted)
@property(readonly,nonatomic,nullable) OCItem *archivedServerItem; //!< Archived OCItem describing the (known) server item at the time the action was committed. (persisted)

@property(strong,nullable) NSDictionary<OCSyncActionParameter, id> *parameters; //!< Parameters specific to the respective sync action (persisted)

#pragma mark - Ephermal properties
@property(strong,nullable) NSDictionary<OCSyncActionParameter, id> *ephermalParameters; //!< Parameters specific to the respective sync action (ephermal)

#pragma mark - Sync lane properties
@property(strong,nonatomic,nullable) NSSet<OCSyncLaneTag> *laneTags; //!< Set of lane tags defining the scope of the action (persisted)

#pragma mark - User-facing
@property(strong,nullable,nonatomic) NSString *localizedDescription; //!< Localized description of the sync action (persisted)
@property(assign,nonatomic) OCEventType actionEventType; //!< Event type best describing this sync action (persisted)

#pragma mark - Init
- (instancetype)initWithItem:(OCItem *)item;

#pragma mark - Implementation
- (BOOL)implements:(SEL)featureSelector;

#pragma mark - Preflight and descheduling
- (void)preflightWithContext:(OCSyncContext *)syncContext; 	//!< Preflights an action (i.e. marking an item scheduled for deletion as deleted). Returns an error in OCCoreSyncContext.error in case of failure and to remove the sync record.

- (void)descheduleWithContext:(OCSyncContext *)syncContext;	//!< Performs cleanup at the time a sync record is being descheduled.

#pragma mark - Scheduling
- (OCCoreSyncInstruction)scheduleWithContext:(OCSyncContext *)syncContext;	//!< Schedules network request(s) for an action. Return YES if scheduling worked. Return NO and possibly an error in OCCoreSyncContext.error if not.

#pragma mark - Event handling
- (OCCoreSyncInstruction)handleEventWithContext:(OCSyncContext *)syncContext; 	//!< Entry point for processing events. Routing to -handleResultWithContext: and the sync record's OCWaitConditions as needed.

- (OCCoreSyncInstruction)handleResultWithContext:(OCSyncContext *)syncContext;	//!< Handles the result of an action (usually following receiving an OCEvent). Return YES if the action succeeded and the sync record has been made obsolete by it (=> can be removed). Return NO if the action has not yet completed or succeeded and add OCIssue(s) to OCCoreSyncContext.issues where appropriate.

#pragma mark - Cancellation handling
- (OCCoreSyncInstruction)cancelWithContext:(OCSyncContext *)syncContext; //!< Called when the action is cancelled. Deschedules the record by default.

#pragma mark - Offline coalescation
- (NSError *)updatePreviousSyncRecord:(OCSyncRecord *)syncRecord context:(OCSyncContext *)syncContext; //!< If implemented, is called by the Sync Engine if there's a previous action in the queue targeting the same item. (TODO)
- (NSError *)updateActionWith:(OCItem *(^)(OCSyncContext *syncContext, OCSyncAction *syncAction, OCItem *item))actionUpdater context:(OCSyncContext *)syncContext; //!< Called when an action has not yet been scheduled and a subsequent action is queued on the same item. The actionUpdater block is provided by the subsequent action (TODO)

#pragma mark - Wait condition failure recovery
- (BOOL)recoverFromWaitCondition:(OCWaitCondition *)waitCondition failedWithError:(NSError *)error context:(OCSyncContext *)syncContext; //!< Handles recovery from failed wait conditions. Returns YES if the Sync Engine should proceed processing (skipping removed/descheduled sync records, rerunning updated waitConditions and calling -scheduleWithContext: otherwise).

#pragma mark - Issue handling
- (nullable NSError *)resolveIssue:(OCSyncIssue *)issue withChoice:(OCSyncIssueChoice *)choice context:(OCSyncContext *)syncContext; //!< Handle user choice to resolve an issue. Return nil if the issue has been resolved, an error if it hasn't. The sync record is descheduled if an error is returned.

#pragma mark - Restore progress
- (nullable OCItem *)itemToRestoreProgressRegistrationFor;
- (void)restoreProgressRegistrationForSyncRecord:(OCSyncRecord *)syncRecord; //!< Restores progress registrations

#pragma mark - Lane tags
- (NSMutableSet <OCSyncLaneTag> *)generateLaneTagsFromItems:(NSArray<OCItem *> *)items; //!< Helper method to create lane tags from an array of items. Allow passing NSNull objects to simplify syntax using OCSyncActionWrapNullableItem.
- (NSSet <OCSyncLaneTag> *)generateLaneTags; //!< Called by the -laneTags if no _laneTags is nil.

#pragma mark - Coding / Decoding
- (void)encodeActionData:(NSCoder *)coder;	//!< Called by -encodeWithCoder: to avoid repeated boilerplate code in subclasses. No-op in OCSyncAction, so direct subclasses don't need to call super.
- (void)decodeActionData:(NSCoder *)decoder;	//!< Called by -initWithCoder: to avoid repeated boilerplate code in subclasses. No-op in OCSyncAction, so direct subclasses don't need to call super.

@end

extern OCSyncActionCategory OCSyncActionCategoryAll;		//!< Category for all (actions and transfers alike)
extern OCSyncActionCategory OCSyncActionCategoryActions;	//!< Category for item actions (like delete, move, ..) - default
extern OCSyncActionCategory OCSyncActionCategoryTransfer;	//!< Catagory for file transfers (like upload/download)

NS_ASSUME_NONNULL_END

#import "OCSyncContext.h"
#import "OCCore+SyncEngine.h"
#import "NSError+OCError.h"
#import "OCMacros.h"
#import "NSString+OCParentPath.h"
#import "OCLogger.h"
#import "OCCore+FileProvider.h"
#import "OCFile.h"
