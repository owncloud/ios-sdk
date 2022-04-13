//
//  OCResourceText.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 12.04.22.
//  Copyright © 2022 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2022, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCResourceText.h"

@implementation OCResourceText

#pragma mark - Secure Coding
+ (BOOL)supportsSecureCoding
{
	return (YES);
}

- (void)encodeWithCoder:(nonnull NSCoder *)coder
{
	[super encodeWithCoder:coder];

	[coder encodeObject:_text forKey:@"text"];
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)coder
{
	if ((self = [super initWithCoder:coder]) != nil)
	{
		_text = [coder decodeObjectOfClass:NSString.class forKey:@"text"];
	}

	return (self);
}

@end
