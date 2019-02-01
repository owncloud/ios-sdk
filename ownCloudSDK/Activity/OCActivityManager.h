//
//  OCActivityManager.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 25.01.19.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2019, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import <Foundation/Foundation.h>
#import "OCActivity.h"
#import "OCLogTag.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCActivityManager : NSObject <OCLogTagging>

#pragma mark - Init
- (instancetype)initWithUpdateNotificationName:(NSString *)updateNotificationName;

#pragma mark - Update notifications
@property(readonly,nonatomic) NSNotificationName activityUpdateNotificationName;

#pragma mark - Access
@property(readonly,nonatomic) NSArray <OCActivity *> *activities;
- (nullable OCActivity *)activityForIdentifier:(OCActivityIdentifier)activityIdentifier;

#pragma mark - Updating
- (void)update:(OCActivityUpdate *)update;

@end

extern NSString *OCActivityManagerNotificationUserInfoUpdatesKey; 	  //!< UserInfo key that contains an array of dictionaries providing info on the activity updates:

extern NSString *OCActivityManagerUpdateTypeKey; 	//!< the type of the update [OCActivityUpdateType]
extern NSString *OCActivityManagerUpdateActivityKey; 	//!< the updated activity object [OCActivity]

NS_ASSUME_NONNULL_END
