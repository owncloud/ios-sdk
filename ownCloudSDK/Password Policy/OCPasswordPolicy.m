//
//  OCPasswordPolicy.m
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

#import "OCPasswordPolicy.h"
#import "OCPasswordPolicyRule.h"
#import "OCPasswordPolicyReport.h"

@implementation OCPasswordPolicy

- (instancetype)initWithRules:(NSArray<OCPasswordPolicyRule *> *)rules
{
	if ((self = [super init]) != nil)
	{
		self.rules = rules;
	}

	return (self);
}

- (OCPasswordPolicyReport *)validate:(NSString *)password
{
	OCPasswordPolicyReport *report = [OCPasswordPolicyReport new];

	// Validate password against all rules of the policy and generate a new report
	for (OCPasswordPolicyRule *rule in _rules)
	{
		[report addRule:rule result:[rule validate:password]];
	}

	return (report);
}

@end
