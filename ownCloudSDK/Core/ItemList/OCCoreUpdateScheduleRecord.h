//
//  OCCoreUpdateScheduleRecord.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 27.09.21.
//  Copyright © 2021 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2021, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import <Foundation/Foundation.h>
#import "OCAppIdentity.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCCoreUpdateScheduleRecord : NSObject <NSSecureCoding>
{
	NSMutableDictionary<OCAppComponentIdentifier, NSDate *> *_lastTimestampByComponents;
}

@property(class,strong,nonatomic,readonly) NSArray<OCAppComponentIdentifier> *prioritizedComponents;

@property(strong,nullable) NSString *lastCheckComponent;
@property(strong,nullable) NSDate *lastCheckBegin;
@property(strong,nullable) NSDate *lastCheckEnd;

@property(assign) NSTimeInterval pollInterval;

@property(readonly,strong,nullable) NSDictionary<OCAppComponentIdentifier, NSDate *> *lastTimestampByComponents;

- (void)beginCheck;
- (void)endCheck;

- (void)updateComponentTimestamp;

- (nullable NSDate *)nextDateByBeginAndEndDate;
- (nullable NSDate *)nextDateByPrioritizedComponents:(NSString * _Nullable * _Nullable)outComponent;

//- (nullable NSDate *)nextUpdateAttemptDate; //!< Returns the date at which to re-attempt updating. If updating should be attempted immediately, returns nil.

@end

NS_ASSUME_NONNULL_END
