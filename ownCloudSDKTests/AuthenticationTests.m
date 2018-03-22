//
//  AuthenticationTests.m
//  ownCloudSDKTests
//
//  Created by Felix Schwarz on 24.02.18.
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

@interface AuthenticationTests : XCTestCase <OCConnectionDelegate>

@end

@implementation AuthenticationTests

- (void)setUp
{
	[super setUp];
	// Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
	// Put teardown code here. This method is called after the invocation of each test method in the class.
	[super tearDown];
}

- (void)testAuthenticatioMethodAutoRegistration
{
	NSArray <Class> *authenticationMethodClasses;
	
	if ((authenticationMethodClasses = [OCAuthenticationMethod registeredAuthenticationMethodClasses]) != nil)
	{
		NSMutableArray <OCAuthenticationMethodIdentifier> *expectedIdentifiers = [NSMutableArray arrayWithObjects:
			OCAuthenticationMethodOAuth2Identifier,
			OCAuthenticationMethodBasicAuthIdentifier,
		nil];
		
		for (Class authenticationMethodClass in authenticationMethodClasses)
		{
			[expectedIdentifiers removeObject:[authenticationMethodClass identifier]];
		}
		
		XCTAssert((expectedIdentifiers.count == 0), @"Expected Authentication Methods did not auto-register: %@", expectedIdentifiers);
	}
}

- (void)_performBasicAuthenticationTestWithURL:(NSURL *)url user:(NSString *)user password:(NSString *)password allowUpgrades:(BOOL)allowUpgrades expectsSuccess:(BOOL)expectsSuccess
{
	XCTestExpectation *receivedReplyExpectation = [self expectationWithDescription:@"Received reply"];

	OCBookmark *bookmark;
	OCConnection *connection;

	bookmark = [OCBookmark bookmarkForURL:url];

	if ((connection = [[OCConnection alloc] initWithBookmark:bookmark]) != nil)
	{
		[connection generateAuthenticationDataWithMethod:OCAuthenticationMethodBasicAuthIdentifier
							 options:@{
							 		OCAuthenticationMethodUsernameKey : user,
							 		OCAuthenticationMethodPassphraseKey : password,
							 		OCAuthenticationMethodAllowURLProtocolUpgradesKey : @(allowUpgrades)
								  }
					       completionHandler:^(NSError *error, OCAuthenticationMethodIdentifier authenticationMethodIdentifier, NSData *authenticationData) {
					       		if (expectsSuccess)
					       		{
								XCTAssert((error==nil), @"Authentication failed: %@", error);
							}
							else
							{
								XCTAssert((error!=nil), @"Authentication failed: %@", error);
								if (error!=nil)
								{
									NSLog(@"Failed as expected. Error: %@", error);
								}
							}

						       	if (error == nil)
						       	{
							       	// Success! Save authentication data to bookmark.
								bookmark.authenticationMethodIdentifier = authenticationMethodIdentifier;
							       	bookmark.authenticationData = authenticationData;
								
							       	// Request resource
							       	OCConnectionRequest *request = nil;
								request = [OCConnectionRequest requestWithURL:[connection URLForEndpoint:OCConnectionEndpointIDCapabilities options:nil]];
								[request setValue:@"json" forParameter:@"format"];
								
							       	[connection sendRequest:request toQueue:connection.commandQueue ephermalCompletionHandler:^(OCConnectionRequest *request, NSError *error) {
									NSLog(@"Result of request: %@ (error: %@):\n## Task: %@\n\n## Response: %@\n\n## Body: %@", request, error, request.urlSessionTask, request.response, request.responseBodyAsString);
									
									if (request.responseHTTPStatus.isSuccess)
									{
										NSError *error = nil;
										NSDictionary *capabilitiesDict;
										
										capabilitiesDict = [request responseBodyConvertedDictionaryFromJSONWithError:&error];
										XCTAssert((capabilitiesDict!=nil), @"Conversion from JSON successful");
										XCTAssert(([capabilitiesDict valueForKeyPath:@"ocs.data.version.string"]!=nil), @"Capabilities structure intact");
										
										NSLog(@"Capabilities: %@", capabilitiesDict);
										NSLog(@"Version: %@", [capabilitiesDict valueForKeyPath:@"ocs.data.version.string"]);
									}
									
									[receivedReplyExpectation fulfill];
							       	}];
						       	}
						       	else
						       	{
						       		// Operation failed here. No need to wait until 60 seconds run out
								[receivedReplyExpectation fulfill];
							}
					       }
		 ];
	}

	[self waitForExpectationsWithTimeout:60 handler:nil];
}

- (void)testBasicAuthenticationSuccess
{
	[self _performBasicAuthenticationTestWithURL:[NSURL URLWithString:@"http://demo.owncloud.org/"] user:@"demo" password:@"demo" allowUpgrades:YES expectsSuccess:YES];
}

- (void)testBasicAuthenticationRedirectFailure
{
	[self _performBasicAuthenticationTestWithURL:[NSURL URLWithString:@"http://demo.owncloud.org/"] user:@"demo" password:@"demo" allowUpgrades:NO expectsSuccess:NO];
}

- (void)testBasicAuthenticationFailure
{
	[self _performBasicAuthenticationTestWithURL:[NSURL URLWithString:@"https://demo.owncloud.org/"] user:@"nosuchuser" password:@"nosuchpass" allowUpgrades:YES expectsSuccess:NO];
}

- (void)testAuthenticationMethodDetection
{
	XCTestExpectation *receivedReplyExpectation = [self expectationWithDescription:@"Received reply"];

	OCBookmark *bookmark;
	OCConnection *connection;

	// bookmark = [OCBookmark bookmarkForURL:[NSURL URLWithString:@"https://owncloud-io.lan/"]];
	bookmark = [OCBookmark bookmarkForURL:[NSURL URLWithString:@"https://demo.owncloud.org/"]];

	if ((connection = [[OCConnection alloc] initWithBookmark:bookmark]) != nil)
	{
		connection.delegate = self;
	
		[connection requestSupportedAuthenticationMethodsWithOptions:nil completionHandler:^(NSError *error, NSArray<OCAuthenticationMethodIdentifier> *supportMethods) {
			NSLog(@"Error: %@ Supported methods: %@", error, supportMethods);
			
			[receivedReplyExpectation fulfill];
		}];
	}

	[self waitForExpectationsWithTimeout:60 handler:nil];
}

- (void)connection:(OCConnection *)connection request:(OCConnectionRequest *)request certificate:(OCCertificate *)certificate validationResult:(OCCertificateValidationResult)validationResult validationError:(NSError *)validationError recommendsProceeding:(BOOL)recommendsProceeding proceedHandler:(OCConnectionCertificateProceedHandler)proceedHandler
{
	NSLog(@"Connection asked for user confirmation of certificate for %@, would recommend: %d", certificate.hostName, recommendsProceeding);
	proceedHandler(YES, nil);
}

- (void)testAuthenticationMethodDetectionManualRedirectHandling
{
	XCTestExpectation *receivedReplyExpectation = [self expectationWithDescription:@"Received reply"];
	XCTestExpectation *receivedRedirectExpectation = [self expectationWithDescription:@"Received redirect"];
	XCTestExpectation *receivedMethodsExpectation = [self expectationWithDescription:@"Received methods"];

	OCBookmark *bookmark;
	OCConnection *connection;

	bookmark = [OCBookmark bookmarkForURL:[NSURL URLWithString:@"http://demo.owncloud.org/"]];

	if ((connection = [[OCConnection alloc] initWithBookmark:bookmark]) != nil)
	{
		[connection requestSupportedAuthenticationMethodsWithOptions:nil completionHandler:^(NSError *error, NSArray<OCAuthenticationMethodIdentifier> *supportMethods) {
			NSLog(@"1 - Error: %@ - Supported methods: %@", error, supportMethods);

			if ([error isOCErrorWithCode:OCErrorAuthorizationRedirect])
			{
				NSURL *redirectURLBase;
				
				[receivedRedirectExpectation fulfill];
			
				if ((redirectURLBase = [error ocErrorInfoDictionary][OCAuthorizationMethodAlternativeServerURLKey]) != nil)
				{
					connection.bookmark.url = redirectURLBase;

					[connection requestSupportedAuthenticationMethodsWithOptions:nil completionHandler:^(NSError *error, NSArray<OCAuthenticationMethodIdentifier> *supportMethods) {
						NSLog(@"2 - Error: %@ - Supported methods: %@", error, supportMethods);
			
						[receivedReplyExpectation fulfill];
						
						if (supportMethods.count > 0)
						{
							[receivedMethodsExpectation fulfill];
						}
					}];
				}
			}
		}];
	}

	[self waitForExpectationsWithTimeout:60 handler:nil];
}

- (void)testAuthenticationMethodDetectionAutomaticRedirectHandling
{
	XCTestExpectation *receivedReplyExpectation = [self expectationWithDescription:@"Received reply"];
	XCTestExpectation *receivedAuthMethodsExpectation = [self expectationWithDescription:@"Retrieved auth methods"];

	OCBookmark *bookmark;
	OCConnection *connection;

	// bookmark = [OCBookmark bookmarkForURL:[NSURL URLWithString:@"http://owncloud-io.lan/"]];
	bookmark = [OCBookmark bookmarkForURL:[NSURL URLWithString:@"http://demo.owncloud.org/"]];

	if ((connection = [[OCConnection alloc] initWithBookmark:bookmark]) != nil)
	{
		[connection requestSupportedAuthenticationMethodsWithOptions:@{ OCAuthenticationMethodAllowURLProtocolUpgradesKey : @(YES) } completionHandler:^(NSError *error, NSArray<OCAuthenticationMethodIdentifier> *supportMethods) {
			NSLog(@"Supported methods: %@", supportMethods);
			
			if (supportMethods.count > 0)
			{
				[receivedAuthMethodsExpectation fulfill];
			}
			
			[receivedReplyExpectation fulfill];
		}];
	}

	[self waitForExpectationsWithTimeout:60 handler:nil];
}

- (void)testAuthenticationMethodDetectionWithoutAutomaticRedirectHandling
{
	XCTestExpectation *receivedReplyExpectation = [self expectationWithDescription:@"Received reply"];
	XCTestExpectation *receivedAuthMethodsExpectation = [self expectationWithDescription:@"Retrieved auth methods"];

	OCBookmark *bookmark;
	OCConnection *connection;

	// bookmark = [OCBookmark bookmarkForURL:[NSURL URLWithString:@"http://owncloud-io.lan/"]];
	bookmark = [OCBookmark bookmarkForURL:[NSURL URLWithString:@"http://demo.owncloud.org/"]];

	if ((connection = [[OCConnection alloc] initWithBookmark:bookmark]) != nil)
	{
		[connection requestSupportedAuthenticationMethodsWithOptions:nil completionHandler:^(NSError *error, NSArray<OCAuthenticationMethodIdentifier> *supportMethods) {
			NSLog(@"Supported methods: %@", supportMethods);
			
			if (supportMethods.count == 0)
			{
				[receivedAuthMethodsExpectation fulfill];
			}
			
			[receivedReplyExpectation fulfill];
		}];
	}

	[self waitForExpectationsWithTimeout:60 handler:nil];
}

- (void)testAuthenticationMethodSorting
{
	NSArray <OCAuthenticationMethodIdentifier> *authMethods = @[ OCAuthenticationMethodBasicAuthIdentifier, @"other-method", OCAuthenticationMethodOAuth2Identifier ];
	NSArray <OCAuthenticationMethodIdentifier> *expectedMethods = @[ OCAuthenticationMethodOAuth2Identifier, OCAuthenticationMethodBasicAuthIdentifier, @"other-method"];

	NSArray <OCAuthenticationMethodIdentifier> *filteredAndSorted = [OCConnection filteredAndSortedMethodIdentifiers:authMethods allowedMethodIdentifiers:nil preferredMethodIdentifiers:@[OCAuthenticationMethodOAuth2Identifier, OCAuthenticationMethodBasicAuthIdentifier]];
	
	XCTAssert([filteredAndSorted isEqualToArray:expectedMethods], @"Result has expected order and content");
}

- (void)testAuthenticationMethodFiltering
{
	NSArray <OCAuthenticationMethodIdentifier> *authMethods = @[ OCAuthenticationMethodBasicAuthIdentifier, @"other-method", OCAuthenticationMethodOAuth2Identifier ];
	NSArray <OCAuthenticationMethodIdentifier> *expectedMethods = @[ OCAuthenticationMethodOAuth2Identifier];

	NSArray <OCAuthenticationMethodIdentifier> *filteredAndSorted = [OCConnection filteredAndSortedMethodIdentifiers:authMethods allowedMethodIdentifiers:@[OCAuthenticationMethodOAuth2Identifier] preferredMethodIdentifiers:@[OCAuthenticationMethodOAuth2Identifier, OCAuthenticationMethodBasicAuthIdentifier]];
	
	XCTAssert([filteredAndSorted isEqualToArray:expectedMethods], @"Result has expected order and content");
}


- (void)testAuthenticationMethodSortingAndFiltering
{
	NSArray <OCAuthenticationMethodIdentifier> *authMethods = @[ OCAuthenticationMethodBasicAuthIdentifier, @"other-method", OCAuthenticationMethodOAuth2Identifier ];
	NSArray <OCAuthenticationMethodIdentifier> *expectedMethods = @[ OCAuthenticationMethodOAuth2Identifier, OCAuthenticationMethodBasicAuthIdentifier];

	NSArray <OCAuthenticationMethodIdentifier> *filteredAndSorted = [OCConnection filteredAndSortedMethodIdentifiers:authMethods allowedMethodIdentifiers:expectedMethods preferredMethodIdentifiers:expectedMethods];
	
	XCTAssert([filteredAndSorted isEqualToArray:expectedMethods], @"Result has expected order and content");
}

@end
