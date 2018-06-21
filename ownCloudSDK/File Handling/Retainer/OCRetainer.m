//
//  OCRetainer.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 21.06.18.
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

#import "OCRetainer.h"

@implementation OCRetainer

@synthesize type = _type;

@synthesize uuid = _uuid;

@synthesize processID = _processID;
@synthesize processBundleIdentifier = _processBundleIdentifier;

@synthesize explicitIdentifier = _explicitIdentifier;

@synthesize expiryDate = _expiryDate;

+ (instancetype)processRetainer
{
	return ([[self alloc] initWithProcess]);
}

+ (instancetype)explicitRetainerWithIdentifier:(NSString *)identifier
{
	return ([[self alloc] initWithExplicitIdentifier:identifier]);
}

+ (instancetype)expiringRetainerValidUntil:(NSDate *)expiryDate
{
	return ([[self alloc] initWithExpiryDate:expiryDate]);
}

#pragma mark - Init & Dealloc
- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_uuid = [NSUUID UUID];
	}

	return(self);
}

- (instancetype)initWithProcess
{
	if ((self = [self init]) != nil)
	{
		_type = OCRetainerTypeProcess;
		_processID = getpid();
		_processBundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
	}

	return(self);
}

- (instancetype)initWithExplicitIdentifier:(NSString *)identifier
{
	if ((self = [self init]) != nil)
	{
		_type = OCRetainerTypeExplicit;
		_explicitIdentifier = identifier;
	}

	return(self);
}

- (instancetype)initWithExpiryDate:(NSDate *)expiryDate
{
	if ((self = [self init]) != nil)
	{
		_type = OCRetainerTypeExpires;
		_expiryDate = expiryDate;
	}

	return(self);
}

- (BOOL)isValid
{
	BOOL isValid = NO;

	switch (_type)
	{
		case OCRetainerTypeProcess:
			isValid = [_processBundleIdentifier isEqual:[[NSBundle mainBundle] bundleIdentifier]] && (_processID == getpid());
		break;

		case OCRetainerTypeExpires:
			isValid = ([_expiryDate timeIntervalSinceNow] > 0);
		break;

		case OCRetainerTypeExplicit:
			isValid = YES;
		break;
	}

	return (isValid);
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
		_type = (OCRetainerType)[decoder decodeIntegerForKey:@"type"];

		_uuid = [decoder decodeObjectOfClass:[NSUUID class] forKey:@"uuid"];

		_processID = (pid_t)[decoder decodeIntegerForKey:@"processID"];
		_processBundleIdentifier = [decoder decodeObjectOfClass:[NSString class] forKey:@"processBundleIdentifier"];

		_explicitIdentifier = [decoder decodeObjectOfClass:[NSString class] forKey:@"explicitIdentifier"];

		_expiryDate = [decoder decodeObjectOfClass:[NSString class] forKey:@"expiryDate"];
	}

	return (self);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeInteger:_type forKey:@"type"];

	[coder encodeObject:_uuid forKey:@"uuid"];

	[coder encodeInteger:_processID forKey:@"processID"];
	[coder encodeObject:_processBundleIdentifier forKey:@"processBundleIdentifier"];

	[coder encodeObject:_explicitIdentifier forKey:@"explicitIdentifier"];

	[coder encodeObject:_expiryDate forKey:@"expiryDate"];
}

@end
