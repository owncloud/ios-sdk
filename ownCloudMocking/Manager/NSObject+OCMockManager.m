//
//  NSObject+OCMockManager.m
//  ownCloudMocking
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

#import "NSObject+OCMockManager.h"
#import "NSObject+OCSwizzle.h"

@implementation NSObject (OCMockManager)

+ (void)addMockLocation:(OCMockLocation)mockLocation forSelector:(SEL)originalSelector with:(SEL)mockingSelector
{
	// OCLogDebug(@"Added mocking location %@", mockLocation);

	[self exchangeInstanceMethodImplementationOfClass:self selector:originalSelector withSelector:mockingSelector ofClass:self];
}

+ (void)addMockLocation:(OCMockLocation)mockLocation forClassSelector:(SEL)originalSelector with:(SEL)mockingSelector;
{
	// OCLogDebug(@"Added mocking location %@", mockLocation);

	[self exchangeClassMethodImplementationOfClass:self selector:originalSelector withSelector:mockingSelector ofClass:self];
}

@end
