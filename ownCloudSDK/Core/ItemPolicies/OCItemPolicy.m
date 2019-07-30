//
//  OCItemPolicy.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 10.07.19.
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

#import "OCItemPolicy.h"

@implementation OCItemPolicy

- (instancetype)initWithKind:(OCItemPolicyKind)kind condition:(OCQueryCondition *)condition
{
	if ((self = [self init]) != nil)
	{
		_kind = kind;
		_condition = condition;
	}

	return (self);
}

- (instancetype)initWithKind:(OCItemPolicyKind)kind item:(OCItem *)item
{
	OCQueryCondition *condition = nil;

	switch (item.type)
	{
		case OCItemTypeCollection:
			condition = [OCQueryCondition where:OCItemPropertyNamePath startsWith:item.path];
		break;

		case OCItemTypeFile:
			condition = [OCQueryCondition where:OCItemPropertyNameLocalID startsWith:item.localID];
		break;
	}

	return ([self initWithKind:kind condition:condition]);
}

#pragma mark - Secure coding
+ (BOOL)supportsSecureCoding
{
	return (YES);
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
	if ((self = [self init]) != nil)
	{
		_identifier = [decoder decodeObjectOfClass:[NSString class] forKey:@"identifier"];
		_policyDescription = [decoder decodeObjectOfClass:[NSString class] forKey:@"policyDescription"];

		_path = [decoder decodeObjectOfClass:[NSString class] forKey:@"path"];
		_localID = [decoder decodeObjectOfClass:[NSString class] forKey:@"localID"];

		_kind = [decoder decodeObjectOfClass:[NSString class] forKey:@"kind"];
		_condition = [decoder decodeObjectOfClass:[OCQueryCondition class] forKey:@"condition"];

		_policyAutoRemovalMethod = [decoder decodeIntegerForKey:@"policyAutoRemovalMethod"];
		_policyAutoRemovalCondition = [decoder decodeObjectOfClass:[OCQueryCondition class] forKey:@"policyAutoRemovalCondition"];
	}

	return (self);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:_identifier forKey:@"identifier"];
	[coder encodeObject:_policyDescription forKey:@"policyDescription"];

	[coder encodeObject:_path forKey:@"path"];
	[coder encodeObject:_localID forKey:@"localID"];

	[coder encodeObject:_kind forKey:@"kind"];
	[coder encodeObject:_condition forKey:@"condition"];

	[coder encodeInteger:_policyAutoRemovalMethod forKey:@"policyAutoRemovalMethod"];
	[coder encodeObject:_policyAutoRemovalCondition forKey:@"policyAutoRemovalCondition"];
}

@end

OCItemPolicyIdentifier OCItemPolicyIdentifierInternalPrefix = @"_sys.";
