//
//  BookmarkManagerTests.m
//  ownCloudSDKTests
//
//  Created by Felix Schwarz on 16.01.19.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <ownCloudSDK/ownCloudSDK.h>
#import "OCTestTarget.h"

@interface BookmarkManagerTests : XCTestCase
{

}

@end

@implementation BookmarkManagerTests

- (void)testBookmarkManager
{
	OCBookmarkManager *manager = [OCBookmarkManager sharedBookmarkManager];
	OCBookmark *bookmark1, *bookmark2;
	id observerToken = nil;
	__block NSUInteger changeNotificationCount = 0;

	bookmark1 = [OCTestTarget userBookmark];
	bookmark2 = [OCTestTarget adminBookmark];

	observerToken = [NSNotificationCenter.defaultCenter addObserverForName:OCBookmarkManagerListChanged object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
		changeNotificationCount++;
	}];

	// Clear bookmarks
	[[NSFileManager defaultManager] removeItemAtURL:manager.bookmarkStoreURL error:NULL];
	[manager loadBookmarks];

	[manager addBookmark:bookmark1];
	XCTAssert(manager.bookmarks.count == 1);
	XCTAssert(changeNotificationCount == 1);

	[manager addBookmark:bookmark2];
	XCTAssert(manager.bookmarks.count == 2);
	XCTAssert(changeNotificationCount == 2);

	XCTAssert([manager bookmarkAtIndex:0] == bookmark1);
	XCTAssert([manager bookmarkAtIndex:1] == bookmark2);

	XCTAssert([manager bookmarkForUUID:bookmark1.uuid] == bookmark1);
	XCTAssert([manager bookmarkForUUID:bookmark2.uuid] == bookmark2);
	XCTAssert([manager bookmarkForUUID:NSUUID.UUID] == nil);

	[manager moveBookmarkFrom:1 to:0];
	XCTAssert([manager bookmarkAtIndex:0] == bookmark2);
	XCTAssert([manager bookmarkAtIndex:1] == bookmark1);
	XCTAssert(manager.bookmarks.count == 2);
	XCTAssert(changeNotificationCount == 3);

	[manager removeBookmark:bookmark2];
	XCTAssert(manager.bookmarks.count == 1);
	XCTAssert(changeNotificationCount == 4);
	XCTAssert([manager bookmarkAtIndex:0] == bookmark1);

	[manager updateBookmark:bookmark1];
	XCTAssert(manager.bookmarks.count == 1);
	XCTAssert(changeNotificationCount == 5);
	XCTAssert([manager bookmarkAtIndex:0] == bookmark1);

	[manager saveBookmarks];
	[manager loadBookmarks];

	XCTAssert(manager.bookmarks.count == 1);
	XCTAssert([manager bookmarkAtIndex:0] != nil);
	XCTAssert([manager bookmarkAtIndex:0] != bookmark1);
	XCTAssert([[manager bookmarkAtIndex:0].uuid isEqual:bookmark1.uuid]);

	[manager removeBookmark:[manager bookmarkAtIndex:0]];
	XCTAssert(manager.bookmarks.count == 0);

	[NSNotificationCenter.defaultCenter removeObserver:observerToken];
}

- (void)testBookmarkManagerBrokenFileLoad
{
	OCBookmarkManager *manager = [OCBookmarkManager sharedBookmarkManager];

	// Clear bookmarks
	[[NSFileManager defaultManager] removeItemAtURL:manager.bookmarkStoreURL error:NULL];

	// Write corrupt data
	[[NSData dataWithBytes:&manager length:sizeof(manager)] writeToURL:manager.bookmarkStoreURL atomically:YES];

	// Try to load and see if it crashes
	[manager loadBookmarks];

	XCTAssert(manager.bookmarks.count == 0);
}

@end
