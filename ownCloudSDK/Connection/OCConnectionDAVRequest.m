//
//  OCConnectionDAVRequest.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 05.03.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import "OCConnectionDAVRequest.h"
#import "OCItem.h"

@implementation OCConnectionDAVRequest

@synthesize xmlRequest = _xmlRequest;

+ (instancetype)propfindRequestWithURL:(NSURL *)url depth:(NSUInteger)depth
{
	OCConnectionDAVRequest *request = [OCConnectionDAVRequest requestWithURL:url];
	
	request.method = OCConnectionRequestMethodPROPFIND;
	request.xmlRequest = [OCXMLNode documentWithRootElement:
		[OCXMLNode elementWithName:@"D:propfind" attributes:@[[OCXMLNode namespaceWithName:@"D" stringValue:@"DAV:"]] children:@[
			[OCXMLNode elementWithName:@"D:prop"],
		]]
	];
	[request setValue:@"application/xml" forHeaderField:@"Content-Type"];
	[request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)depth] forHeaderField:@"Depth"];

	return (request);
}

- (OCXMLNode *)xmlRequestPropAttribute
{
	return ([[_xmlRequest nodesForXPath:@"D:propfind/D:prop"] firstObject]);
}

- (NSData *)bodyData
{
	if ((_bodyData == nil) && (_xmlRequest != nil))
	{
		_bodyData = [_xmlRequest XMLUTF8Data];
	}
	
	return (_bodyData);
}

- (NSArray <OCItem *> *)responseItems
{
	NSArray <OCItem *> *responseItems = nil;
	
	if (self.responseBodyData != nil)
	{
		NSXMLParser *xmlParser;
		
		if ((xmlParser = [[NSXMLParser alloc] initWithData:self.responseBodyData]) != nil)
		{
			xmlParser.delegate = self;
			
			if ([xmlParser parse])
			{
				// Successful parse
				responseItems = _parseResultItems;
			}
			else
			{
				// Error parsing
			}
		}
	}
	
	return (responseItems);
}

#pragma mark - XML parsing
- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(nullable NSString *)namespaceURI qualifiedName:(nullable NSString *)qName attributes:(NSDictionary<NSString *, NSString *> *)attributeDict
{
	NSLog(@"Start %@ %@ %@ %@", elementName, namespaceURI, qName, attributeDict);
	
	if ([elementName isEqualToString:@"d:response"])
	{
		if (_parseResultItems==nil) { _parseResultItems = [NSMutableArray array]; }
	
		_parseItem = [OCItem new];
	}
	
	_parseCurrentElement = elementName;
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(nullable NSString *)namespaceURI qualifiedName:(nullable NSString *)qName
{
	if ([elementName isEqualToString:@"d:response"])
	{
		[_parseResultItems addObject:_parseItem];
		_parseItem = nil;
	}

	NSLog(@"End %@ %@ %@", elementName, namespaceURI, qName);
}

- (void)parserDidEndDocument:(NSXMLParser *)parser
{
	NSLog(@"End document");
}

@end
