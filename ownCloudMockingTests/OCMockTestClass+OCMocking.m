//
//  OCMockTestClass+OCMocking.m
//  ownCloudMockingTests
//
//  Created by Felix Schwarz on 11.07.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import "OCMockTestClass+OCMocking.h"

@implementation OCMockTestClass (OCMocking)

+ (void)load
{
	[self addMockLocation:OCMockLocationMockTestClassReturnsTrue
	      forClassSelector:@selector(returnsTrue)
	      with:@selector(ocm_returnsTrue)];

	[self addMockLocation:OCMockLocationMockTestClassReturnsFalse
	      forSelector:@selector(returnsFalse)
	      with:@selector(ocm_returnsFalse)];
}

+ (BOOL)ocm_returnsTrue
{
	OCMockMockTestClassReturnsTrueBlock mockBlock;

	if ((mockBlock = [[OCMockManager sharedMockManager] mockingBlockForLocation:OCMockLocationMockTestClassReturnsTrue]) != nil)
	{
		return (mockBlock());
	}
	else
	{
		return ([self ocm_returnsTrue]);
	}
}

- (BOOL)ocm_returnsFalse
{
	OCMockMockTestClassReturnsFalseBlock mockBlock;

	if ((mockBlock = [[OCMockManager sharedMockManager] mockingBlockForLocation:OCMockLocationMockTestClassReturnsFalse]) != nil)
	{
		return (mockBlock());
	}
	else
	{
		return ([self ocm_returnsFalse]);
	}
}

@end

OCMockLocation OCMockLocationMockTestClassReturnsTrue = @"OCMockTestClass.returnsTrue";
OCMockLocation OCMockLocationMockTestClassReturnsFalse = @"OCMockTestClass.returnsFalse";

