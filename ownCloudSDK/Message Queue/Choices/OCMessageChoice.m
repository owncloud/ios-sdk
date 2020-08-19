//
//  OCMessageChoice.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 14.06.20.
//  Copyright © 2020 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2020, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCMessageChoice.h"
#import "OCEvent.h"

@implementation OCMessageChoice

+ (instancetype)choiceOfType:(OCIssueChoiceType)type identifier:(OCMessageChoiceIdentifier)identifier label:(NSString *)label metaData:(OCMessageChoiceMetaData)metaData
{
	OCMessageChoice *choice = [self new];

	choice.type = type;
	choice.identifier = identifier;
	choice.label = label;
	choice.metaData = metaData;

	return (choice);
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
		_identifier = [decoder decodeObjectOfClass:[NSString class] forKey:@"identifier"];
		_label = [decoder decodeObjectOfClass:[NSString class] forKey:@"label"];
		_metaData = [decoder decodeObjectOfClasses:OCEvent.safeClasses forKey:@"metaData"];
	}

	return (self);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeInteger:_type forKey:@"type"];
	[coder encodeObject:_identifier forKey:@"identifier"];
	[coder encodeObject:_label forKey:@"label"];
	[coder encodeObject:_metaData forKey:@"metaData"];
}

@end

OCMessageChoiceIdentifier OCMessageChoiceIdentifierOK = @"_ok"; // Careful: this is also used for OCSyncIssueChoiceIdentifierOK
OCMessageChoiceIdentifier OCMessageChoiceIdentifierRetry = @"_retry"; // Careful: this is also used for OCMessageChoiceIdentifierRetry
OCMessageChoiceIdentifier OCMessageChoiceIdentifierCancel = @"_cancel"; // Careful: this is also used for OCMessageChoiceIdentifierCancel
