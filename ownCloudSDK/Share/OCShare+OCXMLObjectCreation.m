//
//  OCShare+OCXMLObjectCreation.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 01.03.19.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2019, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCShare+OCXMLObjectCreation.h"
#import "OCXMLParserNode.h"
#import "NSDate+OCDateParser.h"

@implementation OCShare (OCXMLObjectCreation)

+ (NSString *)xmlElementNameForObjectCreation
{
	return (@"element");
}

+ (instancetype)instanceFromNode:(OCXMLParserNode *)shareNode xmlParser:(OCXMLParser *)xmlParser
{
	OCShare *share = nil;
	OCShareID shareID;

	if ((shareID = shareNode.keyValues[@"id"]) != nil)
	{
		if ((share = [OCShare new]) != nil)
		{
			// Identifier
			share.identifier = shareID;

			// Type
			NSString *shareType;

			if ((shareType = shareNode.keyValues[@"share_type"]) != nil)
			{
				share.type = shareType.integerValue;
			}

			// Item path
			share.itemPath = shareNode.keyValues[@"path"];

			// Item type
			NSString *itemType;

			if ((itemType = shareNode.keyValues[@"item_type"]) != nil)
			{
				if ([itemType isEqual:@"file"])
				{
					share.itemType = OCItemTypeFile;
				}
				else if ([itemType isEqual:@"folder"])
				{
					share.itemType = OCItemTypeCollection;
				}
			}

			// Item owner
			NSString *userNameFileOwner=nil, *displayNameFileOwner=nil;

			userNameFileOwner = shareNode.keyValues[@"uid_file_owner"];
			displayNameFileOwner = shareNode.keyValues[@"displayname_file_owner"];

			if ((userNameFileOwner != nil) || (displayNameFileOwner != nil))
			{
				share.itemOwner = [OCUser new];
				share.itemOwner.userName = userNameFileOwner;
				share.itemOwner.displayName = displayNameFileOwner;
			}

			// Item MIME Type
			share.itemMIMEType = shareNode.keyValues[@"mimetype"];

			// Share name
			share.name = shareNode.keyValues[@"name"];

			// Share token
			share.token = shareNode.keyValues[@"token"];

			// Share URL
			NSString *shareURLString;

			if ((shareURLString = shareNode.keyValues[@"url"]) != nil)
			{
				share.url = [NSURL URLWithString:shareURLString];
			}

			// Creation date
			NSString *createDateUNIXTimestamp;

			if ((createDateUNIXTimestamp = shareNode.keyValues[@"stime"]) != nil)
			{
				share.creationDate = [[NSDate alloc] initWithTimeIntervalSince1970:(NSTimeInterval)createDateUNIXTimestamp.integerValue];
			}

			// Expiration date
			NSString *expirationDateString;

			if ((expirationDateString = shareNode.keyValues[@"expiration"]) != nil)
			{
				share.expirationDate = [NSDate dateParsedFromCompactUTCString:expirationDateString error:NULL];
			}

			// Owner
			NSString *userNameShareOwner=nil, *displayNameShareOwner=nil;

			userNameShareOwner = shareNode.keyValues[@"uid_owner"];
			displayNameShareOwner = shareNode.keyValues[@"displayname_owner"];

			if ((userNameShareOwner != nil) || (displayNameShareOwner != nil))
			{
				share.owner = [OCUser new];
				share.owner.userName = userNameShareOwner;
				share.owner.displayName = displayNameShareOwner;
			}

			// Recipient
			if (shareType != nil)
			{
				NSString *recipientName, *recipientDisplayName;

				recipientName = shareNode.keyValues[@"share_with"];
				recipientDisplayName = shareNode.keyValues[@"share_with_displayname"];

				if ((recipientName!=nil) || (recipientDisplayName!=nil))
				{
					switch (share.type)
					{
						case OCShareTypeUserShare:
							share.recipient = [OCRecipient recipientWithUser:[OCUser userWithUserName:recipientName displayName:recipientDisplayName]];
						break;

						case OCShareTypeGroupShare:
							share.recipient = [OCRecipient recipientWithGroup:[OCGroup groupWithIdentifier:recipientName name:recipientDisplayName]];
						break;

						default:
						break;
					}
				}
			}

			// Permissions
			NSString *permissions;

			if ((permissions = shareNode.keyValues[@"permissions"]) != nil)
			{
				share.permissions = permissions.integerValue;
			}
		}
	}

	return (share);
}

@end

/*

// User with two shares:

# RESPONSE --------------------------------------------------------
Method:     GET
URL:        https://demo.owncloud.com/ocs/v1.php/apps/files_sharing/api/v1/shares
Request-ID: 85A55099-E6CE-4200-A81F-B972DC1171B7
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
Date: Fri, 01 Mar 2019 12:32:12 GMT
x-robots-tag: none
Content-Length: 509
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
   <id>27</id>
   <share_type>0</share_type>
   <uid_owner>demo</uid_owner>
   <displayname_owner>demo</displayname_owner>
   <permissions>19</permissions>
   <stime>1551430723</stime>
   <parent/>
   <expiration/>
   <token/>
   <uid_file_owner>demo</uid_file_owner>
   <displayname_file_owner>demo</displayname_file_owner>
   <path>/SharedImage.jpg</path>
   <item_type>file</item_type>
   <mimetype>image/jpeg</mimetype>
   <storage_id>home::demo</storage_id>
   <storage>3</storage>
   <item_source>246</item_source>
   <file_source>246</file_source>
   <file_parent>12</file_parent>
   <file_target>/SharedImage.jpg</file_target>
   <share_with>admin</share_with>
   <share_with_displayname>admin</share_with_displayname>
   <share_with_additional_info/>
   <mail_send>0</mail_send>
  </element>
  <element>
   <id>26</id>
   <share_type>3</share_type>
   <uid_owner>demo</uid_owner>
   <displayname_owner>demo</displayname_owner>
   <permissions>1</permissions>
   <stime>1551430709</stime>
   <parent/>
   <expiration/>
   <token>JSzGhtzHZZRG1Ns</token>
   <uid_file_owner>demo</uid_file_owner>
   <displayname_file_owner>demo</displayname_file_owner>
   <path>/SharedImage.jpg</path>
   <item_type>file</item_type>
   <mimetype>image/jpeg</mimetype>
   <storage_id>home::demo</storage_id>
   <storage>3</storage>
   <item_source>246</item_source>
   <file_source>246</file_source>
   <file_parent>12</file_parent>
   <file_target>/SharedImage.jpg</file_target>
   <share_with/>
   <share_with_displayname/>
   <name>Public link</name>
   <url>https://demo.owncloud.com/s/JSzGhtzHZZRG1Ns</url>
   <mail_send>0</mail_send>
  </element>
 </data>
</ocs>

----------------------------------------------------------------- [… PipelineID:ephermal, Instance:0x7fb964d16830, HTTP, Response, GET, RequestID:85A55099-E6CE-4200-A81F-B972DC1171B7, URLSessionTaskID:4]

// Share recipient with public reshare (one without, one with password and expiration date)

# RESPONSE --------------------------------------------------------
Method:     GET
URL:        https://demo.owncloud.com/ocs/v1.php/apps/files_sharing/api/v1/shares
Request-ID: F2103C2C-E07D-48E8-8E73-E2B001FE274F
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
Date: Fri, 01 Mar 2019 12:39:13 GMT
x-robots-tag: none
Content-Length: 604
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
   <id>28</id>
   <share_type>3</share_type>
   <uid_owner>admin</uid_owner>
   <displayname_owner>admin</displayname_owner>
   <permissions>1</permissions>
   <stime>1551436238</stime>
   <parent/>
   <expiration/>
   <token>URRc6Qg3z53YmPL</token>
   <uid_file_owner>demo</uid_file_owner>
   <displayname_file_owner>demo</displayname_file_owner>
   <path>/SharedImage.jpg</path>
   <item_type>file</item_type>
   <mimetype>image/jpeg</mimetype>
   <storage_id>shared::/SharedImage.jpg</storage_id>
   <storage>3</storage>
   <item_source>246</item_source>
   <file_source>246</file_source>
   <file_parent>10</file_parent>
   <file_target>/SharedImage.jpg</file_target>
   <share_with/>
   <share_with_displayname/>
   <name>Public link1</name>
   <url>https://demo.owncloud.com/s/URRc6Qg3z53YmPL</url>
   <mail_send>0</mail_send>
  </element>
  <element>
   <id>29</id>
   <share_type>3</share_type>
   <uid_owner>admin</uid_owner>
   <displayname_owner>admin</displayname_owner>
   <permissions>1</permissions>
   <stime>1551443896</stime>
   <parent/>
   <expiration>2019-03-20 00:00:00</expiration>
   <token>DYKVR0odXmVef2y</token>
   <uid_file_owner>demo</uid_file_owner>
   <displayname_file_owner>demo</displayname_file_owner>
   <path>/SharedImage.jpg</path>
   <item_type>file</item_type>
   <mimetype>image/jpeg</mimetype>
   <storage_id>shared::/SharedImage.jpg</storage_id>
   <storage>3</storage>
   <item_source>246</item_source>
   <file_source>246</file_source>
   <file_parent>10</file_parent>
   <file_target>/SharedImage.jpg</file_target>
   <share_with>1|$2y$10$LVnwGBk.zESw1fjCJhl4EebJKmB7VrRGVB6xvNz7Qbf0L7JBnHjwW</share_with>
   <share_with_displayname>1|$2y$10$LVnwGBk.zESw1fjCJhl4EebJKmB7VrRGVB6xvNz7Qbf0L7JBnHjwW</share_with_displayname>
   <name>Public link</name>
   <url>https://demo.owncloud.com/s/DYKVR0odXmVef2y</url>
   <mail_send>0</mail_send>
  </element>
 </data>
</ocs>

// Share recipient

# RESPONSE --------------------------------------------------------
Method:     GET
URL:        https://demo.owncloud.com/ocs/v1.php/apps/files_sharing/api/v1/shares?shared_with_me=true
Request-ID: 902B5A7C-33C5-40C4-BBA3-C56A92381BDC
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
Date: Fri, 01 Mar 2019 12:35:31 GMT
x-robots-tag: none
Content-Length: 413
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
   <id>27</id>
   <share_type>0</share_type>
   <uid_owner>demo</uid_owner>
   <displayname_owner>demo</displayname_owner>
   <permissions>19</permissions>
   <stime>1551430723</stime>
   <parent/>
   <expiration/>
   <token/>
   <uid_file_owner>demo</uid_file_owner>
   <displayname_file_owner>demo</displayname_file_owner>
   <state>0</state>
   <path>/SharedImage.jpg</path>
   <item_type>file</item_type>
   <mimetype>image/jpeg</mimetype>
   <storage_id>shared::/SharedImage.jpg</storage_id>
   <storage>3</storage>
   <item_source>246</item_source>
   <file_source>246</file_source>
   <file_parent>10</file_parent>
   <file_target>/SharedImage.jpg</file_target>
   <share_with>admin</share_with>
   <share_with_displayname>admin</share_with_displayname>
   <share_with_additional_info/>
   <mail_send>0</mail_send>
  </element>
 </data>
</ocs>


// Share creator of public folder share (Download / View)

# RESPONSE --------------------------------------------------------
Method:     GET
URL:        https://demo.owncloud.com/ocs/v1.php/apps/files_sharing/api/v1/shares
Request-ID: 15DD4E9B-C96C-4509-A7C7-3535549697A5
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
Date: Mon, 04 Mar 2019 13:49:04 GMT
x-robots-tag: none
Content-Length: 439
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
   <id>4</id>
   <share_type>3</share_type>
   <uid_owner>admin</uid_owner>
   <displayname_owner>admin</displayname_owner>
   <permissions>1</permissions>
   <stime>1551706852</stime>
   <parent/>
   <expiration/>
   <token>MFvU91PDCvAfzWh</token>
   <uid_file_owner>admin</uid_file_owner>
   <displayname_file_owner>admin</displayname_file_owner>
   <path>/Photos</path>
   <item_type>folder</item_type>
   <mimetype>httpd/unix-directory</mimetype>
   <storage_id>home::admin</storage_id>
   <storage>2</storage>
   <item_source>86</item_source>
   <file_source>86</file_source>
   <file_parent>9</file_parent>
   <file_target>/Photos</file_target>
   <share_with/>
   <share_with_displayname/>
   <name>Public link</name>
   <url>https://demo.owncloud.com/s/MFvU91PDCvAfzWh</url>
   <mail_send>0</mail_send>
  </element>
 </data>
</ocs>

// Share creator of public folder share (Download / View / Upload)

# RESPONSE --------------------------------------------------------
Method:     GET
URL:        https://demo.owncloud.com/ocs/v1.php/apps/files_sharing/api/v1/shares
Request-ID: 2B20D73E-3BBD-40F5-AD11-3174F8F5C474
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
Date: Mon, 04 Mar 2019 13:43:41 GMT
x-robots-tag: none
Content-Length: 440
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
   <id>4</id>
   <share_type>3</share_type>
   <uid_owner>admin</uid_owner>
   <displayname_owner>admin</displayname_owner>
   <permissions>15</permissions>
   <stime>1551706852</stime>
   <parent/>
   <expiration/>
   <token>PDCvAfMFvU91zWh</token>
   <uid_file_owner>admin</uid_file_owner>
   <displayname_file_owner>admin</displayname_file_owner>
   <path>/Photos</path>
   <item_type>folder</item_type>
   <mimetype>httpd/unix-directory</mimetype>
   <storage_id>home::admin</storage_id>
   <storage>2</storage>
   <item_source>86</item_source>
   <file_source>86</file_source>
   <file_parent>9</file_parent>
   <file_target>/Photos</file_target>
   <share_with/>
   <share_with_displayname/>
   <name>Public link</name>
   <url>https://demo.owncloud.com/s/PDCvAfMFvU91zWh</url>
   <mail_send>0</mail_send>
  </element>
 </data>
</ocs>

// Share creator of public folder share (Filedrop / Upload only)

# RESPONSE --------------------------------------------------------
Method:     GET
URL:        https://demo.owncloud.com/ocs/v1.php/apps/files_sharing/api/v1/shares
Request-ID: 586C0F46-DEB5-4DA8-8219-74CF94C026EE
Error:      -
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
200 NO ERROR
Content-Type: text/xml; charset=UTF-8
Pragma: no-cache
content-security-policy: default-src 'self'; script-src 'self' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; frame-src *; img-src * data: blob:; font-src 'self' data:; media-src *; connect-src *
Set-Cookie: ocs7se16w8jy=t58hm9ummjs2fh7upiottk14sk; path=/; secure; HttpOnly, oc_sessionPassphrase=1FcdWiNnjq75zIfeJrQhKbfpNKK4fXJ35FY7iI4N43u68gWCrsoyKDM1uHTnDhuqQKOVELYHZ0AQDeufj%2FKB7wIPms0jZCHZAhuHUE0b7EDQXsL8VmrriipV4UPspjNd; path=/; secure; HttpOnly, ocs7se16w8jy=lbso12odlonjsjcoqmdjiolv6b; path=/; secure; HttpOnly, cookie_test=test; expires=Mon, 04-Mar-2019 14:50:03 GMT; Max-Age=3600, oc_username=deleted; expires=Thu, 01-Jan-1970 00:00:01 GMT; Max-Age=0; secure; HttpOnly, oc_token=deleted; expires=Thu, 01-Jan-1970 00:00:01 GMT; Max-Age=0; secure; HttpOnly, oc_remember_login=deleted; expires=Thu, 01-Jan-1970 00:00:01 GMT; Max-Age=0; secure; HttpOnly, oc_username=deleted; expires=Thu, 01-Jan-1970 00:00:01 GMT; Max-Age=0; path=/; secure; HttpOnly, oc_token=deleted; expires=Thu, 01-Jan-1970 00:00:01 GMT; Max-Age=0; path=/; secure; HttpOnly, oc_remember_login=deleted; expires=Thu, 01-Jan-1970 00:00:01 GMT; Max-Age=0; path=/; secure; HttpOnly, ocs7se16w8jy=q5g576nfftoco3otnn0t5plcnq; path=/; secure; HttpOnly, ocs7se16w8jy=07gfceqikgglubvaq56vq86en4; path=/; secure; HttpOnly
Server: Apache
x-download-options: noopen
Content-Encoding: gzip
x-xss-protection: 1; mode=block
x-permitted-cross-domain-policies: none
Expires: Thu, 19 Nov 1981 08:52:00 GMT
Cache-Control: no-store, no-cache, must-revalidate
Date: Mon, 04 Mar 2019 13:50:02 GMT
x-robots-tag: none
Content-Length: 437
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
   <id>4</id>
   <share_type>3</share_type>
   <uid_owner>admin</uid_owner>
   <displayname_owner>admin</displayname_owner>
   <permissions>4</permissions>
   <stime>1551706852</stime>
   <parent/>
   <expiration/>
   <token>MFvU91PDCvAfzWh</token>
   <uid_file_owner>admin</uid_file_owner>
   <displayname_file_owner>admin</displayname_file_owner>
   <path>/Photos</path>
   <item_type>folder</item_type>
   <mimetype>httpd/unix-directory</mimetype>
   <storage_id>home::admin</storage_id>
   <storage>2</storage>
   <item_source>86</item_source>
   <file_source>86</file_source>
   <file_parent>9</file_parent>
   <file_target>/Photos</file_target>
   <share_with/>
   <share_with_displayname/>
   <name>Public link</name>
   <url>https://demo.owncloud.com/s/MFvU91PDCvAfzWh</url>
   <mail_send>0</mail_send>
  </element>
 </data>
</ocs>


*/
