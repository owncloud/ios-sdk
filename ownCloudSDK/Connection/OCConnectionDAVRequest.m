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
#import "OCConnectionDAVMultistatusResponse.h"

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

+ (instancetype)proppatchRequestWithURL:(NSURL *)url content:(NSArray <OCXMLNode *> *)contentNodes
{
	OCConnectionDAVRequest *request = [OCConnectionDAVRequest requestWithURL:url];

	request.method = OCConnectionRequestMethodPROPPATCH;
	request.xmlRequest = [OCXMLNode documentWithRootElement:
		[OCXMLNode elementWithName:@"D:propertyupdate" attributes:@[[OCXMLNode namespaceWithName:@"D" stringValue:@"DAV:"]] children:contentNodes]
	];
	[request setValue:@"application/xml" forHeaderField:@"Content-Type"];

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

- (NSArray <OCItem *> *)responseItemsForBasePath:(NSString *)basePath withErrors:(NSArray <NSError *> **)errors
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

				[parser addObjectCreationClasses:@[ [OCItem class], [NSError class] ]];

				if ([parser parse])
				{
					// OCLogDebug(@"Parsed objects: %@", parser.parsedObjects);

					@synchronized(self)
					{
						responseItems = _parseResultItems = parser.parsedObjects;
					}
				}

				if (parser.errors.count > 0)
				{
					OCLogDebug(@"DAV Error(s): %@", parser.errors);
					if (errors != NULL)
					{
						*errors = parser.errors;
					}
				}
			}
		}
	}

	return (responseItems);
}

- (NSDictionary <OCPath, OCConnectionDAVMultistatusResponse *> *)multistatusResponsesForBasePath:(NSString *)basePath
{
	NSMutableDictionary <OCPath, OCConnectionDAVMultistatusResponse *> *responsesByPath = nil;
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
			responsesByPath = _parsedResponsesByPath;
		}

		if (responsesByPath == nil)
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

				[parser addObjectCreationClasses:@[ [OCConnectionDAVMultistatusResponse class] ]];

				if ([parser parse])
				{
					// OCLogDebug(@"Parsed objects: %@", parser.parsedObjects);

					@synchronized(self)
					{
						responsesByPath = [NSMutableDictionary new];

						for (id parsedObject in parser.parsedObjects)
						{
							if ([parsedObject isKindOfClass:[OCConnectionDAVMultistatusResponse class]])
							{
								OCConnectionDAVMultistatusResponse *multiStatusResponse = (OCConnectionDAVMultistatusResponse *)parsedObject;

								if (multiStatusResponse.path != nil)
								{
									responsesByPath[multiStatusResponse.path] = multiStatusResponse;
								}
							}
						}

						_parsedResponsesByPath = responsesByPath;
					}
				}
			}
		}
	}

	return (responsesByPath);
}

@end
