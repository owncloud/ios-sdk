//
//  CoreRedirectTests.m
//  ownCloudSDKTests
//
//  Created by Felix Schwarz on 18.08.20.
//  Copyright © 2020 ownCloud GmbH. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <ownCloudSDK/ownCloudSDK.h>
#import <ownCloudMocking/ownCloudMocking.h>
#import "OCCore+Internal.h"
#import "TestTools.h"
#import "OCTestTarget.h"
#import "OCItem+OCItemCreationDebugging.h"
#import "OCHostSimulator.h"

@interface CoreRedirectTests : XCTestCase
{
	OCHostSimulator *hostSimulator;
	OCHTTPResponse *hostStatusResponse;
	NSURL *originallyRequestedURL;

	XCTestExpectation *_requestWithoutCookiesReceivedExpectation;
	XCTestExpectation *_requestForCookiesReceivedExpectation;
	XCTestExpectation *_requestWithCookiesReceivedExpectation;
}

@end

@implementation CoreRedirectTests

- (void)setUp {
	__weak CoreRedirectTests *weakSelf = self;

	hostSimulator = [OCHostSimulator new];
	hostSimulator.requestHandler = ^BOOL(OCConnection *connection, OCHTTPRequest *request, OCHostSimulatorResponseHandler responseHandler) {
		CoreRedirectTests *strongSelf = weakSelf;

		if ([request.url.path isEqual:@"/set/cookies"])
		{
			NSString *originalURLString = strongSelf->originallyRequestedURL.absoluteString;

			responseHandler(nil, [OCHostSimulatorResponse responseWithURL:request.url statusCode:OCHTTPStatusCodeTEMPORARY_REDIRECT headers:@{
				@"Location" 	: originalURLString,
				@"Set-Cookie"	: @"sessionCookie=value; Max-Age=2592000; Path=/"
			} contentType:@"text/html" body:nil]);

			[strongSelf->_requestForCookiesReceivedExpectation fulfill];
			strongSelf->_requestForCookiesReceivedExpectation = nil;

			return (YES);
		}

		if (request.headerFields[@"Cookie"] == nil)
		{
			strongSelf->originallyRequestedURL = request.url;

			responseHandler(nil, [OCHostSimulatorResponse responseWithURL:request.url statusCode:OCHTTPStatusCodeTEMPORARY_REDIRECT headers:@{
				@"Location" : @"/set/cookies"
			} contentType:@"text/html" body:nil]);

			[strongSelf->_requestWithoutCookiesReceivedExpectation fulfill];
			strongSelf->_requestWithoutCookiesReceivedExpectation = nil;

			return (YES);
		}
		else
		{
			if (strongSelf->_requestWithoutCookiesReceivedExpectation == nil)
			{
				[strongSelf->_requestWithCookiesReceivedExpectation fulfill];
				strongSelf->_requestWithCookiesReceivedExpectation = nil;
			}
		}

		return (NO);
	};
	hostSimulator.unroutableRequestHandler = nil;
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)retrieveCertificateForBookmark:(OCBookmark *)bookmark response:(void(^)(OCCertificate *certificate, OCHTTPResponse *statusResponse))certificateHandler
{
	OCConnection *connection = [[OCConnection alloc] initWithBookmark:bookmark];

	[connection connectWithCompletionHandler:^(NSError * _Nullable error, OCIssue * _Nullable issue) {
		[connection sendRequest:[OCHTTPRequest requestWithURL:[NSURL URLWithString:@"/status.php" relativeToURL:bookmark.url]] ephermalCompletionHandler:^(OCHTTPRequest * _Nonnull request, OCHTTPResponse * _Nullable response, NSError * _Nullable error) {
			bookmark.certificate = request.httpResponse.certificate;
			bookmark.certificateModificationDate = NSDate.date;

			[connection disconnectWithCompletionHandler:^{
				certificateHandler(request.httpResponse.certificate, request.httpResponse);
			}];
		}];
	}];
}

- (void)testCookieRedirect
{
	XCTestExpectation *expectCertificate = [self expectationWithDescription:@"Receive certificate"];
	XCTestExpectation *expectCoreDone = [self expectationWithDescription:@"Core done"];
	OCBookmark *bookmark = OCTestTarget.userBookmark;

	_requestWithoutCookiesReceivedExpectation = [self expectationWithDescription:@"Request without cookies received"];
	_requestForCookiesReceivedExpectation = [self expectationWithDescription:@"Request for cookies received"];
	_requestWithCookiesReceivedExpectation = [self expectationWithDescription:@"Request with cookies received"];

	[self retrieveCertificateForBookmark:bookmark response:^(OCCertificate *certificate, OCHTTPResponse *statusResponse) {
		self->hostStatusResponse = statusResponse;

		self->hostSimulator.certificate = certificate;

		NSLog(@"Certificate: %@", certificate);

		OCCore *core;

		if ((core = [[OCCore alloc] initWithBookmark:bookmark]) != nil)
		{
			core.connection.hostSimulator = self->hostSimulator;
			core.connection.cookieStorage = [OCHTTPCookieStorage new];

			[core startWithCompletionHandler:^(id sender, NSError *error) {
				[core stopWithCompletionHandler:^(id sender, NSError *error) {
					[expectCoreDone fulfill];
				}];
			}];
		}

		[expectCertificate fulfill];
	}];

	[self waitForExpectationsWithTimeout:40 handler:nil];
}

@end
