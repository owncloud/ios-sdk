//
//  OCHTTPDAVMultistatusResponse.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 13.11.18.
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

#import "OCHTTPDAVMultistatusResponse.h"
#import "OCXMLParserNode.h"

@implementation OCHTTPDAVMultistatusResponse

#pragma mark - OCXMLObjectCreation conformance
+ (NSString *)xmlElementNameForObjectCreation
{
	return (@"d:response");
}

+ (instancetype)instanceFromNode:(OCXMLParserNode *)responseNode xmlParser:(OCXMLParser *)xmlParser
{
	OCHTTPDAVMultistatusResponse *response = nil;
	NSMutableDictionary <OCHTTPStatus *, NSMutableDictionary <NSString *, id> *> *valueForPropByStatusCode = nil;

	OCPath itemPath;

	// Path of item
	if ((itemPath = responseNode.keyValues[@"d:href"]) != nil)
	{
		// d:href is URL encoded, do URL-decode itemPath
		itemPath = [itemPath stringByRemovingPercentEncoding];

		if ((valueForPropByStatusCode = [NSMutableDictionary new]) != nil)
		{
			OCPath basePath;

			// Remove base path (if applicable)
			if ((basePath = xmlParser.options[@"basePath"]) != nil)
			{
				if ([itemPath hasPrefix:basePath])
				{
					itemPath = [itemPath substringFromIndex:basePath.length];
				}
			}

			// Extract Properties
			[responseNode enumerateChildNodesWithName:@"d:propstat" usingBlock:^(OCXMLParserNode *propstatNode) {
				OCHTTPStatus *httpStatus;

				if ((httpStatus = propstatNode.keyValues[@"d:status"]) != nil)
				{
					NSMutableDictionary <NSString *, id> *valueForProp;

					if ((valueForProp = valueForPropByStatusCode[httpStatus]) == nil)
					{
						valueForPropByStatusCode[httpStatus] = valueForProp = [NSMutableDictionary new];
					}

					[propstatNode enumerateChildNodesWithName:@"d:prop" usingBlock:^(OCXMLParserNode *propNode) {
						if (propNode.keyValues != nil)
						{
							[valueForProp addEntriesFromDictionary:propNode.keyValues];
						}

						[propNode.children enumerateObjectsUsingBlock:^(OCXMLParserNode * _Nonnull propChild, NSUInteger idx, BOOL * _Nonnull stop) {
							if ((propChild.name != nil) && (valueForProp[propChild.name] == nil))
							{
								valueForProp[propChild.name] = [NSNull null];
							}
						}];
					}];
				}
			}];

			// Compile response item
			response = [[OCHTTPDAVMultistatusResponse alloc] initResponseForPath:itemPath withValuesForPropByStatusCode:valueForPropByStatusCode];
		}
	}

	return (response);
}

#pragma mark - Init & Dealloc
- (instancetype)initResponseForPath:(OCPath)path withValuesForPropByStatusCode:(NSDictionary <OCHTTPStatus *, NSDictionary <NSString *, id> *> *)valueForPropByStatusCode
{
	if ((self = [super init]) != nil)
	{
		_path = path;
		_valueForPropByStatusCode = valueForPropByStatusCode;
	}

	return(self);
}

- (NSString *)description
{
	return ([NSString stringWithFormat:@"<%@: %p, path: %@, valueForPropByStatusCode: %@>", NSStringFromClass(self.class), self, _path, _valueForPropByStatusCode]);
}

- (OCHTTPStatus *)statusForProperty:(NSString *)propertyName
{
	if (propertyName != nil)
	{
		for (OCHTTPStatus *statusCode in _valueForPropByStatusCode)
		{
			if (_valueForPropByStatusCode[statusCode][propertyName] != nil)
			{
				return (statusCode);
			}
		}
	}

	return (nil);
}

@end

// Examples

/*
<?xml version="1.0"?>
<d:multistatus xmlns:d="DAV:" xmlns:s="http://sabredav.org/ns" xmlns:oc="http://owncloud.org/ns">
<d:response>
    <d:href>/remote.php/dav/files/admin/ownCloud%20Manual.pdf</d:href>
    <d:propstat>
        <d:prop>
            <d:getlastmodified/>
        </d:prop>
        <d:status>HTTP/1.1 403 Forbidden</d:status>
    </d:propstat>
    <d:propstat>
        <d:prop>
            <oc:favorite/>
        </d:prop>
        <d:status>HTTP/1.1 424 Failed Dependency</d:status>
    </d:propstat>
</d:response>
</d:multistatus>
*/
