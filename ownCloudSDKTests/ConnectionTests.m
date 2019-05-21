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

#import "OCTestTarget.h"

@interface ConnectionTests : XCTestCase <OCEventHandler, OCClassSettingsSource>
{
	 OCConnection *newConnection;
}

@end

@implementation ConnectionTests

- (void)setUp {
	[super setUp];

	OCConnection.setupHTTPPolicy = OCConnectionSetupHTTPPolicyAllow;
}

- (void)tearDown {
	OCConnection.setupHTTPPolicy = OCConnectionSetupHTTPPolicyAuto;

	[super tearDown];
}

- (void)testBasicRequest
{
	XCTestExpectation *expectAnswer = [self expectationWithDescription:@"Received reply"];
	XCTestExpectation *expectContentMatch = [self expectationWithDescription:@"Reply content matches expectations"];

	OCBookmark *bookmark = [OCBookmark bookmarkForURL:[NSURL URLWithString:@"https://www.apple.com/"]];
	OCConnection *connection;
	OCHTTPRequest *request;

	connection = [[OCConnection alloc] initWithBookmark:bookmark];

	request = [OCHTTPRequest requestWithURL:bookmark.url];

	[connection sendRequest:request ephermalCompletionHandler:^(OCHTTPRequest *request, OCHTTPResponse *response, NSError *error) {
		[expectAnswer fulfill];

		OCLog(@"Result of request: %@ (error: %@):\n\n## Response: %@\n\n## Body: %@", request, error, response.httpURLResponse, response.bodyAsString);

		if ((response.status.isSuccess) && ([response.bodyAsString containsString:@"/mac/"]))
		{
			[expectContentMatch fulfill];
		}
	}];

	[self waitForExpectationsWithTimeout:60 handler:nil];
}

- (void)_runPreparationTestsForURL:(NSURL *)url completionHandler:(void(^)(NSURL *url, OCBookmark *bookmark, OCIssue *issue, NSArray <OCAuthenticationMethodIdentifier> *supportedMethods, NSArray <OCAuthenticationMethodIdentifier> *preferredAuthenticationMethods))completionHandler
{
	XCTestExpectation *expectAnswer = [self expectationWithDescription:@"Received reply"];

	OCBookmark *bookmark = [OCBookmark bookmarkForURL:url];
	
	OCConnection *connection;
	
	connection = [[OCConnection alloc] initWithBookmark:bookmark];
	
	[connection prepareForSetupWithOptions:nil completionHandler:^(OCIssue *issue,  NSURL *suggestedURL, NSArray<OCAuthenticationMethodIdentifier> *supportedMethods, NSArray<OCAuthenticationMethodIdentifier> *preferredAuthenticationMethods) {
		OCLog(@"Issues: %@", issue.issues);
		OCLog(@"SuggestedURL: %@", suggestedURL);
		OCLog(@"Supported authentication methods: %@ - Preferred authentication methods: %@", supportedMethods, preferredAuthenticationMethods);
		
		completionHandler(url, bookmark, issue, supportedMethods, preferredAuthenticationMethods);
		
		[expectAnswer fulfill];
	}];
	
	[self waitForExpectationsWithTimeout:60 handler:nil];
}

- (void)testSetupPreparationSuccess
{
	[self _runPreparationTestsForURL:[NSURL URLWithString:@"https://demo.owncloud.org/"] completionHandler:^(NSURL *url, OCBookmark *bookmark, OCIssue *issue, NSArray<OCAuthenticationMethodIdentifier> *supportedMethods, NSArray<OCAuthenticationMethodIdentifier> *preferredAuthenticationMethods) {
		XCTAssert(issue.issues.count==1, @"1 issue found");

		XCTAssert((issue.issues[0].type == OCIssueTypeCertificate), @"Issue is certificate issue");
		XCTAssert((issue.issues[0].level == OCIssueLevelInformal), @"Issue level is informal");

		[issue approve];
		
		XCTAssert (([bookmark.url isEqual:url]) && (bookmark.originURL==nil), @"Bookmark has expected values");
	}];
}

- (void)testSetupPreparationInvalidURL
{
	// "Typo" in URL

	[self _runPreparationTestsForURL:[NSURL URLWithString:@"https://nosuch.owncloud/"] completionHandler:^(NSURL *url, OCBookmark *bookmark, OCIssue *issue, NSArray<OCAuthenticationMethodIdentifier> *supportedMethods, NSArray<OCAuthenticationMethodIdentifier> *preferredAuthenticationMethods) {
		XCTAssert(issue.issues.count==1, @"1 issue found");
		XCTAssert(([issue issuesWithLevelGreaterThanOrEqualTo:OCIssueLevelError].count==1), @"1 error");

		XCTAssert([issue.issues lastObject].type==OCIssueTypeError, @"Is error issue");
		XCTAssert(![[issue.issues lastObject].error isOCErrorWithCode:OCErrorServerDetectionFailed], @"Is not OCErrorServerDetectionFailed error");

		[issue approve];
		
		XCTAssert (([bookmark.url isEqual:url]) && (bookmark.originURL==nil), @"Bookmark has expected values");
	}];
}

- (void)testSetupPreparationInvalidServer
{
	// URL doesn't point to ownCloud instance

	[self _runPreparationTestsForURL:[NSURL URLWithString:@"https://owncloud.com/"] completionHandler:^(NSURL *url, OCBookmark *bookmark, OCIssue *issue, NSArray<OCAuthenticationMethodIdentifier> *supportedMethods, NSArray<OCAuthenticationMethodIdentifier> *preferredAuthenticationMethods) {
		XCTAssert(issue.issues.count==2, @"2 issues");
		XCTAssert(([issue issuesWithLevelGreaterThanOrEqualTo:OCIssueLevelError].count==1), @"1 error");

		XCTAssert([issue.issues lastObject].type==OCIssueTypeError, @"Is error issue");
		XCTAssert([[issue.issues lastObject].error isOCErrorWithCode:OCErrorServerDetectionFailed], @"Is OCErrorServerDetectionFailed error");

		[issue approve];
		
		XCTAssert (([bookmark.url isEqual:url]) && (bookmark.originURL==nil), @"Bookmark has expected values");
	}];
}

- (void)testSetupPreparationProtocolUpgradeIssue
{
	// http://demo.owncloud.org/ => https://demo.owncloud.org/

	[self _runPreparationTestsForURL:[NSURL URLWithString:@"http://demo.owncloud.org/"] completionHandler:^(NSURL *url, OCBookmark *bookmark, OCIssue *issue, NSArray<OCAuthenticationMethodIdentifier> *supportedMethods, NSArray<OCAuthenticationMethodIdentifier> *preferredAuthenticationMethods) {
		XCTAssert(issue.issues.count==2, @"2 issues");
		XCTAssert(([issue issuesWithLevelGreaterThanOrEqualTo:OCIssueLevelError].count==0), @"0 errors");

		XCTAssert((issue.issues[0].type == OCIssueTypeCertificate), @"Issue is certificate issue");
		XCTAssert((issue.issues[0].level == OCIssueLevelInformal), @"Issue level is informal");

		XCTAssert((issue.issues[1].type == OCIssueTypeURLRedirection), @"Issue is URL redirection issue");
		XCTAssert((issue.issues[1].level == OCIssueLevelInformal), @"Issue level is informal");
		XCTAssert([issue.issues[1].originalURL isEqual:url], @"Redirect originalURL is correct");
		XCTAssert([issue.issues[1].suggestedURL isEqual:[NSURL URLWithString:@"https://demo.owncloud.org:443/"]], @"Redirect suggestedURL is correct");

		XCTAssert (([bookmark.url isEqual:url]) && (bookmark.originURL==nil), @"Bookmark has expected values");

		[issue approve];
		
		XCTAssert (([bookmark.url isEqual:[NSURL URLWithString:@"https://demo.owncloud.org:443/"]]) && [bookmark.originURL isEqual:url] && (bookmark.originURL!=nil), @"Bookmark has expected values");
	}];
}


- (void)testSetupPreparationOneRedirectIssue
{
	// https://goo.gl/dh6yW5 => https://demo.owncloud.org/

	[self _runPreparationTestsForURL:[NSURL URLWithString:@"https://goo.gl/dh6yW5"] completionHandler:^(NSURL *url, OCBookmark *bookmark, OCIssue *issue, NSArray<OCAuthenticationMethodIdentifier> *supportedMethods, NSArray<OCAuthenticationMethodIdentifier> *preferredAuthenticationMethods) {
		XCTAssert(issue.issues.count==3, @"3 issues");
		XCTAssert(([issue issuesWithLevelGreaterThanOrEqualTo:OCIssueLevelError].count==0), @"0 errors");

		XCTAssert((issue.issues[0].type == OCIssueTypeCertificate), @"Issue is certificate issue");
		XCTAssert((issue.issues[0].level == OCIssueLevelInformal), @"Issue level is informal");

		XCTAssert((issue.issues[1].type == OCIssueTypeCertificate), @"Issue is certificate issue");
		XCTAssert((issue.issues[1].level == OCIssueLevelInformal), @"Issue level is informal");

		XCTAssert((issue.issues[2].type == OCIssueTypeURLRedirection), @"Issue is URL redirection issue");
		XCTAssert((issue.issues[2].level == OCIssueLevelWarning), @"Issue level is warning");
		XCTAssert([issue.issues[2].originalURL isEqual:url], @"Redirect originalURL is correct");
		XCTAssert([issue.issues[2].suggestedURL isEqual:[NSURL URLWithString:@"https://demo.owncloud.org/"]], @"Redirect suggestedURL is correct");

		XCTAssert (([bookmark.url isEqual:url]) && (bookmark.originURL==nil), @"Bookmark has expected values");

		[issue approve];
		
		XCTAssert (([bookmark.url isEqual:[NSURL URLWithString:@"https://demo.owncloud.org/"]]) && [bookmark.originURL isEqual:url] && (bookmark.originURL!=nil), @"Bookmark has expected values");
	}];
}

- (void)testSetupPreparationTwoRedirectIssues
{
	// http://bit.ly/2GTa2wD => https://goo.gl/dh6yW5 => https://demo.owncloud.org/

	[self _runPreparationTestsForURL:[NSURL URLWithString:@"http://bit.ly/2GTa2wD"] completionHandler:^(NSURL *url, OCBookmark *bookmark, OCIssue *issue, NSArray<OCAuthenticationMethodIdentifier> *supportedMethods, NSArray<OCAuthenticationMethodIdentifier> *preferredAuthenticationMethods) {
		XCTAssert(issue.issues.count==4, @"4 issues");
		XCTAssert(([issue issuesWithLevelGreaterThanOrEqualTo:OCIssueLevelError].count==0), @"0 errors");

		XCTAssert((issue.issues[0].type == OCIssueTypeCertificate), @"Issue is certificate issue");
		XCTAssert((issue.issues[0].level == OCIssueLevelInformal), @"Issue level is informal");

		XCTAssert((issue.issues[1].type == OCIssueTypeURLRedirection), @"Issue is URL redirection issue");
		XCTAssert((issue.issues[1].level == OCIssueLevelWarning), @"Issue level is warning");
		XCTAssert([issue.issues[1].originalURL isEqual:[NSURL URLWithString:@"http://bit.ly/2GTa2wD"]], @"Redirect originalURL is correct");
		XCTAssert([issue.issues[1].suggestedURL isEqual:[NSURL URLWithString:@"https://goo.gl/dh6yW5"]], @"Redirect suggestedURL is correct");

		XCTAssert((issue.issues[2].type == OCIssueTypeCertificate), @"Issue is certificate issue");
		XCTAssert((issue.issues[2].level == OCIssueLevelInformal), @"Issue level is informal");

		XCTAssert((issue.issues[3].type == OCIssueTypeURLRedirection), @"Issue is URL redirection issue");
		XCTAssert((issue.issues[3].level == OCIssueLevelWarning), @"Issue level is warning");
		XCTAssert([issue.issues[3].originalURL isEqual:[NSURL URLWithString:@"https://goo.gl/dh6yW5"]], @"Redirect originalURL is correct");
		XCTAssert([issue.issues[3].suggestedURL isEqual:[NSURL URLWithString:@"https://demo.owncloud.org/"]], @"Redirect suggestedURL is correct");

		XCTAssert (([bookmark.url isEqual:url]) && (bookmark.originURL==nil), @"Bookmark has expected values");

		[issue approve];

		XCTAssert (([bookmark.url isEqual:[NSURL URLWithString:@"https://demo.owncloud.org/"]]) && [bookmark.originURL isEqual:url] && (bookmark.originURL!=nil), @"Bookmark has expected values");
	}];
}

- (void)testSetupPreparationThreeRedirectIssues
{
	// https://t.co/JTo2XnbS5G => http://bit.ly/2GTa2wD => https://goo.gl/dh6yW5 => https://demo.owncloud.org/

	[self _runPreparationTestsForURL:[NSURL URLWithString:@"https://t.co/JTo2XnbS5G"] completionHandler:^(NSURL *url, OCBookmark *bookmark, OCIssue *issue, NSArray<OCAuthenticationMethodIdentifier> *supportedMethods, NSArray<OCAuthenticationMethodIdentifier> *preferredAuthenticationMethods) {
		XCTAssert(issue.issues.count==6, @"6 issues");
		XCTAssert(([issue issuesWithLevelGreaterThanOrEqualTo:OCIssueLevelError].count==0), @"0 errors");

		XCTAssert((issue.issues[0].type == OCIssueTypeCertificate), @"Issue is certificate issue");
		XCTAssert((issue.issues[0].level == OCIssueLevelInformal), @"Issue level is informal");

		XCTAssert((issue.issues[1].type == OCIssueTypeURLRedirection), @"Issue is URL redirection issue");
		XCTAssert((issue.issues[1].level == OCIssueLevelWarning), @"Issue level is warning");
		XCTAssert([issue.issues[1].originalURL isEqual:[NSURL URLWithString:@"https://t.co/JTo2XnbS5G"]], @"Redirect originalURL is correct");
		XCTAssert([issue.issues[1].suggestedURL isEqual:[NSURL URLWithString:@"http://bit.ly/2GTa2wD"]], @"Redirect suggestedURL is correct");

		XCTAssert((issue.issues[2].type == OCIssueTypeCertificate), @"Issue is certificate issue");
		XCTAssert((issue.issues[2].level == OCIssueLevelInformal), @"Issue level is informal");

		XCTAssert((issue.issues[3].type == OCIssueTypeURLRedirection), @"Issue is URL redirection issue");
		XCTAssert((issue.issues[3].level == OCIssueLevelWarning), @"Issue level is warning");
		XCTAssert([issue.issues[3].originalURL isEqual:[NSURL URLWithString:@"http://bit.ly/2GTa2wD"]], @"Redirect originalURL is correct");
		XCTAssert([issue.issues[3].suggestedURL isEqual:[NSURL URLWithString:@"https://goo.gl/dh6yW5"]], @"Redirect suggestedURL is correct");

		XCTAssert((issue.issues[4].type == OCIssueTypeCertificate), @"Issue is certificate issue");
		XCTAssert((issue.issues[4].level == OCIssueLevelInformal), @"Issue level is informal");

		XCTAssert((issue.issues[5].type == OCIssueTypeURLRedirection), @"Issue is URL redirection issue");
		XCTAssert((issue.issues[5].level == OCIssueLevelWarning), @"Issue level is warning");
		XCTAssert([issue.issues[5].originalURL isEqual:[NSURL URLWithString:@"https://goo.gl/dh6yW5"]], @"Redirect originalURL is correct");
		XCTAssert([issue.issues[5].suggestedURL isEqual:[NSURL URLWithString:@"https://demo.owncloud.org/"]], @"Redirect suggestedURL is correct");

		XCTAssert (([bookmark.url isEqual:url]) && (bookmark.originURL==nil), @"Bookmark has expected values");

		[issue approve];

		XCTAssert (([bookmark.url isEqual:[NSURL URLWithString:@"https://demo.owncloud.org/"]]) && [bookmark.originURL isEqual:url] && (bookmark.originURL!=nil), @"Bookmark has expected values");
	}];
}

- (void)testSetupPreparationCertificateAndFailedDetectionIssue
{
	// demo.owncloud.org is hosted on betty.owncloud.com

	[self _runPreparationTestsForURL:[NSURL URLWithString:@"https://betty.owncloud.com/"] completionHandler:^(NSURL *url, OCBookmark *bookmark, OCIssue *issue, NSArray<OCAuthenticationMethodIdentifier> *supportedMethods, NSArray<OCAuthenticationMethodIdentifier> *preferredAuthenticationMethods) {
		XCTAssert(issue.issues.count==2, @"2 issues");
		XCTAssert(([issue issuesWithLevelGreaterThanOrEqualTo:OCIssueLevelError].count==1), @"1 error");

		XCTAssert((issue.issues[0].type == OCIssueTypeCertificate), @"Issue is certificate issue");
		XCTAssert((issue.issues[1].type == OCIssueTypeError), @"Detection failed");
	}];
}

- (void)_testConnectWithUserEnteredURLString:(NSString *)userEnteredURLString useAuthMethod:(OCAuthenticationMethodIdentifier)useAuthMethod preConnectAction:(void(^)(OCConnection *connection))preConnectAction connectAction:(void(^)(NSError *error, OCIssue *issue, OCConnection *connection))connectionAction
{
	// NSString *userEnteredURLString = @"https://admin:admin@demo.owncloud.org"; // URL string retrieved from a text field, as entered by the user.
	// UIViewController *topViewController; // View controller to use as parent for presenting view controllers needed for authentication
	OCBookmark *bookmark = nil; // Bookmark from previous recipe
	NSString *userName=OCTestTarget.userLogin, *password=OCTestTarget.userPassword; // Either provided as part of userEnteredURLString - or set independently
	__block OCConnection *connection;
	
	// Create bookmark from normalized URL (and extract username and password if included)
	bookmark = [OCBookmark bookmarkForURL:[NSURL URLWithUsername:&userName password:&password afterNormalizingURLString:userEnteredURLString protocolWasPrepended:NULL]];
	
	if ((connection = [[OCConnection alloc] initWithBookmark:bookmark]) != nil)
	{
		// Prepare for setup
		[connection prepareForSetupWithOptions:nil completionHandler:^(OCIssue *issue, NSURL *suggestedURL, NSArray <OCAuthenticationMethodIdentifier> *supportedMethods, NSArray <OCAuthenticationMethodIdentifier> *preferredAuthenticationMethods)
		 {
			 // Check for warnings and errors
			 NSArray <OCIssue *> *errorIssues = [issue issuesWithLevelGreaterThanOrEqualTo:OCIssueLevelError];
			 NSArray <OCIssue *> *warningAndErrorIssues = [issue issuesWithLevelGreaterThanOrEqualTo:OCIssueLevelWarning];
			 BOOL proceedWithAuthentication = YES;
			 
			 if (errorIssues.count > 0)
			 {
				 // Tell user it can't be done and present the issues in warningAndErrorIssues to the user
			 }
			 else
			 {
				 if (warningAndErrorIssues.count > 0)
				 {
					 // Present issues contained in warningAndErrorIssues to user, then call -approve or -reject on the group issue containing all
					 if (YES)
					 {
						 // Apply changes to bookmark
						 [issue approve];
						 proceedWithAuthentication = YES;
					 }
					 else
					 {
						 // Handle rejection as needed
						 // [issue reject];
					 }
				 }
				 else
				 {
					 // No or only informal issues. Apply changes to bookmark contained in the issues.
					 [issue approve];
					 proceedWithAuthentication = YES;
				 }
			 }
			 
			 // Proceed with authentication
			 if (proceedWithAuthentication)
			 {
				 // Generate authentication data for bookmark
				 [connection generateAuthenticationDataWithMethod:((useAuthMethod!=nil) ? useAuthMethod : [preferredAuthenticationMethods firstObject]) // Use most-preferred, allowed authentication method
									  options:@{
										    // OCAuthenticationMethodPresentingViewControllerKey : topViewController,
										    OCAuthenticationMethodUsernameKey : userName,
										    OCAuthenticationMethodPassphraseKey : password
										    }
								completionHandler:^(NSError *error, OCAuthenticationMethodIdentifier authenticationMethodIdentifier, NSData *authenticationData) {
									if (error == nil)
									{
										// Success! Save authentication data to bookmark.
										bookmark.authenticationData = authenticationData;
										bookmark.authenticationMethodIdentifier = authenticationMethodIdentifier;
										
										// -- At this point, we have a bookmark that can be used to log into an ownCloud server --

										OCLog(@"Done getting bookmark..");

										dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{

											self->newConnection = [[OCConnection alloc] initWithBookmark:bookmark];

											if (preConnectAction != nil)
											{
												preConnectAction(self->newConnection);
											}

											// newConnection.bookmark.url = [NSURL URLWithString:@"https://owncloud-io.lan/"];

											[self->newConnection connectWithCompletionHandler:^(NSError *error, OCIssue *issue) {

												OCLog(@"Done connecting: %@ %@", error, issue);

												connectionAction(error, issue, self->newConnection);
											}];
										});
									}
									else
									{
										// Failure
										OCLog(@"Could not get token (error: %@)", error);
									}
									
								}
				  ];
			 }
		 }];
	}
}

- (void)testConnect
{
	XCTestExpectation *expectConnect = [self expectationWithDescription:@"Connected"];

	[self _testConnectWithUserEnteredURLString:@"https://admin:admin@demo.owncloud.org" useAuthMethod:nil preConnectAction:nil connectAction:^(NSError *error, OCIssue *issue, OCConnection *connection) {
		// Testing just the connect here

		XCTAssert((error==nil), @"No error");
		XCTAssert((issue==nil), @"No issue");
		XCTAssert((connection!=nil), @"Connection!");

		[expectConnect fulfill];
	}];

	[self waitForExpectationsWithTimeout:60 handler:nil];
}

- (NSDictionary<OCClassSettingsKey, id> *)settingsForIdentifier:(OCClassSettingsIdentifier)identifier
{
	if ([identifier isEqual:[OCConnection classSettingsIdentifier]])
	{
		return (@{
			OCConnectionMinimumVersionRequired : @"100.0.0.0"
		});
	}

	return (nil);
}

- (void)testConnectMinimumServerVersion
{
	XCTestExpectation *expectConnect = [self expectationWithDescription:@"Connect called back"];
	XCTestExpectation *expectPrepare = [self expectationWithDescription:@"Prepare called back"];

	// General version compare tests
	XCTAssert([@"10.0"  compareVersionWith:@"10.0"]==NSOrderedSame, @"Same digit count 1");
	XCTAssert([@"10.0"  compareVersionWith:@"9.0"]==NSOrderedDescending, @"Same digit count 2");
	XCTAssert([@"9.0"   compareVersionWith:@"10.0"]==NSOrderedAscending, @"Same digit count 3");
	XCTAssert([@"9.0.0" compareVersionWith:@"9.0"]==NSOrderedSame, @"Overlength equality 1");
	XCTAssert([@"9.0"   compareVersionWith:@"9.0.0"]==NSOrderedSame, @"Overlength equality 2");
	XCTAssert([@"9.0.1" compareVersionWith:@"9.0"]==NSOrderedDescending, @"Overlength inequality 1");
	XCTAssert([@"9.0.0" compareVersionWith:@"9.0.0.1"]==NSOrderedAscending, @"Overlength inequality 2");

	// Connection version compare tests
	[[OCClassSettings sharedSettings] addSource:self];

	// Test detection during preparation
	{
		OCConnection *connection;
		OCBookmark *bookmark = [OCBookmark bookmarkForURL:[NSURL URLWithString:@"https://demo.owncloud.org"]];

		if ((connection = [[OCConnection alloc] initWithBookmark:bookmark]) != nil)
		{
			[connection prepareForSetupWithOptions:nil completionHandler:^(OCIssue *issue, NSURL *suggestedURL, NSArray <OCAuthenticationMethodIdentifier> *supportedMethods, NSArray <OCAuthenticationMethodIdentifier> *preferredAuthenticationMethods)
		 	{
				OCLog(@"Issue: %@", issue);

		 		XCTAssert((issue.type == OCIssueTypeGroup));
		 		XCTAssert((issue.issues.count == 2));
		 		XCTAssert(([issue issuesWithLevelGreaterThanOrEqualTo:OCIssueLevelError].count == 1));
		 		XCTAssert(([[issue issuesWithLevelGreaterThanOrEqualTo:OCIssueLevelError].firstObject.error isOCErrorWithCode:OCErrorServerVersionNotSupported]));

		 		[expectPrepare fulfill];
		 	}];
		}
	}

	// Test detection with existing bookmarks
	{
		OCConnection *connection;
		OCBookmark *bookmark = [OCBookmark bookmarkForURL:[NSURL URLWithString:@"https://demo.owncloud.org"]];

		bookmark.authenticationMethodIdentifier = OCAuthenticationMethodIdentifierBasicAuth;
		bookmark.authenticationData = [OCAuthenticationMethodBasicAuth authenticationDataForUsername:@"admin" passphrase:@"admin" authenticationHeaderValue:NULL error:NULL];

		if ((connection = [[OCConnection alloc] initWithBookmark:bookmark]) != nil)
		{
			[connection connectWithCompletionHandler:^(NSError *error, OCIssue *issue) {
				// Testing just the connect here

				XCTAssert((error!=nil), @"Error: %@", error);
				XCTAssert((issue!=nil), @"Issue: %@", issue);
				XCTAssert((connection!=nil), @"Connection");

				OCLog(@"Error: %@ Issue: %@", error, issue);

				[expectConnect fulfill];
			}];
		}
	}

	[self waitForExpectationsWithTimeout:60 handler:nil];

	[[OCClassSettings sharedSettings] removeSource:self];
}


- (void)testConnectWithFakedCert
{
	XCTestExpectation *expectConnect = [self expectationWithDescription:@"Connected"];

	[self _testConnectWithUserEnteredURLString:@"https://admin:admin@demo.owncloud.org" useAuthMethod:nil preConnectAction:^(OCConnection *connection) {
		// Load and inject fake certificate for demo.owncloud.org
		NSURL *fakeCertURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"fake-demo_owncloud_org" withExtension:@"cer"];
		NSData *fakeCertData = [NSData dataWithContentsOfURL:fakeCertURL];

		connection.bookmark.certificate = [OCCertificate certificateWithCertificateData:fakeCertData hostName:@"demo.owncloud.org"];

	} connectAction:^(NSError *error, OCIssue *issue, OCConnection *connection) {
		// Testing just the connect here

		XCTAssert((error!=nil), @"Error");
		XCTAssert((issue!=nil), @"Issue");

		[expectConnect fulfill];
	}];

	[self waitForExpectationsWithTimeout:60 handler:nil];
}


- (void)testConnectAndGetRootList
{
	XCTestExpectation *expectConnect = [self expectationWithDescription:@"Connected"];
	XCTestExpectation *expectRootList = [self expectationWithDescription:@"Received root list"];

	[self _testConnectWithUserEnteredURLString:@"https://admin:admin@demo.owncloud.org" useAuthMethod:nil preConnectAction:nil connectAction:^(NSError *error, OCIssue *issue, OCConnection *connection) {
		OCLog(@"User: %@", connection.loggedInUser.userName);

		XCTAssert((error==nil), @"No error");
		XCTAssert((issue==nil), @"No issue");
		XCTAssert((connection!=nil), @"Connection!");

		if (error == nil)
		{
			// connection.bookmark.url = [NSURL URLWithString:@"https://owncloud-io.lan/"];

			[connection retrieveItemListAtPath:@"/" depth:1 completionHandler:^(NSError *error, NSArray<OCItem *> *items) {
				OCLog(@"Items at root: %@", items);

				XCTAssert((error==nil), @"No error");
				XCTAssert((items.count>0), @"Items were found at root");

				[expectRootList fulfill];
			}];
		}
		else
		{
			[expectRootList fulfill];
		}

		[expectConnect fulfill];
	}];

	[self waitForExpectationsWithTimeout:60 handler:nil];
}

- (void)handleEvent:(OCEvent *)event sender:(id)sender
{
	void (^block)(OCEvent *e, id sender) = event.ephermalUserInfo[@"completionHandler"];

	block(event, sender);
}

- (void)testConnectAndGetThumbnails
{
	XCTestExpectation *expectConnect = [self expectationWithDescription:@"Connected"];
	XCTestExpectation *expectFileList = [self expectationWithDescription:@"Received file list"];
	__block XCTestExpectation *expectErrorForCollection = [self expectationWithDescription:@"Received error for collection"];
	__block NSUInteger receivedThumbnails = 0;
	XCTestExpectation *expectThumbnailsForAllFiles = [self expectationWithDescription:@"Received thumbnails for all files"];
	__block NSUInteger thumbnailByteCount = 0;

	[OCEvent registerEventHandler:self forIdentifier:@"test"];

	[self _testConnectWithUserEnteredURLString:@"http://admin:admin@demo.owncloud.org" useAuthMethod:OCAuthenticationMethodIdentifierBasicAuth preConnectAction:nil connectAction:^(NSError *error, OCIssue *issue, OCConnection *connection) {
		OCLog(@"User: %@ Preview API: %d", connection.loggedInUser.userName, connection.supportsPreviewAPI);

		XCTAssert((error==nil), @"No error: %@", error);
		XCTAssert((issue==nil), @"No issue: %@", issue);
		XCTAssert((connection!=nil), @"Connection!");

		if (error == nil)
		{
			// connection.bookmark.url = [NSURL URLWithString:@"https://owncloud-io.lan/"];

			[connection retrieveItemListAtPath:@"/Photos" depth:1 completionHandler:^(NSError *error, NSArray<OCItem *> *items) {
				OCLog(@"Items at /Photos: %@", items);

				for (OCItem *item in items)
				{
					CGSize maxSize = CGSizeMake(384, 384);

					[connection retrieveThumbnailFor:item
						    to:nil
						    maximumSize:maxSize
						    resultTarget:[OCEventTarget eventTargetWithEventHandlerIdentifier:@"test"
						    				userInfo:nil
						    				ephermalUserInfo:@{
						    					@"completionHandler" : ^(OCEvent *event, id sender){
						    						OCLog(@"Event: %@ Error: %@ Thumbnail Size: %@ Bytes: %lu Sender: %@", event, event.error, NSStringFromCGSize(((OCItemThumbnail *)event.result).image.size), ((OCItemThumbnail *)event.result).data.length, sender);

						    						thumbnailByteCount += ((OCItemThumbnail *)event.result).data.length;

						    						if (item.type == OCItemTypeCollection)
						    						{
						    							if (event.error != nil)
						    							{
														[expectErrorForCollection fulfill];
														expectErrorForCollection = nil;
													}
												}

												if (item.type == OCItemTypeFile)
												{
													OCItemThumbnail *thumbnail = (OCItemThumbnail *)event.result;

													if ((thumbnail!=nil) && ((thumbnail.image.size.width==maxSize.width) || (thumbnail.image.size.height==maxSize.height)))
													{
														receivedThumbnails++;

														if (receivedThumbnails == (items.count-1)) // -1 for the root directory
														{
															[expectThumbnailsForAllFiles fulfill];
														}
													}
												}
											}
									        }
								 ]
					];
				}

				XCTAssert((error==nil), @"No error");
				XCTAssert((items.count>0), @"Items were found at root");

				[expectFileList fulfill];
			}];
		}
		else
		{
			[expectFileList fulfill];
		}

		[expectConnect fulfill];
	}];

	[self waitForExpectationsWithTimeout:60 handler:nil];

	OCLog(@"Average thumbnail byte size: %lu", (thumbnailByteCount/((receivedThumbnails!=0)?receivedThumbnails:1)));
}

- (void)testConnectAndDownloadFile
{
	XCTestExpectation *expectConnect = [self expectationWithDescription:@"Connected"];
	XCTestExpectation *expectFileList = [self expectationWithDescription:@"Received file list"];
	XCTestExpectation *expectFileDownload = [self expectationWithDescription:@"File downloaded"];
	XCTestExpectation *expectChecksumVerifies = [self expectationWithDescription:@"File checksum verified"];
	OCConnection *connection = nil;
	OCBookmark *bookmark = [OCBookmark bookmarkForURL:OCTestTarget.secureTargetURL];
	__block OCProgress *downloadProgress = nil;

	bookmark.authenticationMethodIdentifier = OCAuthenticationMethodIdentifierBasicAuth;
	bookmark.authenticationData = [OCAuthenticationMethodBasicAuth authenticationDataForUsername:OCTestTarget.userLogin passphrase:OCTestTarget.userPassword authenticationHeaderValue:NULL error:NULL];

	connection = [[OCConnection alloc] initWithBookmark:bookmark];

	XCTAssert(connection!=nil);

	[connection connectWithCompletionHandler:^(NSError *error, OCIssue *issue) {
		XCTAssert(error==nil);
		XCTAssert(issue==nil);

		if (error == nil)
		{
			[connection retrieveItemListAtPath:@"/Photos" depth:1 completionHandler:^(NSError *error, NSArray<OCItem *> *items) {
				OCLog(@"Items at /Photos: %@", items);
				OCItem *downloadItem = nil;

				for (OCItem *item in items)
				{
					if (item.type == OCItemTypeFile)
					{
						downloadItem = item;
						break;
					}
				}

				if (downloadItem != nil)
				{
					downloadProgress = [connection downloadItem:downloadItem to:nil options:nil resultTarget:[OCEventTarget eventTargetWithEphermalEventHandlerBlock:^(OCEvent *event, id sender) {
						if (event.file != nil)
						{
							[expectFileDownload fulfill];

							OCLog(@"File downloaded: %@ (%@)", event.file.url, event.file.checksum.headerString);

							[event.file.checksum verifyForFile:event.file.url completionHandler:^(NSError *error, BOOL isValid, OCChecksum *actualChecksum) {
								OCLog(@"File checksum verified: error=%@, isValid=%d, actualChecksum=%@", error, isValid, actualChecksum);

								XCTAssert(error==nil);
								XCTAssert(isValid==YES);
								XCTAssert([actualChecksum isEqual:event.file.checksum]);

								[expectChecksumVerifies fulfill];
							}];
						}
					} userInfo:nil ephermalUserInfo:nil]];

					[downloadProgress addObserver:self forKeyPath:@"progress.fractionCompleted" options:NSKeyValueObservingOptionInitial context:nil];
				}

				XCTAssert((error==nil), @"No error");
				XCTAssert((items.count>0), @"Items were found at root");

				[expectFileList fulfill];
			}];
		}
		else
		{
			[expectFileList fulfill];
		}

		[expectConnect fulfill];
	}];

	[self waitForExpectationsWithTimeout:120 handler:nil];

	[downloadProgress removeObserver:self forKeyPath:@"progress.fractionCompleted" context:nil];

	OCLog(@"Done: %@", connection);
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
	if ([keyPath isEqualToString:@"progress.fractionCompleted"])
	{
		OCLog(@"Fraction of %@: %f", object, ((OCProgress *)object).progress.fractionCompleted);
	}
}

- (void)testConnectAndBackgroundItemListRetrieval
{
	XCTestExpectation *expectConnect = [self expectationWithDescription:@"Connected"];
	XCTestExpectation *expectFileList = [self expectationWithDescription:@"Received file list"];
	OCConnection *connection = nil;
	OCBookmark *bookmark = [OCBookmark bookmarkForURL:OCTestTarget.secureTargetURL];

	bookmark.authenticationMethodIdentifier = OCAuthenticationMethodIdentifierBasicAuth;
	bookmark.authenticationData = [OCAuthenticationMethodBasicAuth authenticationDataForUsername:OCTestTarget.userLogin passphrase:OCTestTarget.userPassword authenticationHeaderValue:NULL error:NULL];

	connection = [[OCConnection alloc] initWithBookmark:bookmark];

	XCTAssert(connection!=nil);

	[connection connectWithCompletionHandler:^(NSError *error, OCIssue *issue) {
		XCTAssert(error==nil);
		XCTAssert(issue==nil);

		[expectConnect fulfill];

		if (error == nil)
		{
			[connection retrieveItemListAtPath:@"/Photos" depth:1 options:nil resultTarget:[OCEventTarget eventTargetWithEphermalEventHandlerBlock:^(OCEvent *event, id sender) {
				OCLog(@"Items at /Photos: %@, Error: %@, Path: %@, Depth: %ld", event.result, event.error, event.path, event.depth);

				XCTAssert(event.result!=nil);
				XCTAssert([event.result isKindOfClass:[NSArray class]]);
				XCTAssert(((NSArray *)event.result).count > 0);
				XCTAssert(event.error==nil);
				XCTAssert([event.path isEqual:@"/Photos"]);
				XCTAssert(event.depth==1);

				[expectFileList fulfill];
			} userInfo:nil ephermalUserInfo:nil]];
		}
		else
		{
			[expectFileList fulfill];
		}
	}];

	[self waitForExpectationsWithTimeout:60 handler:nil];
}

- (void)testConnectAndUploadFile
{
	XCTestExpectation *expectConnect = [self expectationWithDescription:@"Connected"];
	XCTestExpectation *expectFileList = [self expectationWithDescription:@"Received file list"];
	XCTestExpectation *expectFileUpload = [self expectationWithDescription:@"File uploaded"];
	XCTestExpectation *expectFileDeleted = [self expectationWithDescription:@"File deleted"];
	OCConnection *connection = nil;
	OCBookmark *bookmark = [OCBookmark bookmarkForURL:OCTestTarget.secureTargetURL];
	__block OCProgress *uploadProgress = nil;

	bookmark.authenticationMethodIdentifier = OCAuthenticationMethodIdentifierBasicAuth;
	bookmark.authenticationData = [OCAuthenticationMethodBasicAuth authenticationDataForUsername:OCTestTarget.userLogin passphrase:OCTestTarget.userPassword authenticationHeaderValue:NULL error:NULL];

	connection = [[OCConnection alloc] initWithBookmark:bookmark];

	XCTAssert(connection!=nil);

	[connection connectWithCompletionHandler:^(NSError *error, OCIssue *issue) {
		XCTAssert(error==nil);
		XCTAssert(issue==nil);

		if (error == nil)
		{
			[connection retrieveItemListAtPath:@"/" depth:1 completionHandler:^(NSError *error, NSArray<OCItem *> *items) {
				OCLog(@"Items at /: %@", items);
				OCItem *rootItem = nil;

				for (OCItem *item in items)
				{
					if ([item.path isEqual:@"/"])
					{
						rootItem = item;
						break;
					}
				}

				if (rootItem != nil)
				{
					NSURL *uploadFileURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"rainbow" withExtension:@"png"];
					NSString *uploadName = [NSString stringWithFormat:@"rainbow-%f.png", NSDate.timeIntervalSinceReferenceDate];

					uploadProgress = [connection uploadFileFromURL:uploadFileURL withName:uploadName to:rootItem replacingItem:nil options:nil resultTarget:[OCEventTarget eventTargetWithEphermalEventHandlerBlock:^(OCEvent *event, id sender) {
						OCLog(@"File uploaded: %@ error = %@", event.result, event.error);

						XCTAssert(event.result!=nil);
						XCTAssert(event.error==nil);

						[expectFileUpload fulfill];

						[connection deleteItem:OCTypedCast(event.result, OCItem) requireMatch:YES resultTarget:[OCEventTarget eventTargetWithEphermalEventHandlerBlock:^(OCEvent *event, id sender) {
							OCLog(@"File deleted with error = %@", event.error);

							XCTAssert(event.error==nil);

							[expectFileDeleted fulfill];
						} userInfo:nil ephermalUserInfo:nil]];
					} userInfo:nil ephermalUserInfo:nil]];

					[uploadProgress addObserver:self forKeyPath:@"progress.fractionCompleted" options:NSKeyValueObservingOptionInitial context:nil];
				}

				XCTAssert((error==nil), @"No error");
				XCTAssert((items.count>0), @"Items were found at root");

				[expectFileList fulfill];
			}];
		}

		[expectConnect fulfill];
	}];

	[self waitForExpectationsWithTimeout:60 handler:nil];

	[uploadProgress removeObserver:self forKeyPath:@"progress.fractionCompleted" context:nil];
}

- (void)testConnectAndFavoriteFirstFile
{
	XCTestExpectation *expectConnect = [self expectationWithDescription:@"Connected"];
	XCTestExpectation *expectFavorite = [self expectationWithDescription:@"Received favorite response"];
	XCTestExpectation *expectRootList = [self expectationWithDescription:@"Received root list"];

	[self _testConnectWithUserEnteredURLString:@"https://admin:admin@demo.owncloud.org" useAuthMethod:nil preConnectAction:nil connectAction:^(NSError *error, OCIssue *issue, OCConnection *connection) {
		OCLog(@"User: %@", connection.loggedInUser.userName);

		XCTAssert((error==nil), @"No error");
		XCTAssert((issue==nil), @"No issue");
		XCTAssert((connection!=nil), @"Connection!");

		if (error == nil)
		{
			// connection.bookmark.url = [NSURL URLWithString:@"https://owncloud-io.lan/"];

			[connection retrieveItemListAtPath:@"/" depth:1 completionHandler:^(NSError *error, NSArray<OCItem *> *items) {
				OCLog(@"Items at root: %@", items);

				XCTAssert((error==nil), @"No error");
				XCTAssert((items.count>0), @"Items were found at root");

				[expectRootList fulfill];

				for (OCItem *item in items)
				{
					if (item.type == OCItemTypeFile)
					{
						NSArray<OCItemPropertyName> *propertiesToUpdate = @[ OCItemPropertyNameIsFavorite, OCItemPropertyNameLastModified ];

						item.isFavorite = @(!item.isFavorite.boolValue);
						item.lastModified = [NSDate dateWithTimeIntervalSinceNow:-(24*60*60*7)];

						[connection updateItem:item properties:propertiesToUpdate options:nil resultTarget:[OCEventTarget eventTargetWithEphermalEventHandlerBlock:^(OCEvent *event, id sender) {
							NSDictionary <OCItemPropertyName, OCHTTPStatus *> *statusByPropertyName = OCTypedCast(event.result, NSDictionary);

							OCLog(@"Update item result event: %@, result: %@", event, statusByPropertyName);

							for (OCItemPropertyName propertyName in propertiesToUpdate)
							{
								XCTAssert(statusByPropertyName[propertyName].isSuccess);
							}

							[expectFavorite fulfill];
						} userInfo:nil ephermalUserInfo:nil]];

						break;
					}
				}
			}];
		}
		else
		{
			[expectRootList fulfill];
		}

		[expectConnect fulfill];
	}];

	[self waitForExpectationsWithTimeout:60 handler:nil];
}

- (void)testStatusRequest
{
	OCBookmark *bookmark = [OCTestTarget userBookmark];
	OCConnection *connection;
	XCTestExpectation *expectServerStatusResponse = [self expectationWithDescription:@"Received server status response"];

	connection = [[OCConnection alloc] initWithBookmark:bookmark];
	XCTAssert(connection!=nil);

	XCTAssert(connection.serverVersion == nil);
	XCTAssert(connection.serverVersionString == nil);
	XCTAssert(connection.serverEdition == nil);
	XCTAssert(connection.serverProductName == nil);
	XCTAssert(connection.serverLongProductVersionString == nil);

	[connection requestServerStatusWithCompletionHandler:^(NSError *error, OCHTTPRequest *request, NSDictionary<NSString *,id> *statusInfo) {
		XCTAssert(statusInfo!=nil);
		XCTAssert(statusInfo[@"edition"]!=nil);
		XCTAssert(statusInfo[@"installed"]!=nil);
		XCTAssert(statusInfo[@"maintenance"]!=nil);
		XCTAssert(statusInfo[@"needsDbUpgrade"]!=nil);
		XCTAssert(statusInfo[@"productname"]!=nil);
		XCTAssert(statusInfo[@"version"]!=nil);
		XCTAssert(statusInfo[@"versionstring"]!=nil);

		XCTAssert(connection.serverVersion != nil);
		XCTAssert(connection.serverVersionString != nil);
		XCTAssert(connection.serverEdition != nil);
		XCTAssert(connection.serverProductName != nil);
		XCTAssert(connection.serverLongProductVersionString != nil);

		[expectServerStatusResponse fulfill];
	}];

	[self waitForExpectationsWithTimeout:120 handler:nil];
}

- (void)testCapabilitiesDecoding
{
	NSURL *capabilitiesURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"capabilities" withExtension:@"json"];
	NSDictionary<NSString *, id> *jsonDict = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfURL:capabilitiesURL] options:0 error:NULL];
	OCCapabilities *capabilities = [[OCCapabilities alloc] initWithRawJSON:jsonDict];

	XCTAssert(capabilities.majorVersion.integerValue == 10);
	XCTAssert(capabilities.minorVersion.integerValue == 1);
	XCTAssert(capabilities.microVersion != nil);

	XCTAssert(capabilities.pollInterval.integerValue == 60);
	XCTAssert([capabilities.webDAVRoot isEqual:@"remote.php/webdav"]);

	XCTAssert((capabilities.installed!=nil) && capabilities.installed.boolValue);
	XCTAssert((capabilities.maintenance!=nil) && !capabilities.maintenance.boolValue);
	XCTAssert((capabilities.needsDBUpgrade!=nil) && !capabilities.needsDBUpgrade.boolValue);
	XCTAssert([capabilities.version isEqual:@"10.1.0.4"]);
	XCTAssert([capabilities.versionString isEqual:@"10.1.0"]);
	XCTAssert([capabilities.edition isEqual:@"Community"]);
	XCTAssert([capabilities.productName isEqual:@"ownCloud"]);
	XCTAssert([capabilities.hostName isEqual:@"owncloud"]);

	XCTAssert([capabilities.supportedChecksumTypes isEqualToArray:@[ OCChecksumAlgorithmIdentifierSHA1 ]]);
	XCTAssert([capabilities.preferredUploadChecksumType isEqual:OCChecksumAlgorithmIdentifierSHA1]);

	XCTAssert([capabilities.davChunkingVersion isEqual:@"1.0"]);
	XCTAssert([capabilities.davReports isEqualToArray:@[ @"search-files" ]]);

	XCTAssert((capabilities.supportsPrivateLinks!=nil) && capabilities.supportsPrivateLinks.boolValue);
	XCTAssert((capabilities.supportsBigFileChunking!=nil) && capabilities.supportsBigFileChunking.boolValue);
	XCTAssert([capabilities.blacklistedFiles isEqualToArray:@[ @".htaccess" ]]);
	XCTAssert((capabilities.supportsUndelete!=nil) && capabilities.supportsUndelete.boolValue);
	XCTAssert((capabilities.supportsVersioning!=nil) && capabilities.supportsVersioning.boolValue);

	XCTAssert((capabilities.sharingAPIEnabled!=nil) && capabilities.sharingAPIEnabled.boolValue);
	XCTAssert((capabilities.sharingResharing!=nil) && capabilities.sharingResharing.boolValue);
	XCTAssert((capabilities.sharingGroupSharing!=nil) && capabilities.sharingGroupSharing.boolValue);
	XCTAssert((capabilities.sharingAutoAcceptShare!=nil) && capabilities.sharingAutoAcceptShare.boolValue);
	XCTAssert((capabilities.sharingWithGroupMembersOnly!=nil) && capabilities.sharingWithGroupMembersOnly.boolValue);
	XCTAssert((capabilities.sharingWithMembershipGroupsOnly!=nil) && capabilities.sharingWithMembershipGroupsOnly.boolValue);
	XCTAssert((capabilities.sharingAllowed!=nil) && capabilities.sharingAllowed.boolValue);
	XCTAssert(capabilities.sharingDefaultPermissions == 31);
	XCTAssert((capabilities.sharingSearchMinLength!=nil) && (capabilities.sharingSearchMinLength.integerValue==2));

	XCTAssert((capabilities.publicSharingEnabled!=nil) && capabilities.publicSharingEnabled.boolValue);
	XCTAssert((capabilities.publicSharingPasswordEnforced!=nil) && !capabilities.publicSharingPasswordEnforced.boolValue);
	XCTAssert((capabilities.publicSharingPasswordEnforcedForReadOnly!=nil) && !capabilities.publicSharingPasswordEnforcedForReadOnly.boolValue);
	XCTAssert((capabilities.publicSharingPasswordEnforcedForReadWrite!=nil) && !capabilities.publicSharingPasswordEnforcedForReadWrite.boolValue);
	XCTAssert((capabilities.publicSharingPasswordEnforcedForUploadOnly!=nil) && !capabilities.publicSharingPasswordEnforcedForUploadOnly.boolValue);
	XCTAssert((capabilities.publicSharingExpireDateEnabled!=nil) && !capabilities.publicSharingExpireDateEnabled.boolValue);
	XCTAssert((capabilities.publicSharingSendMail!=nil) && !capabilities.publicSharingSendMail.boolValue);
	XCTAssert((capabilities.publicSharingSocialShare!=nil) && capabilities.publicSharingSocialShare.boolValue);
	XCTAssert((capabilities.publicSharingUpload!=nil) && capabilities.publicSharingUpload.boolValue);
	XCTAssert((capabilities.publicSharingMultiple!=nil) && capabilities.publicSharingMultiple.boolValue);
	XCTAssert((capabilities.publicSharingSupportsUploadOnly!=nil) && capabilities.publicSharingSupportsUploadOnly.boolValue);
	XCTAssert((capabilities.publicSharingDefaultLinkName!=nil) && [capabilities.publicSharingDefaultLinkName isEqual:@"Public link"]);

	XCTAssert((capabilities.userSharingSendMail!=nil) && !capabilities.userSharingSendMail.boolValue);

	XCTAssert((capabilities.userEnumerationEnabled!=nil) && capabilities.userEnumerationEnabled.boolValue);
	XCTAssert((capabilities.userEnumerationGroupMembersOnly!=nil) && !capabilities.userEnumerationGroupMembersOnly.boolValue);

	XCTAssert((capabilities.federatedSharingIncoming!=nil) && capabilities.federatedSharingIncoming.boolValue);
	XCTAssert((capabilities.federatedSharingOutgoing!=nil) && capabilities.federatedSharingOutgoing.boolValue);

	NSArray *endpoints = @[ @"list", @"get", @"delete" ];
	XCTAssert([capabilities.notificationEndpoints isEqualToArray:endpoints]);
}

- (void)_testPropFindZeroStresstest
{
	XCTestExpectation *expectConnect = [self expectationWithDescription:@"Connected"];
	__block XCTestExpectation *expectFileList = [self expectationWithDescription:@"Received file list"];
	__block XCTestExpectation *expectFolderCreateList = [self expectationWithDescription:@"Create folder"];
	__block XCTestExpectation *expectFolderDeleteList = [self expectationWithDescription:@"Deleted folder"];
	OCConnection *connection = nil;
	OCBookmark *bookmark = [OCBookmark bookmarkForURL:OCTestTarget.secureTargetURL];
	__block NSUInteger scheduleCount = 100, remaining = scheduleCount, remainingFolder = scheduleCount, deleteCount = scheduleCount;

	bookmark.authenticationMethodIdentifier = OCAuthenticationMethodIdentifierBasicAuth;
	bookmark.authenticationData = [OCAuthenticationMethodBasicAuth authenticationDataForUsername:OCTestTarget.userLogin passphrase:OCTestTarget.userPassword authenticationHeaderValue:NULL error:NULL];

	connection = [[OCConnection alloc] initWithBookmark:bookmark];

	XCTAssert(connection!=nil);

	[connection connectWithCompletionHandler:^(NSError *error, OCIssue *issue) {
		XCTAssert(error==nil);
		XCTAssert(issue==nil);

		[expectConnect fulfill];

		if (error == nil)
		{
			[connection retrieveItemListAtPath:@"/" depth:0 options:nil resultTarget:[OCEventTarget eventTargetWithEphermalEventHandlerBlock:^(OCEvent *event, id sender) {
				OCItem *rootFolder = ((NSArray <OCItem *> *)event.result).firstObject;

				for (NSUInteger i=0; i < scheduleCount; i++)
				{
					[connection createFolder:[NSString stringWithFormat:@"test-%lu-%f", (unsigned long)i, NSDate.timeIntervalSinceReferenceDate] inside:rootFolder options:nil resultTarget:[OCEventTarget eventTargetWithEphermalEventHandlerBlock:^(OCEvent *event, id sender) {
						OCLog(@"Create folder: error=%@, result=%@", event.error, event.result);

						@synchronized(self)
						{
							remainingFolder--;
							if (remainingFolder == 0)
							{
								[expectFolderCreateList fulfill];
								expectFolderCreateList = nil;
							}
						}

						[connection deleteItem:(OCItem *)event.result requireMatch:NO resultTarget:[OCEventTarget eventTargetWithEphermalEventHandlerBlock:^(OCEvent *event, id sender) {
							OCLog(@"Delete folder: error=%@, result=%@", event.error, event.result);

							@synchronized(self)
							{
								deleteCount--;
								if (deleteCount == 0)
								{
									[expectFolderDeleteList fulfill];
									expectFolderDeleteList = nil;
								}
							}

							[connection retrieveItemListAtPath:@"/" depth:0 completionHandler:^(NSError *error, NSArray<OCItem *> *items) {
								OCLog(@"Items at /: %@, Error: %@", items, error);

								XCTAssert(items.count > 0);
								XCTAssert(items.firstObject.eTag != nil);
							}];

							[connection retrieveItemListAtPath:@"/" depth:0 options:nil resultTarget:[OCEventTarget eventTargetWithEphermalEventHandlerBlock:^(OCEvent *event, id sender) {
								OCLog(@"Item at /: %@, Error: %@, Path: %@, Depth: %ld", event.result, event.error, event.path, event.depth);

								XCTAssert(event.result!=nil);
								XCTAssert([event.result isKindOfClass:[NSArray class]]);
								XCTAssert(((NSArray *)event.result).count > 0);
								XCTAssert(((NSArray <OCItem *> *)event.result).firstObject.eTag != nil);
								XCTAssert(event.error==nil);
								XCTAssert([event.path isEqual:@"/"]);
								XCTAssert(event.depth==0);
							} userInfo:nil ephermalUserInfo:nil]];
						} userInfo:nil ephermalUserInfo:nil]];
					} userInfo:nil ephermalUserInfo:nil]];

					[connection retrieveItemListAtPath:@"/" depth:0 options:nil resultTarget:[OCEventTarget eventTargetWithEphermalEventHandlerBlock:^(OCEvent *event, id sender) {
						OCLog(@"Item at /: %@, Error: %@, Path: %@, Depth: %ld", event.result, event.error, event.path, event.depth);

						XCTAssert(event.result!=nil);
						XCTAssert([event.result isKindOfClass:[NSArray class]]);
						XCTAssert(((NSArray *)event.result).count > 0);
						XCTAssert(((NSArray <OCItem *> *)event.result).firstObject.eTag != nil);
						XCTAssert(event.error==nil);
						XCTAssert([event.path isEqual:@"/"]);
						XCTAssert(event.depth==0);

						@synchronized(self)
						{
							remaining--;
							if (remaining == 0)
							{
								[expectFileList fulfill];
								expectFileList = nil;
							}
						}
					} userInfo:nil ephermalUserInfo:nil]];

					[connection retrieveItemListAtPath:@"/" depth:1 completionHandler:^(NSError *error, NSArray<OCItem *> *items) {
						OCLog(@"Items at /: %@, Error: %@", items, error);

						XCTAssert(items.count > 0);
						XCTAssert(items.firstObject.eTag != nil);
					}];

					usleep(20000);
				}
			} userInfo:nil ephermalUserInfo:nil]];
		}
		else
		{
			[expectFileList fulfill];
		}
	}];

	[self waitForExpectationsWithTimeout:120 handler:nil];
}


@end

