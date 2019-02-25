//
//  OCSyncRecord.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 07.02.18.
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
#import "NSProgress+OCEvent.h"
#import "OCItem.h"
#import "OCTypes.h"
#import "OCCore.h"
#import "OCLogger.h"
#import "OCActivity.h"

NS_ASSUME_NONNULL_BEGIN

@class OCSyncIssue;
@class OCWaitCondition;
@class OCProcessSession;

typedef NS_ENUM(NSInteger, OCSyncRecordState)
{
	OCSyncRecordStatePending,    //!< Sync record is new and has not yet passed preflight
	OCSyncRecordStateReady,      //!< Sync record has passed preflight and is now ready to be processed
	OCSyncRecordStateProcessing, //!< Sync record's action has been scheduled and is processing. Actions can optionally provide a OCWaitCondition to detect failures and allow recovery.
	OCSyncRecordStateCompleted,  //!< Sync record's action has completed and the sync record can be removed
	OCSyncRecordStateFailed	     //!< Sync record's action failed unrecoverably
};

@interface OCSyncRecord : NSObject <NSSecureCoding, OCLogPrivacyMasking, OCActivitySource>
{
	OCSyncRecordID _recordID;
	OCProcessSession *_originProcessSession;

	OCActivityIdentifier _activityIdentifier;

	OCSyncActionIdentifier _actionIdentifier;
	OCSyncAction *_action;
	NSDate *_timestamp;

	OCSyncRecordState _state;
	NSDate *_inProgressSince;

	NSArray <OCWaitCondition *> *_waitConditions;

	NSMutableArray <OCWaitCondition *> *_newWaitConditions;

	OCCoreActionResultHandler _resultHandler;
}

#pragma mark - Database ID
@property(strong,nullable) OCSyncRecordID recordID; //!< OCDatabase-specific ID referencing the sync record in the database (ephermal)
@property(strong,readonly) OCProcessSession *originProcessSession; //!< The process session that this sync record originated in

#pragma mark - Action Definition
@property(readonly) OCSyncActionIdentifier actionIdentifier; //!< The action
@property(strong) OCSyncAction *action; //!< The sync action
@property(readonly) NSDate *timestamp; //!< Time the action was triggered
@property(readonly,nonatomic,nullable) OCLocalID localID; //!< The localID of the item targeted by the action

#pragma mark - Scheduling and processing tracking
@property(readonly,nonatomic) OCSyncRecordState state; //!< Current processing state

@property(strong,nullable) NSDate *inProgressSince; //!< Time since which the action is being executed

@property(strong,nullable) NSArray <OCWaitCondition *> *waitConditions; //!< If state==OCSyncRecordStateProcessing, the conditions that need to be fulfilled before proceeding.

#pragma mark - Result, cancel and progress handling
@property(copy,nullable) OCCoreActionResultHandler resultHandler; //!< Result handler to call after the sync record has been processed. Execution not guaranteed. (ephermal)
@property(strong,nonatomic,nullable) OCProgress *progress; //!< Progress object tracking the progress of the action described in the sync record.

+ (OCActivityIdentifier)activityIdentifierForSyncRecordID:(OCSyncRecordID)recordID;

#pragma mark - Instantiation
- (instancetype)initWithAction:(OCSyncAction *)action resultHandler:(OCCoreActionResultHandler)resultHandler;

#pragma mark - Serialization / Deserialization
+ (instancetype)syncRecordFromSerializedData:(NSData *)serializedData;
- (NSData *)serializedData;

#pragma mark - Wait conditions
- (void)addWaitCondition:(OCWaitCondition *)waitCondition;
- (void)removeWaitCondition:(OCWaitCondition *)waitCondition;

- (nullable OCWaitCondition *)waitConditionForUUID:(NSUUID *)uuid;

#pragma mark - State
- (void)transitionToState:(OCSyncRecordState)state withWaitConditions:(nullable NSArray <OCWaitCondition *> *)waitConditions; //!< Transitions the sync record to a particular state (can be identical with the current one) while replacing the waitConditions with the provided ones. You're responsible from updating the record in the database.

- (void)completeWithError:(nullable NSError *)error core:(OCCore *)core item:(nullable OCItem *)item parameter:(nullable id)parameter; //!< Calls the resultHandler and subsequently drops it. You're responsible from updating the record in the database.

#pragma mark - Progress convenience method
- (void)addProgress:(OCProgress *)progress;

@end

extern OCSyncActionIdentifier OCSyncActionIdentifierDeleteLocal; //!< Locally triggered deletion
extern OCSyncActionIdentifier OCSyncActionIdentifierDeleteRemote; //!< Remotely triggered deletion
extern OCSyncActionIdentifier OCSyncActionIdentifierMove;
extern OCSyncActionIdentifier OCSyncActionIdentifierCopy;
extern OCSyncActionIdentifier OCSyncActionIdentifierCreateFolder;
extern OCSyncActionIdentifier OCSyncActionIdentifierDownload;
extern OCSyncActionIdentifier OCSyncActionIdentifierUpload;
extern OCSyncActionIdentifier OCSyncActionIdentifierUpdate;

extern NSString *OCSyncRecordProgressUserInfoKeySource;

NS_ASSUME_NONNULL_END
