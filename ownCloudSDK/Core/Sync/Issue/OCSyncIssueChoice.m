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

@dynamic identifier;

+ (instancetype)choiceOfType:(OCIssueChoiceType)type impact:(OCSyncIssueChoiceImpact)impact identifier:(OCSyncIssueChoiceIdentifier)identifier label:(NSString *)label metaData:(NSDictionary<NSString*, id> *)metaData
{
	OCSyncIssueChoice *choice = [self choiceOfType:type identifier:identifier label:label metaData:metaData];

	choice.impact = impact;

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

- (instancetype)withAutoChoiceForError:(NSError *)error
{
	_autoChoiceForError = error;

	return (self);
}

#pragma mark - En-/Decoding
+ (BOOL)supportsSecureCoding
{
	return (YES);
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super initWithCoder:decoder]) != nil)
	{
		_impact = [decoder decodeIntegerForKey:@"impact"];
		_autoChoiceForError = [decoder decodeObjectOfClasses:OCEvent.safeClasses forKey:@"autoChoiceForError"];
	}

	return (self);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[super encodeWithCoder:coder];

	[coder encodeInteger:_impact forKey:@"impact"];
	[coder encodeObject:_autoChoiceForError forKey:@"autoChoiceForError"];
}

#pragma mark - Description
- (NSString *)description
{
	return ([NSString stringWithFormat:@"<%@: %p, identifier: %@, autoChoiceForError: %@, label: %@>", NSStringFromClass(self.class), self, self.identifier, _autoChoiceForError, self.label]);
}

@end

OCSyncIssueChoiceIdentifier OCSyncIssueChoiceIdentifierOK = @"_ok";
OCSyncIssueChoiceIdentifier OCSyncIssueChoiceIdentifierRetry = @"_retry";
OCSyncIssueChoiceIdentifier OCSyncIssueChoiceIdentifierCancel = @"_cancel";
