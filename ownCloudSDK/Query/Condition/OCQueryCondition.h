//
//  OCQueryCondition.h
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

#import <Foundation/Foundation.h>
#import "OCTypes.h"
#import "OCItem.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, OCQueryConditionOperator)
{
	OCQueryConditionOperatorPropertyGreaterThanValue,
	OCQueryConditionOperatorPropertyLessThanValue,
	OCQueryConditionOperatorPropertyEqualToValue,
	OCQueryConditionOperatorPropertyNotEqualToValue,
	OCQueryConditionOperatorPropertyHasPrefix,
	OCQueryConditionOperatorPropertyHasSuffix,
	OCQueryConditionOperatorPropertyContains,

	OCQueryConditionOperatorOr,
	OCQueryConditionOperatorAnd,

	OCQueryConditionOperatorNegate
};

@interface OCQueryCondition : NSObject <NSSecureCoding>

@property(assign) OCQueryConditionOperator operator;

@property(strong,nullable) OCItemPropertyName property;
@property(strong,nullable) id value;

@property(strong,nullable) OCItemPropertyName sortBy; //!< If non-nil, sorting hint for the database by which property the data should be pre-sorted. Only supported for properties that have their own column in the database.
@property(assign) BOOL sortAscending; //!< If .sortBy is non-nil, whether the sort order should be ascending (YES) or descending (NO).

@property(strong,nullable) NSNumber *maxResultCount; //!< If non-nil, the maximum number of results to fetch from a database

+ (instancetype)where:(OCItemPropertyName)property isGreaterThan:(id)value;
+ (instancetype)where:(OCItemPropertyName)property isLessThan:(id)value;
+ (instancetype)where:(OCItemPropertyName)property isEqualTo:(id)value;
+ (instancetype)where:(OCItemPropertyName)property isNotEqualTo:(id)value;
+ (instancetype)where:(OCItemPropertyName)property startsWith:(id)value;
+ (instancetype)where:(OCItemPropertyName)property endsWith:(id)value;
+ (instancetype)where:(OCItemPropertyName)property contains:(id)value;

+ (instancetype)anyOf:(NSArray <OCQueryCondition *> *)conditions;
+ (instancetype)require:(NSArray <OCQueryCondition *> *)conditions;
+ (instancetype)negating:(BOOL)negating condition:(OCQueryCondition *)condition;

- (instancetype)sortedBy:(OCItemPropertyName)property ascending:(BOOL)ascending;
- (instancetype)limitedToMaxResultCount:(NSUInteger)maxResultCounts;

@end

NS_ASSUME_NONNULL_END
