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
	
	NSLog(@"%@", [xmlDocument XMLString]);

	NSLog(@"%@", [xmlDocument nodesForXPath:@"D:propfind/D:prop/size"]);

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

	NSLog(@"Parsed objects: %@", parser.parsedObjects);

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

- (void)testHashes
{
	NSData *data = [@"Hello" dataUsingEncoding:NSUTF8StringEncoding];

	NSLog(@"%@", [[data md5Hash] asHexStringWithSeparator:@" "]);
	XCTAssert([[[data md5Hash] asHexStringWithSeparator:@" "] isEqual:@"8B 1A 99 53 C4 61 12 96 A8 27 AB F8 C4 78 04 D7"]);

	NSLog(@"%@", [[data sha1Hash] asHexStringWithSeparator:@" "]);
	XCTAssert([[[data sha1Hash] asHexStringWithSeparator:@" "] isEqual:@"F7 FF 9E 8B 7B B2 E0 9B 70 93 5A 5D 78 5E 0C C5 D9 D0 AB F0"]);

	NSLog(@"%@", [[data sha256Hash] asHexStringWithSeparator:@" "]);
	XCTAssert([[[data sha256Hash] asHexStringWithSeparator:@" "] isEqual:@"18 5F 8D B3 22 71 FE 25 F5 61 A6 FC 93 8B 2E 26 43 06 EC 30 4E DA 51 80 07 D1 76 48 26 38 19 69"]);

}

@end
