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
	NSURL *originallyRequestedURL;

	XCTestExpectation *_requestWithoutCookiesReceivedExpectation;
	XCTestExpectation *_requestForCookiesReceivedExpectation;
	XCTestExpectation *_requestWithCookiesReceivedExpectation;
}

@end

@implementation CoreRedirectTests

- (void)setUp {
	__weak CoreRedirectTests *weakSelf = self;

	hostSimulator = [OCHostSimulator cookieRedirectSimulatorWithRequestWithoutCookiesHandler:^{
		CoreRedirectTests *strongSelf;

		if ((strongSelf = weakSelf) != nil)
		{
			[strongSelf->_requestWithoutCookiesReceivedExpectation fulfill];
		}
	} requestForCookiesHandler:^{
		CoreRedirectTests *strongSelf;

		if ((strongSelf = weakSelf) != nil)
		{
			[strongSelf->_requestForCookiesReceivedExpectation fulfill];
		}
	} requestWithCookiesHandler:^{
		CoreRedirectTests *strongSelf;

		if ((strongSelf = weakSelf) != nil)
		{
			[strongSelf->_requestWithCookiesReceivedExpectation fulfill];
		}
	}];
}

- (void)retrieveCertificateForBookmark:(OCBookmark *)bookmark response:(void(^)(OCCertificate *certificate))certificateHandler
{
	OCConnection *connection = [[OCConnection alloc] initWithBookmark:bookmark];

	[connection connectWithCompletionHandler:^(NSError * _Nullable error, OCIssue * _Nullable issue) {
		[connection sendRequest:[OCHTTPRequest requestWithURL:[NSURL URLWithString:@"/status.php" relativeToURL:bookmark.url]] ephermalCompletionHandler:^(OCHTTPRequest * _Nonnull request, OCHTTPResponse * _Nullable response, NSError * _Nullable error) {
			bookmark.certificate = request.httpResponse.certificate;
			bookmark.certificateModificationDate = NSDate.date;

			[connection disconnectWithCompletionHandler:^{
				certificateHandler(request.httpResponse.certificate);
			}];
		}];
	}];
}

- (void)testCoreCookieRedirect
{
	XCTestExpectation *certificateExpectation = [self expectationWithDescription:@"Receive certificate"];
	XCTestExpectation *coreDoneExpectation = [self expectationWithDescription:@"Core done"];
	OCBookmark *bookmark = OCTestTarget.userBookmark;

	_requestWithoutCookiesReceivedExpectation = [self expectationWithDescription:@"Request without cookies received"];
	_requestForCookiesReceivedExpectation = [self expectationWithDescription:@"Request for cookies received"];
	_requestWithCookiesReceivedExpectation = [self expectationWithDescription:@"Request with cookies received"];

	[self retrieveCertificateForBookmark:bookmark response:^(OCCertificate *certificate) {
		self->hostSimulator.certificate = certificate;

		NSLog(@"Certificate: %@", certificate);

		OCLogDebug(@"===================== ACTUAL TEST =====================");

		OCCore *core;

		if ((core = [[OCCore alloc] initWithBookmark:bookmark]) != nil)
		{
			core.connection.hostSimulator = self->hostSimulator;
			core.connection.cookieStorage = [OCHTTPCookieStorage new];

			[core startWithCompletionHandler:^(id sender, NSError *error) {
				XCTAssert(error == nil);

				[core stopWithCompletionHandler:^(id sender, NSError *error) {
					XCTAssert(error == nil);

					[coreDoneExpectation fulfill];
				}];
			}];
		}

		[certificateExpectation fulfill];
	}];

	[self waitForExpectationsWithTimeout:40 handler:nil];
}

- (void)testConnectionSetupCookieRedirect
{
	XCTestExpectation *certificateExpectation = [self expectationWithDescription:@"Receive certificate"];
	XCTestExpectation *prepareForSetupExpectaction = [self expectationWithDescription:@"Prepare for setup"];
	XCTestExpectation *generateAuthDataExpectaction = [self expectationWithDescription:@"Generate auth data"];
	XCTestExpectation *connectExpectaction = [self expectationWithDescription:@"Connect"];
	XCTestExpectation *disconnectExpectaction = [self expectationWithDescription:@"Disonnect"];
	OCBookmark *bookmark = [OCBookmark bookmarkForURL:[NSURL URLWithString:@"https://demo.owncloud.org/"]];

	_requestWithoutCookiesReceivedExpectation = [self expectationWithDescription:@"Request without cookies received"];
	_requestForCookiesReceivedExpectation = [self expectationWithDescription:@"Request for cookies received"];
	_requestWithCookiesReceivedExpectation = [self expectationWithDescription:@"Request with cookies received"];

	[self retrieveCertificateForBookmark:bookmark response:^(OCCertificate *certificate) {
		OCConnection *connection;

		OCLogDebug(@"===================== ACTUAL TEST =====================");

		if ((connection = [[OCConnection alloc] initWithBookmark:bookmark]) != nil)
		{
			connection.hostSimulator = self->hostSimulator;
			connection.cookieStorage = [OCHTTPCookieStorage new];

			[connection prepareForSetupWithOptions:nil completionHandler:^(OCIssue * _Nullable issue, NSURL * _Nullable suggestedURL, NSArray<OCAuthenticationMethodIdentifier> * _Nullable supportedMethods, NSArray<OCAuthenticationMethodIdentifier> * _Nullable preferredAuthenticationMethods) {
				XCTAssert(supportedMethods.count > 0);
				XCTAssert(preferredAuthenticationMethods.count > 0);

				OCLogDebug(@"issue=%@, suggestedURL=%@, supportedMethods=%@, preferredAuthenticationMethods=%@", issue, suggestedURL, supportedMethods, preferredAuthenticationMethods);

				[prepareForSetupExpectaction fulfill];

				[connection generateAuthenticationDataWithMethod:preferredAuthenticationMethods.lastObject options:@{
					OCAuthenticationMethodUsernameKey   : @"demo",
					OCAuthenticationMethodPassphraseKey : @"demo"
				} completionHandler:^(NSError * _Nullable error, OCAuthenticationMethodIdentifier  _Nullable authenticationMethodIdentifier, NSData * _Nullable authenticationData) {
					XCTAssert(error == nil);
					XCTAssert(authenticationData != nil);
					XCTAssert(authenticationMethodIdentifier != nil);

					bookmark.authenticationMethodIdentifier = authenticationMethodIdentifier;
					bookmark.authenticationData = authenticationData;

					[generateAuthDataExpectaction fulfill];

					[connection connectWithCompletionHandler:^(NSError * _Nullable error, OCIssue * _Nullable issue) {
						XCTAssert(error == nil);
						XCTAssert(issue == nil);

						[connection disconnectWithCompletionHandler:^{
							[disconnectExpectaction fulfill];
						}];

						[connectExpectaction fulfill];
					}];
				}];
			}];
		}

		[certificateExpectation fulfill];
	}];

	[self waitForExpectationsWithTimeout:40 handler:nil];
}

@end
