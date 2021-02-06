//
//  OCLock.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 04.02.21.
//  Copyright © 2021 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2021, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCLock.h"
#import "OCLockManager.h"

@implementation OCLock

- (instancetype)initWithIdentifier:(OCLockResourceIdentifier)resourceIdentifier
{
	if ((self = [super init]) != nil)
	{
		_identifier = NSUUID.UUID.UUIDString;
		_resourceIdentifier = resourceIdentifier;

		[self keepAlive:YES];
	}

	return (self);
}

- (BOOL)isValid
{
	if ((_expirationDate == nil) ||
	   ((_expirationDate != nil) && ([_expirationDate timeIntervalSinceNow] <= 0.0)))
	{
		return (NO);
	}

	return (YES);
}

- (BOOL)keepAlive:(BOOL)force
{
	if (force || (_expirationDate.timeIntervalSinceNow < (OCLockExpirationInterval * 0.8)))
	{
		_expirationDate = [NSDate dateWithTimeIntervalSinceNow:OCLockExpirationInterval];

		return (YES);
	}

	return (NO);
}

- (void)releaseLock
{
	[self.manager releaseLock:self];
}

#pragma mark - Secure Coding
+ (BOOL)supportsSecureCoding
{
	return (YES);
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
	if ((self = [super init]) != nil)
	{
		_identifier = [coder decodeObjectOfClass:NSString.class forKey:@"identifier"];
		_resourceIdentifier = [coder decodeObjectOfClass:NSString.class forKey:@"resourceIdentifier"];
		_expirationDate = [coder decodeObjectOfClass:NSDate.class forKey:@"expirationDate"];
	}

	return (self);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:_identifier forKey:@"identifier"];
	[coder encodeObject:_resourceIdentifier forKey:@"resourceIdentifier"];
	[coder encodeObject:_expirationDate forKey:@"expirationDate"];
}

@end

const NSTimeInterval OCLockExpirationInterval = 4.0;
