//
//  OCRecipient.m
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

#import "OCRecipient.h"
#import "OCMacros.h"

@implementation OCRecipient

@dynamic identifier;
@dynamic displayName;

+ (instancetype)recipientWithUser:(OCUser *)user
{
	OCRecipient *recipient = [self new];

	recipient.type = OCRecipientTypeUser;
	recipient.user = user;

	return (recipient);
}

+ (instancetype)recipientWithGroup:(OCGroup *)group
{
	OCRecipient *recipient = [self new];

	recipient.type = OCRecipientTypeGroup;
	recipient.group = group;

	return (recipient);
}

- (instancetype)withSearchResultName:(NSString *)searchResultName
{
	self.searchResultName = searchResultName;

	return (self);
}

- (NSString *)identifier
{
	switch (_type)
	{
		case OCRecipientTypeUser:
			return (_user.userName);
		break;

		case OCRecipientTypeGroup:
			return (_group.identifier);
		break;
	}

	return (nil);
}

- (NSString *)displayName
{
	switch (_type)
	{
		case OCRecipientTypeUser:
			return ((_searchResultName.length == 0) ? _user.displayName : [_user.displayName stringByAppendingFormat:@" (%@)", _searchResultName]);
		break;

		case OCRecipientTypeGroup:
			return ((_searchResultName.length == 0) ? _group.name : [_group.name stringByAppendingFormat:@" (%@)", _searchResultName]);
		break;
	}

	return (nil);
}

#pragma mark - Comparison
- (NSUInteger)hash
{
	return (_type ^ (_user.hash << 3) ^ (_group.hash >> 3) ^ (_searchResultName.hash << 1));
}

- (BOOL)isEqual:(id)object
{
	OCRecipient *otherRecipient = OCTypedCast(object, OCRecipient);

	if (otherRecipient != nil)
	{
		#define compareVar(var) ((otherRecipient->var == var) || [otherRecipient->var isEqual:var])

		return ((otherRecipient.type == _type) && compareVar(_user) && compareVar(_group) && compareVar(_searchResultName));
	}

	return (NO);
}

#pragma mark - Copying
- (id)copyWithZone:(NSZone *)zone
{
	OCRecipient *recipient = [OCRecipient new];

	recipient->_type = _type;
	recipient->_user = _user;
	recipient->_group = _group;
	recipient->_searchResultName = _searchResultName;
	recipient->_matchType = _matchType;

	return (recipient);
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
		_type = [decoder decodeIntegerForKey:@"type"];

		_group = [decoder decodeObjectOfClass:[OCGroup class] forKey:@"group"];
		_user = [decoder decodeObjectOfClass:[OCUser class] forKey:@"user"];

		_searchResultName = [decoder decodeObjectOfClass:[NSString class] forKey:@"searchResultName"];

		_matchType = [decoder decodeIntegerForKey:@"matchType"];
	}

	return (self);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeInteger:_type forKey:@"type"];

	[coder encodeObject:_group forKey:@"group"];
	[coder encodeObject:_user forKey:@"user"];

	[coder encodeObject:_searchResultName forKey:@"searchResultName"];

	[coder encodeInteger:_matchType forKey:@"matchType"];
}

#pragma mark - Description
- (NSString *)description
{
	NSString *typeAsString = @"unknown";

	switch (_type)
	{
		case OCRecipientTypeUser:
			typeAsString = @"user";
		break;

		case OCRecipientTypeGroup:
			typeAsString = @"group";
		break;
	}

	return ([NSString stringWithFormat:@"<%@: %p, type: %@, identifier: %@, name: %@%@%@%@%@>", NSStringFromClass(self.class), self, typeAsString, self.identifier, self.displayName, ((_user!=nil)?[NSString stringWithFormat:@", user: %@", _user]:@""), ((_group!=nil)?[NSString stringWithFormat:@", group: %@", _group]:@""), ((_searchResultName!=nil)?[NSString stringWithFormat:@", searchResultName: %@", _searchResultName]:@""), ((_matchType!=OCRecipientMatchTypeUnknown) ? ((_matchType==OCRecipientMatchTypeExact) ? @", matchType: exact" : @", matchType: additional") : @"")]);
}

@end
