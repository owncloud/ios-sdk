//
//  OCPasswordPolicyReport.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 06.02.24.
//  Copyright © 2024 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2024, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCPasswordPolicyReport.h"
#import "OCPasswordPolicyRule.h"

@implementation OCPasswordPolicyReport
{
	NSMutableArray<OCPasswordPolicyRule *> *_rules;
	NSMapTable<OCPasswordPolicyRule *, NSString *> *_resultByRule;
}

- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_rules = [NSMutableArray new];
		_resultByRule = [NSMapTable weakToStrongObjectsMapTable];
	}

	return (self);
}

- (NSArray<OCPasswordPolicyRule *> *)rules
{
	return (_rules);
}

- (void)addRule:(OCPasswordPolicyRule *)rule result:(NSString *)result
{
	[_rules addObject:rule];
	[_resultByRule setObject:result forKey:rule];
}

- (BOOL)passedValidationForRule:(OCPasswordPolicyRule *)rule
{
	return ([self resultForRule:rule] == nil);
}

- (NSString *)resultForRule:(OCPasswordPolicyRule *)rule
{
	return ([_resultByRule objectForKey:rule]);
}

- (BOOL)passedValidation
{
	return (_resultByRule.count == 0);
}

@end
