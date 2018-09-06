//
//  OCCoreSyncAction.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 06.09.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "OCCore.h"
#import "OCSyncRecord.h"

NS_ASSUME_NONNULL_BEGIN

@class OCCoreSyncContext;

@interface OCCoreSyncAction : NSObject

@property(weak,nullable) OCCore *core; //!< The core using this sync action.

#pragma mark - Implementation
- (BOOL)implements:(SEL)featureSelector;

#pragma mark - Retrieve existing records (preflight)
- (void)retrieveExistingRecordsForContext:(OCCoreSyncContext *)syncContext; //!< Can be called by -preflightWithContext: to fill syncContext.existingRecords with records of the same action and path

#pragma mark - Preflight and descheduling
- (void)preflightWithContext:(OCCoreSyncContext *)syncContext; 	//!< Preflights an action (i.e. marking an item scheduled for deletion as deleted). Returns an error in OCCoreSyncContext.error in case of failure and to remove the sync record.

- (void)descheduleWithContext:(OCCoreSyncContext *)syncContext;	//!< Performs cleanup at the time a sync record is being descheduled.

#pragma mark - Scheduling and result handling
- (BOOL)scheduleWithContext:(OCCoreSyncContext *)syncContext;	//!< Schedules network request(s) for an action. Return YES if scheduling worked. Return NO and possibly an error in OCCoreSyncContext.error if not.

- (BOOL)handleResultWithContext:(OCCoreSyncContext *)syncContext; //!< Handles the result of an action (usually following receiving an OCEvent). Return YES if the action succeeded and the sync record has been made obsolete by it (=> can be removed). Return NO if the action has not yet completed or succeeded and add OCConnectionIssue(s) to OCCoreSyncContext.issues where appropriate.

@end

NS_ASSUME_NONNULL_END

#import "OCCoreSyncContext.h"
#import "OCCore+SyncEngine.h"
#import "NSError+OCError.h"
#import "OCMacros.h"
#import "NSString+OCParentPath.h"
#import "OCLogger.h"
#import "OCCore+FileProvider.h"
#import "OCFile.h"
