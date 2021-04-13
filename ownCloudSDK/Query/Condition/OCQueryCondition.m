//
//  OCQueryCondition.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 18.03.19.
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

#import "OCQueryCondition.h"
#import "OCEvent.h"

@implementation OCQueryCondition

+ (instancetype)where:(OCItemPropertyName)property isGreaterThan:(id)value
{
	return ([[OCQueryCondition alloc] initWithOperator:OCQueryConditionOperatorPropertyGreaterThanValue property:property value:value]);
}

+ (instancetype)where:(OCItemPropertyName)property isLessThan:(id)value
{
	return ([[OCQueryCondition alloc] initWithOperator:OCQueryConditionOperatorPropertyLessThanValue property:property value:value]);
}

+ (instancetype)where:(OCItemPropertyName)property isEqualTo:(id)value
{
	return ([[OCQueryCondition alloc] initWithOperator:OCQueryConditionOperatorPropertyEqualToValue property:property value:value]);
}

+ (instancetype)where:(OCItemPropertyName)property isNotEqualTo:(id)value
{
	return ([[OCQueryCondition alloc] initWithOperator:OCQueryConditionOperatorPropertyNotEqualToValue property:property value:value]);
}

+ (instancetype)where:(OCItemPropertyName)property startsWith:(id)value
{
	return ([[OCQueryCondition alloc] initWithOperator:OCQueryConditionOperatorPropertyHasPrefix property:property value:value]);
}

+ (instancetype)where:(OCItemPropertyName)property endsWith:(id)value
{
	return ([[OCQueryCondition alloc] initWithOperator:OCQueryConditionOperatorPropertyHasSuffix property:property value:value]);
}

+ (instancetype)where:(OCItemPropertyName)property contains:(id)value
{
	return ([[OCQueryCondition alloc] initWithOperator:OCQueryConditionOperatorPropertyContains property:property value:value]);
}

+ (instancetype)anyOf:(NSArray <OCQueryCondition *> *)conditions
{
	return ([[OCQueryCondition alloc] initWithOperator:OCQueryConditionOperatorOr property:nil value:conditions]);
}

+ (instancetype)require:(NSArray <OCQueryCondition *> *)conditions
{
	return ([[OCQueryCondition alloc] initWithOperator:OCQueryConditionOperatorAnd property:nil value:conditions]);
}

+ (instancetype)negating:(BOOL)negating condition:(OCQueryCondition *)condition
{
	if (negating)
	{
		return ([[OCQueryCondition alloc] initWithOperator:OCQueryConditionOperatorNegate property:nil value:condition]);
	}
	else
	{
		return (condition);
	}
}

- (instancetype)sortedBy:(OCItemPropertyName)property ascending:(BOOL)ascending
{
	self.sortBy = property;
	self.sortAscending = ascending;

	return (self);
}

- (instancetype)limitedToMaxResultCount:(NSUInteger)maxResultCounts
{
	self.maxResultCount = @(maxResultCounts);

	return (self);
}

- (instancetype)initWithOperator:(OCQueryConditionOperator)operator property:(OCItemPropertyName)property value:(id)value
{
	if ((self = [super init]) != nil)
	{
		_operator = operator;
		_property = property;
		_value = value;
	}

	return (self);
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
		_operator = [decoder decodeIntegerForKey:@"operator"];

		_property = [decoder decodeObjectOfClass:[NSString class] forKey:@"property"];
		_value = [decoder decodeObjectOfClasses:OCEvent.safeClasses forKey:@"value"];

		_sortBy = [decoder decodeObjectOfClass:[NSString class] forKey:@"sortBy"];
		_sortAscending = [decoder decodeBoolForKey:@"sortAscending"];

		_maxResultCount = [decoder decodeObjectOfClass:[NSNumber class] forKey:@"maxResultCount"];
	}

	return (self);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeInteger:_operator forKey:@"operator"];

	[coder encodeObject:_property forKey:@"property"];
	[coder encodeObject:_value forKey:@"value"];

	[coder encodeObject:_sortBy forKey:@"sortBy"];
	[coder encodeBool:_sortAscending forKey:@"sortAscending"];

	[coder encodeObject:_maxResultCount forKey:@"maxResultCount"];
}

#pragma mark - Description
- (NSString *)description
{
	NSString *operatorName = nil;
	NSString *conditionDescription = nil;
	BOOL logical = NO;

	switch (_operator)
	{
		case OCQueryConditionOperatorPropertyGreaterThanValue:
			operatorName = @">";
		break;

		case OCQueryConditionOperatorPropertyLessThanValue:
			operatorName = @"<";
		break;

		case OCQueryConditionOperatorPropertyEqualToValue:
			operatorName = @"==";
		break;

		case OCQueryConditionOperatorPropertyNotEqualToValue:
			operatorName = @"!=";
		break;

		case OCQueryConditionOperatorPropertyHasPrefix:
			operatorName = @"beginsWith";
		break;

		case OCQueryConditionOperatorPropertyHasSuffix:
			operatorName = @"endsWith";
		break;

		case OCQueryConditionOperatorPropertyContains:
			operatorName = @"contains";
		break;

		case OCQueryConditionOperatorOr:
			operatorName = @"anyOf";
			logical = YES;
		break;

		case OCQueryConditionOperatorAnd:
			operatorName = @"require";
			logical = YES;
		break;

		case OCQueryConditionOperatorNegate:
			operatorName = @"negate";
			logical = YES;
		break;
	}

	if (logical)
	{
		conditionDescription = [NSString stringWithFormat:@"%@ %@", operatorName, _value];
	}
	else
	{
		conditionDescription = [NSString stringWithFormat:@"%@ %@ %@", _property, operatorName, _value];
	}

	return ([NSString stringWithFormat:@"<%@: %p, %@%@>", NSStringFromClass(self.class), self, conditionDescription, ((_sortBy!=nil) ? [NSString stringWithFormat:@" sortBy: %@%@", _sortBy, (_sortAscending ? @"ASC" : @"DESC")] : @"")]);
}


@end
