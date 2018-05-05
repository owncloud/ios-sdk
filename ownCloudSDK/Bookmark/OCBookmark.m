//
//  OCBookmark.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 05.02.18.
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

#import "OCBookmark.h"
#import "OCAppIdentity.h"

@implementation OCBookmark

@synthesize uuid = _uuid;

@synthesize name = _name;
@synthesize url = _url;

@synthesize certificate = _certificate;
@synthesize certificateModificationDate = _certificateModificationDate;

@synthesize authenticationMethodIdentifier = _authenticationMethodIdentifier;
@synthesize authenticationData = _authenticationData;
@synthesize authenticationDataStorage = _authenticationDataStorage;

+ (instancetype)bookmarkForURL:(NSURL *)url //!< Creates a bookmark for the ownCloud server with the specified URL.
{
	OCBookmark *bookmark = [OCBookmark new];
	
	bookmark.url = url;
	
	return (bookmark);
}

+ (instancetype)bookmarkFromBookmarkData:(NSData *)bookmarkData; //!< Creates a bookmark from BookmarkData
{
	return ([NSKeyedUnarchiver unarchiveObjectWithData:bookmarkData]);
}

#pragma mark - Init & Dealloc
- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_uuid = [NSUUID UUID];
	}
	
	return(self);
}

- (void)dealloc
{
}

- (NSData *)bookmarkData
{
	return ([NSKeyedArchiver archivedDataWithRootObject:self]);
}

#pragma mark - Keychain access
- (NSData *)authenticationData
{
	if (_authenticationDataStorage == OCBookmarkAuthenticationDataStorageKeychain)
	{
		if (_authenticationData == nil)
		{
			_authenticationData = [[OCAppIdentity sharedAppIdentity].keychain readDataFromKeychainItemForAccount:_uuid.UUIDString path:@"authenticationData"];
		}
	}
	
	return (_authenticationData);
}

- (void)setAuthenticationData:(NSData *)authenticationData
{
	[self setAuthenticationData:authenticationData saveToKeychain:(_authenticationDataStorage == OCBookmarkAuthenticationDataStorageKeychain)];
}

- (void)setAuthenticationData:(NSData *)authenticationData saveToKeychain:(BOOL)saveToKeychain
{
	_authenticationData = authenticationData;

	if (saveToKeychain)
	{
		if (_authenticationData == nil)
		{
			[[OCAppIdentity sharedAppIdentity].keychain removeKeychainItemForAccount:_uuid.UUIDString path:@"authenticationData"];
		}
		else
		{
			[[OCAppIdentity sharedAppIdentity].keychain writeData:_authenticationData toKeychainItemForAccount:_uuid.UUIDString path:@"authenticationData"];
		}

		[[NSNotificationCenter defaultCenter] postNotificationName:OCBookmarkAuthenticationDataChangedNotification object:self];
	}
}

- (void)setAuthenticationDataStorage:(OCBookmarkAuthenticationDataStorage)authenticationDataStorage
{
	if (_authenticationDataStorage != authenticationDataStorage)
	{
		[self setAuthenticationData:self.authenticationData saveToKeychain:(authenticationDataStorage == OCBookmarkAuthenticationDataStorageKeychain)];
	}
}

#pragma mark - Data replacement
- (void)setValuesFrom:(OCBookmark *)sourceBookmark
{
	_uuid = sourceBookmark.uuid;

	_name = sourceBookmark.name;
	_url  = sourceBookmark.url;

	_originURL = sourceBookmark.originURL;

	_certificate = sourceBookmark.certificate;
	_certificateModificationDate = sourceBookmark.certificateModificationDate;

	_authenticationMethodIdentifier = sourceBookmark.authenticationMethodIdentifier;
	_authenticationData = sourceBookmark.authenticationData;
	_authenticationDataStorage = sourceBookmark.authenticationDataStorage;
}

#pragma mark - Secure Coding
+ (BOOL)supportsSecureCoding
{
	return (YES);
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
	if ((self = [self init]) != nil)
	{
		_uuid = [decoder decodeObjectOfClass:[NSUUID class] forKey:@"uuid"];

		_name = [decoder decodeObjectOfClass:[NSString class] forKey:@"name"];
		_url = [decoder decodeObjectOfClass:[NSURL class] forKey:@"url"];

		_originURL = [decoder decodeObjectOfClass:[NSURL class] forKey:@"originURL"];

		_certificate = [decoder decodeObjectOfClass:[OCCertificate class] forKey:@"certificate"];
		_certificateModificationDate = [decoder decodeObjectOfClass:[NSDate class] forKey:@"certificateModificationDate"];

		_authenticationMethodIdentifier = [decoder decodeObjectOfClass:[NSString class] forKey:@"authenticationMethodIdentifier"];

		// _authenticationData is not stored in the bookmark
	}
	
	return (self);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:_uuid forKey:@"uuid"];

	[coder encodeObject:_name forKey:@"name"];
	[coder encodeObject:_url forKey:@"url"];

	[coder encodeObject:_originURL forKey:@"originURL"];

	[coder encodeObject:_certificate forKey:@"certificate"];
	[coder encodeObject:_certificateModificationDate forKey:@"certificateModificationDate"];

	[coder encodeObject:_authenticationMethodIdentifier forKey:@"authenticationMethodIdentifier"];

	// _authenticationData is not stored in the bookmark
}

#pragma mark - Copying
- (id)copyWithZone:(NSZone *)zone
{
	OCBookmark *copiedBookmark = [OCBookmark new];

	[copiedBookmark setValuesFrom:self];

	return (copiedBookmark);
}

@end

NSNotificationName OCBookmarkAuthenticationDataChangedNotification = @"OCBookmarkAuthenticationDataChanged";
