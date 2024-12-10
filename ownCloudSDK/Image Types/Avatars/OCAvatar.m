//
//  OCAvatar.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 29.09.20.
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

#import "OCAvatar.h"

@implementation OCAvatar

+ (CGSize)defaultSize
{
	return (CGSizeMake(128,128));
}

#pragma mark - Secure Coding
+ (BOOL)supportsSecureCoding
{
	return (YES);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[super encodeWithCoder:coder];

	[coder encodeObject:_uniqueUserIdentifier    	forKey:@"userIdentifier"];
	[coder encodeObject:_eTag		forKey:@"eTag"];
	[coder encodeObject:_timestamp		forKey:@"timestamp"];
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super initWithCoder:decoder]) != nil)
	{
		_uniqueUserIdentifier = [decoder decodeObjectOfClass:NSString.class forKey:@"userIdentifier"];
		_eTag = [decoder decodeObjectOfClass:NSString.class forKey:@"eTag"];
		_timestamp = [decoder decodeObjectOfClass:NSDate.class forKey:@"timestamp"];
	}

	return (self);
}

@end
