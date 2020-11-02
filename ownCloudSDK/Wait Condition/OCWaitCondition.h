//
//  OCWaitCondition.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 20.12.18.
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
#import "OCEvent.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, OCWaitConditionState)
{
	OCWaitConditionStateWait,	//!< The condition has not yet been made. Continue to wait.
	OCWaitConditionStateProceed,	//!< The condition has been met permanently. Proceed.
	OCWaitConditionStateFail	//!< The condition has failed with an error. Resolve.
};

typedef NSString* OCWaitConditionOption;
typedef NSDictionary<OCWaitConditionOption,id>* OCWaitConditionOptions;
typedef void(^OCWaitConditionEvaluationResultHandler)(OCWaitConditionState state, BOOL conditionUpdated, NSError * _Nullable error);

@interface OCWaitCondition : NSObject <NSSecureCoding>
{
	NSUUID *_uuid;
}

@property(strong,readonly) NSUUID *uuid;
@property(nullable,strong,nonatomic,readonly) NSDate *nextRetryDate;

@property(nullable,strong) NSString *localizedDescription; //!< Localized description of what the wait condition is waiting for, for presentation in status overviews.

- (void)evaluateWithOptions:(nullable OCWaitConditionOptions)options completionHandler:(OCWaitConditionEvaluationResultHandler)completionHandler; //!< Evaluate the condition. Returns the outcome as state + error info.

- (BOOL)handleEvent:(OCEvent *)event withOptions:(OCWaitConditionOptions)options sender:(id)sender; //!< Handle OCEvent directed at this condition. Return NO if the waitCondition did not handle the event, YES if it did.

- (instancetype)withLocalizedDescription:(NSString *)localizedDescription;

@end

extern OCWaitConditionOption OCWaitConditionOptionCore; //!< Instance of OCCore.
extern OCWaitConditionOption OCWaitConditionOptionSyncRecord; //!< Sync Record this wait condition is relating to.
extern OCWaitConditionOption OCWaitConditionOptionSyncContext; //!< Sync Context (during event handling)

extern OCEventUserInfoKey OCEventUserInfoKeyWaitConditionUUID; //!< Key for wait condition UUID inside an OCEvent's userInfo.

NS_ASSUME_NONNULL_END
