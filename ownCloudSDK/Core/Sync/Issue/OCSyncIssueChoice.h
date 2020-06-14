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
#import "OCMessageChoice.h"

NS_ASSUME_NONNULL_BEGIN

typedef OCMessageChoiceIdentifier OCSyncIssueChoiceIdentifier;

typedef NS_ENUM(NSInteger,OCSyncIssueChoiceImpact)
{
	OCSyncIssueChoiceImpactNonDestructive,
	OCSyncIssueChoiceImpactDataLoss
};

@interface OCSyncIssueChoice : OCMessageChoice <NSSecureCoding>

@property(assign) OCSyncIssueChoiceImpact impact;

@property(strong) OCSyncIssueChoiceIdentifier identifier;

@property(nullable,strong) NSError *autoChoiceForError; //!< If a handler can resolve this error, it can pick this option automatically

+ (instancetype)choiceOfType:(OCIssueChoiceType)type impact:(OCSyncIssueChoiceImpact)impact identifier:(OCSyncIssueChoiceIdentifier)identifier label:(NSString *)label metaData:(nullable NSDictionary<NSString*, id<NSSecureCoding>> *)metaData;

+ (instancetype)okChoice;
+ (instancetype)retryChoice; //!< The OCSyncAction default implementation reschedules the record.
+ (instancetype)cancelChoiceWithImpact:(OCSyncIssueChoiceImpact)impact; //!< The OCSyncAction default implementation deschedules the record.

- (instancetype)withAutoChoiceForError:(NSError *)error; //!< See .autoChoiceForError

@end

extern OCSyncIssueChoiceIdentifier OCSyncIssueChoiceIdentifierOK;
extern OCSyncIssueChoiceIdentifier OCSyncIssueChoiceIdentifierRetry;
extern OCSyncIssueChoiceIdentifier OCSyncIssueChoiceIdentifierCancel;

NS_ASSUME_NONNULL_END
