//
//  OCKeyValueRecord.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 23.08.19.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2019, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCKeyValueRecord.h"
#import "OCLogger.h"
#import "OCKeyValueStack.h"

@implementation OCKeyValueRecord

- (instancetype)initWithValue:(id<NSSecureCoding>)value
{
	if ((self = [self init]) != nil)
	{
		_type = OCKeyValueRecordTypeValue;
		[self updateWithObject:value];
	}

	return (self);
}

- (instancetype)initWithKeyValueStack
{
	if ((self = [self init]) != nil)
	{
		_type = OCKeyValueRecordTypeStack;
		[self updateWithObject:[OCKeyValueStack new]];
	}

	return (self);
}

- (void)updateWithObject:(id<NSSecureCoding>)object
{
	@synchronized(self)
	{
		_seed = _seed + 1;

		_object = object;
		_data = (object != nil) ? [NSKeyedArchiver archivedDataWithRootObject:object] : nil;
	}
}

- (BOOL)updateFromRecord:(OCKeyValueRecord *)otherRecord
{
	if (otherRecord != nil)
	{
		if (otherRecord.seed != _seed) // != instead of > to cover integer overflows for frequently updated keys. The logic to avoid updating with outdated seeds is performed before this method is called.
		{
			// Update
			@synchronized(self)
			{
				@synchronized(otherRecord)
				{
					_seed = otherRecord.seed;
					_object = otherRecord.object;
					_data = otherRecord.data;
				}
			}

			return (YES);
		}
	}

	return (NO);
}

- (id<NSSecureCoding>)decodeObjectWithClasses:(NSSet<Class> *)decodeClasses
{
	@synchronized(self)
	{
		if ((_object == nil) && (_data != nil))
		{
			NSError *error = nil;

			if ((_object = [NSKeyedUnarchiver unarchivedObjectOfClasses:decodeClasses fromData:_data error:&error]) == nil)
			{
				OCLogError(@"Error decoding object from data: %@", error);
			}
		}

		return (_object);
	}
}

#pragma mark - Secure Coding
+ (BOOL)supportsSecureCoding
{
	return (YES);
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
	if ((self = [self init]) != nil)
	{
		_seed = [decoder decodeIntegerForKey:@"seed"];
		_type = [decoder decodeIntegerForKey:@"type"];

		_data = [decoder decodeObjectOfClass:[NSData class] forKey:@"data"];
	}

	return (self);
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeInteger:_seed forKey:@"seed"];
	[encoder encodeInteger:_type forKey:@"type"];

	[encoder encodeObject:_data  forKey:@"data"];
}

@end
