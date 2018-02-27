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

@interface AuthenticationTests : XCTestCase
@end

@implementation AuthenticationTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
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

- (void)_performBasicAuthenticationTestWithURL:(NSURL *)url user:(NSString *)user password:(NSString *)password expectsSuccess:(BOOL)expectsSuccess
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
									[receivedReplyExpectation fulfill];
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
									
									if (request.response.statusCode == 200)
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
					       }
		 ];
	}

	[self waitForExpectationsWithTimeout:60 handler:nil];
}

- (void)testBasicAuthenticationSuccess
{
	[self _performBasicAuthenticationTestWithURL:[NSURL URLWithString:@"http://owncloud-io.lan/"] user:@"admin" password:@"admin" expectsSuccess:YES];
}

- (void)testBasicAuthenticationFailure
{
	[self _performBasicAuthenticationTestWithURL:[NSURL URLWithString:@"http://owncloud-io.lan/"] user:@"nosuchuser" password:@"nosuchpass" expectsSuccess:NO];
}

@end
