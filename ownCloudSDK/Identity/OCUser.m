//
//  OCUser.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 22.02.18.
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

#import "OCUser.h"
#import "OCMacros.h"
#import "OCLogger.h"
#import "GAUser.h"

@implementation OCUser

@dynamic isRemote;
@dynamic remoteHost;
@dynamic remoteUserName;

+ (instancetype)userWithUserName:(nullable NSString *)userName displayName:(nullable NSString *)displayName
{
	OCUser *user = [OCUser new];

	user.userName = userName;
	user.displayName = displayName;

	user.type = user.isRemote ? OCUserTypeFederated : OCUserTypeMember;

	return (user);
}

+ (instancetype)userWithUserName:(nullable NSString *)userName displayName:(nullable NSString *)displayName isRemote:(BOOL)isRemote
{
	OCUser *user = [OCUser new];

	user.userName = userName;
	user.displayName = displayName;
	user->_forceIsRemote = @(isRemote);

	user.type = user.isRemote ? OCUserTypeFederated : OCUserTypeMember;

	return (user);
}

+ (instancetype)userWithGraphUser:(GAUser *)gaUser
{
	OCUser *user = [OCUser new];

	user.displayName = gaUser.displayName;
	user.identifier = gaUser.identifier;

	if ([gaUser.userType isEqual:@"Member"])
	{
		user.type = OCUserTypeMember;
	}
	if ([gaUser.userType isEqual:@"Guest"])
	{
		user.type = OCUserTypeGuest;
	}
	if ([gaUser.userType isEqual:@"Federated"])
	{
		user.type = OCUserTypeFederated;
	}

	return (user);
}

- (NSRange)_atRemoteRange
{
	NSRange atRange;

	atRange = [_userName rangeOfString:@"@" options:NSBackwardsSearch];

	if ((atRange.location == 0) || (atRange.location == (_userName.length-1)))
	{
		// Handle local user names starting or ending with "@" like "@example" or "example@" and make sure they aren't treated as remote
		atRange.location = NSNotFound;
	}

	if ((atRange.location != NSNotFound) && (_forceIsRemote != nil) && !_forceIsRemote.boolValue)
	{
		// Handle local user names containing an "@", like "guest@domain.com" correctly if explicit information for the remote status is available
		atRange.location = NSNotFound;
	}

	return (atRange);
}

- (BOOL)isRemote
{
	return ([self _atRemoteRange].location != NSNotFound);
}

- (NSString *)remoteUserName
{
	NSRange atRange = [self _atRemoteRange];

	if (atRange.location != NSNotFound)
	{
		return ([_userName substringToIndex:atRange.location]);
	}

	return (nil);
}

- (NSString *)remoteHost
{
	NSRange atRange = [self _atRemoteRange];

	if (atRange.location != NSNotFound)
	{
		return ([_userName substringFromIndex:atRange.location+1]);
	}

	return (nil);
}

- (OCUniqueUserIdentifier)uniqueIdentifier
{
	if (_identifier != nil)
	{
		// Graph User IDentifier
		return (_identifier);
	}
	return ([NSString stringWithFormat:@"%@:%d", self.userName, self.isRemote]);
}

+ (NSPersonNameComponentsFormatter *)localizedInitialsFormatter
{
	static dispatch_once_t onceToken;
	static NSPersonNameComponentsFormatter *formatter;
	dispatch_once(&onceToken, ^{
		formatter = [NSPersonNameComponentsFormatter new];
		formatter.style= NSPersonNameComponentsFormatterStyleAbbreviated;
	});

	return (formatter);
}

+ (NSString *)localizedInitialsForName:(NSString *)name
{
	if (name.length > 0)
	{
		NSString *localizedInitials = nil;

		@try {
			NSPersonNameComponentsFormatter *localizedFormatter = OCUser.localizedInitialsFormatter;
			NSPersonNameComponents *nameComponents;

			if ((nameComponents = [localizedFormatter personNameComponentsFromString:name]) != nil)
			{
				localizedInitials = [localizedFormatter stringFromPersonNameComponents:nameComponents];
			}
		} @catch (NSException *exception) {
			OCLogDebug(@"Exception asking the OS for localized initials for %@: %@", name, exception);
		}

		if (localizedInitials == nil)
		{
			// Simple fallback algorithm taking the first letter of each word
			NSArray<NSString *> *nameParts = [name componentsSeparatedByString:@" "];
			NSMutableString *initials = [NSMutableString new];

			for (NSString *namePart in nameParts)
			{
				if (namePart.length > 0)
				{
					[initials appendString:[[namePart substringToIndex:1] uppercaseString]];
				}
			}

			if (initials.length > 0)
			{
				localizedInitials = initials;
			}
		}

		return (localizedInitials);
	}

	return (nil);
}

- (NSString *)localizedInitials
{
	NSString *localizedInitials = nil;

	if (self.displayName.length > 0)
	{
		localizedInitials = [OCUser localizedInitialsForName:self.displayName];
	}

	if (localizedInitials == nil)
	{
		localizedInitials = [OCUser localizedInitialsForName:self.userName];
	}

	return (localizedInitials);
}

#pragma mark - Comparison
- (NSUInteger)hash
{
	return ((_userName.hash << 1) ^ (_displayName.hash >> 1) ^ _emailAddress.hash ^ ((_forceIsRemote != nil) ? _forceIsRemote.boolValue : 0xEF));
}

- (BOOL)isEqual:(id)object
{
	OCUser *otherUser = OCTypedCast(object, OCUser);

	if (otherUser != nil)
	{
		#define compareVar(var) ((otherUser->var == var) || [otherUser->var isEqual:var])

		return (compareVar(_userName) && compareVar(_displayName) && compareVar(_emailAddress) && compareVar(_forceIsRemote));
	}

	return (NO);
}

#pragma mark - Copying
- (id)copyWithZone:(NSZone *)zone
{
	OCUser *user = [OCUser new];

	user->_userName = _userName;
	user->_identifier = _identifier;
	user->_displayName = _displayName;
	user->_emailAddress = _emailAddress;
	user->_forceIsRemote = _forceIsRemote;

	return (user);
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
		self.displayName = [decoder decodeObjectOfClass:NSString.class forKey:@"displayName"];

		self.userName = [decoder decodeObjectOfClass:NSString.class forKey:@"userName"];
		self.emailAddress = [decoder decodeObjectOfClass:NSString.class forKey:@"emailAddress"];
		_forceIsRemote = [decoder decodeObjectOfClass:NSNumber.class forKey:@"forceIsRemote"];

		self.type = [decoder decodeIntegerForKey:@"type"];
		self.identifier = [decoder decodeObjectOfClass:NSString.class forKey:@"identifier"];
	}

	return (self);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:self.displayName forKey:@"displayName"];

	[coder encodeObject:self.userName forKey:@"userName"];
	[coder encodeObject:self.emailAddress forKey:@"emailAddress"];
	[coder encodeObject:_forceIsRemote forKey:@"forceIsRemote"];

	[coder encodeInteger:_type forKey:@"type"];
	[coder encodeObject:self.identifier forKey:@"identifier"];
}

#pragma mark - Description
- (NSString *)description
{
	return ([NSString stringWithFormat:@"<%@: %p, displayName: %@%@%@%@>", NSStringFromClass(self.class), self, _displayName, ((_userName!=nil) ? [NSString stringWithFormat:@", userName: %@",_userName] : @""), ((_identifier!=nil) ? [NSString stringWithFormat:@", identifier: %@",_identifier] : @""), ((_emailAddress!=nil) ? [NSString stringWithFormat:@", emailAddress: [%@]",_emailAddress] : @"")]);
}

@end
