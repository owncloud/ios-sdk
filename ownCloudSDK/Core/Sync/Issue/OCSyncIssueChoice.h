//
//  OCSyncIssueChoice.h
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
#import "OCIssueChoice.h"

NS_ASSUME_NONNULL_BEGIN

typedef NSString* OCSyncIssueChoiceIdentifier;

typedef NS_ENUM(NSInteger,OCSyncIssueChoiceImpact)
{
	OCSyncIssueChoiceImpactNonDestructive,
	OCSyncIssueChoiceImpactDataLoss
};

@interface OCSyncIssueChoice : NSObject <NSSecureCoding>

@property(assign) OCIssueChoiceType type;
@property(assign) OCSyncIssueChoiceImpact impact;

@property(strong) OCSyncIssueChoiceIdentifier identifier;
@property(strong) NSString *label;

@property(nullable,strong) NSDictionary<NSString*, id<NSSecureCoding>> *metaData;

+ (instancetype)choiceOfType:(OCIssueChoiceType)type impact:(OCSyncIssueChoiceImpact)impact identifier:(OCSyncIssueChoiceIdentifier)identifier label:(NSString *)label metaData:(nullable NSDictionary<NSString*, id<NSSecureCoding>> *)metaData;

+ (instancetype)okChoice;
+ (instancetype)retryChoice; //!< The OCSyncAction default implementation reschedules the record.
+ (instancetype)cancelChoiceWithImpact:(OCSyncIssueChoiceImpact)impact; //!< The OCSyncAction default implementation deschedules the record.

@end

extern OCSyncIssueChoiceIdentifier OCSyncIssueChoiceIdentifierOK;
extern OCSyncIssueChoiceIdentifier OCSyncIssueChoiceIdentifierRetry;
extern OCSyncIssueChoiceIdentifier OCSyncIssueChoiceIdentifierCancel;

NS_ASSUME_NONNULL_END
