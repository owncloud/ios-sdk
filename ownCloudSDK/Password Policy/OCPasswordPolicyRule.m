//
//  OCPasswordPolicyRule.m
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

#import "OCPasswordPolicyRule.h"

@implementation OCPasswordPolicyRule

- (instancetype)initWithLocalizedDescription:(NSString *)localizedDescription
{
	if ((self = [super init]) != nil)
	{
		self.localizedDescription = localizedDescription;
	}

	return (self);
}

- (NSString *)validate:(NSString *)password
{
	return (@"Unimplemented rule");
}

@end
