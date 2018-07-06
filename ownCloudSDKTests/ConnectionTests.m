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
#import <ownCloudSDK/NSString+OCVersionCompare.h>

@interface ConnectionTests : XCTestCase <OCEventHandler, OCClassSettingsSource>
{
	 OCConnection *newConnection;
}

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
	
	connection = [[OCConnection alloc] initWithBookmark:bookmark persistentStoreBaseURL:nil];
	
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
	
	connection = [[OCConnection alloc] initWithBookmark:bookmark persistentStoreBaseURL:nil];
	
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
		XCTAssert(issue.issues.count==1, @"1 issue found");

		XCTAssert((issue.issues[0].type == OCConnectionIssueTypeCertificate), @"Issue is certificate issue");
		XCTAssert((issue.issues[0].level == OCConnectionIssueLevelInformal), @"Issue level is informal");

		[issue approve];
		
		XCTAssert (([bookmark.url isEqual:url]) && (bookmark.originURL==nil), @"Bookmark has expected values");
	}];
}

- (void)testSetupPreparationInvalidURL
{
	// "Typo" in URL

	[self _runPreparationTestsForURL:[NSURL URLWithString:@"https://nosuch.owncloud/"] completionHandler:^(NSURL *url, OCBookmark *bookmark, OCConnectionIssue *issue, NSArray<OCAuthenticationMethodIdentifier> *supportedMethods, NSArray<OCAuthenticationMethodIdentifier> *preferredAuthenticationMethods) {
		XCTAssert(issue.issues.count==1, @"1 issue found");
		XCTAssert(([issue issuesWithLevelGreaterThanOrEqualTo:OCConnectionIssueLevelError].count==1), @"1 error");

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
		XCTAssert(issue.issues.count==2, @"2 issues");
		XCTAssert(([issue issuesWithLevelGreaterThanOrEqualTo:OCConnectionIssueLevelError].count==1), @"1 error");

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
		XCTAssert(issue.issues.count==2, @"2 issues");
		XCTAssert(([issue issuesWithLevelGreaterThanOrEqualTo:OCConnectionIssueLevelError].count==0), @"0 errors");

		XCTAssert((issue.issues[0].type == OCConnectionIssueTypeCertificate), @"Issue is certificate issue");
		XCTAssert((issue.issues[0].level == OCConnectionIssueLevelInformal), @"Issue level is informal");

		XCTAssert((issue.issues[1].type == OCConnectionIssueTypeURLRedirection), @"Issue is URL redirection issue");
		XCTAssert((issue.issues[1].level == OCConnectionIssueLevelInformal), @"Issue level is informal");
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

	[self _runPreparationTestsForURL:[NSURL URLWithString:@"https://goo.gl/dh6yW5"] completionHandler:^(NSURL *url, OCBookmark *bookmark, OCConnectionIssue *issue, NSArray<OCAuthenticationMethodIdentifier> *supportedMethods, NSArray<OCAuthenticationMethodIdentifier> *preferredAuthenticationMethods) {
		XCTAssert(issue.issues.count==3, @"3 issues");
		XCTAssert(([issue issuesWithLevelGreaterThanOrEqualTo:OCConnectionIssueLevelError].count==0), @"0 errors");

		XCTAssert((issue.issues[0].type == OCConnectionIssueTypeCertificate), @"Issue is certificate issue");
		XCTAssert((issue.issues[0].level == OCConnectionIssueLevelInformal), @"Issue level is informal");

		XCTAssert((issue.issues[1].type == OCConnectionIssueTypeCertificate), @"Issue is certificate issue");
		XCTAssert((issue.issues[1].level == OCConnectionIssueLevelInformal), @"Issue level is informal");

		XCTAssert((issue.issues[2].type == OCConnectionIssueTypeURLRedirection), @"Issue is URL redirection issue");
		XCTAssert((issue.issues[2].level == OCConnectionIssueLevelWarning), @"Issue level is warning");
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

	[self _runPreparationTestsForURL:[NSURL URLWithString:@"http://bit.ly/2GTa2wD"] completionHandler:^(NSURL *url, OCBookmark *bookmark, OCConnectionIssue *issue, NSArray<OCAuthenticationMethodIdentifier> *supportedMethods, NSArray<OCAuthenticationMethodIdentifier> *preferredAuthenticationMethods) {
		XCTAssert(issue.issues.count==4, @"4 issues");
		XCTAssert(([issue issuesWithLevelGreaterThanOrEqualTo:OCConnectionIssueLevelError].count==0), @"0 errors");

		XCTAssert((issue.issues[0].type == OCConnectionIssueTypeCertificate), @"Issue is certificate issue");
		XCTAssert((issue.issues[0].level == OCConnectionIssueLevelInformal), @"Issue level is informal");

		XCTAssert((issue.issues[1].type == OCConnectionIssueTypeURLRedirection), @"Issue is URL redirection issue");
		XCTAssert((issue.issues[1].level == OCConnectionIssueLevelWarning), @"Issue level is warning");
		XCTAssert([issue.issues[1].originalURL isEqual:[NSURL URLWithString:@"http://bit.ly/2GTa2wD"]], @"Redirect originalURL is correct");
		XCTAssert([issue.issues[1].suggestedURL isEqual:[NSURL URLWithString:@"https://goo.gl/dh6yW5"]], @"Redirect suggestedURL is correct");

		XCTAssert((issue.issues[2].type == OCConnectionIssueTypeCertificate), @"Issue is certificate issue");
		XCTAssert((issue.issues[2].level == OCConnectionIssueLevelInformal), @"Issue level is informal");

		XCTAssert((issue.issues[3].type == OCConnectionIssueTypeURLRedirection), @"Issue is URL redirection issue");
		XCTAssert((issue.issues[3].level == OCConnectionIssueLevelWarning), @"Issue level is warning");
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

	[self _runPreparationTestsForURL:[NSURL URLWithString:@"https://t.co/JTo2XnbS5G"] completionHandler:^(NSURL *url, OCBookmark *bookmark, OCConnectionIssue *issue, NSArray<OCAuthenticationMethodIdentifier> *supportedMethods, NSArray<OCAuthenticationMethodIdentifier> *preferredAuthenticationMethods) {
		XCTAssert(issue.issues.count==6, @"6 issues");
		XCTAssert(([issue issuesWithLevelGreaterThanOrEqualTo:OCConnectionIssueLevelError].count==0), @"0 errors");

		XCTAssert((issue.issues[0].type == OCConnectionIssueTypeCertificate), @"Issue is certificate issue");
		XCTAssert((issue.issues[0].level == OCConnectionIssueLevelInformal), @"Issue level is informal");

		XCTAssert((issue.issues[1].type == OCConnectionIssueTypeURLRedirection), @"Issue is URL redirection issue");
		XCTAssert((issue.issues[1].level == OCConnectionIssueLevelWarning), @"Issue level is warning");
		XCTAssert([issue.issues[1].originalURL isEqual:[NSURL URLWithString:@"https://t.co/JTo2XnbS5G"]], @"Redirect originalURL is correct");
		XCTAssert([issue.issues[1].suggestedURL isEqual:[NSURL URLWithString:@"http://bit.ly/2GTa2wD"]], @"Redirect suggestedURL is correct");

		XCTAssert((issue.issues[2].type == OCConnectionIssueTypeCertificate), @"Issue is certificate issue");
		XCTAssert((issue.issues[2].level == OCConnectionIssueLevelInformal), @"Issue level is informal");

		XCTAssert((issue.issues[3].type == OCConnectionIssueTypeURLRedirection), @"Issue is URL redirection issue");
		XCTAssert((issue.issues[3].level == OCConnectionIssueLevelWarning), @"Issue level is warning");
		XCTAssert([issue.issues[3].originalURL isEqual:[NSURL URLWithString:@"http://bit.ly/2GTa2wD"]], @"Redirect originalURL is correct");
		XCTAssert([issue.issues[3].suggestedURL isEqual:[NSURL URLWithString:@"https://goo.gl/dh6yW5"]], @"Redirect suggestedURL is correct");

		XCTAssert((issue.issues[4].type == OCConnectionIssueTypeCertificate), @"Issue is certificate issue");
		XCTAssert((issue.issues[4].level == OCConnectionIssueLevelInformal), @"Issue level is informal");

		XCTAssert((issue.issues[5].type == OCConnectionIssueTypeURLRedirection), @"Issue is URL redirection issue");
		XCTAssert((issue.issues[5].level == OCConnectionIssueLevelWarning), @"Issue level is warning");
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

	[self _runPreparationTestsForURL:[NSURL URLWithString:@"https://betty.owncloud.com/"] completionHandler:^(NSURL *url, OCBookmark *bookmark, OCConnectionIssue *issue, NSArray<OCAuthenticationMethodIdentifier> *supportedMethods, NSArray<OCAuthenticationMethodIdentifier> *preferredAuthenticationMethods) {
		XCTAssert(issue.issues.count==2, @"2 issues");
		XCTAssert(([issue issuesWithLevelGreaterThanOrEqualTo:OCConnectionIssueLevelError].count==1), @"1 error");

		XCTAssert((issue.issues[0].type == OCConnectionIssueTypeCertificate), @"Issue is certificate issue");
		XCTAssert((issue.issues[1].type == OCConnectionIssueTypeError), @"Detection failed");
	}];
}

- (void)_testConnectWithUserEnteredURLString:(NSString *)userEnteredURLString useAuthMethod:(OCAuthenticationMethodIdentifier)useAuthMethod preConnectAction:(void(^)(OCConnection *connection))preConnectAction connectAction:(void(^)(NSError *error, OCConnectionIssue *issue, OCConnection *connection))connectionAction
{
	// NSString *userEnteredURLString = @"https://admin:admin@demo.owncloud.org"; // URL string retrieved from a text field, as entered by the user.
	// UIViewController *topViewController; // View controller to use as parent for presenting view controllers needed for authentication
	OCBookmark *bookmark = nil; // Bookmark from previous recipe
	NSString *userName=@"admin", *password=@"admin"; // Either provided as part of userEnteredURLString - or set independently
	__block OCConnection *connection;
	
	// Create bookmark from normalized URL (and extract username and password if included)
	bookmark = [OCBookmark bookmarkForURL:[NSURL URLWithUsername:&userName password:&password afterNormalizingURLString:userEnteredURLString protocolWasPrepended:NULL]];
	
	if ((connection = [[OCConnection alloc] initWithBookmark:bookmark persistentStoreBaseURL:nil]) != nil)
	{
		// Prepare for setup
		[connection prepareForSetupWithOptions:nil completionHandler:^(OCConnectionIssue *issue, NSURL *suggestedURL, NSArray <OCAuthenticationMethodIdentifier> *supportedMethods, NSArray <OCAuthenticationMethodIdentifier> *preferredAuthenticationMethods)
		 {
			 // Check for warnings and errors
			 NSArray <OCConnectionIssue *> *errorIssues = [issue issuesWithLevelGreaterThanOrEqualTo:OCConnectionIssueLevelError];
			 NSArray <OCConnectionIssue *> *warningAndErrorIssues = [issue issuesWithLevelGreaterThanOrEqualTo:OCConnectionIssueLevelWarning];
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

										NSLog(@"Done getting bookmark..");

										dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{

											newConnection = [[OCConnection alloc] initWithBookmark:bookmark persistentStoreBaseURL:nil];

											if (preConnectAction != nil)
											{
												preConnectAction(newConnection);
											}

											// newConnection.bookmark.url = [NSURL URLWithString:@"https://owncloud-io.lan/"];

											[newConnection connectWithCompletionHandler:^(NSError *error, OCConnectionIssue *issue) {

												NSLog(@"Done connecting: %@ %@", error, issue);

												connectionAction(error, issue, newConnection);
											}];
										});
									}
									else
									{
										// Failure
										NSLog(@"Could not get token (error: %@)", error);
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

	[self _testConnectWithUserEnteredURLString:@"https://admin:admin@demo.owncloud.org" useAuthMethod:nil preConnectAction:nil connectAction:^(NSError *error, OCConnectionIssue *issue, OCConnection *connection) {
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
	XCTestExpectation *expectConnect = [self expectationWithDescription:@"Connected"];

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

	[self _testConnectWithUserEnteredURLString:@"https://admin:admin@demo.owncloud.org" useAuthMethod:nil preConnectAction:nil connectAction:^(NSError *error, OCConnectionIssue *issue, OCConnection *connection) {
		// Testing just the connect here

		XCTAssert((error!=nil), @"Error: %@", error);
		XCTAssert((issue!=nil), @"Issue: %@", issue);
		XCTAssert((connection!=nil), @"Connection");

		NSLog(@"Error: %@ Issue: %@", error, issue);

		[expectConnect fulfill];
	}];

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

	} connectAction:^(NSError *error, OCConnectionIssue *issue, OCConnection *connection) {
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

	[self _testConnectWithUserEnteredURLString:@"https://admin:admin@demo.owncloud.org" useAuthMethod:nil preConnectAction:nil connectAction:^(NSError *error, OCConnectionIssue *issue, OCConnection *connection) {
		NSLog(@"User: %@", connection.loggedInUser.userName);

		XCTAssert((error==nil), @"No error");
		XCTAssert((issue==nil), @"No issue");
		XCTAssert((connection!=nil), @"Connection!");

		if (error == nil)
		{
			// connection.bookmark.url = [NSURL URLWithString:@"https://owncloud-io.lan/"];

			[connection retrieveItemListAtPath:@"/" depth:1 completionHandler:^(NSError *error, NSArray<OCItem *> *items) {
				NSLog(@"Items at root: %@", items);

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

	[self _testConnectWithUserEnteredURLString:@"http://admin:admin@demo.owncloud.org" useAuthMethod:OCAuthenticationMethodBasicAuthIdentifier preConnectAction:nil connectAction:^(NSError *error, OCConnectionIssue *issue, OCConnection *connection) {
		NSLog(@"User: %@ Preview API: %d", connection.loggedInUser.userName, connection.supportsPreviewAPI);

		XCTAssert((error==nil), @"No error: %@", error);
		XCTAssert((issue==nil), @"No issue: %@", issue);
		XCTAssert((connection!=nil), @"Connection!");

		if (error == nil)
		{
			// connection.bookmark.url = [NSURL URLWithString:@"https://owncloud-io.lan/"];

			[connection retrieveItemListAtPath:@"/Photos" depth:1 completionHandler:^(NSError *error, NSArray<OCItem *> *items) {
				NSLog(@"Items at /Photos: %@", items);

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
						    						NSLog(@"Event: %@ Error: %@ Thumbnail Size: %@ Bytes: %lu Sender: %@", event, event.error, NSStringFromCGSize(((OCItemThumbnail *)event.result).image.size), ((OCItemThumbnail *)event.result).data.length, sender);

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

	NSLog(@"Average thumbnail byte size: %lu", (thumbnailByteCount/((receivedThumbnails!=0)?receivedThumbnails:1)));
}

- (void)testConnectAndDownloadFile
{
	XCTestExpectation *expectConnect = [self expectationWithDescription:@"Connected"];
	XCTestExpectation *expectFileList = [self expectationWithDescription:@"Received file list"];
	XCTestExpectation *expectFileDownload = [self expectationWithDescription:@"File downloaded"];
	XCTestExpectation *expectChecksumVerifies = [self expectationWithDescription:@"File checksum verified"];
	OCConnection *connection = nil;
	OCBookmark *bookmark = [OCBookmark bookmarkForURL:[NSURL URLWithString:@"https://demo.owncloud.org/"]];

	bookmark.authenticationMethodIdentifier = OCAuthenticationMethodBasicAuthIdentifier;
	bookmark.authenticationData = [OCAuthenticationMethodBasicAuth authenticationDataForUsername:@"admin" passphrase:@"admin" authenticationHeaderValue:NULL error:NULL];

	connection = [[OCConnection alloc] initWithBookmark:bookmark persistentStoreBaseURL:nil];

	XCTAssert(connection!=nil);

	[connection connectWithCompletionHandler:^(NSError *error, OCConnectionIssue *issue) {
		XCTAssert(error==nil);
		XCTAssert(issue==nil);

		if (error == nil)
		{
			[connection retrieveItemListAtPath:@"/Photos" depth:1 completionHandler:^(NSError *error, NSArray<OCItem *> *items) {
				NSLog(@"Items at /Photos: %@", items);
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
					[connection downloadItem:downloadItem to:nil options:nil resultTarget:[OCEventTarget eventTargetWithEphermalEventHandlerBlock:^(OCEvent *event, id sender) {
						if (event.file != nil)
						{
							[expectFileDownload fulfill];

							NSLog(@"File downloaded: %@ (%@)", event.file.url, event.file.checksum.headerString);

							[event.file.checksum verifyForFile:event.file.url completionHandler:^(NSError *error, BOOL isValid, OCChecksum *actualChecksum) {
								NSLog(@"File checksum verified: error=%@, isValid=%d, actualChecksum=%@", error, isValid, actualChecksum);

								XCTAssert(error==nil);
								XCTAssert(isValid==YES);
								XCTAssert([actualChecksum isEqual:event.file.checksum]);

								[expectChecksumVerifies fulfill];
							}];
						}
					} userInfo:nil ephermalUserInfo:nil]];
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
}

@end

