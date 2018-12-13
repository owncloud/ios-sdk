//
//  MiscTests.m
//  ownCloudSDKTests
//
//  Created by Felix Schwarz on 02.03.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <ownCloudSDK/ownCloudSDK.h>

@interface MiscTests : XCTestCase

@end

@implementation MiscTests

#pragma mark - NSURL+OCURLNormalization
- (void)testURLNormalization
{
	// Test variations, leading and trailing space, missing or lower/uppercase scheme
	NSDictionary <NSString *, NSString *> *expectedResultByInput = @{
		// Input					  // Expected
		@"https://demo.owncloud.org/index.php"  	: @"https://demo.owncloud.org/",
		@"https://demo.owncloud.org/index.php/apps/"  	: @"https://demo.owncloud.org/",
		@"https://demo.owncloud.org" 			: @"https://demo.owncloud.org/",
		@"HTTP://demo.owncloud.org" 			: @"http://demo.owncloud.org/",
		@"HTTPS://demo.owncloud.org" 			: @"https://demo.owncloud.org/",
		@"Https://demo.owncloud.org" 			: @"https://demo.owncloud.org/",
		@" 	http://demo.owncloud.org" 		: @"http://demo.owncloud.org/",
		@" 	demo.owncloud.org" 			: @"https://demo.owncloud.org/",
		@"	 demo.owncloud.org" 			: @"https://demo.owncloud.org/",
		@"http://demo.owncloud.org	 " 		: @"http://demo.owncloud.org/",
		@"demo.owncloud.org	" 			: @"https://demo.owncloud.org/",
		@"demo.owncloud.org	 " 			: @"https://demo.owncloud.org/",
		@"	demo.owncloud.org	 " 		: @"https://demo.owncloud.org/",
	};
	
	for (NSString *inputString in expectedResultByInput)
	{
		NSString *expectedURLString = expectedResultByInput[inputString];
		NSURL *computedURL = [NSURL URLWithUsername:NULL password:NULL afterNormalizingURLString:inputString protocolWasPrepended:NULL];

		NSAssert([[computedURL absoluteString] isEqual:expectedURLString], @"Computed URL matches expectation: %@=%@", [computedURL absoluteString], expectedURLString);
	}
	
	// Test user + pass extraction
	{
		NSString *user=nil, *pass=nil;
		NSURL *normalizedURL;
		
		// Test username + password
		normalizedURL = [NSURL URLWithUsername:&user password:&pass afterNormalizingURLString:@"https://usr:pwd@demo.owncloud.org/" protocolWasPrepended:NULL];
		
		NSAssert([[normalizedURL absoluteString] isEqual:@"https://demo.owncloud.org/"], @"Result URL has no username or password in it: %@", normalizedURL);

		NSAssert([user isEqual:@"usr"], @"Username has been extracted successfully: %@", user);
		NSAssert([pass isEqual:@"pwd"], @"Password has been extracted successfully: %@", pass);

		// Test username only
		normalizedURL = [NSURL URLWithUsername:&user password:&pass afterNormalizingURLString:@"https://usr@demo.owncloud.org/" protocolWasPrepended:NULL];
		
		NSAssert([[normalizedURL absoluteString] isEqual:@"https://demo.owncloud.org/"], @"Result URL has no username or password in it: %@", normalizedURL);

		NSAssert([user isEqual:@"usr"], @"Username has been extracted successfully: %@", user);
		NSAssert((pass==nil), @"No password has been used in this URL: %@", pass);
	}
}

#pragma mark - XML en-/decoding
- (void)testXMLEncoding
{
	// Just a playground right now.. proper tests coming.
	
	/*
<?xml version="1.0" encoding="UTF-8"?>
<D:propfind xmlns:D="DAV:">
	<D:prop>
		<D:resourcetype/>
		<D:getlastmodified/>
		<size xmlns="http://owncloud.org/ns"/>
		<D:creationdate/>
		<id xmlns="http://owncloud.org/ns"/>
		<D:getcontentlength/>
		<D:displayname/>
		<D:quota-available-bytes/>
		<D:getetag/>
		<permissions xmlns="http://owncloud.org/ns"/>
		<D:quota-used-bytes/>
		<D:getcontenttype/>
	</D:prop>
</D:propfind>	*/
	OCXMLNode *xmlDocument = [OCXMLNode documentWithRootElement:
		[OCXMLNode elementWithName:@"D:propfind" attributes:@[[OCXMLNode namespaceWithName:@"D" stringValue:@"DAV:"]] children:@[
			[OCXMLNode elementWithName:@"D:prop" children:@[
				[OCXMLNode elementWithName:@"D:resourcetype"],
				[OCXMLNode elementWithName:@"D:getlastmodified"],
				[OCXMLNode elementWithName:@"D:creationdate"],
				[OCXMLNode elementWithName:@"D:getcontentlength"],
				[OCXMLNode elementWithName:@"D:displayname"],
				[OCXMLNode elementWithName:@"D:getcontenttype"],
				[OCXMLNode elementWithName:@"D:getetag"],
				[OCXMLNode elementWithName:@"D:quota-available-bytes"],
				[OCXMLNode elementWithName:@"D:quota-used-bytes"],
				[OCXMLNode elementWithName:@"size" attributes:@[[OCXMLNode namespaceWithName:nil stringValue:@"http://owncloud.org/ns"]]],
				[OCXMLNode elementWithName:@"id" attributes:@[[OCXMLNode namespaceWithName:nil stringValue:@"http://owncloud.org/ns"]]],
				[OCXMLNode elementWithName:@"permissions" attributes:@[[OCXMLNode namespaceWithName:nil stringValue:@"http://owncloud.org/ns"]]],
				[OCXMLNode elementWithName:@"test" attributes:@[[OCXMLNode attributeWithName:@"escapeThese" stringValue:@"Attribute \"'&<>"]] stringValue:@"Value \"'&<>"]
			]],
		]]
	];
	
	OCLog(@"%@", [xmlDocument XMLString]);

	OCLog(@"%@", [xmlDocument nodesForXPath:@"D:propfind/D:prop/size"]);

	XCTAssert([[xmlDocument XMLString] isEqualToString:[NSString stringWithFormat:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<D:propfind xmlns:D=\"DAV:\">\n<D:prop>\n<D:resourcetype/>\n<D:getlastmodified/>\n<D:creationdate/>\n<D:getcontentlength/>\n<D:displayname/>\n<D:getcontenttype/>\n<D:getetag/>\n<D:quota-available-bytes/>\n<D:quota-used-bytes/>\n<size xmlns=\"http://owncloud.org/ns\"/>\n<id xmlns=\"http://owncloud.org/ns\"/>\n<permissions xmlns=\"http://owncloud.org/ns\"/>\n<test escapeThese=\"Attribute &quot;&apos;&amp;&lt;&gt;\">Value &quot;&apos;&amp;&lt;&gt;</test>\n</D:prop>\n</D:propfind>\n"]], @"Produced XML as expected.");

}

- (void)testXMLDecoding
{
	// Just a playground right now.. proper tests coming.

	NSString *xmlString = @"<?xml version=\"1.0\"?><d:multistatus xmlns:d=\"DAV:\" xmlns:s=\"http://sabredav.org/ns\" xmlns:cal=\"urn:ietf:params:xml:ns:caldav\" xmlns:cs=\"http://calendarserver.org/ns/\" xmlns:card=\"urn:ietf:params:xml:ns:carddav\" xmlns:oc=\"http://owncloud.org/ns\"><d:response><d:href>/remote.php/dav/files/admin/</d:href><d:propstat><d:prop><d:resourcetype><d:collection/></d:resourcetype><d:getlastmodified>Tue, 06 Mar 2018 22:10:00 GMT</d:getlastmodified><d:getetag>&quot;5a9f11b8b440c&quot;</d:getetag><d:quota-available-bytes>-3</d:quota-available-bytes><d:quota-used-bytes>5809166</d:quota-used-bytes><oc:size>5809166</oc:size><oc:id>00000015ocnq90xhpk22</oc:id><oc:permissions>RDNVCK</oc:permissions></d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat><d:propstat><d:prop><d:getcontentlength/><d:getcontenttype/></d:prop><d:status>HTTP/1.1 404 Not Found</d:status></d:propstat></d:response><d:response><d:href>/remote.php/dav/files/admin/Documents/</d:href><d:propstat><d:prop><d:resourcetype><d:collection/></d:resourcetype><d:getlastmodified>Tue, 06 Mar 2018 22:10:00 GMT</d:getlastmodified><d:getetag>&quot;5a9f11b8b440c&quot;</d:getetag><d:quota-available-bytes>-3</d:quota-available-bytes><d:quota-used-bytes>36227</d:quota-used-bytes><oc:size>36227</oc:size><oc:id>00000021ocnq90xhpk22</oc:id><oc:permissions>RDNVCK</oc:permissions></d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat><d:propstat><d:prop><d:getcontentlength/><d:getcontenttype/></d:prop><d:status>HTTP/1.1 404 Not Found</d:status></d:propstat></d:response><d:response><d:href>/remote.php/dav/files/admin/Photos/</d:href><d:propstat><d:prop><d:resourcetype><d:collection/></d:resourcetype><d:getlastmodified>Tue, 06 Mar 2018 22:09:59 GMT</d:getlastmodified><d:getetag>&quot;5a9f11b7bbbc5&quot;</d:getetag><d:quota-available-bytes>-3</d:quota-available-bytes><d:quota-used-bytes>678556</d:quota-used-bytes><oc:size>678556</oc:size><oc:id>00000016ocnq90xhpk22</oc:id><oc:permissions>RDNVCK</oc:permissions></d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat><d:propstat><d:prop><d:getcontentlength/><d:getcontenttype/></d:prop><d:status>HTTP/1.1 404 Not Found</d:status></d:propstat></d:response><d:response><d:href>/remote.php/dav/files/admin/ownCloud%20Manual.pdf</d:href><d:propstat><d:prop><d:resourcetype/><d:getlastmodified>Fri, 23 Feb 2018 11:52:05 GMT</d:getlastmodified><d:getcontentlength>5094383</d:getcontentlength><d:getcontenttype>application/pdf</d:getcontenttype><d:getetag>&quot;c43d4f3af69fb2d8ad1e873dadf9d973&quot;</d:getetag><oc:size>5094383</oc:size><oc:id>00000020ocnq90xhpk22</oc:id><oc:permissions>RDNVW</oc:permissions></d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat><d:propstat><d:prop><d:quota-available-bytes/><d:quota-used-bytes/></d:prop><d:status>HTTP/1.1 404 Not Found</d:status></d:propstat></d:response></d:multistatus>";
	
	OCXMLParser *parser = [[OCXMLParser alloc] initWithData:[xmlString dataUsingEncoding:NSUTF8StringEncoding]];

	parser.forceRetain = YES;
	parser.options = [@{ @"basePath" : @"/remote.php/dav/files/admin" } mutableCopy];

	[parser addObjectCreationClasses:@[ [OCItem class] ]];
	
	[parser parse];

	OCLog(@"Parsed objects: %@", parser.parsedObjects);

	NSArray <OCItem *> *items = parser.parsedObjects;

	XCTAssert(items.count == 4, @"4 items");
	XCTAssert([items[0].name isEqual:@"/"], @"Name match: %@", items[0].name);
	XCTAssert([items[1].name isEqual:@"Documents"], @"Name match: %@", items[1].name);
	XCTAssert([items[2].name isEqual:@"Photos"], @"Name match: %@", items[2].name);
	XCTAssert([items[3].name isEqual:@"ownCloud Manual.pdf"], @"Name match: %@", items[3].name);

	XCTAssert(items[0].mimeType == nil, @"Type match: %@", items[0].mimeType);
	XCTAssert(items[1].mimeType == nil, @"Type match: %@", items[1].mimeType);
	XCTAssert(items[2].mimeType == nil, @"Type match: %@", items[2].mimeType);
	XCTAssert([items[3].mimeType isEqual:@"application/pdf"], @"Type match: %@", items[3].mimeType);

	XCTAssert((items[0].type == OCItemTypeCollection), @"Type match: %ld", (long)items[0].type);
	XCTAssert((items[1].type == OCItemTypeCollection), @"Type match: %ld", (long)items[1].type);
	XCTAssert((items[2].type == OCItemTypeCollection), @"Type match: %ld", (long)items[2].type);
	XCTAssert((items[3].type == OCItemTypeFile), 	   @"Type match: %ld", (long)items[3].type);
}

- (void)testXMLDAVExceptionDecoding
{
	NSString *xmlString=@"<?xml version='1.0' encoding='utf-8'?><d:error xmlns:d=\"DAV:\" xmlns:s=\"http://sabredav.org/ns\">  <s:exception>Sabre\\DAV\\Exception\\ServiceUnavailable</s:exception>  <s:message>System in maintenance mode.</s:message></d:error>";
	NSError *error = nil;

	OCXMLParser *parser = [[OCXMLParser alloc] initWithData:[xmlString dataUsingEncoding:NSUTF8StringEncoding]];

	parser.forceRetain = YES;
	[parser addObjectCreationClasses:@[ [NSError class] ]];

	[parser parse];

	OCLog(@"Parsed objects: %@ - Errors: %@", parser.parsedObjects, parser.errors);

	error = parser.errors.firstObject;

	XCTAssert(parser.parsedObjects.count == 0);
	XCTAssert(parser.errors.count == 1);
	XCTAssert([error isKindOfClass:[NSError class]]);
	XCTAssert(error.isDAVException);
	XCTAssert([error.davExceptionName isEqual:@"Sabre\\DAV\\Exception\\ServiceUnavailable"]);
	XCTAssert([error.davExceptionMessage isEqual:@"System in maintenance mode."]);
	XCTAssert([error.localizedDescription isEqual:@"Server down for maintenance."]);
}

#pragma mark - OCCache
- (void)testCacheCountLimit
{
	OCCache *cache = [OCCache new];

	cache.countLimit = 2;

	[cache setObject:@"1" forKey:@"1"];
	XCTAssert([[cache objectForKey:@"1"] isEqual:@"1"], @"Value saved");

	[cache setObject:@"2" forKey:@"2"];
	XCTAssert([[cache objectForKey:@"2"] isEqual:@"2"], @"Value saved");

	[cache setObject:@"3" forKey:@"3"];
	XCTAssert([[cache objectForKey:@"3"] isEqual:@"3"], @"Value saved");

	// Value 1 should have been discarded at this point
	XCTAssert([cache objectForKey:@"1"] == nil, @"Value 1 auto-removed from cache");
}

- (void)testCacheCostLimit
{
	OCCache *cache = [OCCache new];

	cache.totalCostLimit = 200;

	[cache setObject:@"1" forKey:@"1" cost:100];
	XCTAssert([[cache objectForKey:@"1"] isEqual:@"1"], @"Value saved");

	[cache setObject:@"2" forKey:@"2" cost:50];
	XCTAssert([[cache objectForKey:@"2"] isEqual:@"2"], @"Value saved");

	[cache setObject:@"3" forKey:@"3" cost:50];
	XCTAssert([[cache objectForKey:@"3"] isEqual:@"3"], @"Value saved");

	XCTAssert([cache objectForKey:@"1"] != nil, @"Value 1 still in cache");
	XCTAssert([cache objectForKey:@"2"] != nil, @"Value 2 still in cache");
	XCTAssert([cache objectForKey:@"3"] != nil, @"Value 3 still in cache");

	[cache setObject:@"4" forKey:@"4" cost:1];
	XCTAssert([[cache objectForKey:@"4"] isEqual:@"4"], @"Value saved");

	// Value 1 should have been discarded at this point
	XCTAssert([cache objectForKey:@"1"] == nil, @"Value 1 auto-removed from cache");
	XCTAssert([cache objectForKey:@"2"] != nil, @"Value 2 still in cache");
	XCTAssert([cache objectForKey:@"3"] != nil, @"Value 3 still in cache");
	XCTAssert([cache objectForKey:@"4"] != nil, @"Value 4 still in cache");
}

- (void)testCacheUnlimited
{
	OCCache *cache = [OCCache new];

	[cache setObject:@"1" forKey:@"1"];
	XCTAssert([[cache objectForKey:@"1"] isEqual:@"1"], @"Value saved");

	[cache setObject:@"2" forKey:@"2"];
	XCTAssert([[cache objectForKey:@"2"] isEqual:@"2"], @"Value saved");

	[cache setObject:@"3" forKey:@"3"];
	XCTAssert([[cache objectForKey:@"3"] isEqual:@"3"], @"Value saved");

	XCTAssert([cache objectForKey:@"1"] != nil, @"Value 1 still in cache");
	XCTAssert([cache objectForKey:@"2"] != nil, @"Value 2 still in cache");
	XCTAssert([cache objectForKey:@"3"] != nil, @"Value 3 still in cache");
}

#pragma mark - OCUser
- (void)testUserSerialization
{
	OCUser *user = [OCUser new];

	user.displayName = @"Display Name";
	user.userName = @"userName";
	user.emailAddress = @"em@il.address";
	user.avatarData = [NSData data];

	NSData *userData = [NSKeyedArchiver archivedDataWithRootObject:user];

	XCTAssert(userData!=nil);

	OCUser *deserializedUser = [NSKeyedUnarchiver unarchiveObjectWithData:userData];

	XCTAssert([deserializedUser.displayName isEqual:user.displayName]);
	XCTAssert([deserializedUser.userName isEqual:user.userName]);
	XCTAssert([deserializedUser.emailAddress isEqual:user.emailAddress]);
	XCTAssert([deserializedUser.avatarData isEqual:user.avatarData]);
}

#pragma mark - OCHTTPStatus
- (void)testHTTPStatus
{
	// isError
	XCTAssert(![OCHTTPStatus HTTPStatusWithCode:200].isError);
	XCTAssert(![OCHTTPStatus HTTPStatusWithCode:300].isError);
	XCTAssert([OCHTTPStatus HTTPStatusWithCode:400].isError);
	XCTAssert([OCHTTPStatus HTTPStatusWithCode:500].isError);

	// isSuccess
	XCTAssert([OCHTTPStatus HTTPStatusWithCode:200].isSuccess);
	XCTAssert(![OCHTTPStatus HTTPStatusWithCode:300].isSuccess);
	XCTAssert(![OCHTTPStatus HTTPStatusWithCode:400].isSuccess);
	XCTAssert(![OCHTTPStatus HTTPStatusWithCode:500].isSuccess);

	// isRedirection
	XCTAssert(![OCHTTPStatus HTTPStatusWithCode:200].isRedirection);
	XCTAssert([OCHTTPStatus HTTPStatusWithCode:300].isRedirection);
	XCTAssert(![OCHTTPStatus HTTPStatusWithCode:400].isRedirection);
	XCTAssert(![OCHTTPStatus HTTPStatusWithCode:500].isRedirection);

	// Comparison
	XCTAssert([[OCHTTPStatus HTTPStatusWithCode:200] isEqual:[OCHTTPStatus HTTPStatusWithCode:200]]);
	XCTAssert(![[OCHTTPStatus HTTPStatusWithCode:500] isEqual:[OCHTTPStatus HTTPStatusWithCode:200]]);

	// Error creation
	XCTAssert([[OCHTTPStatus HTTPStatusWithCode:200].error.domain isEqual:OCHTTPStatusErrorDomain]);
	XCTAssert([OCHTTPStatus HTTPStatusWithCode:200].error.code == 200);
	XCTAssert([[[OCHTTPStatus HTTPStatusWithCode:200] errorWithURL:[NSURL URLWithString:@"https://demo.owncloud.com/"]].userInfo[@"url"] isEqual:[NSURL URLWithString:@"https://demo.owncloud.com/"]]);
	XCTAssert([[OCHTTPStatus HTTPStatusWithCode:200] errorWithResponse:[[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://demo.owncloud.com/"] statusCode:200 HTTPVersion:(id)kCFHTTPVersion1_1 headerFields:nil]].userInfo[@"response"] != nil);
	XCTAssert([[OCHTTPStatus HTTPStatusWithCode:200].error HTTPStatus] != nil);
	XCTAssert([[NSError errorWithOCError:OCErrorInternal] HTTPStatus] == nil);
}

#pragma mark - NSData hashing extension
- (void)testHashes
{
	NSData *data = [@"Hello" dataUsingEncoding:NSUTF8StringEncoding];

	OCLog(@"%@", [[data md5Hash] asHexStringWithSeparator:@" "]);
	XCTAssert([[[data md5Hash] asHexStringWithSeparator:@" "] isEqual:@"8B 1A 99 53 C4 61 12 96 A8 27 AB F8 C4 78 04 D7"]);

	OCLog(@"%@", [[data sha1Hash] asHexStringWithSeparator:@" "]);
	XCTAssert([[[data sha1Hash] asHexStringWithSeparator:@" "] isEqual:@"F7 FF 9E 8B 7B B2 E0 9B 70 93 5A 5D 78 5E 0C C5 D9 D0 AB F0"]);

	OCLog(@"%@", [[data sha256Hash] asHexStringWithSeparator:@" "]);
	XCTAssert([[[data sha256Hash] asHexStringWithSeparator:@" "] isEqual:@"18 5F 8D B3 22 71 FE 25 F5 61 A6 FC 93 8B 2E 26 43 06 EC 30 4E DA 51 80 07 D1 76 48 26 38 19 69"]);

}

#pragma mark - OCKeyValueStore
- (void)testKeyValueStore
{
	NSURL *temporaryURL = [[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:@"kvStore"];
	OCKeyValueStore *keyValueStore = [[OCKeyValueStore alloc] initWithRootURL:temporaryURL];
	NSUUID *testUUID = [NSUUID UUID], *retrievedUUID = nil;

	XCTAssert(keyValueStore!=nil);

	keyValueStore[@"test"] = testUUID;
	XCTAssert(keyValueStore.allKeys.count == 1);

	keyValueStore[@"test2"] = @"test";
	XCTAssert(keyValueStore.allKeys.count == 2);

	keyValueStore[@"test2"] = nil;
	XCTAssert(keyValueStore.allKeys.count == 1);

	retrievedUUID = keyValueStore[@"test"];

	XCTAssert(retrievedUUID!=nil);
	XCTAssert([retrievedUUID isEqual:testUUID]);
	XCTAssert(retrievedUUID!=testUUID);

	NSError *error = [keyValueStore eraseBackinngStore];
	XCTAssert(error==nil);
	XCTAssert(![[NSFileManager defaultManager] fileExistsAtPath:temporaryURL.path]);
}

- (void)testStringFormatting
{
	XCTAssert([@"The quick brown fox jumps" isEqual:[@"The quick brown fox jumps" leftPaddedMinLength:10]]);
	XCTAssert([@"The quick brown fox jumps" isEqual:[@"The quick brown fox jumps" rightPaddedMinLength:10]]);
	XCTAssert([@"The quick…" isEqual:[@"The quick brown fox jumps" leftPaddedMaxLength:10]]);
	XCTAssert([@"…fox jumps" isEqual:[@"The quick brown fox jumps" rightPaddedMaxLength:10]]);

	XCTAssert([@"The quick brown fox jumps" isEqual:[@"The quick brown fox jumps" leftPaddedMinLength:20]]);
	XCTAssert([@"The quick brown fox jumps" isEqual:[@"The quick brown fox jumps" rightPaddedMinLength:20]]);
	XCTAssert([@"The quick brown fox…" isEqual:[@"The quick brown fox jumps" leftPaddedMaxLength:20]]);
	XCTAssert([@"…ick brown fox jumps" isEqual:[@"The quick brown fox jumps" rightPaddedMaxLength:20]]);

	XCTAssert([@"The quick brown fox jumps     " isEqual:[@"The quick brown fox jumps" leftPaddedMinLength:30]]);
	XCTAssert([@"     The quick brown fox jumps" isEqual:[@"The quick brown fox jumps" rightPaddedMinLength:30]]);
	XCTAssert([@"The quick brown fox jumps     " isEqual:[@"The quick brown fox jumps" leftPaddedMaxLength:30]]);
	XCTAssert([@"     The quick brown fox jumps" isEqual:[@"The quick brown fox jumps" rightPaddedMaxLength:30]]);
}

#pragma mark - OCIPCNotificationCenter
- (void)testIPNotifications
{
	OCIPNotificationCenter *notificationCenter = OCIPNotificationCenter.sharedNotificationCenter;

	// Test raw sending of darwin message and receipt by XCTDarwinNotificationExpectation
	XCTDarwinNotificationExpectation *darwinMessageSentExpectation = [[XCTDarwinNotificationExpectation alloc] initWithNotificationName:@"hello-darwin"];
	[notificationCenter postNotificationForName:@"hello-darwin" ignoreSelf:NO];

	// Test sending with listener
	__block XCTestExpectation *observerExpectation = [self expectationWithDescription:@"Received hello-all notification"];
	__block XCTestExpectation *secondObserverExpectation = [self expectationWithDescription:@"Received hello-all notification"];
	[notificationCenter addObserver:self forName:@"hello-all" withHandler:^(OCIPNotificationCenter * _Nonnull notificationCenter, id  _Nonnull observer, OCIPCNotificationName  _Nonnull notificationName) {
		if (observerExpectation != nil)
		{
			[observerExpectation fulfill];
			observerExpectation = nil;
		}
		else
		{
			if (secondObserverExpectation != nil)
			{
				[secondObserverExpectation fulfill];
				secondObserverExpectation = nil;

				[notificationCenter removeObserver:observer forName:notificationName];
			}
			else
			{
				XCTAssert(1==0); // Assert since this should never be called a third time
			}
		}

		XCTAssert(observer == self);
	}];
	[notificationCenter postNotificationForName:@"hello-all" ignoreSelf:NO];

	// Test sending with listener but ignored
	[notificationCenter addObserver:self forName:@"hello-others" withHandler:^(OCIPNotificationCenter * _Nonnull notificationCenter, id  _Nonnull observer, OCIPCNotificationName  _Nonnull notificationName) {
		XCTAssert(1==0); // Assert since this should never be called
	}];
	[notificationCenter postNotificationForName:@"hello-others" ignoreSelf:YES];

	// Test adding listener, then removing all, then send a test message that should not be received
	[notificationCenter addObserver:self forName:@"hello-noone" withHandler:^(OCIPNotificationCenter * _Nonnull notificationCenter, id  _Nonnull observer, OCIPCNotificationName  _Nonnull notificationName) {
		XCTAssert(1==0); // Assert since this should never be called
	}];
	[notificationCenter removeAllObserversForName:@"hello-noone"];
	[notificationCenter postNotificationForName:@"hello-noone" ignoreSelf:NO];

	// Verify that two messages generate too calls, send message after hello-others to ensure that message has already run through the system
	// and ending this test at this point, so that the XCTAssert for hello-others would have fired
	[notificationCenter postNotificationForName:@"hello-all" ignoreSelf:YES]; // don't fulfill the secondObserverExpectation just yet
	[notificationCenter postNotificationForName:@"hello-all" ignoreSelf:YES]; // don't fulfill the secondObserverExpectation just yet, but test ignore increments
	[notificationCenter postNotificationForName:@"hello-all" ignoreSelf:NO]; // fulfill secondObserverExpectation now and end the test

	[self waitForExpectations:@[ darwinMessageSentExpectation, observerExpectation, secondObserverExpectation ] timeout:3 enforceOrder:YES];
}

@end
