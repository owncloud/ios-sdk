//
//  BookmarkTests.m
//  ownCloudSDKTests
//
//  Created by Felix Schwarz on 16.02.18.
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

@interface AssumptionTestObject : NSObject <NSSecureCoding>

@property(strong) NSData *data;
@property(strong) NSString *string;

@end

@implementation AssumptionTestObject

#pragma mark - Secure Coding
+ (BOOL)supportsSecureCoding
{
	return (YES);
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
	if ((self = [super init]) != nil)
	{
		self.data = [aDecoder decodeObjectOfClass:[NSData class] forKey:@"data"];
		self.string = [aDecoder decodeObjectOfClass:[NSString class] forKey:@"string"];
	}
	
	return (self);
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
	[aCoder encodeObject:self.string forKey:@"string"];
	[aCoder encodeObject:self.data forKey:@"data"];
}

@end

@interface BookmarkTests : XCTestCase
@end

@implementation BookmarkTests

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

#pragma mark - Security Tests
- (void)testSecurityAssumptions
{
	// Test assumption that strings and data placed in a serialized bookmark can also be found in serialized bookmark
	AssumptionTestObject *testObject = [AssumptionTestObject new];
	NSData *serializedData;
	NSData *secretStringData = [@"SECRETSTRING" dataUsingEncoding:NSUTF8StringEncoding];
	
	testObject.string = @"SECRETSTRING";
	testObject.data = [@"SECRETDATA" dataUsingEncoding:NSUTF8StringEncoding];

	serializedData = [NSKeyedArchiver archivedDataWithRootObject:testObject];
	
	XCTAssert(([serializedData rangeOfData:secretStringData options:0 range:NSMakeRange(0, serializedData.length)].location != NSNotFound), @"SECRETSTRING must be findable inside the serialized data");
	XCTAssert(([serializedData rangeOfData:testObject.data options:0 range:NSMakeRange(0, serializedData.length)].location != NSNotFound), @"SECRETDATA must be findable inside the serialized data");
}

- (void)testSerializationSecurity
{
	// Test if PINs or authentication data is stored in the serialized bookmark (which it shouldn't be)
	NSData *serializedData;
	OCBookmark *bookmark;
	
	[OCAppIdentity sharedAppIdentity].keychain = [OCKeychain new]; // Use app-default keychain (accessing an keychain access group inside a test may be difficult due to code signing requirements)
	
	// Put data into bookmark that should be findable in the serialized version
	bookmark = [[OCBookmark alloc] init];
	bookmark.authenticationData = [@"SECRETDATA" dataUsingEncoding:NSUTF8StringEncoding];;

	// Create serialized data
	serializedData = [bookmark bookmarkData];

	// Check if the generated data could be bogus because something went wrong
	XCTAssert((bookmark!=nil), @"bookmark is not nil");
	XCTAssert((serializedData!=nil), @"serializedData is not nil");

	// Test serialized data
	XCTAssert(([serializedData rangeOfData:bookmark.authenticationData options:0 range:NSMakeRange(0, serializedData.length)].location == NSNotFound), @"OCBookmark.authenticationData must be findable inside the serialized data");
	
	// Remove data from keychain
	bookmark.authenticationData = nil;
}

- (void)testStoreRetrieveAndDeletionOfSecrets
{
	NSData *serializedData;
	NSData *secretAuthData = [@"SECRETDATA" dataUsingEncoding:NSUTF8StringEncoding];
	OCBookmark *bookmark;
	OCBookmark *restoredBookmark;

	[OCAppIdentity sharedAppIdentity].keychain = [OCKeychain new]; // Use app-default keychain (accessing an keychain access group inside a test may be difficult due to code signing requirements)

	// Store data
	bookmark = [[OCBookmark alloc] init];
	bookmark.authenticationData = secretAuthData;
	
	serializedData = [bookmark bookmarkData];

	restoredBookmark = [OCBookmark bookmarkFromBookmarkData:serializedData];
	
	// Check if the generated data could be bogus because something went wrong
	XCTAssert((bookmark!=nil), @"bookmark is not nil");
	XCTAssert((serializedData!=nil), @"serializedData is not nil");
	XCTAssert((restoredBookmark!=nil), @"restoredBookmark is not nil");
	
	// Check if restoredBookmark's pin and authenticationData match that of bookmark
	XCTAssert(([bookmark.authenticationData isEqual:restoredBookmark.authenticationData]), @"bookmark.authenticationData == restoredBookmark.authenticationData");

	// Check if deletion of secrets also deletes them from restored bookmarks
	bookmark.authenticationData = nil;

	restoredBookmark = [OCBookmark bookmarkFromBookmarkData:serializedData];

	XCTAssert((bookmark!=nil), @"bookmark is not nil");
	XCTAssert((serializedData!=nil), @"serializedData is not nil");
	XCTAssert((restoredBookmark!=nil), @"restoredBookmark is not nil");

	XCTAssert((restoredBookmark.authenticationData == nil), @"restoredBookmark.authenticationData == nil");
}


@end
