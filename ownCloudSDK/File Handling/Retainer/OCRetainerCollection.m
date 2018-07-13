//
//  OCRetainerCollection.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 21.06.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

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
