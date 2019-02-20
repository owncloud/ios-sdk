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

#import "OCTestTarget.h"

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
			OCAuthenticationMethodIdentifierOAuth2,
			OCAuthenticationMethodIdentifierBasicAuth,
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
		[connection generateAuthenticationDataWithMethod:OCAuthenticationMethodIdentifierBasicAuth
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
								XCTAssert((error!=nil), @"Authentication succeeded unexpectedly");
								if (error!=nil)
								{
									OCLog(@"Failed as expected. Error: %@", error);
								}
							}

						       	if (error == nil)
						       	{
							       	// Success! Save authentication data to bookmark.
								bookmark.authenticationMethodIdentifier = authenticationMethodIdentifier;
							       	bookmark.authenticationData = authenticationData;

							       	// Verify userName is accessible
							       	XCTAssert([bookmark.userName isEqual:user], @"Username from bookmark (%@) doesn't match user used for creation (%@)", bookmark.name, user);
								
							       	// Request resource
							       	OCHTTPRequest *request = nil;
								request = [OCHTTPRequest requestWithURL:[connection URLForEndpoint:OCConnectionEndpointIDCapabilities options:nil]];
								[request setValue:@"json" forParameter:@"format"];
								
							       	[connection sendRequest:request ephermalCompletionHandler:^(OCHTTPRequest *request, OCHTTPResponse *response, NSError *error) {
									OCLog(@"Result of request: %@ (error: %@):\n\n## Response: %@\n\n## Body: %@", request, error, response.httpURLResponse, response.bodyAsString);
									
									if (response.status.isSuccess)
									{
										NSError *error = nil;
										NSDictionary *capabilitiesDict;
										
										capabilitiesDict = [response bodyConvertedDictionaryFromJSONWithError:&error];
										XCTAssert((capabilitiesDict!=nil), @"Conversion from JSON successful");
										XCTAssert(([capabilitiesDict valueForKeyPath:@"ocs.data.version.string"]!=nil), @"Capabilities structure intact");
										
										OCLog(@"Capabilities: %@", capabilitiesDict);
										OCLog(@"Version: %@", [capabilitiesDict valueForKeyPath:@"ocs.data.version.string"]);
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
	[self _performBasicAuthenticationTestWithURL:OCTestTarget.insecureTargetURL user:OCTestTarget.userLogin password:OCTestTarget.userPassword allowUpgrades:YES expectsSuccess:YES];
}

- (void)testBasicAuthenticationRedirectFailure
{
	[self _performBasicAuthenticationTestWithURL:OCTestTarget.insecureTargetURL user:OCTestTarget.userLogin password:OCTestTarget.userPassword allowUpgrades:NO expectsSuccess:NO];
}

- (void)testBasicAuthenticationFailure
{
	[self _performBasicAuthenticationTestWithURL:OCTestTarget.secureTargetURL user:@"nosuchuser" password:@"nosuchpass" allowUpgrades:YES expectsSuccess:NO];
}

- (void)testAuthenticationMethodDetection
{
	XCTestExpectation *receivedReplyExpectation = [self expectationWithDescription:@"Received reply"];

	OCBookmark *bookmark;
	OCConnection *connection;

	// bookmark = [OCBookmark bookmarkForURL:[NSURL URLWithString:@"https://owncloud-io.lan/"]];
	bookmark = [OCBookmark bookmarkForURL:OCTestTarget.secureTargetURL];

	if ((connection = [[OCConnection alloc] initWithBookmark:bookmark]) != nil)
	{
		connection.delegate = self;
	
		[connection requestSupportedAuthenticationMethodsWithOptions:nil completionHandler:^(NSError *error, NSArray<OCAuthenticationMethodIdentifier> *supportMethods) {
			OCLog(@"Error: %@ Supported methods: %@", error, supportMethods);
			
			[receivedReplyExpectation fulfill];
		}];
	}

	[self waitForExpectationsWithTimeout:60 handler:nil];
}

- (void)connection:(OCConnection *)connection request:(OCHTTPRequest *)request certificate:(OCCertificate *)certificate validationResult:(OCCertificateValidationResult)validationResult validationError:(NSError *)validationError recommendsProceeding:(BOOL)recommendsProceeding proceedHandler:(OCConnectionCertificateProceedHandler)proceedHandler
{
	OCLog(@"Connection asked for user confirmation of certificate for %@, would recommend: %d", certificate.hostName, recommendsProceeding);
	proceedHandler(YES, nil);
}

- (void)testAuthenticationMethodDetectionManualRedirectHandling
{
	XCTestExpectation *receivedReplyExpectation = [self expectationWithDescription:@"Received reply"];
	XCTestExpectation *receivedRedirectExpectation = [self expectationWithDescription:@"Received redirect"];
	XCTestExpectation *receivedMethodsExpectation = [self expectationWithDescription:@"Received methods"];

	OCBookmark *bookmark;
	OCConnection *connection;

	bookmark = [OCBookmark bookmarkForURL:OCTestTarget.insecureTargetURL];

	if ((connection = [[OCConnection alloc] initWithBookmark:bookmark]) != nil)
	{
		[connection requestSupportedAuthenticationMethodsWithOptions:nil completionHandler:^(NSError *error, NSArray<OCAuthenticationMethodIdentifier> *supportMethods) {
			OCLog(@"1 - Error: %@ - Supported methods: %@", error, supportMethods);

			if ([error isOCErrorWithCode:OCErrorAuthorizationRedirect])
			{
				NSURL *redirectURLBase;
				
				[receivedRedirectExpectation fulfill];
			
				if ((redirectURLBase = [error ocErrorInfoDictionary][OCAuthorizationMethodAlternativeServerURLKey]) != nil)
				{
					connection.bookmark.url = redirectURLBase;

					[connection requestSupportedAuthenticationMethodsWithOptions:nil completionHandler:^(NSError *error, NSArray<OCAuthenticationMethodIdentifier> *supportMethods) {
						OCLog(@"2 - Error: %@ - Supported methods: %@", error, supportMethods);
			
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
	bookmark = [OCBookmark bookmarkForURL:OCTestTarget.insecureTargetURL];

	if ((connection = [[OCConnection alloc] initWithBookmark:bookmark]) != nil)
	{
		[connection requestSupportedAuthenticationMethodsWithOptions:@{ OCAuthenticationMethodAllowURLProtocolUpgradesKey : @(YES) } completionHandler:^(NSError *error, NSArray<OCAuthenticationMethodIdentifier> *supportMethods) {
			OCLog(@"Supported methods: %@", supportMethods);
			
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
	bookmark = [OCBookmark bookmarkForURL:OCTestTarget.insecureTargetURL];

	if ((connection = [[OCConnection alloc] initWithBookmark:bookmark]) != nil)
	{
		[connection requestSupportedAuthenticationMethodsWithOptions:nil completionHandler:^(NSError *error, NSArray<OCAuthenticationMethodIdentifier> *supportMethods) {
			OCLog(@"Supported methods: %@", supportMethods);
			
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
	NSArray <OCAuthenticationMethodIdentifier> *authMethods = @[ OCAuthenticationMethodIdentifierBasicAuth, @"other-method", OCAuthenticationMethodIdentifierOAuth2 ];
	NSArray <OCAuthenticationMethodIdentifier> *expectedMethods = @[ OCAuthenticationMethodIdentifierOAuth2, OCAuthenticationMethodIdentifierBasicAuth, @"other-method"];

	NSArray <OCAuthenticationMethodIdentifier> *filteredAndSorted = [OCConnection filteredAndSortedMethodIdentifiers:authMethods allowedMethodIdentifiers:nil preferredMethodIdentifiers:@[OCAuthenticationMethodIdentifierOAuth2, OCAuthenticationMethodIdentifierBasicAuth]];
	
	XCTAssert([filteredAndSorted isEqualToArray:expectedMethods], @"Result has expected order and content");
}

- (void)testAuthenticationMethodFiltering
{
	NSArray <OCAuthenticationMethodIdentifier> *authMethods = @[ OCAuthenticationMethodIdentifierBasicAuth, @"other-method", OCAuthenticationMethodIdentifierOAuth2 ];
	NSArray <OCAuthenticationMethodIdentifier> *expectedMethods = @[ OCAuthenticationMethodIdentifierOAuth2];

	NSArray <OCAuthenticationMethodIdentifier> *filteredAndSorted = [OCConnection filteredAndSortedMethodIdentifiers:authMethods allowedMethodIdentifiers:@[OCAuthenticationMethodIdentifierOAuth2] preferredMethodIdentifiers:@[OCAuthenticationMethodIdentifierOAuth2, OCAuthenticationMethodIdentifierBasicAuth]];
	
	XCTAssert([filteredAndSorted isEqualToArray:expectedMethods], @"Result has expected order and content");
}


- (void)testAuthenticationMethodSortingAndFiltering
{
	NSArray <OCAuthenticationMethodIdentifier> *authMethods = @[ OCAuthenticationMethodIdentifierBasicAuth, @"other-method", OCAuthenticationMethodIdentifierOAuth2 ];
	NSArray <OCAuthenticationMethodIdentifier> *expectedMethods = @[ OCAuthenticationMethodIdentifierOAuth2, OCAuthenticationMethodIdentifierBasicAuth];

	NSArray <OCAuthenticationMethodIdentifier> *filteredAndSorted = [OCConnection filteredAndSortedMethodIdentifiers:authMethods allowedMethodIdentifiers:expectedMethods preferredMethodIdentifiers:expectedMethods];
	
	XCTAssert([filteredAndSorted isEqualToArray:expectedMethods], @"Result has expected order and content");
}

@end
