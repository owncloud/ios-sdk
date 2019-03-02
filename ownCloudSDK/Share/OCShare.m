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

#pragma mark - Secure Coding
+ (BOOL)supportsSecureCoding
{
	return (YES);
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super init]) != nil)
	{
		_type = [decoder decodeIntegerForKey:@"type"];
		_url = [decoder decodeObjectOfClass:[NSURL class] forKey:@"url"];
		_expirationDate = [decoder decodeObjectOfClass:[NSDate class] forKey:@"expirationDate"];
	}
	
	return (self);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeInteger:self.type forKey:@"type"];
	[coder encodeObject:self.url forKey:@"url"];
	[coder encodeObject:self.expirationDate forKey:@"expirationDate"];
}

@end
