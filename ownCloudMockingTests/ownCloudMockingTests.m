//
//  ownCloudMockingTests.m
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

#import <XCTest/XCTest.h>
#import <ownCloudMocking/ownCloudMocking.h>

#import "OCMockTestClass.h"
#import "OCMockTestClass+OCMocking.h"

@interface ownCloudMockingTests : XCTestCase

@end

@implementation ownCloudMockingTests

- (void)testMocking
{
	OCMockTestClass *mockTest = [OCMockTestClass new];

	XCTAssert(OCMockTestClass.returnsTrue==YES);
	XCTAssert(mockTest.returnsFalse==NO);

	[OCMockManager.sharedMockManager addMockingBlocks:@{
		OCMockLocationMockTestClassReturnsTrue  : ^{ return (NO); },
		OCMockLocationMockTestClassReturnsFalse : ^{ return (YES); },
	}];

	XCTAssert(OCMockTestClass.returnsTrue==NO);
	XCTAssert(mockTest.returnsFalse==YES);

	[OCMockManager.sharedMockManager removeMockingBlocksForClass:[OCMockTestClass class]];

	XCTAssert(OCMockTestClass.returnsTrue==YES);
	XCTAssert(mockTest.returnsFalse==NO);
}

@end
