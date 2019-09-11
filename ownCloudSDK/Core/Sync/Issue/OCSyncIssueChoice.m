//
//  OCSyncIssueChoice.m
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

#import "OCSyncIssueChoice.h"
#import "OCMacros.h"
#import "OCEvent.h"

@implementation OCSyncIssueChoice

+ (instancetype)choiceOfType:(OCIssueChoiceType)type impact:(OCSyncIssueChoiceImpact)impact identifier:(OCSyncIssueChoiceIdentifier)identifier label:(NSString *)label metaData:(NSDictionary<NSString*, id> *)metaData
{
	OCSyncIssueChoice *choice = [self new];

	choice.type = type;
	choice.impact = impact;
	choice.identifier = identifier;
	choice.label = label;
	choice.metaData = metaData;

	return (choice);
}

+ (instancetype)okChoice
{
	return ([self choiceOfType:OCIssueChoiceTypeRegular impact:OCSyncIssueChoiceImpactNonDestructive identifier:OCSyncIssueChoiceIdentifierOK label:OCLocalized(@"OK") metaData:nil]);
}

+ (instancetype)retryChoice
{
	return ([self choiceOfType:OCIssueChoiceTypeDefault impact:OCSyncIssueChoiceImpactNonDestructive identifier:OCSyncIssueChoiceIdentifierRetry label:OCLocalized(@"Retry") metaData:nil]);
}

+ (instancetype)cancelChoiceWithImpact:(OCSyncIssueChoiceImpact)impact
{
	return ([self choiceOfType:OCIssueChoiceTypeCancel impact:impact identifier:OCSyncIssueChoiceIdentifierCancel label:OCLocalized(@"Cancel") metaData:nil]);
}

#pragma mark - En-/Decoding
+ (BOOL)supportsSecureCoding
{
	return (YES);
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
	if ((self = [self init]) != nil)
	{
		_type = [decoder decodeIntegerForKey:@"type"];
		_impact = [decoder decodeIntegerForKey:@"impact"];
		_identifier = [decoder decodeObjectOfClass:[NSString class] forKey:@"identifier"];
		_label = [decoder decodeObjectOfClass:[NSString class] forKey:@"label"];
		_metaData = [decoder decodeObjectOfClasses:OCEvent.safeClasses forKey:@"metaData"];
	}

	return (self);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeInteger:_type forKey:@"type"];
	[coder encodeInteger:_impact forKey:@"impact"];
	[coder encodeObject:_identifier forKey:@"identifier"];
	[coder encodeObject:_label forKey:@"label"];
	[coder encodeObject:_metaData forKey:@"metaData"];
}


@end

OCSyncIssueChoiceIdentifier OCSyncIssueChoiceIdentifierOK = @"_ok";
OCSyncIssueChoiceIdentifier OCSyncIssueChoiceIdentifierRetry = @"_retry";
OCSyncIssueChoiceIdentifier OCSyncIssueChoiceIdentifierCancel = @"_cancel";
