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
#import <ownCloudMocking/ownCloudMocking.h>
#import "OCAuthenticationMethod+OCTools.h"

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

#pragma mark - Infrastructure
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

#pragma mark - Basic auth
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

#pragma mark - OAuth2
- (void)testOAuth2TokenGeneration
{
	XCTestExpectation *expectAuthControllerInvocation = [self expectationWithDescription:@"Auth controller invocation"];
	XCTestExpectation *expectAuthCodeGrantRequest = [self expectationWithDescription:@"Auth code grant request sent"];
	XCTestExpectation *expectBookmarkDataCompletenHandlerCall = [self expectationWithDescription:@"Bookmark data completion handler called"];

	OCBookmark *bookmark = [OCBookmark bookmarkForURL:OCTestTarget.insecureTargetURL];
	NSString *basicAuthString = [OCAuthenticationMethod basicAuthorizationValueForUsername:OCTestTarget.userLogin passphrase:OCTestTarget.userPassword];
	NSString *refreshAuthString = [OCAuthenticationMethod basicAuthorizationValueForUsername:[OCAuthenticationMethodOAuth2 classSettingForOCClassSettingsKey:OCAuthenticationMethodOAuth2ClientID] passphrase:[OCAuthenticationMethodOAuth2 classSettingForOCClassSettingsKey:OCAuthenticationMethodOAuth2ClientSecret]];

	OCConnection *connection;
	OCHostSimulator *hostSimulator;

	if ((connection = [[OCConnection alloc] initWithBookmark:bookmark]) != nil)
	{
		// Add host simulator
		hostSimulator = [[OCHostSimulator alloc] init];
		hostSimulator.unroutableRequestHandler = nil; // Pass through requests we don't handle

		connection.hostSimulator = hostSimulator;

		// Intercept endpoints
		hostSimulator.requestHandler = ^BOOL(OCConnection *connection, OCHTTPRequest *request, OCHostSimulatorResponseHandler responseHandler) {
			BOOL fixAuthentication = YES;

			OCLogDebug(@"headerFields[Authorization]=%@", request.headerFields[@"Authorization"]);

			if ([request.url.absoluteString hasSuffix:@"ocs/v2.php/cloud/user"])
			{
				responseHandler(nil, [OCHostSimulatorResponse responseWithURL:request.url statusCode:OCHTTPStatusCodeOK headers:@{} contentType:@"application/json; charset=utf-8" body:@"{\"ocs\":{\"meta\":{\"status\":\"ok\",\"statuscode\":200,\"message\":\"OK\",\"totalitems\":\"\",\"itemsperpage\":\"\"},\"data\":{\"id\":\"demo\",\"display-name\":\"demo\",\"email\":null}}}"]);

				return (YES);
			}

			if ([request.url.absoluteString hasSuffix:@"index.php/apps/oauth2/api/v1/token"])
			{
				NSString *requestGrantType = nil, *requestCode = nil, *requestRedirectURI = nil;
				NSURLComponents *urlComponents = [[NSURLComponents alloc] init];

				urlComponents.query = [[NSString alloc] initWithData:request.bodyData encoding:NSUTF8StringEncoding];

				for (NSURLQueryItem *urlQueryItem in urlComponents.queryItems)
				{
					if ([urlQueryItem.name isEqual:@"grant_type"])
					{
						requestGrantType = urlQueryItem.value;
					}

					if ([urlQueryItem.name isEqual:@"code"])
					{
						requestCode = urlQueryItem.value;
					}

					if ([urlQueryItem.name isEqual:@"redirect_uri"])
					{
						requestRedirectURI = urlQueryItem.value;
					}
				}

				XCTAssert([request.headerFields[@"Authorization"] isEqualToString:refreshAuthString]);

				if ([requestGrantType isEqualToString:@"authorization_code"])
				{
					XCTAssert([requestCode isEqualToString:@"issuedAuthCode"]);
					XCTAssert([requestRedirectURI isEqualToString:@"oc://ios.owncloud.com"]);

					[expectAuthCodeGrantRequest fulfill];

					responseHandler(nil, [OCHostSimulatorResponse responseWithURL:request.url statusCode:OCHTTPStatusCodeOK headers:@{} contentType:@"application/json; charset=utf-8" body:@"{\"access_token\":\"issuedAccessToken\",\"token_type\":\"Bearer\",\"expires_in\":125,\"refresh_token\":\"issuedRefreshToken\",\"user_id\":\"joe\",\"message_url\":\"https:\\/\\/www.owncloud.org\\/apps\\/oauth2\\/authorization-successful\"}"]);
				}

				return (YES);
			}

			if (fixAuthentication)
			{
				if ([request.headerFields[@"Authorization"] containsString:@"Bearer "])
				{
					[request setValue:basicAuthString forHeaderField:@"Authorization"];
				}
			}

			return (NO);
		};

		OCMockAuthenticationMethodOAuth2StartAuthenticationSessionForURLSchemeCompletionHandlerBlock mockBlock;

		mockBlock = ^(id *authenticationSession, NSURL *authorizationRequestURL, NSString *scheme, OCAuthenticationMethodBookmarkAuthenticationDataGenerationOptions options, void(^completionHandler)(NSURL *_Nullable callbackURL, NSError *_Nullable error)) {

			NSLog(@"authenticationSession=%@, authorizationRequestURL=%@, scheme=%@", *authenticationSession, authorizationRequestURL, scheme);

			[expectAuthControllerInvocation fulfill];

			completionHandler([NSURL URLWithString:@"oc://ios.owncloud.com/?code=issuedAuthCode"], nil);

			return (YES);
		};

		[OCMockManager.sharedMockManager addMockingBlocks:@{
			OCMockLocationAuthenticationMethodOAuth2StartAuthenticationSessionForURLSchemeCompletionHandler : mockBlock
		}];

		[connection generateAuthenticationDataWithMethod:OCAuthenticationMethodIdentifierOAuth2 options:@{
			OCAuthenticationMethodPresentingViewControllerKey : [UIViewController new]
		} completionHandler:^(NSError *error, OCAuthenticationMethodIdentifier authenticationMethodIdentifier, NSData *authenticationData) {
			XCTAssert([authenticationMethodIdentifier isEqualToString:OCAuthenticationMethodIdentifierOAuth2]);
			XCTAssert(authenticationData!=nil);
			XCTAssert(error==nil);

			bookmark.authenticationMethodIdentifier = authenticationMethodIdentifier;
			bookmark.authenticationData = authenticationData;

			NSDictionary *authSecretDict = [connection.authenticationMethod cachedAuthenticationSecretForConnection:connection];

			OCLog(@"authSecretDict=%@", authSecretDict);

			XCTAssert([authSecretDict[@"bearerString"] isEqualToString:@"Bearer issuedAccessToken"]);
			XCTAssert([(NSDate *)authSecretDict[@"expirationDate"] timeIntervalSinceNow] > 110);
			XCTAssert([(NSDate *)authSecretDict[@"expirationDate"] timeIntervalSinceNow] < 126);
			XCTAssert([[(NSDictionary *)authSecretDict[@"tokenResponse"] objectForKey:@"access_token"] isEqualToString:@"issuedAccessToken"]);
			XCTAssert([[(NSDictionary *)authSecretDict[@"tokenResponse"] objectForKey:@"refresh_token"] isEqualToString:@"issuedRefreshToken"]);

			XCTAssert([[OCAuthenticationMethodOAuth2 userNameFromAuthenticationData:authenticationData] isEqualToString:@"joe"]);
			XCTAssert([OCAuthenticationMethodOAuth2 type] == OCAuthenticationMethodTypeToken);
			XCTAssert([[OCAuthenticationMethodOAuth2 name] isEqualToString:@"OAuth2"]);

			[expectBookmarkDataCompletenHandlerCall fulfill];
		}];
	}

	[self waitForExpectationsWithTimeout:60 handler:nil];

	OCLogDebug(@"hostSimulator=%@", hostSimulator);

	[OCMockManager.sharedMockManager removeAllMockingBlocks];
}

- (void)testOAuth2TokenRefresh
{
	// Create expectations
	__block XCTestExpectation *expectFirstRequestWithRefreshedAccessToken = [self expectationWithDescription:@"received first PROPFIND request with refreshed refresh token"];
	__block XCTestExpectation *expectSecondRequestWithRefreshedAccessToken = [self expectationWithDescription:@"received second PROPFIND request with refreshed twice refresh token"];
	XCTestExpectation *expectSecondDisconnect = [self expectationWithDescription:@"Second disconnect returned"];
	__block NSUInteger tokenRequestCount = 0;

	// Create fake OAuth2 bookmark in need of a refresh
	OCBookmark *bookmark = [OCBookmark bookmarkForURL:OCTestTarget.secureTargetURL];
	NSDictionary *originalJSONResponseDict = [NSJSONSerialization JSONObjectWithData:[@"{\"access_token\":\"originalAccessToken\",\"token_type\":\"Bearer\",\"expires_in\":3600,\"refresh_token\":\"originalRefreshToken\",\"user_id\":\"joe\",\"message_url\":\"https:\\/\\/demo.owncloud.org\\/apps\\/oauth2\\/authorization-successful\"}" dataUsingEncoding:NSUTF8StringEncoding] options:0 error:NULL];
	NSString *basicAuthString = [OCAuthenticationMethod basicAuthorizationValueForUsername:OCTestTarget.userLogin passphrase:OCTestTarget.userPassword];
	NSString *refreshAuthString = [OCAuthenticationMethod basicAuthorizationValueForUsername:[OCAuthenticationMethodOAuth2 classSettingForOCClassSettingsKey:OCAuthenticationMethodOAuth2ClientID] passphrase:[OCAuthenticationMethodOAuth2 classSettingForOCClassSettingsKey:OCAuthenticationMethodOAuth2ClientSecret]];

	bookmark.authenticationMethodIdentifier = OCAuthenticationMethodIdentifierOAuth2;
	bookmark.authenticationData = [NSPropertyListSerialization dataWithPropertyList:@{
		@"expirationDate" : [NSDate distantPast],
		@"bearerString"  : [NSString stringWithFormat:@"Bearer %@", originalJSONResponseDict[@"access_token"]],
		@"tokenResponse" : originalJSONResponseDict
	} format:NSPropertyListXMLFormat_v1_0 options:0 error:NULL];

	// Create connection
	OCConnection *connection;
	OCHostSimulator *hostSimulator;

	if ((connection = [[OCConnection alloc] initWithBookmark:bookmark]) != nil)
	{
		__block BOOL firstPropfindRequest = YES;

		// Add host simulator
		hostSimulator = [[OCHostSimulator alloc] init];
		hostSimulator.unroutableRequestHandler = nil; // Pass through requests we don't handle

		connection.hostSimulator = hostSimulator;

		// Intercept endpoints
		hostSimulator.requestHandler = ^BOOL(OCConnection *connection, OCHTTPRequest *request, OCHostSimulatorResponseHandler responseHandler) {
			BOOL fixAuthentication = YES;

			OCLogDebug(@"headerFields[Authorization]=%@", request.headerFields[@"Authorization"]);

			if ([request.url.absoluteString hasSuffix:@"index.php/apps/oauth2/api/v1/token"])
			{
				NSString *requestGrantType = nil, *requestRefreshToken = nil;
				NSURLComponents *urlComponents = [[NSURLComponents alloc] init];

				urlComponents.query = [[NSString alloc] initWithData:request.bodyData encoding:NSUTF8StringEncoding];

				for (NSURLQueryItem *urlQueryItem in urlComponents.queryItems)
				{
					if ([urlQueryItem.name isEqual:@"grant_type"])
					{
						requestGrantType = urlQueryItem.value;
					}

					if ([urlQueryItem.name isEqual:@"refresh_token"])
					{
						requestRefreshToken = urlQueryItem.value;
					}
				}

				XCTAssert([request.headerFields[@"Authorization"] isEqualToString:refreshAuthString]);

				switch (tokenRequestCount)
				{
					case 0:
						XCTAssert([requestGrantType isEqual:@"refresh_token"]);
						XCTAssert([requestRefreshToken isEqual:@"originalRefreshToken"]);

						responseHandler(nil, [OCHostSimulatorResponse responseWithURL:request.url statusCode:OCHTTPStatusCodeOK headers:@{} contentType:@"application/json; charset=utf-8" body:@"{\"access_token\":\"refreshedAccessToken\",\"token_type\":\"Bearer\",\"expires_in\":125,\"refresh_token\":\"refreshedRefreshToken\",\"user_id\":\"joe\",\"message_url\":\"https:\\/\\/www.owncloud.org\\/apps\\/oauth2\\/authorization-successful\"}"]);
					break;

					case 1:
						XCTAssert([requestGrantType isEqual:@"refresh_token"]);
						XCTAssert([requestRefreshToken isEqual:@"refreshedRefreshToken"]);

						responseHandler(nil, [OCHostSimulatorResponse responseWithURL:request.url statusCode:OCHTTPStatusCodeOK headers:@{} contentType:@"application/json; charset=utf-8" body:@"{\"access_token\":\"refreshedTwiceAccessToken\",\"token_type\":\"Bearer\",\"expires_in\":125,\"refresh_token\":\"refreshedTwiceRefreshToken\",\"user_id\":\"joe\",\"message_url\":\"https:\\/\\/www.owncloud.org\\/apps\\/oauth2\\/authorization-successful\"}"]);
					break;

					default:
						XCTFail(@"Token endpoint should not be contacted more than twice");
					break;
				}

				tokenRequestCount++;

				return (YES);
			}

			if ([request.url.absoluteString hasSuffix:@"remote.php/dav/files"])
			{
				if ([request.headerFields[@"Authorization"] isEqualToString:@"Bearer refreshedAccessToken"])
				{
					XCTAssert(firstPropfindRequest);
					XCTAssert(expectFirstRequestWithRefreshedAccessToken!=nil);
					XCTAssert(expectSecondRequestWithRefreshedAccessToken!=nil);

					[expectFirstRequestWithRefreshedAccessToken fulfill];
					expectFirstRequestWithRefreshedAccessToken = nil;
				}

				if ([request.headerFields[@"Authorization"] isEqualToString:@"Bearer refreshedTwiceAccessToken"])
				{
					XCTAssert(!firstPropfindRequest);
					XCTAssert(expectFirstRequestWithRefreshedAccessToken==nil);
					XCTAssert(expectSecondRequestWithRefreshedAccessToken!=nil);

					[expectSecondRequestWithRefreshedAccessToken fulfill];
					expectSecondRequestWithRefreshedAccessToken = nil;
				}

				firstPropfindRequest = NO;
			}

			if (fixAuthentication)
			{
				if ([request.headerFields[@"Authorization"] containsString:@"Bearer "])
				{
					[request setValue:basicAuthString forHeaderField:@"Authorization"];
				}
			}

			return (NO);
		};

		[connection connectWithCompletionHandler:^(NSError *error, OCIssue *issue) {
			OCLog(@"error=%@, issue=%@", error, issue);
			XCTAssert(expectFirstRequestWithRefreshedAccessToken==nil);

			[connection disconnectWithCompletionHandler:^{
				sleep (6);

				[connection connectWithCompletionHandler:^(NSError *error, OCIssue *issue) {
					OCLog(@"error=%@, issue=%@", error, issue);

					[connection disconnectWithCompletionHandler:^{
						[expectSecondDisconnect fulfill];
					}];
				}];
			}];
		}];
	}

	[self waitForExpectationsWithTimeout:60 handler:nil];

	XCTAssert(tokenRequestCount==2);

	OCLogDebug(@"hostSimulator=%@", hostSimulator);
}

#pragma mark - OpenID Connect
- (void)testOpenIDConnect
{
	// Ensure OIDC test target is available
	OCBookmark *bookmark = OCTestTarget.oidcBookmark;
	if (bookmark == nil) { return; }

	XCTestExpectation *detectionExpectation = [self expectationWithDescription:@"OIDC detected"];
	OCConnection *connection;

	if ((connection = [[OCConnection alloc] initWithBookmark:bookmark]) != nil)
	{
		connection.delegate = self;

		[connection prepareForSetupWithOptions:nil completionHandler:^(OCIssue * _Nullable issue, NSURL * _Nullable suggestedURL, NSArray<OCAuthenticationMethodIdentifier> * _Nullable supportedMethods, NSArray<OCAuthenticationMethodIdentifier> * _Nullable preferredAuthenticationMethods) {
			OCLog(@"preferredAuthenticationMethods: %@ supportedMethods: %@", preferredAuthenticationMethods, supportedMethods);

			if ([preferredAuthenticationMethods.firstObject isEqual:OCAuthenticationMethodIdentifierOpenIDConnect])
			{
				[detectionExpectation fulfill];
			}
		}];
	}

	[self waitForExpectationsWithTimeout:60 handler:nil];
}

#pragma mark - Detection
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

#pragma mark - Sorting and filtering
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
