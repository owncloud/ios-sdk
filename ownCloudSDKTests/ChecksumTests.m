//
//  ChecksumTests.m
//  ownCloudSDKTests
//
//  Created by Felix Schwarz on 21.06.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <ownCloudSDK/ownCloudSDK.h>

@interface ChecksumTests : XCTestCase

@end

@implementation ChecksumTests

- (void)testChecksumComputationAndVerification
{
	NSURL *fakeCertURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"fake-demo_owncloud_org" withExtension:@"cer"];
	NSString *fakeCertSHA1Checksum = @"4c0400b48c9935a47e38c35a2dbbe66d69d6c660";
	NSString *validHeaderString = [NSString stringWithFormat:@"%@:%@", OCChecksumAlgorithmIdentifierSHA1, fakeCertSHA1Checksum];

	XCTestExpectation *computeExpectation = [self expectationWithDescription:@"Computation returned"];
	XCTestExpectation *verifiedExpectation = [self expectationWithDescription:@"Verification returned"];
	XCTestExpectation *unsupportedVerifiedExpectation = [self expectationWithDescription:@"Unsupported verification returned"];
	XCTestExpectation *incorrectVerifiedExpectation = [self expectationWithDescription:@"Incorrect verification returned"];

	// Verify computation and verification
	[OCChecksum computeForFile:fakeCertURL checksumAlgorithm:OCChecksumAlgorithmIdentifierSHA1 completionHandler:^(NSError *error, OCChecksum *computedChecksum) {
		XCTAssert((error==nil));
		XCTAssert((computedChecksum!=nil));

		XCTAssert([computedChecksum.checksum isEqual:fakeCertSHA1Checksum]);
		XCTAssert([computedChecksum.algorithmIdentifier isEqual:OCChecksumAlgorithmIdentifierSHA1]);

		XCTAssert([[OCChecksum checksumFromHeaderString:validHeaderString] isEqual:computedChecksum]);

		OCLog(@"Computed checksum: %@", computedChecksum.headerString);

		[computeExpectation fulfill];

		[computedChecksum verifyForFile:fakeCertURL completionHandler:^(NSError *error, BOOL isValid, OCChecksum *actualChecksum) {
			XCTAssert(error==nil);
			XCTAssert(isValid==YES);
			XCTAssert([actualChecksum isEqual:computedChecksum]);

			XCTAssert([actualChecksum.checksum isEqual:fakeCertSHA1Checksum]);
			XCTAssert([actualChecksum.algorithmIdentifier isEqual:OCChecksumAlgorithmIdentifierSHA1]);

			OCLog(@"Actual checksum: %@", computedChecksum.headerString);

			[verifiedExpectation fulfill];
		}];
	}];

	// Verify handling of unknown algorithms
	[[[OCChecksum alloc] initWithAlgorithmIdentifier:@"NONE" checksum:@"123"] verifyForFile:fakeCertURL completionHandler:^(NSError *error, BOOL isValid, OCChecksum *actualChecksum) {
		[unsupportedVerifiedExpectation fulfill];

		XCTAssert(error!=nil);
		XCTAssert(isValid==NO);
		XCTAssert(actualChecksum==nil);

		XCTAssert([error isOCErrorWithCode:OCErrorFeatureNotImplemented]);
	}];

	// Verify verification of invalid checksums
	[[[OCChecksum alloc] initWithAlgorithmIdentifier:OCChecksumAlgorithmIdentifierSHA1 checksum:@"123"] verifyForFile:fakeCertURL completionHandler:^(NSError *error, BOOL isValid, OCChecksum *actualChecksum) {
		[incorrectVerifiedExpectation fulfill];

		XCTAssert(error==nil);
		XCTAssert(isValid==NO);
		XCTAssert(actualChecksum!=nil);
	}];

	[self waitForExpectationsWithTimeout:5 handler:nil];
}

@end
