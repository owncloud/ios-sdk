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

#import "OCHTTPDAVRequest.h"
#import "OCItem.h"
#import "OCXMLParser.h"
#import "OCLogger.h"
#import "OCHTTPDAVMultistatusResponse.h"

@implementation OCHTTPDAVRequest

+ (instancetype)propfindRequestWithURL:(NSURL *)url depth:(OCPropfindDepth)depth
{
	OCHTTPDAVRequest *request = [OCHTTPDAVRequest requestWithURL:url];
	
	request.method = OCHTTPMethodPROPFIND;
	request.xmlRequest = [OCXMLNode documentWithRootElement:
		[OCXMLNode elementWithName:@"D:propfind" attributes:@[
			[OCXMLNode namespaceWithName:@"D" stringValue:@"DAV:"],
			[OCXMLNode namespaceWithName:@"oc" stringValue:@"http://owncloud.org/ns"]
		] children:@[
			[OCXMLNode elementWithName:@"D:prop"]
		]]
	];
	[request setValue:@"application/xml" forHeaderField:OCHTTPHeaderFieldNameContentType];
	[request setValue:((depth == OCPropfindDepthInfinity) ? @"infinity" : [NSString stringWithFormat:@"%lu", (unsigned long)depth]) forHeaderField:OCHTTPHeaderFieldNameDepth];

	return (request);
}

+ (instancetype)proppatchRequestWithURL:(NSURL *)url content:(NSArray <OCXMLNode *> *)contentNodes
{
	OCHTTPDAVRequest *request = [OCHTTPDAVRequest requestWithURL:url];

	request.method = OCHTTPMethodPROPPATCH;
	request.xmlRequest = [OCXMLNode documentWithRootElement:
		[OCXMLNode elementWithName:@"D:propertyupdate" attributes:@[
			[OCXMLNode namespaceWithName:@"D" stringValue:@"DAV:"],
			[OCXMLNode namespaceWithName:@"oc" stringValue:@"http://owncloud.org/ns"]
		] children:contentNodes]
	];
	[request setValue:@"application/xml" forHeaderField:OCHTTPHeaderFieldNameContentType];

	return (request);
}

+ (instancetype)reportRequestWithURL:(NSURL *)url rootElementName:(NSString *)rootElementName content:(NSArray <OCXMLNode *> *)contentNodes
{
	OCHTTPDAVRequest *request = [OCHTTPDAVRequest requestWithURL:url];

	request.method = OCHTTPMethodREPORT;
	request.xmlRequest = [OCXMLNode documentWithRootElement:
		[OCXMLNode elementWithName:rootElementName attributes:@[
			[OCXMLNode namespaceWithName:@"D" stringValue:@"DAV:"],
			[OCXMLNode namespaceWithName:@"oc" stringValue:@"http://owncloud.org/ns"]
		] children:contentNodes]
	];
	[request setValue:@"application/xml" forHeaderField:OCHTTPHeaderFieldNameContentType];

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

- (NSArray <OCItem *> *)responseItemsForBasePath:(NSString *)basePath reuseUsersByID:(NSMutableDictionary<NSString *,OCUser *> *)usersByUserID withErrors:(NSArray <NSError *> **)errors
{
	NSArray <OCItem *> *responseItems = nil;
	NSData *responseData = self.httpResponse.bodyData;

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
						basePath, 	@"basePath",
						usersByUserID, 	@"usersByUserID",
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

- (NSDictionary <OCPath, OCHTTPDAVMultistatusResponse *> *)multistatusResponsesForBasePath:(NSString *)basePath
{
	NSMutableDictionary <OCPath, OCHTTPDAVMultistatusResponse *> *responsesByPath = nil;
	NSData *responseData = self.httpResponse.bodyData;

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

				[parser addObjectCreationClasses:@[ [OCHTTPDAVMultistatusResponse class] ]];

				if ([parser parse])
				{
					// OCLogDebug(@"Parsed objects: %@", parser.parsedObjects);

					@synchronized(self)
					{
						responsesByPath = [NSMutableDictionary new];

						for (id parsedObject in parser.parsedObjects)
						{
							if ([parsedObject isKindOfClass:[OCHTTPDAVMultistatusResponse class]])
							{
								OCHTTPDAVMultistatusResponse *multiStatusResponse = (OCHTTPDAVMultistatusResponse *)parsedObject;

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
