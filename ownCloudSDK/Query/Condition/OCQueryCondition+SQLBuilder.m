//
//  OCQueryCondition+SQLBuilder.m
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

#import "OCQueryCondition+SQLBuilder.h"
#import "OCLogger.h"
#import "OCMacros.h"

@implementation OCQueryCondition (SQLBuilder)

- (NSString *)buildSQLQueryWithPropertyColumnNameMap:(NSDictionary<OCItemPropertyName, NSString *> *)propertyColumnNameMap parameters:(NSArray **)outParameters error:(NSError **)error
{
	NSString *query = nil;
	NSArray *parameters = nil;

	switch (self.operator)
	{
		case OCQueryConditionOperatorPropertyGreaterThanValue:
			query = [[NSString alloc] initWithFormat:@"(%@ > ?)", propertyColumnNameMap[self.property]];
			parameters = @[ self.value ];
		break;

		case OCQueryConditionOperatorPropertyLessThanValue:
			query = [[NSString alloc] initWithFormat:@"(%@ < ?)", propertyColumnNameMap[self.property]];
			parameters = @[ self.value ];
		break;

		case OCQueryConditionOperatorPropertyEqualToValue:
			query = [[NSString alloc] initWithFormat:@"(%@ = ?)", propertyColumnNameMap[self.property]];
			parameters = @[ self.value ];
		break;

		case OCQueryConditionOperatorPropertyNotEqualToValue:
			query = [[NSString alloc] initWithFormat:@"(%@ != ?)", propertyColumnNameMap[self.property]];
			parameters = @[ self.value ];
		break;

		case OCQueryConditionOperatorPropertyHasPrefix:
			query = [[NSString alloc] initWithFormat:@"(%@ LIKE ?)", propertyColumnNameMap[self.property]];
			parameters = @[ [NSString stringWithFormat:@"%%%@", self.value] ];
		break;

		case OCQueryConditionOperatorPropertyHasSuffix:
			query = [[NSString alloc] initWithFormat:@"(%@ LIKE ?)", propertyColumnNameMap[self.property]];
			parameters = @[ [NSString stringWithFormat:@"%@%%", self.value] ];
		break;

		case OCQueryConditionOperatorPropertyContains:
			query = [[NSString alloc] initWithFormat:@"(%@ LIKE ?)", propertyColumnNameMap[self.property]];
			parameters = @[ [NSString stringWithFormat:@"%%%@%%", self.value] ];
		break;

		case OCQueryConditionOperatorAnd:
		case OCQueryConditionOperatorOr: {
			NSArray <OCQueryCondition *> *conditions;

			if ((conditions = OCTypedCast(self.value, NSArray)) != nil)
			{
				NSMutableString *queryString = [NSMutableString new];
				NSMutableArray *combinedParameters = [NSMutableArray new];
				NSString *operatorString = (self.operator == OCQueryConditionOperatorAnd) ? @"AND" : @"OR";

				for (OCQueryCondition *condition in conditions)
				{
					NSArray *conditionParameters = nil;
					NSString *conditionQueryString = nil;

					if ((conditionQueryString = [condition buildSQLQueryWithPropertyColumnNameMap:propertyColumnNameMap parameters:&conditionParameters error:NULL]) != nil)
					{
						if (queryString.length > 0)
						{
							[queryString appendFormat:@" %@ %@", operatorString, conditionQueryString];
						}
						else
						{
							[queryString appendString:conditionQueryString];
						}

						if (conditionParameters.count > 0)
						{
							[combinedParameters addObjectsFromArray:conditionParameters];
						}
					}
				}

				query = [NSString stringWithFormat:@"(%@)", queryString];
				parameters = combinedParameters;
			}
			else
			{
				OCLogError(@"AND/OR condition value is not an array of conditions");
			}
		}
		break;

		case OCQueryConditionOperatorNegate: {
			OCQueryCondition *condition;

			if ((condition = OCTypedCast(self.value, OCQueryCondition)) != nil)
			{
				query = [NSString stringWithFormat:@"(NOT %@)", [condition buildSQLQueryWithPropertyColumnNameMap:propertyColumnNameMap parameters:&parameters error:NULL]];
			}
			else
			{
				OCLogError(@"Negate condition value is not a condition");
			}
		}
		break;
	}

	if ((self.sortBy != nil) && (query != nil))
	{
		NSString *sortByColumnName;

		if ((sortByColumnName = propertyColumnNameMap[self.sortBy]) != nil)
		{
			query = [query stringByAppendingFormat:@" ORDER BY %@ %@", sortByColumnName, (self.sortAscending ? @"ASC" : @"DESC")];
		}
	}

	*outParameters = parameters;

	return (query);
}

@end
