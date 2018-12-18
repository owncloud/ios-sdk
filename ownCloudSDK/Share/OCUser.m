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

@implementation OCUser

@synthesize userName = _userName;
@synthesize displayName = _displayName;
@synthesize avatarData = _avatarData;

- (UIImage *)avatar
{
	if ((_avatar == nil) && (_avatarData != nil))
	{
		_avatar = [UIImage imageWithData:self.avatarData];
	}
	
	return (_avatar);
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
		self.userName = [decoder decodeObjectOfClass:[NSString class] forKey:@"userName"];
		self.displayName = [decoder decodeObjectOfClass:[NSString class] forKey:@"displayName"];
		self.emailAddress = [decoder decodeObjectOfClass:[NSString class] forKey:@"emailAddress"];
		self.avatarData = [decoder decodeObjectOfClass:[NSData class] forKey:@"avatarData"];
	}
	
	return (self);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:self.userName forKey:@"userName"];
	[coder encodeObject:self.displayName forKey:@"displayName"];
	[coder encodeObject:self.emailAddress forKey:@"emailAddress"];
	[coder encodeObject:self.avatarData forKey:@"avatarData"];
}

@end
