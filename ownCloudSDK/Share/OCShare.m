//
//  OCShare.m
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

#import "OCShare.h"
#import "OCMacros.h"

@implementation OCShare

@dynamic canRead;
@dynamic canUpdate;
@dynamic canCreate;
@dynamic canDelete;
@dynamic canShare;

- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_type = OCShareTypeUnknown;
	}

	return (self);
}

#pragma mark - Convenience constructors
+ (instancetype)shareWithRecipient:(OCRecipient *)recipient path:(OCPath)path permissions:(OCSharePermissionsMask)permissions expiration:(nullable NSDate *)expirationDate
{
	OCShare *share = [OCShare new];

	if (recipient.type == OCRecipientTypeGroup)
	{
		share.type = OCShareTypeGroupShare;
	}
	else if (recipient.type == OCRecipientTypeUser)
	{
		if (recipient.user.isRemote)
		{
			share.type = OCShareTypeRemote;
		}
		else
		{
			share.type = OCShareTypeUserShare;
		}
	}

	share.recipient = recipient;

	share.itemPath = path;

	share.permissions = permissions;
	share.expirationDate = expirationDate;

	return (share);
}

+ (instancetype)shareWithPublicLinkToPath:(OCPath)path linkName:(nullable NSString *)name permissions:(OCSharePermissionsMask)permissions password:(nullable NSString *)password expiration:(nullable NSDate *)expirationDate
{
	OCShare *share = [OCShare new];

	share.type = OCShareTypeLink;

	share.name = name;

	share.itemPath = path;

	share.password = password;

	share.permissions = permissions;
	share.expirationDate = expirationDate;

	return (share);
}

#pragma mark - Permission convenience
#define BIT_ACCESSOR(getMethodName,setMethodName,flag) \
- (BOOL)getMethodName \
{ \
	return ((_permissions & flag) == flag); \
} \
\
- (void)setMethodName:(BOOL)flagValue \
{ \
	_permissions = (_permissions & ~flag) | (flagValue ? flag : 0); \
}

BIT_ACCESSOR(canRead,	setCanRead,	OCSharePermissionsMaskRead);
BIT_ACCESSOR(canUpdate,	setCanUpdate,	OCSharePermissionsMaskUpdate);
BIT_ACCESSOR(canCreate,	setCanCreate,	OCSharePermissionsMaskCreate);
BIT_ACCESSOR(canDelete,	setCanDelete,	OCSharePermissionsMaskDelete);
BIT_ACCESSOR(canShare,	setCanShare,	OCSharePermissionsMaskShare);

#pragma mark - Comparison
- (NSUInteger)hash
{
	return (_identifier.hash ^ _token.hash ^ _itemPath.hash ^ _owner.hash ^ _recipient.hash ^ _itemOwner.hash ^ _type);
}

- (BOOL)isEqual:(id)object
{
	OCShare *otherShare = OCTypedCast(object, OCShare);

	if (otherShare != nil)
	{
		#define compareVar(var) ((otherShare->var == var) || [otherShare->var isEqual:var])

		return (compareVar(_identifier) &&

			(otherShare->_type == _type) &&

			compareVar(_itemPath) &&
			(otherShare->_itemType == _itemType) &&
			compareVar(_itemOwner) &&
			compareVar(_itemMIMEType) &&

			compareVar(_name) &&
			compareVar(_token) &&
			compareVar(_url) &&

			(otherShare->_permissions == _permissions) &&

			compareVar(_creationDate) &&
			compareVar(_expirationDate) &&

			compareVar(_owner) &&
			compareVar(_recipient) &&

			compareVar(_mountPoint) &&
			compareVar(_accepted)
		);
	}

	return (NO);
}

#pragma mark - Secure Coding
+ (BOOL)supportsSecureCoding
{
	return (YES);
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super init]) != nil)
	{
		_identifier = [decoder decodeObjectOfClass:[NSString class] forKey:@"identifier"];

		_type = [decoder decodeIntegerForKey:@"type"];

		_itemPath = [decoder decodeObjectOfClass:[NSString class] forKey:@"itemPath"];
		_itemType = [decoder decodeIntegerForKey:@"itemType"];
		_itemOwner = [decoder decodeObjectOfClass:[OCUser class] forKey:@"itemOwner"];
		_itemMIMEType = [decoder decodeObjectOfClass:[NSString class] forKey:@"itemMIMEType"];

		_name = [decoder decodeObjectOfClass:[NSString class] forKey:@"name"];
		_token = [decoder decodeObjectOfClass:[NSString class] forKey:@"token"];
		_url = [decoder decodeObjectOfClass:[NSURL class] forKey:@"url"];

		_permissions = [decoder decodeIntegerForKey:@"permissions"];

		_creationDate = [decoder decodeObjectOfClass:[NSDate class] forKey:@"creationDate"];
		_expirationDate = [decoder decodeObjectOfClass:[NSDate class] forKey:@"expirationDate"];

		_owner = [decoder decodeObjectOfClass:[OCUser class] forKey:@"owner"];
		_recipient = [decoder decodeObjectOfClass:[OCRecipient class] forKey:@"recipient"];

		_mountPoint = [decoder decodeObjectOfClass:[NSString class] forKey:@"mountPoint"];
		_accepted = [decoder decodeObjectOfClass:[NSNumber class] forKey:@"accepted"];
	}
	
	return (self);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:_identifier forKey:@"identifier"];

	[coder encodeInteger:_type forKey:@"type"];

	[coder encodeObject:_itemPath forKey:@"itemPath"];
	[coder encodeInteger:_itemType forKey:@"itemType"];
	[coder encodeObject:_itemOwner forKey:@"itemOwner"];
	[coder encodeObject:_itemMIMEType forKey:@"itemMIMEType"];

	[coder encodeObject:_name forKey:@"name"];
	[coder encodeObject:_token forKey:@"token"];
	[coder encodeObject:_url forKey:@"url"];

	[coder encodeInteger:_permissions forKey:@"permissions"];

	[coder encodeObject:_creationDate forKey:@"creationDate"];
	[coder encodeObject:_expirationDate forKey:@"expirationDate"];

	[coder encodeObject:_owner forKey:@"owner"];
	[coder encodeObject:_recipient forKey:@"recipient"];

	[coder encodeObject:_mountPoint forKey:@"mountPoint"];
	[coder encodeObject:_accepted forKey:@"accepted"];
}

#pragma mark - Description
- (NSString *)description
{
	NSString *typeAsString = nil, *permissionsString = @"";

	switch (_type)
	{
		case OCShareTypeUserShare:
			typeAsString = @"user";
		break;

		case OCShareTypeGroupShare:
			typeAsString = @"group";
		break;

		case OCShareTypeLink:
			typeAsString = @"link";
		break;

		case OCShareTypeGuest:
			typeAsString = @"guest";
		break;

		case OCShareTypeRemote:
			typeAsString = @"remote";
		break;

		case OCShareTypeUnknown:
			typeAsString = @"unknown";
		break;
	}

	if (self.canRead) { permissionsString = [permissionsString stringByAppendingString:@"read, "]; }
	if (self.canUpdate) { permissionsString = [permissionsString stringByAppendingString:@"update, "]; }
	if (self.canCreate) { permissionsString = [permissionsString stringByAppendingString:@"create, "]; }
	if (self.canDelete) { permissionsString = [permissionsString stringByAppendingString:@"delete, "]; }
	if (self.canShare) { permissionsString = [permissionsString stringByAppendingString:@"share, "]; }

	if (permissionsString.length > 3)
	{
		permissionsString = [permissionsString substringWithRange:NSMakeRange(0, permissionsString.length-2)];
	}
	else
	{
		permissionsString = @"none";
	}

	return ([NSString stringWithFormat:@"<%@: %p, identifier: %@, type: %@, name: %@, itemPath: %@, itemType: %@, itemMIMEType: %@, itemOwner: %@, creationDate: %@, expirationDate: %@, permissions: %@%@%@%@%@%@%@>", NSStringFromClass(self.class), self, _identifier, typeAsString, _name, _itemPath, ((_itemType == OCItemTypeFile) ? @"file" : @"folder"), _itemMIMEType, _itemOwner, _creationDate, _expirationDate, permissionsString, ((_password!=nil) ? @", password: [redacted]" : @""), ((_token!=nil)?[NSString stringWithFormat:@", token: %@", _token] : @""), ((_url!=nil)?[NSString stringWithFormat:@", url: %@", _url] : @""), ((_owner!=nil) ? [NSString stringWithFormat:@", owner: %@", _owner] : @""), ((_recipient!=nil) ? [NSString stringWithFormat:@", recipient: %@", _recipient] : @""), ((_accepted!=nil) ? [NSString stringWithFormat:@", accepted: %@", _accepted] : @"")]);
}

#pragma mark - Copying
- (id)copyWithZone:(NSZone *)zone
{
	OCShare *copiedShare = [self.class new];

	copiedShare->_identifier = _identifier;
	copiedShare->_type = _type;

	copiedShare->_itemPath = _itemPath;
	copiedShare->_itemType = _itemType;
	copiedShare->_itemOwner = _itemOwner;
	copiedShare->_itemMIMEType = _itemMIMEType;

	copiedShare->_name = _name;
	copiedShare->_token = _token;
	copiedShare->_url = _url;

	copiedShare->_permissions = _permissions;

	copiedShare->_creationDate = _creationDate;
	copiedShare->_expirationDate = _expirationDate;

	copiedShare->_password = _password;

	copiedShare->_owner = _owner;
	copiedShare->_recipient = _recipient;

	copiedShare->_mountPoint = _mountPoint;
	copiedShare->_accepted = _accepted;

	return (copiedShare);
}

@end
