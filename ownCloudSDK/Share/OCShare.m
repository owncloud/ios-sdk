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

@synthesize type;

@synthesize url;

@synthesize expirationDate;

@synthesize users;

#pragma mark - Secure Coding
+ (BOOL)supportsSecureCoding
{
	return (YES);
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super init]) != nil)
	{
		self.type = [decoder decodeIntegerForKey:@"type"];
		self.url = [decoder decodeObjectOfClass:[NSURL class] forKey:@"url"];
		self.expirationDate = [decoder decodeObjectOfClass:[NSDate class] forKey:@"expirationDate"];
		self.users = [decoder decodeObjectOfClass:[NSArray class] forKey:@"users"];
	}
	
	return (self);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeInteger:self.type forKey:@"type"];
	[coder encodeObject:self.url forKey:@"url"];
	[coder encodeObject:self.expirationDate forKey:@"expirationDate"];
	[coder encodeObject:self.users forKey:@"users"];
}

@end
