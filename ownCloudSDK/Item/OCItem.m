//
//  OCItem.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 05.02.18.
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

#import "OCItem.h"

@implementation OCItem

#pragma mark - Secure Coding
+ (BOOL)supportsSecureCoding
{
	return (YES);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	// Stub implementation
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super init]) != nil)
	{
		// Stub implementation
	}

	return (self);
}

#pragma mark - Properties
- (NSString *)name
{
	return ([self.path lastPathComponent]);
}

#pragma mark - Description
- (NSString *)description
{
	return ([NSString stringWithFormat:@"<%@: %p, type: %lu, name: %@, path: %@, size: %lu bytes, MIME-Type: %@, Last modified: %@>", NSStringFromClass(self.class), self, (unsigned long)self.type, self.name, self.path, self.size, self.mimeType, self.lastModified]);
}

@end
