//
//  ExtensionTests.m
//  ownCloudSDKTests
//
//  Created by Felix Schwarz on 05.12.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <ownCloudSDK/ownCloudSDK.h>

@interface ExtensionTests : XCTestCase

@end

@implementation ExtensionTests

- (void)setUp
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		OCExtension *extension1, *extension2, *extension3, *extension4;

		extension1 = [OCExtension extensionWithIdentifier:@"ext.1" type:@"test.extension" location:@"menu" features:@{ @"isFirst" : @(YES) } objectProvider:^id(OCExtension * _Nonnull extension, OCExtensionContext * _Nonnull context, NSError *__autoreleasing  _Nullable * _Nullable outError) {
			return (@(1));
		}];

		extension2 = [OCExtension extensionWithIdentifier:@"ext.2" type:@"test.extension" location:@"window" features:@{ @"isFirst" : @(NO), @"isSecond" : @(YES) } objectProvider:^id(OCExtension * _Nonnull extension, OCExtensionContext * _Nonnull context, NSError *__autoreleasing  _Nullable * _Nullable outError) {
			return (@(2));
		}];

		extension2.customMatcher = ^OCExtensionPriority(OCExtensionContext * _Nonnull context, OCExtensionPriority defaultPriority) {
			dispatch_block_t customMatcherBlock;

			if ((customMatcherBlock = context.preferences[@"customMatcherBlock"]) != nil)
			{
				customMatcherBlock();
			}

			return (defaultPriority);
		};

		extension3 = [OCExtension extensionWithIdentifier:@"ext.3" type:@"test.extension" location:nil features:nil objectProvider:^id(OCExtension * _Nonnull extension, OCExtensionContext * _Nonnull context, NSError *__autoreleasing  _Nullable * _Nullable outError) {
			return (@(3));
		}];

		extension4 = [OCExtension extensionWithIdentifier:@"ext.4" type:@"test.other-extension" location:nil features:nil objectProvider:^id(OCExtension * _Nonnull extension, OCExtensionContext * _Nonnull context, NSError *__autoreleasing  _Nullable * _Nullable outError) {
			return (@(4));
		}];

		[OCExtensionManager.sharedExtensionManager addExtension:extension1];
		[OCExtensionManager.sharedExtensionManager addExtension:extension2];
		[OCExtensionManager.sharedExtensionManager addExtension:extension3];
		[OCExtensionManager.sharedExtensionManager addExtension:extension4];
	});
}

- (void)testMatching
{
	NSError *error = nil;
	NSArray <OCExtensionMatch *> *matches;
	OCExtensionContext *context;
	XCTestExpectation *expectCustomMatcherExecution = [self expectationWithDescription:@"Custom matcher ran block"];
	XCTestExpectation *expectAsyncReturn = [self expectationWithDescription:@"Async matching completed"];

	void (^VerifyMatches)(NSArray <OCExtensionMatch *> *matches, NSArray <OCExtensionIdentifier> *expectedIdentifiers, BOOL allowUnexpected) = ^(NSArray <OCExtensionMatch *> *matches, NSArray <OCExtensionIdentifier> *expectedExtensionIdentifiers, BOOL allowUnexpected){
		NSMutableArray <OCExtensionIdentifier> *expectedIdentifiers = [[NSMutableArray alloc] initWithArray:expectedExtensionIdentifiers];

		XCTAssert((matches.count == expectedIdentifiers.count) || allowUnexpected);

		for (OCExtensionMatch *match in matches)
		{
			XCTAssert(match.extension.identifier != nil);
			XCTAssert([expectedIdentifiers containsObject:match.extension.identifier] || allowUnexpected);
			[expectedIdentifiers removeObject:match.extension.identifier];
		}

		XCTAssert(expectedIdentifiers.count == 0);
	};

	// Match all for location
	matches = [OCExtensionManager.sharedExtensionManager provideExtensionsForContext:[OCExtensionContext contextWithLocation:[OCExtensionLocation locationOfType:@"test.extension" identifier:nil] requirements:nil preferences:nil] error:&error];
	XCTAssert(matches!=nil);
	VerifyMatches(matches, @[ @"ext.1", @"ext.2", @"ext.3" ], NO);

	matches = [OCExtensionManager.sharedExtensionManager provideExtensionsForContext:[OCExtensionContext contextWithLocation:[OCExtensionLocation locationOfType:@"test.other-extension" identifier:nil] requirements:nil preferences:nil] error:&error];
	XCTAssert(matches!=nil);
	VerifyMatches(matches, @[ @"ext.4" ], NO);

	matches = [OCExtensionManager.sharedExtensionManager provideExtensionsForContext:[OCExtensionContext contextWithLocation:nil requirements:nil preferences:nil] error:&error];
	XCTAssert(matches!=nil);
	VerifyMatches(matches, @[ @"ext.1", @"ext.2", @"ext.3", @"ext.4" ], YES);

	// Match for location and identifier (no location == all locations)
	matches = [OCExtensionManager.sharedExtensionManager provideExtensionsForContext:[OCExtensionContext contextWithLocation:[OCExtensionLocation locationOfType:@"test.extension" identifier:@"menu"] requirements:nil preferences:nil] error:&error];
	XCTAssert(matches!=nil);
	VerifyMatches(matches, @[ @"ext.1", @"ext.3" ], NO);

	matches = [OCExtensionManager.sharedExtensionManager provideExtensionsForContext:[OCExtensionContext contextWithLocation:[OCExtensionLocation locationOfType:@"test.extension" identifier:@"window"] requirements:nil preferences:nil] error:&error];
	XCTAssert(matches!=nil);
	VerifyMatches(matches, @[ @"ext.2", @"ext.3" ], NO);

	// Match for required features
	context = [OCExtensionContext contextWithLocation:[OCExtensionLocation locationOfType:@"test.extension" identifier:nil] requirements:@{ @"isFirst" : @(YES) } preferences:nil];
	matches = [OCExtensionManager.sharedExtensionManager provideExtensionsForContext:context error:&error];
	XCTAssert(matches!=nil);
	XCTAssert([[matches[0].extension provideObjectForContext:context] isEqual:@(1)]); // Tests objectProvider block
	VerifyMatches(matches, @[ @"ext.1" ], NO);

	matches = [OCExtensionManager.sharedExtensionManager provideExtensionsForContext:[OCExtensionContext contextWithLocation:[OCExtensionLocation locationOfType:@"test.extension" identifier:nil] requirements:@{ @"isSecond" : @(YES) } preferences:nil] error:&error];
	XCTAssert(matches!=nil);
	VerifyMatches(matches, @[ @"ext.2" ], NO);

	// Match for preferred features
	matches = [OCExtensionManager.sharedExtensionManager provideExtensionsForContext:[OCExtensionContext contextWithLocation:[OCExtensionLocation locationOfType:@"test.extension" identifier:nil] requirements:nil preferences:@{ @"isSecond" : @(YES) }] error:&error];
	XCTAssert(matches!=nil);
	VerifyMatches(matches, @[ @"ext.2", @"ext.1", @"ext.3" ], NO);
	XCTAssert([matches[0].extension.identifier isEqualToString:@"ext.2"]);

	matches = [OCExtensionManager.sharedExtensionManager provideExtensionsForContext:[OCExtensionContext contextWithLocation:[OCExtensionLocation locationOfType:@"test.extension" identifier:nil] requirements:nil preferences:@{ @"isFirst" : @(YES), @"customMatcherBlock" : [ ^{ [expectCustomMatcherExecution fulfill]; } copy] }] error:&error];
	XCTAssert(matches!=nil);
	VerifyMatches(matches, @[ @"ext.1", @"ext.2", @"ext.3" ], NO);
	XCTAssert([matches[0].extension.identifier isEqualToString:@"ext.1"]);

	// Test async
	context = [OCExtensionContext contextWithLocation:[OCExtensionLocation locationOfType:@"test.extension" identifier:nil] requirements:@{ @"isFirst" : @(YES) } preferences:nil];
	[OCExtensionManager.sharedExtensionManager provideExtensionsForContext:context completionHandler:^(NSError * _Nullable error, OCExtensionContext * _Nonnull context, NSArray<OCExtensionMatch *> *matches) {
		XCTAssert(matches!=nil);
		XCTAssert([[matches[0].extension provideObjectForContext:context] isEqual:@(1)]); // Tests objectProvider block
		VerifyMatches(matches, @[ @"ext.1" ], NO);

		[expectAsyncReturn fulfill];
	}];

	[self waitForExpectationsWithTimeout:30 handler:nil];
}

@end
