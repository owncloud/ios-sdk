//
//  OCMockTestClass+OCMocking.m
//  ownCloudMockingTests
//
//  Created by Felix Schwarz on 11.07.18.
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

