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

	OCSyncAction _action;
	NSDate *_timestamp;

	OCSyncRecordState _state;
	NSDate *_inProgressSince;
	NSString *_blockedByBundleIdentifier;
	NSNumber *_blockedByPID;
	BOOL _allowsRescheduling;

	NSData *_archivedServerItemData;
	OCItem *_archivedServerItem;

	OCPath _itemPath;

	NSDictionary<OCSyncActionParameter, id> *_parameters;

	OCCoreActionResultHandler _resultHandler;
}

@property(strong) OCSyncRecordID recordID; //!< OCDatabase-specific ID referencing the sync record in the database (ephermal)

@property(readonly) OCSyncAction action; //!< The action
@property(readonly) NSDate *timestamp; //!< Time the action was triggered

@property(assign,nonatomic) OCSyncRecordState state; //!< Current processing state
@property(strong) NSDate *inProgressSince; //!< Time since which the action is being executed
@property(strong) NSString *blockedByBundleIdentifier; //!< If state==OCSyncRecordStateAwaitingUserInteraction, the bundle identifier of the app responsible for it.
@property(strong) NSNumber *blockedByPID; //!< If state==OCSyncRecordStateAwaitingUserInteraction, the PID of the app responsible for it.
@property(readonly,nonatomic) BOOL blockedByDifferentCopyOfThisProcess; //!< If state==OCSyncRecordStateAwaitingUserInteraction, checks if blockedByBundleIdentifier and blockedByPID match the calling process.
@property(assign) BOOL allowsRescheduling; //!< If YES, the record may be rescheduled if state==OCSyncRecordStateAwaitingUserInteraction.

@property(readonly,nonatomic) OCPath itemPath; //!< the path of the item, drawn from OCSyncActionParameterPath, OCSyncActionParameterItem and OCSyncActionParameterSourcePath (in that order)
@property(readonly,nonatomic) OCItem *item; //!< OCSyncActionParameterItem

@property(readonly,nonatomic) OCItem *archivedServerItem; //!< Archived OCItem describing the (known) server item at the time the record was committed.

@property(strong) NSDictionary<OCSyncActionParameter, id> *parameters; //!< Parameters specific to the respective sync action

@property(copy) OCCoreActionResultHandler resultHandler; //!< Result handler to call after the sync record has been processed. Execution not guaranteed. (ephermal)

@property(strong) NSProgress *progress; //!< Progress object tracking the progress of the action described in the sync record. (ephermal)

- (instancetype)initWithAction:(OCSyncAction)action archivedServerItem:(OCItem *)archivedServerItem parameters:(NSDictionary <OCSyncActionParameter, id> *)parameters resultHandler:(OCCoreActionResultHandler)resultHandler;

+ (instancetype)syncRecordFromSerializedData:(NSData *)serializedData;

- (NSData *)serializedData;

@end

extern OCSyncAction OCSyncActionDeleteLocal; //!< Locally triggered deletion
extern OCSyncAction OCSyncActionDeleteRemote; //!< Remotely triggered deletion
extern OCSyncAction OCSyncActionMove;
extern OCSyncAction OCSyncActionCopy;
extern OCSyncAction OCSyncActionCreateFolder;
extern OCSyncAction OCSyncActionUpload;
extern OCSyncAction OCSyncActionDownload;

extern OCSyncActionParameter OCSyncActionParameterParentItem; // (OCItem *)
extern OCSyncActionParameter OCSyncActionParameterItem; // (OCItem *)
extern OCSyncActionParameter OCSyncActionParameterPath; // (OCPath)
extern OCSyncActionParameter OCSyncActionParameterSourcePath; // (OCPath)
extern OCSyncActionParameter OCSyncActionParameterTargetPath; // (OCPath)
extern OCSyncActionParameter OCSyncActionParameterSourceItem; // (OCItem *)
extern OCSyncActionParameter OCSyncActionParameterTargetItem; // (OCItem *)
extern OCSyncActionParameter OCSyncActionParameterTargetName; // (NSString *)
extern OCSyncActionParameter OCSyncActionParameterRequireMatch; // (NSNumber* (BOOL))
