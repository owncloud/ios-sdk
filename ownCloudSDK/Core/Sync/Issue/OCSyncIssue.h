//
//  OCSyncIssue.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 19.12.18.
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
#import "OCIssue.h"
#import "OCSyncIssueChoice.h"
#import "OCTypes.h"
#import "OCEvent.h"

@class OCSyncRecord;
@class OCWaitConditionIssue;

NS_ASSUME_NONNULL_BEGIN

@interface OCSyncIssue : NSObject <NSSecureCoding>

@property(strong,nullable) OCSyncRecordID syncRecordID;

@property(readonly,strong) NSDate *creationDate;
@property(readonly,strong) NSUUID *uuid;

@property(assign) OCIssueLevel level;

@property(strong) NSString *localizedTitle;
@property(nullable,strong) NSString *localizedDescription;

@property(nullable,strong) NSDictionary<NSString*, id<NSSecureCoding>> *metaData;

@property(strong) NSArray <OCSyncIssueChoice *> *choices;

+ (instancetype)issueForSyncRecord:(OCSyncRecord *)syncRecord level:(OCIssueLevel)level title:(NSString *)title description:(nullable NSString *)description metaData:(nullable NSDictionary<NSString*, id<NSSecureCoding>> *)metaData choices:(NSArray <OCSyncIssueChoice *> *)choices;

- (OCWaitConditionIssue *)makeWaitCondition; //!< Makes a wait condition wrapping the issue

@end

extern OCEventUserInfoKey OCEventUserInfoKeySyncIssue;

NS_ASSUME_NONNULL_END
