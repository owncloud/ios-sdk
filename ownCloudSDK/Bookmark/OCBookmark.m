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

@synthesize certificateData = _certificateData;
@synthesize certificateModificationDate = _certificateModificationDate;

@synthesize authenticationMethodIdentifier = _authenticationMethodIdentifier;
@synthesize authenticationData = _authenticationData;

@synthesize requirePIN = _requirePIN;
@synthesize pin = _pin;

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
- (NSString *)pin
{
	if (_pin == nil)
	{
		NSData *pinData;
		
		if ((pinData = [[OCAppIdentity sharedAppIdentity].keychain readDataFromKeychainItemForAccount:_uuid.UUIDString path:@"pin"]) != nil)
		{
			_pin = [[NSString alloc] initWithData:pinData encoding:NSUTF8StringEncoding];
		}
	}
	
	return (_pin);
}

- (void)setPin:(NSString *)pin
{
	_pin = pin;
	
	if (_pin == nil)
	{
		[[OCAppIdentity sharedAppIdentity].keychain removeKeychainItemForAccount:_uuid.UUIDString path:@"pin"];
	}
	else
	{
		NSData *pinData = nil;

		if ((pinData = [_pin dataUsingEncoding:NSUTF8StringEncoding]) != nil)
		{
			[[OCAppIdentity sharedAppIdentity].keychain writeData:pinData toKeychainItemForAccount:_uuid.UUIDString path:@"pin"];
		}
	}
}

- (NSData *)authenticationData
{
	if (_authenticationData == nil)
	{
		_authenticationData = [[OCAppIdentity sharedAppIdentity].keychain readDataFromKeychainItemForAccount:_uuid.UUIDString path:@"authenticationData"];
	}
	
	return (_authenticationData);
}

- (void)setAuthenticationData:(NSData *)authenticationData
{
	_authenticationData = authenticationData;
	
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
		_certificateData = [decoder decodeObjectOfClass:[NSData class] forKey:@"certificateData"];
		_certificateModificationDate = [decoder decodeObjectOfClass:[NSDate class] forKey:@"certificateModificationDate"];
		_authenticationMethodIdentifier = [decoder decodeObjectOfClass:[NSString class] forKey:@"authenticationMethodIdentifier"];
		_requirePIN = [decoder decodeBoolForKey:@"requirePIN"];

		// _pin and _authenticationData are not stored in the bookmark
	}
	
	return (self);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:_uuid forKey:@"uuid"];
	[coder encodeObject:_name forKey:@"name"];
	[coder encodeObject:_url forKey:@"url"];
	[coder encodeObject:_certificateData forKey:@"certificateData"];
	[coder encodeObject:_certificateModificationDate forKey:@"certificateModificationDate"];
	[coder encodeObject:_authenticationMethodIdentifier forKey:@"authenticationMethodIdentifier"];
	[coder encodeBool:_requirePIN forKey:@"requirePIN"];

	// _pin and _authenticationData are not stored in the bookmark
}


@end

NSNotificationName OCBookmarkAuthenticationDataChangedNotification = @"OCBookmarkAuthenticationDataChanged";
