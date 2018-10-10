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

typedef NS_ENUM(NSUInteger, OCSyncRecordState)
{
	OCSyncRecordStatePending,   //!< Sync record pending processing by the sync engine
	OCSyncRecordStateScheduled, //!< Sync record's action has been scheduled and awaits the result and processing
//	OCSyncRecordStateProcessResult, //!< Sync record's action is processing the result
	OCSyncRecordStateAwaitingUserInteraction //!< Sync record's action waits for user interaction
};

@interface OCSyncRecord : NSObject <NSSecureCoding>
{
	OCSyncRecordID _recordID;

	OCSyncActionIdentifier _actionIdentifier;
	OCSyncAction *_action;
	NSDate *_timestamp;

	OCSyncRecordState _state;
	NSDate *_inProgressSince;
	NSString *_blockedByBundleIdentifier;
	NSNumber *_blockedByPID;
	BOOL _allowsRescheduling;

	OCCoreActionResultHandler _resultHandler;
}

#pragma mark - Database ID
@property(strong) OCSyncRecordID recordID; //!< OCDatabase-specific ID referencing the sync record in the database (ephermal)

#pragma mark - Action Definition
@property(readonly) OCSyncActionIdentifier actionIdentifier; //!< The action
@property(strong) OCSyncAction *action; //!< The sync action
@property(readonly) NSDate *timestamp; //!< Time the action was triggered

#pragma mark - Scheduling and processing tracking
@property(assign,nonatomic) OCSyncRecordState state; //!< Current processing state

@property(strong) NSDate *inProgressSince; //!< Time since which the action is being executed

@property(strong) NSString *blockedByBundleIdentifier; //!< If state==OCSyncRecordStateAwaitingUserInteraction, the bundle identifier of the app responsible for it.
@property(strong) NSNumber *blockedByPID; //!< If state==OCSyncRecordStateAwaitingUserInteraction, the PID of the app responsible for it.
@property(readonly,nonatomic) BOOL blockedByDifferentCopyOfThisProcess; //!< If state==OCSyncRecordStateAwaitingUserInteraction, checks if blockedByBundleIdentifier and blockedByPID match the calling process.

@property(assign) BOOL allowsRescheduling; //!< If YES, the record may be rescheduled if state==OCSyncRecordStateAwaitingUserInteraction.

#pragma mark - Result, cancel and progress handling
@property(copy) OCCoreActionResultHandler resultHandler; //!< Result handler to call after the sync record has been processed. Execution not guaranteed. (ephermal)
@property(strong) NSProgress *progress; //!< Progress object tracking the progress of the action described in the sync record. (ephermal)

#pragma - Instantiation
- (instancetype)initWithAction:(OCSyncAction *)action resultHandler:(OCCoreActionResultHandler)resultHandler;

#pragma - Serialization / Deserialization
+ (instancetype)syncRecordFromSerializedData:(NSData *)serializedData;
- (NSData *)serializedData;

#pragma - Progress convenience method
- (void)addProgress:(NSProgress *)progress;

@end

extern OCSyncActionIdentifier OCSyncActionIdentifierDeleteLocal; //!< Locally triggered deletion
extern OCSyncActionIdentifier OCSyncActionIdentifierDeleteRemote; //!< Remotely triggered deletion
extern OCSyncActionIdentifier OCSyncActionIdentifierMove;
extern OCSyncActionIdentifier OCSyncActionIdentifierCopy;
extern OCSyncActionIdentifier OCSyncActionIdentifierCreateFolder;
extern OCSyncActionIdentifier OCSyncActionIdentifierDownload;
extern OCSyncActionIdentifier OCSyncActionIdentifierUpload;
