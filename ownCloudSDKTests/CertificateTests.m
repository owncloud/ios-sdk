//
//  CertificateTests.m
//  ownCloudSDKTests
//
//  Created by Felix Schwarz on 13.03.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <ownCloudSDK/ownCloudSDK.h>
#import <ownCloudUI/ownCloudUI.h>

@interface CertificateTests : XCTestCase

@end

@implementation CertificateTests

- (void)setUp {
	[super setUp];
	// Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
	// Put teardown code here. This method is called after the invocation of each test method in the class.
	[super tearDown];
}

- (void)testCertificateMetaDataParsing
{
	NSURL *fakeCertURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"fake-demo_owncloud_org" withExtension:@"cer"];
	NSData *fakeCertData = [NSData dataWithContentsOfURL:fakeCertURL];
	NSError *parseError;
	NSDictionary *metaData;
	XCTestExpectation *viewNodesReceivedExpectation = [self expectationWithDescription:@"expect view nodes"];

	OCCertificate *certificate = [OCCertificate certificateWithCertificateData:fakeCertData hostName:@"demo.owncloud.org"];

	XCTAssert(((metaData = [certificate metaDataWithError:&parseError]) != nil), @"Metadata returned");
	XCTAssert([((NSDictionary *)metaData[OCCertificateMetadataSubjectKey])[OCCertificateMetadataCommonNameKey] isEqual:@"demo.owncloud.org"], @"Common name is correct");

	OCLog(@"Certificate metadata: %@ Error: %@", metaData, parseError);

	[certificate certificateDetailsViewNodesWithValidationCompletionHandler:^(NSArray<OCCertificateDetailsViewNode *> *nodes) {
		OCLog(@"DetailsViewNodes: %@", nodes);

		XCTAssert(nodes!=nil);
		XCTAssert(nodes.count==7);

		[viewNodesReceivedExpectation fulfill];
	}];

	[self waitForExpectationsWithTimeout:5 handler:nil];
}

- (void)testCertificateMetaDataParsingFromWeb
{
	NSArray <NSURL *> *urlsToTest = @[
		[NSURL URLWithString:@"https://demo.owncloud.org/"],
		[NSURL URLWithString:@"https://www.braintreegateway.com/"]
	];

	for (NSURL *urlToTest in urlsToTest)
	{
		OCConnection *connection = [[OCConnection alloc] initWithBookmark:[OCBookmark bookmarkForURL:urlToTest]];
		OCHTTPRequest *request = [OCHTTPRequest requestWithURL:connection.bookmark.url];

		request.forceCertificateDecisionDelegation = YES;
		request.ephermalRequestCertificateProceedHandler = ^(OCHTTPRequest *request, OCCertificate *certificate, OCCertificateValidationResult validationResult, NSError *certificateValidationError, OCConnectionCertificateProceedHandler proceedHandler) {
			NSError *parseError = nil;
			NSDictionary *metaData = [certificate metaDataWithError:&parseError];

			OCLog(@"Certificate metadata: %@ Error: %@", metaData, parseError);

			XCTAssert([((NSDictionary *)metaData[OCCertificateMetadataSubjectKey])[OCCertificateMetadataCommonNameKey] isEqual:urlToTest.host], @"Common name is host name");

			proceedHandler(YES, nil);
		};

		[connection sendSynchronousRequest:request];
	}
}

@end
