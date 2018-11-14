//
//  OCRetainerCollection.m
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

#import "OCRetainerCollection.h"

@implementation OCRetainerCollection

- (BOOL)isRetaining
{
	@synchronized(self)
	{
		for (OCRetainer *retainer in _retainers)
		{
			if (retainer.isValid)
			{
				return (YES);
			}
		}
	}

	return (NO);
}

- (void)addRetainer:(OCRetainer *)retainer
{
	@synchronized(self)
	{
		if (_retainers == nil) { _retainers = [NSMutableArray new]; }

		[_retainers addObject:retainer];
	}
}

- (void)removeRetainer:(OCRetainer *)retainer
{
	@synchronized(self)
	{
		[_retainers removeObject:retainer];
	}
}

- (void)removeRetainerWithUUID:(NSUUID *)uuid
{
	@synchronized(self)
	{
		OCRetainer *removeRetainer = nil;

		for (OCRetainer *retainer in _retainers)
		{
			if ([retainer.uuid isEqual:uuid])
			{
				removeRetainer = retainer;
				break;
			}
		}

		if (removeRetainer != nil)
		{
			[_retainers removeObject:removeRetainer];
		}
	}
}

- (void)removeRetainerWithExplicitIdentifier:(NSString *)explicitIdentifier
{
	@synchronized(self)
	{
		OCRetainer *removeRetainer = nil;

		for (OCRetainer *retainer in _retainers)
		{
			if (retainer.type == OCRetainerTypeExplicit)
			{
				if ([retainer.explicitIdentifier isEqual:explicitIdentifier])
				{
					removeRetainer = retainer;
					break;
				}
			}
		}

		if (removeRetainer != nil)
		{
			[_retainers removeObject:removeRetainer];
		}
	}
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
		_retainers = [decoder decodeObjectOfClass:[NSMutableArray class] forKey:@"retainers"];
	}

	return (self);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:_retainers forKey:@"retainers"];
}

@end
