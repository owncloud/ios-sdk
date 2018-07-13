//
//  OCSQLiteQueryCondition.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 13.06.18.
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

#import "OCSQLiteQueryCondition.h"

@implementation OCSQLiteQueryCondition

+ (instancetype)queryConditionWithOperator:(NSString *)sqlOperator value:(id)value apply:(BOOL)apply
{
	OCSQLiteQueryCondition *condition = [self new];

	condition.sqlOperator = sqlOperator;
	condition.value = value;
	condition.apply = apply;

	return (condition);
}

@end
