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
#import "OCChecksum.h"

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
					item.lastUsed = value;
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
			} copy],

			@"oc:favorite" : [^(OCItem *item, NSString *key, id value) {
				if ([value isKindOfClass:[NSString class]])
				{
					item.isFavorite = (((NSString *)value).integerValue) ? (__bridge id)kCFBooleanTrue : (__bridge id)kCFBooleanFalse;
				}
			} copy],

			@"oc:share-type" : [^(OCItem *item, NSString *key, id value) {
				if ([value isKindOfClass:[NSString class]])
				{
					if (((NSString *)value).length > 0)
					{
						switch (((NSString *)value).integerValue)
						{
							case OCShareTypeUserShare:
								item.shareTypesMask |= OCShareTypesMaskUserShare;
							break;

							case OCShareTypeGroupShare:
								item.shareTypesMask |= OCShareTypesMaskGroupShare;
							break;

							case OCShareTypeLink:
								item.shareTypesMask |= OCShareTypesMaskLink;
							break;

							case OCShareTypeGuest:
								item.shareTypesMask |= OCShareTypesMaskGuest;
							break;

							case OCShareTypeRemote:
								item.shareTypesMask |= OCShareTypesMaskRemote;
							break;
						}
					}
				}
			} copy],

			@"oc:checksum" : [^(OCItem *item, NSString *key, id value) {
				if ([value isKindOfClass:[NSString class]])
				{
					NSArray<NSString*> *checksumStrings = [((NSString *)value) componentsSeparatedByString:@" "];

					if (checksumStrings.count > 0)
					{
						NSMutableArray<OCChecksum *> *checksums = (item.checksums!=nil) ? [[NSMutableArray alloc] initWithArray:item.checksums] : [[NSMutableArray alloc] initWithCapacity:checksumStrings.count];

						for (NSString *checksumString in checksumStrings)
						{
							OCChecksum *checksum;

							if ((checksum = [[OCChecksum alloc] initFromHeaderString:checksumString]) != nil)
							{
								[checksums addObject:checksum];
							}
						}

						item.checksums = checksums;
					}
				}
			} copy],

			@"oc:privatelink" : [^(OCItem *item, NSString *key, id value) {
				if ([value isKindOfClass:[NSString class]])
				{
					item.privateLink = [[NSURL alloc] initWithString:value];
				}
			} copy],

			@"d:quota-available-bytes" : [^(OCItem *item, NSString *key, id value) {
				if ([value isKindOfClass:[NSString class]])
				{
					item.quotaBytesRemaining = [NSNumber numberWithLongLong:((NSString *)value).longLongValue];
				}
			} copy],

			@"d:quota-used-bytes" : [^(OCItem *item, NSString *key, id value) {
				if ([value isKindOfClass:[NSString class]])
				{
					item.quotaBytesUsed = [NSNumber numberWithLongLong:((NSString *)value).longLongValue];
				}
			} copy],
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
	NSMutableDictionary<NSString *, OCUser *> *usersByUserID = xmlParser.options[@"usersByUserID"];

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
							NSString *ownerDisplayName = nil, *ownerID = nil;
							OCUser *owner = nil;

							[propNode enumerateChildNodesWithName:@"d:resourcetype" usingBlock:^(OCXMLParserNode *resourcetypeNode) {
								[resourcetypeNode enumerateChildNodesWithName:@"d:collection" usingBlock:^(OCXMLParserNode *collectionNode) {
									isCollection = YES;
								}];
							}];

							item.type = isCollection ? OCItemTypeCollection : OCItemTypeFile;

							[propNode enumerateChildNodesWithName:@"oc:share-types" usingBlock:^(OCXMLParserNode *shareTypesNode) {
								[shareTypesNode enumerateKeyValuesForTarget:item withBlockForKeys:[[self class] _sharedKeyValueEnumeratorDict]];
							}];

							[propNode enumerateChildNodesWithName:@"oc:checksums" usingBlock:^(OCXMLParserNode *shareTypesNode) {
								[shareTypesNode enumerateKeyValuesForTarget:item withBlockForKeys:[[self class] _sharedKeyValueEnumeratorDict]];
							}];

							// Share OCUser instances for owner
							ownerDisplayName = propNode.keyValues[@"oc:owner-display-name"];
							ownerID = propNode.keyValues[@"oc:owner-id"];

							if ((ownerID != nil) && (ownerDisplayName != nil))
							{
								if (usersByUserID != nil)
								{
									@synchronized(usersByUserID)
									{
										if ((owner = usersByUserID[ownerID]) != nil)
										{
											if (![owner.displayName isEqualToString:ownerDisplayName])
											{
												owner = nil;
											}
										}
										else
										{
											owner = [OCUser userWithUserName:ownerID displayName:ownerDisplayName];

											usersByUserID[ownerID] = owner;
										}
									}
								}

								if (owner == nil)
								{
									owner = [OCUser userWithUserName:ownerID displayName:ownerDisplayName];
								}
							}
							else
							{
								if (ownerID != nil)
								{
									owner = [OCUser userWithUserName:ownerID displayName:ownerDisplayName];
								}
							}
							item.owner = owner;

							// Parse remaining key-values
							[propNode enumerateKeyValuesForTarget:item withBlockForKeys:[[self class] _sharedKeyValueEnumeratorDict]];
						}];
					}
				}
			}];

			// Clean up quota
			if (item.quotaBytesRemaining.integerValue < 0)
			{
				// A negative number for quotaBytesUsed indicates that no quota is in effect
				item.quotaBytesRemaining = nil;
			}
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
            <oc:checksums>
            	<oc:checksum>SHA1:b6e74385099c208fa310ee7d0168e270e40de4c9 MD5:2dc1a2fc2aa833b00b92dc4388a86139 ADLER32:0edff753</oc:checksum>
	    </oc:checksums>
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

// Accepted cloud shares

# RESPONSE --------------------------------------------------------
Method:     GET
URL:        https://demo.owncloud.com/ocs/v1.php/apps/files_sharing/api/v1/remote_shares
Request-ID: 19DA2961-8506-4A44-9B12-FFA5D1CF0A98
Error:      -
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
200 NO ERROR
Content-Type: text/xml; charset=UTF-8
Pragma: no-cache
content-security-policy: default-src 'self'; script-src 'self' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; frame-src *; img-src * data: blob:; font-src 'self' data:; media-src *; connect-src *
Server: Apache
x-download-options: noopen
Content-Encoding: gzip
x-xss-protection: 1; mode=block
x-permitted-cross-domain-policies: none
Expires: Thu, 19 Nov 1981 08:52:00 GMT
Cache-Control: no-store, no-cache, must-revalidate
Date: Thu, 07 Mar 2019 15:32:15 GMT
x-robots-tag: none
Content-Length: 333
x-content-type-options: nosniff
Vary: Accept-Encoding
x-frame-options: SAMEORIGIN

<?xml version="1.0"?>
<ocs>
 <meta>
  <status>ok</status>
  <statuscode>100</statuscode>
  <message/>
 </meta>
 <data>
  <element>
   <id>8</id>
   <remote>https://demo.owncloud.org</remote>
   <remote_id>7</remote_id>
   <share_token>owIxIMahh76sG4D</share_token>
   <name>/Documents</name>
   <owner>admin</owner>
   <user>test</user>
   <mountpoint>/Documents (2)</mountpoint>
   <accepted>1</accepted>
   <mimetype>httpd/unix-directory</mimetype>
   <mtime>1551970943</mtime>
   <permissions>9</permissions>
   <type>dir</type>
   <file_id>148</file_id>
  </element>
 </data>
</ocs>

*/
