//
//  OCGroup.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 01.03.19.
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

#import "OCGroup.h"
#import "OCMacros.h"

@implementation OCGroup

+ (instancetype)groupWithIdentifier:(nullable OCUserGroupID)groupID name:(nullable NSString *)name;
{
	OCGroup *group = [self new];

	group.identifier = groupID;
	group.name = name;

	return (group);
}

#pragma mark - Comparison
- (NSUInteger)hash
{
	return ((_identifier.hash >> 1) ^ (_name.hash << 2));
}

- (BOOL)isEqual:(id)object
{
	OCGroup *otherGroup = OCTypedCast(object, OCGroup);

	if (otherGroup != nil)
	{
		#define compareVar(var) ((otherGroup->var == var) || [otherGroup->var isEqual:var])

		return (compareVar(_identifier) && compareVar(_name));
	}

	return (NO);
}

#pragma mark - Copying
- (id)copyWithZone:(NSZone *)zone
{
	OCGroup *group = [OCGroup new];

	group->_identifier = _identifier;
	group->_name = _name;

	return (group);
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
		_identifier = [decoder decodeObjectOfClass:[NSString class] forKey:@"identifier"];
		_name = [decoder decodeObjectOfClass:[NSString class] forKey:@"name"];
	}

	return (self);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:_identifier forKey:@"identifier"];
	[coder encodeObject:_name forKey:@"name"];
}

#pragma mark - Description
- (NSString *)description
{
	return ([NSString stringWithFormat:@"<%@: %p, identifier: %@, name: %@>", NSStringFromClass(self.class), self, _identifier, _name]);
}

@end
