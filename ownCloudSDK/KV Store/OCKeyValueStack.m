//
//  OCKeyValueStack.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 24.08.19.
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

#import "OCKeyValueStack.h"
#import "OCKeyValueStore.h"

@interface OCKeyValueStackEntry : NSObject <NSSecureCoding>

@property(strong,readonly) OCClaim *claim;
@property(strong,nullable,readonly) id<NSSecureCoding> value;

@end

@implementation OCKeyValueStackEntry

- (instancetype)initWithValue:(nullable id<NSSecureCoding>)value claim:(OCClaim *)claim
{
	if ((self = [super init]) != nil)
	{
		_claim = claim;
		_value = value;
	}

	return (self);
}

#pragma mark - Secure coding
+ (BOOL)supportsSecureCoding
{
	return (YES);
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super init]) != nil)
	{
		_claim = [decoder decodeObjectOfClass:[OCClaim class] forKey:@"claim"];
		_value = [decoder decodeObjectOfClasses:[OCKeyValueStore fallbackClasses] forKey:@"value"];
	}

	return (self);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:_claim forKey:@"claim"];
	[coder encodeObject:_value forKey:@"value"];
}

@end

@interface OCKeyValueStack ()
{
	NSMutableArray<OCKeyValueStackEntry *> *_stackEntries;
}

@end

@implementation OCKeyValueStack

- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_stackEntries = [NSMutableArray new];
	}

	return (self);
}

- (void)pushObject:(nullable id<NSSecureCoding>)object withClaim:(OCClaim *)claim
{
	@synchronized (_stackEntries)
	{
		[_stackEntries insertObject:[[OCKeyValueStackEntry alloc] initWithValue:object claim:claim] atIndex:0];
	}
}

- (void)popObjectWithClaimID:(OCClaimIdentifier)claimIdentifier
{
	@synchronized (_stackEntries)
	{
		__block NSUInteger claimIndex = NSNotFound;

		[_stackEntries enumerateObjectsUsingBlock:^(OCKeyValueStackEntry * _Nonnull entry, NSUInteger idx, BOOL * _Nonnull stop) {
			if ([entry.claim.identifier isEqual:claimIdentifier])
			{
				claimIndex = idx;
				*stop = YES;
			}
		}];

		if (claimIndex != NSNotFound)
		{
			[_stackEntries removeObjectAtIndex:claimIndex];
		}
	}
}

- (BOOL)determineFirstValidObject:(id _Nullable * _Nullable)outObject claimIdentifier:(OCClaimIdentifier _Nullable * _Nullable)outClaimIdentifier removedInvalidEntries:(BOOL * _Nullable)outRemovedInvalidEntries
{
	BOOL foundValidObject = NO;

	@synchronized (_stackEntries)
	{
		__block NSMutableIndexSet *removalIndexes = nil;
		__block OCKeyValueStackEntry *returnEntry = nil;

		[_stackEntries enumerateObjectsUsingBlock:^(OCKeyValueStackEntry * _Nonnull entry, NSUInteger idx, BOOL * _Nonnull stop) {
			if (entry.claim.isValid)
			{
				returnEntry = entry;
				*stop = YES;
			}
			else
			{
				if (removalIndexes == nil)
				{
					removalIndexes = [NSMutableIndexSet new];
				}

				[removalIndexes addIndex:idx];
			}
		}];

		if (returnEntry != nil)
		{
			if (outObject != NULL)
			{
				*outObject = returnEntry.value;
			}

			if (outClaimIdentifier != NULL)
			{
				*outClaimIdentifier = returnEntry.claim.identifier;
			}

			foundValidObject  = YES;
		}

		if (removalIndexes != nil)
		{
			[_stackEntries removeObjectsAtIndexes:removalIndexes];

			if (outRemovedInvalidEntries != NULL)
			{
				*outRemovedInvalidEntries = YES;
			}
		}
	}

	return (foundValidObject);
}

#pragma mark - Secure coding
+ (BOOL)supportsSecureCoding
{
	return (YES);
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super init]) != nil)
	{
		_stackEntries = [decoder decodeObjectOfClasses:[[NSSet alloc] initWithObjects:[OCKeyValueStackEntry class], [NSMutableArray class], nil] forKey:@"stackEntries"];
	}

	return (self);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:_stackEntries forKey:@"stackEntries"];
}

@end
