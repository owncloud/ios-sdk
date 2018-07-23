//
//  OCConnectionDAVRequest.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 05.03.18.
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

#import "OCConnectionDAVRequest.h"
#import "OCItem.h"
#import "OCXMLParser.h"
#import "OCLogger.h"

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

- (NSArray <OCItem *> *)responseItemsForBasePath:(NSString *)basePath
{
	NSArray <OCItem *> *responseItems = nil;
	NSData *responseData = nil;

	if (self.downloadRequest)
	{
		responseData = [NSData dataWithContentsOfURL:self.downloadedFileURL];
	}
	else
	{
		responseData = self.responseBodyData;
	}

	if (responseData != nil)
	{
		@synchronized(self)
		{
			responseItems = _parseResultItems;
		}

		if (responseItems == nil)
		{
			OCXMLParser *parser;

			if ((parser = [[OCXMLParser alloc] initWithData:responseData]) != nil)
			{
				if (basePath != nil)
				{
					parser.options = [NSMutableDictionary dictionaryWithObjectsAndKeys:
						basePath, @"basePath",
					nil];
				}

				[parser addObjectCreationClasses:@[ [OCItem class] ]];

				if ([parser parse])
				{
					// OCLogDebug(@"Parsed objects: %@", parser.parsedObjects);

					@synchronized(self)
					{
						responseItems = _parseResultItems = parser.parsedObjects;
					}
				}
			}
		}
	}
	
	return (responseItems);
}

@end
