//
//  ItemTests.m
//  ownCloudSDKTests
//
//  Created by Pablo Carrascal on 28/08/2018.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <ownCloudSDK/ownCloudSDK.h>
#import "Host Simulator/OCHostSimulator.h"
@interface ItemTests : XCTestCase
{
	OCHostSimulator *hostSimulator;
}
@end

@implementation ItemTests

- (void)setUp {
	[super setUp];

	hostSimulator = [[OCHostSimulator alloc] init];
	hostSimulator.unroutableRequestHandler = nil;
}

- (void)tearDown {
	[super tearDown];
}

- (void)testRetrivalOfPrivateLink {

	NSString *userName = @"admin";
	NSString *password = @"admin";
	NSString *server = @"https://demo.owncloud.org";
	NSString *privateLinkBase = @"https://demo.owncloud.org/f/";

	XCTestExpectation *querySuccess = [self expectationWithDescription:@"LOG ---> Success to retrieve the query with path -> /"];

	OCBookmark *bookmark;
	bookmark = [OCBookmark bookmarkForURL:[NSURL URLWithString:server]];
	bookmark.authenticationData = [OCAuthenticationMethodBasicAuth authenticationDataForUsername:userName passphrase:password authenticationHeaderValue:NULL error:NULL];
	bookmark.authenticationMethodIdentifier = OCAuthenticationMethodBasicAuthIdentifier;

	bookmark.authenticationDataStorage = OCBookmarkAuthenticationDataStorageMemory;
	[[OCBookmarkManager sharedBookmarkManager] addBookmark:bookmark];
	[[OCBookmarkManager sharedBookmarkManager] saveBookmarks];

	OCCore *core;
	core = [[OCCoreManager sharedCoreManager] requestCoreForBookmark:bookmark completionHandler:nil];


	NSString* path = [[NSBundle bundleForClass:[self class]] pathForResource:@"privateLinkFilesResponse"
													 ofType:@"xml"];
	NSError* error = nil;
	NSString* content = [NSString stringWithContentsOfFile:path
												  encoding:NSUTF8StringEncoding
													 error:&error];
	XCTAssertNil(error, @"error getting contents of PrivateLinkFilesResponse");
	hostSimulator.responseByPath = @{
									 @"/remote.php/dav/files/admin" :
										 [OCHostSimulatorResponse responseWithURL:nil
																	   statusCode:OCHTTPStatusCodeMULTI_STATUS
																		  headers:nil
																	  contentType:@"application/xml"
																			 body:content]

									 };

	core.connection.hostSimulator = hostSimulator;

	OCQuery *rootQuery;
	// Create a query for the root directory
	rootQuery = [OCQuery queryForPath:@"/"];

	// Provide a block that is called every time there's a query result update available
	rootQuery.changesAvailableNotificationHandler = ^(OCQuery *query) {
		// Request the latest changes
		[query requestChangeSetWithFlags:OCQueryChangeSetRequestFlagDefault completionHandler:^(OCQuery *query, OCQueryChangeSet *changeset) {
			if (changeset != nil)
			{
				NSArray<NSString *> *privateLinkIDs = @[@"1", @"2", @"3"];
				int index = 0;
				NSLog(@"Latest contents of root directory:");
				for (OCItem *item in changeset.queryResult)
				{
					NSString *privateLink = [privateLinkBase stringByAppendingString:privateLinkIDs[index]];
					XCTAssertTrue([privateLink isEqualToString: [item.privateLink absoluteString]], @"The private link <%@>does not match <%@>", [item.privateLink absoluteString], privateLink);
											 index ++;
				}

				if (changeset.queryResult.count > 0)
				{
					[querySuccess fulfill];
				}
			}
		}];
	};

	[core startQuery:rootQuery];
	[self waitForExpectationsWithTimeout:60 handler:nil];

}

@end
