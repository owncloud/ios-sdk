//
//  OCSyncContext.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 15.06.18.
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

@class OCSyncContext;
@class OCSyncIssue;
@class OCWaitCondition;

@interface OCSyncContext : NSObject

// Shared properties (Scheduler + Result Handler)
@property(strong) OCSyncRecord *syncRecord; //!< The sync record to schedule / handle the result for.
@property(strong,nonatomic) NSError *error; //!< Store any errors that occur here.

// Preflight properties
@property(strong) NSArray <OCSyncRecord *> *existingRecords; //!< Other existing records that have the same path and action as the sycnRecord
@property(strong) NSArray <OCSyncRecord *> *removeRecords; //!< After pre-flight, records from .existingRecords that are contained in this array will be removed/descheduled.

// Result Handler properties
@property(strong) OCEvent *event; //!< Event to handle [Result Handler]
@property(strong) OCSyncIssue *issue; //!< Sync issue that should be relayed to the user [Result Handler]

// Item changes properties
@property(strong) NSArray <OCPath>   *refreshPaths;	//!< List of paths for which a refresh should be requested by the Sync Engine
@property(strong) NSArray <OCItem *> *addedItems; 	//!< Newly created items (f.ex. after creating a directory or uploading a file), used to update database and queries
@property(strong) NSArray <OCItem *> *removedItems;  	//!< Removed items (f.ex. after deleting an item), used to update database and queries
@property(strong) NSArray <OCItem *> *updatedItems;  	//!< Updated items (f.ex. after renaming an item), used to update database and queries

@property(assign) BOOL updateStoredSyncRecordAfterItemUpdates; //!< After processing newItems, removedItems, updatedItems (but not refreshPaths), send .syncRecord to the database for updating (NO by default)

// Wait condition collection
@property(strong) NSMutableArray <OCWaitCondition *> *queuedWaitConditions;

#pragma mark - Convenienve initializers
+ (instancetype)preflightContextWithSyncRecord:(OCSyncRecord *)syncRecord;
+ (instancetype)schedulerContextWithSyncRecord:(OCSyncRecord *)syncRecord;
+ (instancetype)descheduleContextWithSyncRecord:(OCSyncRecord *)syncRecord;
+ (instancetype)eventHandlingContextWith:(OCSyncRecord *)syncRecord event:(OCEvent *)event;
+ (instancetype)waitConditionRecoveryContextWith:(OCSyncRecord *)syncRecord;

- (void)addWaitCondition:(OCWaitCondition *)waitCondition;
- (void)addSyncIssue:(OCSyncIssue *)syncIssue;

#pragma mark - State
- (void)transitionToState:(OCSyncRecordState)state withWaitConditions:(nullable NSArray <OCWaitCondition *> *)waitConditions; //!< Convenience method, calling the same method on .syncRecord, but also adding in .queuedWaitConditins and setting updateStoredSyncRecordAfterItemUpdates to YES.

- (void)completeWithError:(nullable NSError *)error core:(OCCore *)core item:(nullable OCItem *)item parameter:(nullable id)parameter; //!< Convenience method, calling the same method on .syncRecord, but also setting updateStoredSyncRecordAfterItemUpdates to YES.

@end
