//
//  OCItem+OCXMLObjectCreation.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 07.03.18.
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

#import "OCXMLParserNode.h"
#import "OCItem+OCXMLObjectCreation.h"
#import "OCHTTPStatus.h"

@implementation OCItem (OCXMLObjectCreation)

+ (OCXMLParserNodeKeyValueEnumeratorDictionary)_sharedKeyValueEnumeratorDict
{
	static OCXMLParserNodeKeyValueEnumeratorDictionary sharedKeyValueEnumeratorDict;
	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		sharedKeyValueEnumeratorDict = @{
			@"d:getcontentlength" : [^(OCItem *item, NSString *key, id value) {
				if ([value isKindOfClass:[NSString class]])
				{
					item.size = ((NSString *)value).integerValue;
				}
			} copy],

			@"oc:size" : [^(OCItem *item, NSString *key, id value) {
				if ([value isKindOfClass:[NSString class]])
				{
					item.size = ((NSString *)value).integerValue;
				}
			} copy],

			@"d:getlastmodified" : [^(OCItem *item, NSString *key, id value) {
				if ([value isKindOfClass:[NSDate class]])
				{
					item.lastModified = value;
				}
			} copy],

			@"d:creationdate" : [^(OCItem *item, NSString *key, id value) {
				if ([value isKindOfClass:[NSDate class]])
				{
					item.creationDate = value;
				}
			} copy],

			@"d:getcontenttype" : [^(OCItem *item, NSString *key, id value) {
				if ([value isKindOfClass:[NSString class]])
				{
					item.mimeType = value;
				}
			} copy],

			@"d:getetag" : [^(OCItem *item, NSString *key, id value) {
				if ([value isKindOfClass:[NSString class]])
				{
					item.eTag = value;
				}
			} copy],

			@"oc:id" : [^(OCItem *item, NSString *key, id value) {
				if ([value isKindOfClass:[NSString class]])
				{
					item.fileID = value;
				}
			} copy],

			@"oc:permissions" : [^(OCItem *item, NSString *key, id value) {
				if ([value isKindOfClass:[NSString class]])
				{
					const char *utf8String;
					NSUInteger stringLen = ((NSString *)value).length;

					OCItemPermissions permissions = 0;

					if ((utf8String = [(NSString *)value UTF8String]) != NULL)
					{
						for (NSUInteger i=0; i<stringLen; i++)
						{
							switch (utf8String[i])
							{
								case 'S':
									permissions |= OCItemPermissionShared;
								break;

								case 'R':
									permissions |= OCItemPermissionShareable;
								break;

								case 'M':
									permissions |= OCItemPermissionMounted;
								break;

								case 'W':
									permissions |= OCItemPermissionWritable;
								break;

								case 'C':
									permissions |= OCItemPermissionCreateFile;
								break;

								case 'K':
									permissions |= OCItemPermissionCreateFolder;
								break;

								case 'D':
									permissions |= OCItemPermissionDelete;
								break;

								case 'N':
									permissions |= OCItemPermissionRename;
								break;

								case 'V':
									permissions |= OCItemPermissionMove;
								break;
							}
						}
					}

					item.permissions = permissions;
				}
			} copy]
		};
	});

	return (sharedKeyValueEnumeratorDict);
}

+ (NSString *)xmlElementNameForObjectCreation
{
	return (@"d:response");
}

+ (instancetype)instanceFromNode:(OCXMLParserNode *)responseNode xmlParser:(OCXMLParser *)xmlParser
{
	OCItem *item = nil;
	NSString *itemPath;

	// Path of item
	if ((itemPath = responseNode.keyValues[@"d:href"]) != nil)
	{
		// d:href is URL encoded, do URL-decode itemPath
		itemPath = [itemPath stringByRemovingPercentEncoding];

		if ((item = [OCItem new]) != nil)
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

			item.path = itemPath;

			// Extract Properties
			[responseNode enumerateChildNodesWithName:@"d:propstat" usingBlock:^(OCXMLParserNode *propstatNode) {
				OCHTTPStatus *httpStatus;

				if ((httpStatus = propstatNode.keyValues[@"d:status"]) != nil)
				{
					if (httpStatus.isSuccess) {
						[propstatNode enumerateChildNodesWithName:@"d:prop" usingBlock:^(OCXMLParserNode *propNode) {
							// Collection?
							__block BOOL isCollection = NO;

							[propNode enumerateChildNodesWithName:@"d:resourcetype" usingBlock:^(OCXMLParserNode *resourcetypeNode) {
								[resourcetypeNode enumerateChildNodesWithName:@"d:collection" usingBlock:^(OCXMLParserNode *collectionNode) {
									isCollection = YES;
								}];
							}];

							item.type = isCollection ? OCItemTypeCollection : OCItemTypeFile;

							// Parse remaining key-values
							[propNode enumerateKeyValuesForTarget:item withBlockForKeys:[[self class] _sharedKeyValueEnumeratorDict]];
						}];
					}
				}
			}];
		}
	}

	return (item);
}

@end

/*
Example response:

<?xml version="1.0"?>
<d:multistatus xmlns:d="DAV:" xmlns:s="http://sabredav.org/ns" xmlns:cal="urn:ietf:params:xml:ns:caldav" xmlns:cs="http://calendarserver.org/ns/" xmlns:card="urn:ietf:params:xml:ns:carddav" xmlns:oc="http://owncloud.org/ns">
<d:response>
    <d:href>/remote.php/dav/files/admin/</d:href>
    <d:propstat>
        <d:prop>
            <d:resourcetype>
                <d:collection/>
            </d:resourcetype>
            <d:getlastmodified>Fri, 23 Feb 2018 11:52:05 GMT</d:getlastmodified>
            <d:getetag>"5a9000658388d"</d:getetag>
            <d:quota-available-bytes>-3</d:quota-available-bytes>
            <d:quota-used-bytes>5812174</d:quota-used-bytes>
            <oc:size>5812174</oc:size>
            <oc:id>00000009ocre5kavbk8j</oc:id>
            <oc:permissions>RDNVCK</oc:permissions>
        </d:prop>
        <d:status>HTTP/1.1 200 OK</d:status>
    </d:propstat>
    <d:propstat>
        <d:prop>
            <d:creationdate/>
            <d:getcontentlength/>
            <d:displayname/>
            <d:getcontenttype/>
        </d:prop>
        <d:status>HTTP/1.1 404 Not Found</d:status>
    </d:propstat>
</d:response>
<d:response>
    <d:href>/remote.php/dav/files/admin/Documents/</d:href>
    <d:propstat>
        <d:prop>
            <d:resourcetype>
                <d:collection/>
            </d:resourcetype>
            <d:getlastmodified>Fri, 23 Feb 2018 11:52:05 GMT</d:getlastmodified>
            <d:getetag>"5a900065214e9"</d:getetag>
            <d:quota-available-bytes>-3</d:quota-available-bytes>
            <d:quota-used-bytes>36227</d:quota-used-bytes>
            <oc:size>36227</oc:size>
            <oc:id>00000011ocre5kavbk8j</oc:id>
            <oc:permissions>RDNVCK</oc:permissions>
        </d:prop>
        <d:status>HTTP/1.1 200 OK</d:status>
    </d:propstat>
    <d:propstat>
        <d:prop>
            <d:creationdate/>
            <d:getcontentlength/>
            <d:displayname/>
            <d:getcontenttype/>
        </d:prop>
        <d:status>HTTP/1.1 404 Not Found</d:status>
    </d:propstat>
</d:response>
<d:response>
    <d:href>/remote.php/dav/files/admin/Photos/</d:href>
    <d:propstat>
        <d:prop>
            <d:resourcetype>
                <d:collection/>
            </d:resourcetype>
            <d:getlastmodified>Fri, 23 Feb 2018 11:52:05 GMT</d:getlastmodified>
            <d:getetag>"5a9000658388d"</d:getetag>
            <d:quota-available-bytes>-3</d:quota-available-bytes>
            <d:quota-used-bytes>678556</d:quota-used-bytes>
            <oc:size>678556</oc:size>
            <oc:id>00000013ocre5kavbk8j</oc:id>
            <oc:permissions>RDNVCK</oc:permissions>
        </d:prop>
        <d:status>HTTP/1.1 200 OK</d:status>
    </d:propstat>
    <d:propstat>
        <d:prop>
            <d:creationdate/>
            <d:getcontentlength/>
            <d:displayname/>
            <d:getcontenttype/>
        </d:prop>
        <d:status>HTTP/1.1 404 Not Found</d:status>
    </d:propstat>
</d:response>
<d:response>
    <d:href>/remote.php/dav/files/admin/ownCloud%20Manual.pdf</d:href>
    <d:propstat>
        <d:prop>
            <d:resourcetype/>
            <d:getlastmodified>Fri, 23 Feb 2018 11:52:05 GMT</d:getlastmodified>
            <d:getcontentlength>5097391</d:getcontentlength>
            <d:getcontenttype>application/pdf</d:getcontenttype>
            <d:getetag>"6a6b6cd32839a296b941dade1e202490"</d:getetag>
            <oc:size>5097391</oc:size>
            <oc:id>00000010ocre5kavbk8j</oc:id>
            <oc:permissions>RDNVW</oc:permissions>
        </d:prop>
        <d:status>HTTP/1.1 200 OK</d:status>
    </d:propstat>
    <d:propstat>
        <d:prop>
            <d:creationdate/>
            <d:displayname/>
            <d:quota-available-bytes/>
            <d:quota-used-bytes/>
        </d:prop>
        <d:status>HTTP/1.1 404 Not Found</d:status>
    </d:propstat>
</d:response>
</d:multistatus>
*/
