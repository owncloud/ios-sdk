//
//  ownCloudMockingTests.m
//  ownCloudMockingTests
//
//  Created by Felix Schwarz on 11.07.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

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
