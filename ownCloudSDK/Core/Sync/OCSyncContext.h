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

@class OCSyncContext;

typedef void(^OCCoreSyncContextCompletionHandler)(OCCore *core, OCSyncContext *parameterSet);

@interface OCSyncContext : NSObject

// Shared properties (Scheduler + Result Handler)
@property(strong) OCSyncRecord *syncRecord; //!< The sync record to schedule / handle the result for.
@property(strong) NSError *error; //!< Store any errors that occur here.

// Preflight properties
@property(strong) NSArray <OCSyncRecord *> *existingRecords; //!< Other existing records that have the same path and action as the sycnRecord
@property(strong) NSArray <OCSyncRecord *> *removeRecords; //!< After pre-flight, records from .existingRecords that are contained in this array will be removed/descheduled.

// Result Handler properties
@property(strong) OCEvent *event; //!< Event to handle [Result Handler]
@property(strong) NSMutableArray <OCConnectionIssue *> *issues; //!< Any issues that should be relayed to the user [Result Handler]

// Item changes properties
@property(assign) NSArray <OCPath>   *refreshPaths;	//!< List of paths for which a refresh should be requested by the Sync Engine
@property(strong) NSArray <OCItem *> *addedItems; 	//!< Newly created items (f.ex. after creating a directory or uploading a file), used to update database and queries
@property(strong) NSArray <OCItem *> *removedItems;  	//!< Removed items (f.ex. after deleting an item), used to update database and queries
@property(strong) NSArray <OCItem *> *updatedItems;  	//!< Updated items (f.ex. after renaming an item), used to update database and queries

@property(assign) BOOL updateStoredSyncRecordAfterItemUpdates; //!< In preflight, after processing newItems, removedItems, updatedItems (but not refreshPaths), send .syncRecord to the database for updating (NO by default)

// @property(copy) OCCoreSyncContextCompletionHandler completionHandler; //!< Completion handler to be called after processing newItems, removedItems, updatedItems (but not refreshPaths - use a temporary OCQuery if you need the result of these)

#pragma mark - Convenienve initializers
+ (instancetype)preflightContextWithSyncRecord:(OCSyncRecord *)syncRecord;
+ (instancetype)schedulerContextWithSyncRecord:(OCSyncRecord *)syncRecord;
+ (instancetype)descheduleContextWithSyncRecord:(OCSyncRecord *)syncRecord;
+ (instancetype)resultHandlerContextWith:(OCSyncRecord *)syncRecord event:(OCEvent *)event issues:(NSMutableArray <OCConnectionIssue *> *)issues;

- (void)addIssue:(OCConnectionIssue *)issue;

@end
