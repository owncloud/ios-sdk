//
//  ConnectionTests.m
//  ownCloudSDKTests
//
//  Created by Felix Schwarz on 25.02.18.
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
#import <ownCloudSDK/ownCloudSDK.h>

@interface ConnectionTests : XCTestCase

@end

@implementation ConnectionTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testBasicRequest
{
	XCTestExpectation *expectAnswer = [self expectationWithDescription:@"Received reply"];
	XCTestExpectation *expectContentMatch = [self expectationWithDescription:@"Reply content matches expectations"];

	OCBookmark *bookmark = [OCBookmark bookmarkForURL:[NSURL URLWithString:@"https://www.apple.com/"]];
	OCConnection *connection;
	OCConnectionRequest *request;
	
	connection = [[OCConnection alloc] initWithBookmark:bookmark];
	
	request = [OCConnectionRequest requestWithURL:bookmark.url];
	
	[connection sendRequest:request toQueue:connection.commandQueue ephermalCompletionHandler:^(OCConnectionRequest *request, NSError *error) {
		[expectAnswer fulfill];

		NSLog(@"Result of request: %@ (error: %@):\n## Task: %@\n\n## Response: %@\n\n## Body: %@", request, error, request.urlSessionTask, request.response, request.responseBodyAsString);
		
		if ((request.responseHTTPStatus.isSuccess) && ([request.responseBodyAsString containsString:@"/mac/"]))
		{
			[expectContentMatch fulfill];
		}
	}];
	
	[self waitForExpectationsWithTimeout:60 handler:nil];
}

- (void)_runPreparationTestsForURL:(NSURL *)url completionHandler:(void(^)(NSURL *url, OCBookmark *bookmark, OCConnectionIssue *issue, NSArray <OCAuthenticationMethodIdentifier> *supportedMethods, NSArray <OCAuthenticationMethodIdentifier> *preferredAuthenticationMethods))completionHandler
{
	XCTestExpectation *expectAnswer = [self expectationWithDescription:@"Received reply"];

	OCBookmark *bookmark = [OCBookmark bookmarkForURL:url];
	
	OCConnection *connection;
	
	connection = [[OCConnection alloc] initWithBookmark:bookmark];
	
	[connection prepareForSetupWithOptions:nil completionHandler:^(OCConnectionIssue *issue,  NSURL *suggestedURL, NSArray<OCAuthenticationMethodIdentifier> *supportedMethods, NSArray<OCAuthenticationMethodIdentifier> *preferredAuthenticationMethods) {
		NSLog(@"Issues: %@", issue.issues);
		NSLog(@"SuggestedURL: %@", suggestedURL);
		NSLog(@"Supported authentication methods: %@ - Preferred authentication methods: %@", supportedMethods, preferredAuthenticationMethods);
		
		completionHandler(url, bookmark, issue, supportedMethods, preferredAuthenticationMethods);
		
		[expectAnswer fulfill];
	}];
	
	[self waitForExpectationsWithTimeout:60 handler:nil];
}

- (void)testSetupPreparationSuccess
{
	[self _runPreparationTestsForURL:[NSURL URLWithString:@"https://demo.owncloud.org/"] completionHandler:^(NSURL *url, OCBookmark *bookmark, OCConnectionIssue *issue, NSArray<OCAuthenticationMethodIdentifier> *supportedMethods, NSArray<OCAuthenticationMethodIdentifier> *preferredAuthenticationMethods) {
		XCTAssert(issue.issues.count==0, @"No issues found");
		
		[issue approve];
		
		XCTAssert (([bookmark.url isEqual:url]) && (bookmark.originURL==nil), @"Bookmark has expected values");
	}];
}

- (void)testSetupPreparationInvalidURL
{
	// "Typo" in URL

	[self _runPreparationTestsForURL:[NSURL URLWithString:@"https://nosuch.owncloud/"] completionHandler:^(NSURL *url, OCBookmark *bookmark, OCConnectionIssue *issue, NSArray<OCAuthenticationMethodIdentifier> *supportedMethods, NSArray<OCAuthenticationMethodIdentifier> *preferredAuthenticationMethods) {
		XCTAssert(issue.issues.count==1, @"One issues found");
		XCTAssert([issue.issues lastObject].type==OCConnectionIssueTypeError, @"Is error issue");
		XCTAssert(![[issue.issues lastObject].error isOCErrorWithCode:OCErrorServerDetectionFailed], @"Is not OCErrorServerDetectionFailed error");

		[issue approve];
		
		XCTAssert (([bookmark.url isEqual:url]) && (bookmark.originURL==nil), @"Bookmark has expected values");
	}];
}

- (void)testSetupPreparationInvalidServer
{
	// URL doesn't point to ownCloud instance

	[self _runPreparationTestsForURL:[NSURL URLWithString:@"https://owncloud.com/"] completionHandler:^(NSURL *url, OCBookmark *bookmark, OCConnectionIssue *issue, NSArray<OCAuthenticationMethodIdentifier> *supportedMethods, NSArray<OCAuthenticationMethodIdentifier> *preferredAuthenticationMethods) {
		XCTAssert(issue.issues.count==1, @"One issues found");
		XCTAssert([issue.issues lastObject].type==OCConnectionIssueTypeError, @"Is error issue");
		XCTAssert([[issue.issues lastObject].error isOCErrorWithCode:OCErrorServerDetectionFailed], @"Is OCErrorServerDetectionFailed error");

		[issue approve];
		
		XCTAssert (([bookmark.url isEqual:url]) && (bookmark.originURL==nil), @"Bookmark has expected values");
	}];
}

- (void)testSetupPreparationProtocolUpgradeIssue
{
	// http://demo.owncloud.org/ => https://demo.owncloud.org/

	[self _runPreparationTestsForURL:[NSURL URLWithString:@"http://demo.owncloud.org/"] completionHandler:^(NSURL *url, OCBookmark *bookmark, OCConnectionIssue *issue, NSArray<OCAuthenticationMethodIdentifier> *supportedMethods, NSArray<OCAuthenticationMethodIdentifier> *preferredAuthenticationMethods) {
		XCTAssert(issue.issues.count==1, @"1 issues");
		XCTAssert((issue.issues[0].type == OCConnectionIssueTypeURLRedirection), @"Issue is URL redirection issue");
		XCTAssert([issue.issues[0].originalURL isEqual:url], @"Redirect originalURL is correct");
		XCTAssert([issue.issues[0].suggestedURL isEqual:[NSURL URLWithString:@"https://demo.owncloud.org:443/"]], @"Redirect suggestedURL is correct");

		XCTAssert (([bookmark.url isEqual:url]) && (bookmark.originURL==nil), @"Bookmark has expected values");

		[issue approve];
		
		XCTAssert (([bookmark.url isEqual:[NSURL URLWithString:@"https://demo.owncloud.org:443/"]]) && [bookmark.originURL isEqual:url] && (bookmark.originURL!=nil), @"Bookmark has expected values");
	}];
}


- (void)testSetupPreparationOneRedirectIssue
{
	// https://goo.gl/dh6yW5 => https://demo.owncloud.org/

	[self _runPreparationTestsForURL:[NSURL URLWithString:@"https://goo.gl/dh6yW5"] completionHandler:^(NSURL *url, OCBookmark *bookmark, OCConnectionIssue *issue, NSArray<OCAuthenticationMethodIdentifier> *supportedMethods, NSArray<OCAuthenticationMethodIdentifier> *preferredAuthenticationMethods) {
		XCTAssert(issue.issues.count==1, @"1 issues");
		XCTAssert((issue.issues[0].type == OCConnectionIssueTypeURLRedirection), @"Issue is URL redirection issue");
		XCTAssert([issue.issues[0].originalURL isEqual:url], @"Redirect originalURL is correct");
		XCTAssert([issue.issues[0].suggestedURL isEqual:[NSURL URLWithString:@"https://demo.owncloud.org/"]], @"Redirect suggestedURL is correct");

		XCTAssert (([bookmark.url isEqual:url]) && (bookmark.originURL==nil), @"Bookmark has expected values");

		[issue approve];
		
		XCTAssert (([bookmark.url isEqual:[NSURL URLWithString:@"https://demo.owncloud.org/"]]) && [bookmark.originURL isEqual:url] && (bookmark.originURL!=nil), @"Bookmark has expected values");
	}];
}

- (void)testSetupPreparationTwoRedirectIssues
{
	// http://bit.ly/2GTa2wD => https://goo.gl/dh6yW5 => https://demo.owncloud.org/

	[self _runPreparationTestsForURL:[NSURL URLWithString:@"http://bit.ly/2GTa2wD"] completionHandler:^(NSURL *url, OCBookmark *bookmark, OCConnectionIssue *issue, NSArray<OCAuthenticationMethodIdentifier> *supportedMethods, NSArray<OCAuthenticationMethodIdentifier> *preferredAuthenticationMethods) {
		XCTAssert(issue.issues.count==2, @"2 issues");
		XCTAssert((issue.issues[0].type == OCConnectionIssueTypeURLRedirection), @"Issue is URL redirection issue");
		XCTAssert([issue.issues[0].originalURL isEqual:[NSURL URLWithString:@"http://bit.ly/2GTa2wD"]], @"Redirect originalURL is correct");
		XCTAssert([issue.issues[0].suggestedURL isEqual:[NSURL URLWithString:@"https://goo.gl/dh6yW5"]], @"Redirect suggestedURL is correct");

		XCTAssert((issue.issues[1].type == OCConnectionIssueTypeURLRedirection), @"Issue is URL redirection issue");
		XCTAssert([issue.issues[1].originalURL isEqual:[NSURL URLWithString:@"https://goo.gl/dh6yW5"]], @"Redirect originalURL is correct");
		XCTAssert([issue.issues[1].suggestedURL isEqual:[NSURL URLWithString:@"https://demo.owncloud.org/"]], @"Redirect suggestedURL is correct");

		XCTAssert (([bookmark.url isEqual:url]) && (bookmark.originURL==nil), @"Bookmark has expected values");

		[issue approve];
		
		XCTAssert (([bookmark.url isEqual:[NSURL URLWithString:@"https://demo.owncloud.org/"]]) && [bookmark.originURL isEqual:url] && (bookmark.originURL!=nil), @"Bookmark has expected values");
	}];
}

- (void)testSetupPreparationThreeRedirectIssues
{
	// https://t.co/JTo2XnbS5G => http://bit.ly/2GTa2wD => https://goo.gl/dh6yW5 => https://demo.owncloud.org/

	[self _runPreparationTestsForURL:[NSURL URLWithString:@"https://t.co/JTo2XnbS5G"] completionHandler:^(NSURL *url, OCBookmark *bookmark, OCConnectionIssue *issue, NSArray<OCAuthenticationMethodIdentifier> *supportedMethods, NSArray<OCAuthenticationMethodIdentifier> *preferredAuthenticationMethods) {
		XCTAssert(issue.issues.count==3, @"3 issues");
		XCTAssert((issue.issues[0].type == OCConnectionIssueTypeURLRedirection), @"Issue is URL redirection issue");
		XCTAssert([issue.issues[0].originalURL isEqual:[NSURL URLWithString:@"https://t.co/JTo2XnbS5G"]], @"Redirect originalURL is correct");
		XCTAssert([issue.issues[0].suggestedURL isEqual:[NSURL URLWithString:@"http://bit.ly/2GTa2wD"]], @"Redirect suggestedURL is correct");

		XCTAssert((issue.issues[1].type == OCConnectionIssueTypeURLRedirection), @"Issue is URL redirection issue");
		XCTAssert([issue.issues[1].originalURL isEqual:[NSURL URLWithString:@"http://bit.ly/2GTa2wD"]], @"Redirect originalURL is correct");
		XCTAssert([issue.issues[1].suggestedURL isEqual:[NSURL URLWithString:@"https://goo.gl/dh6yW5"]], @"Redirect suggestedURL is correct");

		XCTAssert((issue.issues[2].type == OCConnectionIssueTypeURLRedirection), @"Issue is URL redirection issue");
		XCTAssert([issue.issues[2].originalURL isEqual:[NSURL URLWithString:@"https://goo.gl/dh6yW5"]], @"Redirect originalURL is correct");
		XCTAssert([issue.issues[2].suggestedURL isEqual:[NSURL URLWithString:@"https://demo.owncloud.org/"]], @"Redirect suggestedURL is correct");

		XCTAssert (([bookmark.url isEqual:url]) && (bookmark.originURL==nil), @"Bookmark has expected values");

		[issue approve];
		
		XCTAssert (([bookmark.url isEqual:[NSURL URLWithString:@"https://demo.owncloud.org/"]]) && [bookmark.originURL isEqual:url] && (bookmark.originURL!=nil), @"Bookmark has expected values");
	}];
}

- (void)testSetupPreparationCertificateAndFailedDetectionIssue
{
	// demo.owncloud.org is hosted on betty.owncloud.com

	[self _runPreparationTestsForURL:[NSURL URLWithString:@"https://betty.owncloud.com/"] completionHandler:^(NSURL *url, OCBookmark *bookmark, OCConnectionIssue *issue, NSArray<OCAuthenticationMethodIdentifier> *supportedMethods, NSArray<OCAuthenticationMethodIdentifier> *preferredAuthenticationMethods) {
		XCTAssert(issue.issues.count==2, @"2 issues");
		XCTAssert((issue.issues[0].type == OCConnectionIssueTypeCertificateNeedsReview), @"Issue is certificate issue");
		XCTAssert((issue.issues[1].type == OCConnectionIssueTypeError), @"Detection failed");
	}];
}

@end

