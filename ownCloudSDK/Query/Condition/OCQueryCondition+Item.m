//
//  OCQueryCondition+Item.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 19.03.19.
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

#import "OCQueryCondition+Item.h"
#import "OCLogger.h"
#import "OCMacros.h"

@implementation OCQueryCondition (Item)

- (BOOL)fulfilledByItem:(OCItem *)item
{
	BOOL isFulfilled = NO;
	OCQueryConditionOperator operator = self.operator;
	id<NSObject> propertyValue = (self.property != nil) ? [item valueForKey:self.property] : nil;
	id<NSObject> operatorValue = self.value;

	switch (operator)
	{
		case OCQueryConditionOperatorPropertyGreaterThanValue:
			if (propertyValue != nil)
			{
				if ([propertyValue respondsToSelector:@selector(compare:)])
				{
					isFulfilled = ([(NSNumber *)propertyValue compare:(NSNumber *)operatorValue] == NSOrderedDescending);
				}
				else
				{
					OCLogError(@"propertyValue=%@ (class %@) can't be compared because it doesn't respond to compare:", propertyValue, ((propertyValue != nil) ? NSStringFromClass(propertyValue.class) : @"-"));
				}
			}
		break;

		case OCQueryConditionOperatorPropertyLessThanValue:
			if (propertyValue != nil)
			{
				if ([propertyValue respondsToSelector:@selector(compare:)])
				{
					isFulfilled = ([(NSNumber *)propertyValue compare:(NSNumber *)operatorValue] == NSOrderedAscending);
				}
				else
				{
					OCLogError(@"propertyValue=%@ (class %@) can't be compared because it doesn't respond to compare:", propertyValue, ((propertyValue != nil) ? NSStringFromClass(propertyValue.class) : @"-"));
				}
			}
		break;

		case OCQueryConditionOperatorPropertyEqualToValue:
			if (propertyValue != nil)
			{
				isFulfilled = [propertyValue isEqual:operatorValue];
			}
		break;

		case OCQueryConditionOperatorPropertyNotEqualToValue:
			if (propertyValue != nil)
			{
				isFulfilled = ![propertyValue isEqual:operatorValue];
			}
			else
			{
				isFulfilled = YES;
			}
		break;

		case OCQueryConditionOperatorPropertyHasPrefix:
			if (propertyValue != nil)
			{
				if ([propertyValue respondsToSelector:@selector(hasPrefix:)])
				{
					if (operatorValue != nil)
					{
						isFulfilled = [(NSString *)propertyValue hasPrefix:(NSString *)operatorValue];
					}
					else
					{
						OCLogError(@"operatorValue==nil for OCQueryConditionOperatorPropertyHasPrefix: check not possible");
					}
				}
				else
				{
					OCLogError(@"propertyValue=%@ (class %@) can't be checked for prefix because it doesn't respond to hasPrefix:", propertyValue, ((propertyValue != nil) ? NSStringFromClass(propertyValue.class) : @"-"));
				}
			}
		break;

		case OCQueryConditionOperatorPropertyHasSuffix:
			if (propertyValue != nil)
			{
				if ([propertyValue respondsToSelector:@selector(hasSuffix:)])
				{
					if (operatorValue != nil)
					{
						isFulfilled = [(NSString *)propertyValue hasSuffix:(NSString *)operatorValue];
					}
					else
					{
						OCLogError(@"operatorValue==nil for OCQueryConditionOperatorPropertyHasSuffix: check not possible");
					}
				}
				else
				{
					OCLogError(@"propertyValue=%@ (class %@) can't be checked for suffix because it doesn't respond to hasPrefix:", propertyValue, ((propertyValue != nil) ? NSStringFromClass(propertyValue.class) : @"-"));
				}
			}
		break;

		case OCQueryConditionOperatorPropertyContains:
			if (propertyValue != nil)
			{
				if ([propertyValue respondsToSelector:@selector(localizedStandardContainsString:)])
				{
					isFulfilled = [(NSString *)propertyValue localizedStandardContainsString:(NSString *)operatorValue];
				}
				else
				{
					OCLogError(@"propertyValue=%@ (class %@) can't be checked for containing %@ because it doesn't respond to localizedStandardContainsString:", propertyValue, ((propertyValue != nil) ? NSStringFromClass(propertyValue.class) : @"-"), operatorValue);
				}
			}
		break;

		case OCQueryConditionOperatorAnd:
		case OCQueryConditionOperatorOr: {
			NSArray <OCQueryCondition *> *conditions;

			if ((conditions = OCTypedCast(self.value, NSArray)) != nil)
			{
				if (operator == OCQueryConditionOperatorOr)
				{
					for (OCQueryCondition *condition in conditions)
					{
						if ([condition fulfilledByItem:item])
						{
							// Take the earliest exit
							isFulfilled = YES;
							break;
						}
					}

				}
				else if (operator == OCQueryConditionOperatorAnd)
				{
					isFulfilled = YES;

					for (OCQueryCondition *condition in conditions)
					{
						if (![condition fulfilledByItem:item])
						{
							// Take the earliest exit
							isFulfilled = NO;
							break;
						}
					}
				}
			}
			else
			{
				OCLogError(@"And/Or condition value is not an array of conditions");
			}
		}
		break;

		case OCQueryConditionOperatorNegate: {
			OCQueryCondition *condition;

			if ((condition = OCTypedCast(self.value, OCQueryCondition)) != nil)
			{
				isFulfilled = ![condition fulfilledByItem:item];
			}
			else
			{
				OCLogError(@"Negate condition value is not a condition");
			}
		}
		break;
	}

	return (isFulfilled);
}

- (NSComparator)itemComparator
{
	if (self.sortBy != nil)
	{
		NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:self.sortBy ascending:self.sortAscending];

		return (^(id obj1, id obj2){
			return ([sortDescriptor compareObject:obj1 toObject:obj2]);
		});
	}

	return (nil);
}

@end
