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
#import "OCMessage.h"
#import "OCMessageTemplate.h"

@class OCSyncRecord;
@class OCWaitConditionIssue;

NS_ASSUME_NONNULL_BEGIN

typedef NSUUID* OCSyncIssueUUID;
typedef NSDictionary<NSString*,id<NSSecureCoding>>* OCSyncIssueMetadata;
typedef NSDictionary<NSString*,id<NSSecureCoding>>* OCSyncIssueRoutingInfo;

@interface OCSyncIssue : NSObject <NSSecureCoding>

@property(strong,nullable) OCSyncRecordID syncRecordID;
@property(strong,nullable) OCEventTarget *eventTarget;

@property(readonly,strong) NSDate *creationDate;
@property(readonly,strong) OCSyncIssueUUID uuid;

@property(assign) OCIssueLevel level;

@property(strong) NSString *localizedTitle;
@property(nullable,strong) NSString *localizedDescription;

@property(strong,nullable) OCMessageTemplateIdentifier templateIdentifier; //!< Identifier used to categorize the issue

@property(nullable,strong) OCSyncIssueMetadata metaData;

@property(nullable,strong) OCSyncIssueRoutingInfo routingInfo; //!< Internal, do not use

@property(strong) NSArray <OCSyncIssueChoice *> *choices;

#pragma mark - Sync Engine issues
+ (instancetype)issueForSyncRecord:(OCSyncRecord *)syncRecord level:(OCIssueLevel)level title:(NSString *)title description:(nullable NSString *)description metaData:(nullable NSDictionary<NSString*, id<NSSecureCoding>> *)metaData choices:(NSArray <OCSyncIssueChoice *> *)choices;

+ (nullable instancetype)issueFromTemplate:(OCMessageTemplateIdentifier)templateIdentifier forSyncRecord:(OCSyncRecord *)syncRecord level:(OCIssueLevel)level title:(NSString *)title description:(nullable NSString *)description metaData:(nullable NSDictionary<NSString*, id<NSSecureCoding>> *)metaData;

#pragma mark - Other issues
+ (instancetype)issueFromTarget:(nullable OCEventTarget *)eventTarget withLevel:(OCIssueLevel)level title:(NSString *)title description:(nullable NSString *)description metaData:(nullable NSDictionary<NSString*, id<NSSecureCoding>> *)metaData choices:(NSArray <OCSyncIssueChoice *> *)choices;

- (OCSyncIssue *)mapAutoChoiceErrors:(NSDictionary<OCSyncIssueChoiceIdentifier, NSError *> *)choiceToAutoChoiceErrorMap;
- (void)setAutoChoiceError:(NSError *)error forChoiceWithIdentifier:(OCSyncIssueChoiceIdentifier)choiceIdentifier;

- (nullable OCSyncIssueChoice *)choiceWithIdentifier:(OCSyncIssueChoiceIdentifier)choiceIdentifier;

- (OCWaitConditionIssue *)makeWaitCondition; //!< Makes a wait condition wrapping the issue

@end

extern OCEventUserInfoKey OCEventUserInfoKeySyncIssue;

NS_ASSUME_NONNULL_END
