//
//  HostSimulatorTests.m
//  ownCloudSDKTests
//
//  Created by Felix Schwarz on 22.03.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import <XCTest/XCTest.h>

#import <ownCloudSDK/ownCloudSDK.h>
#import <ownCloudMocking/ownCloudMocking.h>
#import "OCTestTarget.h"

@interface HostSimulatorTests : XCTestCase
{
	OCHostSimulator *hostSimulator;
}

@end

@implementation HostSimulatorTests

- (void)setUp {
	[super setUp];
	// Put setup code here. This method is called before the invocation of each test method in the class.

	hostSimulator = [[OCHostSimulator alloc] init];
}

- (void)tearDown {
	// Put teardown code here. This method is called after the invocation of each test method in the class.
	[super tearDown];
}

- (void)_runPreparationTestsForURL:(NSURL *)url completionHandler:(void(^)(NSURL *url, OCBookmark *bookmark, OCIssue *issue, NSArray <OCAuthenticationMethodIdentifier> *supportedMethods, NSArray <OCAuthenticationMethodIdentifier> *preferredAuthenticationMethods))completionHandler
{
	XCTestExpectation *expectAnswer = [self expectationWithDescription:@"Received reply"];

	OCBookmark *bookmark = [OCBookmark bookmarkForURL:url];

	OCConnection *connection;

	// Force-stop all pipelines to get rid of cached HTTPS certificates
	OCSyncExec(waitForForceStops, {
		[OCHTTPPipelineManager.sharedPipelineManager forceStopAllPipelinesGracefully:YES completionHandler:^{
			OCSyncExecDone(waitForForceStops);
		}];
	});

	connection = [[OCConnection alloc] initWithBookmark:bookmark];
	connection.hostSimulator = hostSimulator;

	[connection prepareForSetupWithOptions:nil completionHandler:^(OCIssue *issue,  NSURL *suggestedURL, NSArray<OCAuthenticationMethodIdentifier> *supportedMethods, NSArray<OCAuthenticationMethodIdentifier> *preferredAuthenticationMethods) {
		OCLog(@"Issues: %@", issue.issues);
		OCLog(@"SuggestedURL: %@", suggestedURL);
		OCLog(@"Supported authentication methods: %@ - Preferred authentication methods: %@", supportedMethods, preferredAuthenticationMethods);

		completionHandler(url, bookmark, issue, supportedMethods, preferredAuthenticationMethods);

		[expectAnswer fulfill];
	}];

	[self waitForExpectationsWithTimeout:60 handler:nil];
}

- (void)testSimulatorMissingCertificate
{
	[self _runPreparationTestsForURL:OCTestTarget.secureTargetURL completionHandler:^(NSURL *url, OCBookmark *bookmark, OCIssue *issue, NSArray<OCAuthenticationMethodIdentifier> *supportedMethods, NSArray<OCAuthenticationMethodIdentifier> *preferredAuthenticationMethods) {
		XCTAssert(issue.issues.count==1, @"1 issue found");

		XCTAssert((issue.issues[0].type == OCIssueTypeError), @"Issue is error issue");
		XCTAssert((issue.issues[0].level == OCIssueLevelError), @"Issue level is error");

		XCTAssert((issue.issues[0].error.code == OCErrorCertificateMissing), @"Error is that certificate is missing");
	}];
}

- (void)testSimulatorSimulatedNotFoundResponses
{
	[self _runPreparationTestsForURL:OCTestTarget.insecureTargetURL completionHandler:^(NSURL *url, OCBookmark *bookmark, OCIssue *issue, NSArray<OCAuthenticationMethodIdentifier> *supportedMethods, NSArray<OCAuthenticationMethodIdentifier> *preferredAuthenticationMethods) {
		XCTAssert(issue.issues.count==1, @"1 issue found");

		XCTAssert((issue.issues[0].type == OCIssueTypeError), @"Issue is error issue");
		XCTAssert((issue.issues[0].level == OCIssueLevelError), @"Issue level is error");

		XCTAssert((issue.issues[0].error.code == OCErrorServerDetectionFailed), @"Error is that server couldn't be detected (thanks to simulated 404 responses)");
	}];
}

- (void)testSimulatorInjectResponsesIntoRealConnection
{
	// Do not answer with 404 responses for all unimplemented URLs, but rather let the request through to the real network
	hostSimulator.unroutableRequestHandler = nil;

	hostSimulator.responseByPath = @{

		// Mock response to "/remote.php/dav/files" so that demo.owncloud.org appears to also offer OAuth2 authentication (which it at the time of writing doesn't)
		@"/remote.php/dav/files" :
			[OCHostSimulatorResponse responseWithURL:nil
						statusCode:OCHTTPStatusCodeOK
						headers:@{
							@"Www-Authenticate" : @"Bearer realm=\"\", Basic realm=\"\""
						}
						contentType:@"application/xml"
						body:@""]

	};

	[self _runPreparationTestsForURL:OCTestTarget.secureTargetURL completionHandler:^(NSURL *url, OCBookmark *bookmark, OCIssue *issue, NSArray<OCAuthenticationMethodIdentifier> *supportedMethods, NSArray<OCAuthenticationMethodIdentifier> *preferredAuthenticationMethods) {
		XCTAssert(issue.issues.count==1, @"1 issue found");

		XCTAssert((issue.issues[0].type == OCIssueTypeCertificate), @"Issue is certificate issue");
		XCTAssert((issue.issues[0].level == OCIssueLevelInformal), @"Issue level is informal");

		XCTAssert((preferredAuthenticationMethods.count == 2), @"2 preferred authentication methods");
		XCTAssert([preferredAuthenticationMethods[0] isEqual:OCAuthenticationMethodIdentifierOAuth2], @"OAuth2 is first detected authentication method");
		XCTAssert([preferredAuthenticationMethods[1] isEqual:OCAuthenticationMethodIdentifierBasicAuth], @"Basic Auth is second detected authentication method");

		[issue approve];

		XCTAssert (([bookmark.url isEqual:url]) && (bookmark.originURL==nil), @"Bookmark has expected values");
	}];
}

@end

