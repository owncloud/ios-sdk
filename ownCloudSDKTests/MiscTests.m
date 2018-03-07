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
		NSURL *computedURL = [NSURL URLWithUsername:NULL password:NULL afterNormalizingURLString:inputString protocolWasAppended:NULL];

		NSAssert([[computedURL absoluteString] isEqual:expectedURLString], @"Computed URL matches expectation: %@=%@", [computedURL absoluteString], expectedURLString);
	}
	
	// Test user + pass extraction
	{
		NSString *user=nil, *pass=nil;
		NSURL *normalizedURL;
		
		// Test username + password
		normalizedURL = [NSURL URLWithUsername:&user password:&pass afterNormalizingURLString:@"https://usr:pwd@demo.owncloud.org/" protocolWasAppended:NULL];
		
		NSAssert([[normalizedURL absoluteString] isEqual:@"https://demo.owncloud.org/"], @"Result URL has no username or password in it: %@", normalizedURL);

		NSAssert([user isEqual:@"usr"], @"Username has been extracted successfully: %@", user);
		NSAssert([pass isEqual:@"pwd"], @"Password has been extracted successfully: %@", pass);

		// Test username only
		normalizedURL = [NSURL URLWithUsername:&user password:&pass afterNormalizingURLString:@"https://usr@demo.owncloud.org/" protocolWasAppended:NULL];
		
		NSAssert([[normalizedURL absoluteString] isEqual:@"https://demo.owncloud.org/"], @"Result URL has no username or password in it: %@", normalizedURL);

		NSAssert([user isEqual:@"usr"], @"Username has been extracted successfully: %@", user);
		NSAssert((pass==nil), @"No password has been used in this URL: %@", pass);
	}
}

- (void)testXML
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

}

- (void)testXMLDecoding
{
	NSString *xmlString = @"<?xml version=\"1.0\"?><d:multistatus xmlns:d=\"DAV:\" xmlns:s=\"http://sabredav.org/ns\" xmlns:cal=\"urn:ietf:params:xml:ns:caldav\" xmlns:cs=\"http://calendarserver.org/ns/\" xmlns:card=\"urn:ietf:params:xml:ns:carddav\" xmlns:oc=\"http://owncloud.org/ns\"><d:response><d:href>/remote.php/dav/files/admin/</d:href><d:propstat><d:prop><d:resourcetype><d:collection/></d:resourcetype><d:getlastmodified>Tue, 06 Mar 2018 22:10:00 GMT</d:getlastmodified><d:getetag>&quot;5a9f11b8b440c&quot;</d:getetag><d:quota-available-bytes>-3</d:quota-available-bytes><d:quota-used-bytes>5809166</d:quota-used-bytes><oc:size>5809166</oc:size><oc:id>00000015ocnq90xhpk22</oc:id><oc:permissions>RDNVCK</oc:permissions></d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat><d:propstat><d:prop><d:getcontentlength/><d:getcontenttype/></d:prop><d:status>HTTP/1.1 404 Not Found</d:status></d:propstat></d:response><d:response><d:href>/remote.php/dav/files/admin/Documents/</d:href><d:propstat><d:prop><d:resourcetype><d:collection/></d:resourcetype><d:getlastmodified>Tue, 06 Mar 2018 22:10:00 GMT</d:getlastmodified><d:getetag>&quot;5a9f11b8b440c&quot;</d:getetag><d:quota-available-bytes>-3</d:quota-available-bytes><d:quota-used-bytes>36227</d:quota-used-bytes><oc:size>36227</oc:size><oc:id>00000021ocnq90xhpk22</oc:id><oc:permissions>RDNVCK</oc:permissions></d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat><d:propstat><d:prop><d:getcontentlength/><d:getcontenttype/></d:prop><d:status>HTTP/1.1 404 Not Found</d:status></d:propstat></d:response><d:response><d:href>/remote.php/dav/files/admin/Photos/</d:href><d:propstat><d:prop><d:resourcetype><d:collection/></d:resourcetype><d:getlastmodified>Tue, 06 Mar 2018 22:09:59 GMT</d:getlastmodified><d:getetag>&quot;5a9f11b7bbbc5&quot;</d:getetag><d:quota-available-bytes>-3</d:quota-available-bytes><d:quota-used-bytes>678556</d:quota-used-bytes><oc:size>678556</oc:size><oc:id>00000016ocnq90xhpk22</oc:id><oc:permissions>RDNVCK</oc:permissions></d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat><d:propstat><d:prop><d:getcontentlength/><d:getcontenttype/></d:prop><d:status>HTTP/1.1 404 Not Found</d:status></d:propstat></d:response><d:response><d:href>/remote.php/dav/files/admin/ownCloud%20Manual.pdf</d:href><d:propstat><d:prop><d:resourcetype/><d:getlastmodified>Tue, 06 Mar 2018 22:10:00 GMT</d:getlastmodified><d:getcontentlength>5094383</d:getcontentlength><d:getcontenttype>application/pdf</d:getcontenttype><d:getetag>&quot;c43d4f3af69fb2d8ad1e873dadf9d973&quot;</d:getetag><oc:size>5094383</oc:size><oc:id>00000020ocnq90xhpk22</oc:id><oc:permissions>RDNVW</oc:permissions></d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat><d:propstat><d:prop><d:quota-available-bytes/><d:quota-used-bytes/></d:prop><d:status>HTTP/1.1 404 Not Found</d:status></d:propstat></d:response></d:multistatus>";
	
	OCXMLParser *parser = [[OCXMLParser alloc] initWithParser:[[NSXMLParser alloc] initWithData:[xmlString dataUsingEncoding:NSUTF8StringEncoding]]];
	
	[parser parse];

}

@end
