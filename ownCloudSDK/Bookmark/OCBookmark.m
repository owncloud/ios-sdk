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
#import "OCBookmark+IPNotificationNames.h"
#import "OCEvent.h"
#import "OCAppIdentity.h"

#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
#endif /* TARGET_OS_IOS */

@interface OCBookmark ()
{
	OCIPCNotificationName _coreUpdateNotificationName;
	OCIPCNotificationName _bookmarkAuthUpdateNotificationName;

	NSString *_lastUsername;
}
@end

@implementation OCBookmark

@synthesize uuid = _uuid;

@synthesize name = _name;
@synthesize url = _url;

@synthesize certificate = _certificate;
@synthesize certificateModificationDate = _certificateModificationDate;

@synthesize authenticationMethodIdentifier = _authenticationMethodIdentifier;
@synthesize authenticationData = _authenticationData;
@synthesize authenticationDataStorage = _authenticationDataStorage;
@synthesize authenticationValidationDate = _authenticationValidationDate;

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
		_userInfo = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
			[NSDictionary dictionaryWithObjectsAndKeys:
				NSDate.date, 						@"creation-date",
				OCAppIdentity.sharedAppIdentity.appVersion, 		@"app-version",
				OCAppIdentity.sharedAppIdentity.appBuildNumber,		@"app-build-number",
				OCAppIdentity.sharedAppIdentity.sdkVersionString,	@"sdk-version",
				OCAppIdentity.sharedAppIdentity.sdkCommit,		@"sdk-commit",
				OCLogger.sharedLogger.logIntro,				@"log-intro",
			nil], OCBookmarkUserInfoKeyBookmarkCreation,
		nil];
		_databaseVersion = OCDatabaseVersionLatest;

		[OCIPNotificationCenter.sharedNotificationCenter addObserver:self forName:OCBookmark.bookmarkAuthUpdateNotificationName withHandler:^(OCIPNotificationCenter * _Nonnull notificationCenter, OCBookmark *observerBookmark, OCIPCNotificationName  _Nonnull notificationName) {
			[observerBookmark considerAuthenticationDataFlush];
		}];

		#if TARGET_OS_IOS
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(considerAuthenticationDataFlush) name:UIApplicationWillResignActiveNotification object:nil];
		#endif /* TARGET_OS_IOS */
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(considerAuthenticationDataFlush) name:NSExtensionHostWillResignActiveNotification object:nil];
	}
	
	return(self);
}

- (void)dealloc
{
	[OCIPNotificationCenter.sharedNotificationCenter removeObserver:self forName:OCBookmark.bookmarkAuthUpdateNotificationName];

	#if TARGET_OS_IOS
	[[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillResignActiveNotification object:nil];
	#endif /* TARGET_OS_IOS */
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSExtensionHostWillResignActiveNotification object:nil];
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
	_authenticationValidationDate = (_authenticationData != nil) ? [NSDate new] : nil;

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

		// Update cached/last user name
		NSString *username;

		if ((username = self.userName) != nil)
		{
			// TODO: make configurable if user name may be stored in bookmarks
			_lastUsername = username;
		}

		[[NSNotificationCenter defaultCenter] postNotificationName:OCBookmarkAuthenticationDataChangedNotification object:self];
		[[OCIPNotificationCenter sharedNotificationCenter] postNotificationForName:OCBookmark.bookmarkAuthUpdateNotificationName ignoreSelf:YES];
		[[OCIPNotificationCenter sharedNotificationCenter] postNotificationForName:self.bookmarkAuthUpdateNotificationName ignoreSelf:YES];
	}
}

- (void)setAuthenticationDataStorage:(OCBookmarkAuthenticationDataStorage)authenticationDataStorage
{
	if (_authenticationDataStorage != authenticationDataStorage)
	{
		[self setAuthenticationData:self.authenticationData saveToKeychain:(authenticationDataStorage == OCBookmarkAuthenticationDataStorageKeychain)];
		_authenticationDataStorage = authenticationDataStorage;
	}
}

- (void)considerAuthenticationDataFlush
{
	if (_authenticationDataStorage == OCBookmarkAuthenticationDataStorageKeychain)
	{
		if (_authenticationData != nil)
		{
			_authenticationData = nil;
			OCLogDebug(@"flushed local copy of authenticationData for bookmarkUUID=%@", _uuid);
		}
	}
}

#pragma mark - User info
- (NSMutableDictionary<NSString *,id<NSObject,NSSecureCoding>> *)userInfo
{
	@synchronized(self)
	{
		if (_userInfo == nil)
		{
			_userInfo = [NSMutableDictionary new];
		}
	}

	return (_userInfo);
}

#pragma mark - Convenience
- (NSString *)userName
{
	if ((self.authenticationMethodIdentifier != nil) && (_authenticationData != nil))
	{
		Class authMethod;

		if ((authMethod = [OCAuthenticationMethod registeredAuthenticationMethodForIdentifier:self.authenticationMethodIdentifier]) != nil)
		{
			return ([authMethod userNameFromAuthenticationData:self.authenticationData]);
		}
	}

	return (_lastUsername);
}

#pragma mark - Certificate approval
- (NSNotificationName)certificateUserApprovalUpdateNotificationName
{
	return ([@"OCBookmarkCertificateUserApprovalUpdateNotification." stringByAppendingString:_uuid.UUIDString]);
}

- (void)postCertificateUserApprovalUpdateNotification
{
	[NSNotificationCenter.defaultCenter postNotificationName:self.certificateUserApprovalUpdateNotificationName object:self];
}

#pragma mark - Data replacement
- (void)setValuesFrom:(OCBookmark *)sourceBookmark
{
	_uuid = sourceBookmark.uuid;

	_databaseVersion = sourceBookmark.databaseVersion;

	_name = sourceBookmark.name;
	_url  = sourceBookmark.url;

	_originURL = sourceBookmark.originURL;

	_certificate = sourceBookmark.certificate;
	_certificateModificationDate = sourceBookmark.certificateModificationDate;

	_authenticationMethodIdentifier = sourceBookmark.authenticationMethodIdentifier;
	_authenticationData = sourceBookmark.authenticationData;
	_authenticationDataStorage = sourceBookmark.authenticationDataStorage;
	_authenticationValidationDate = sourceBookmark.authenticationValidationDate;

	_lastUsername = sourceBookmark->_lastUsername;

	_userInfo = sourceBookmark.userInfo;
}

- (void)setLastUserName:(NSString *)userName
{
	_lastUsername = userName;
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
		_uuid = [decoder decodeObjectOfClass:NSUUID.class forKey:@"uuid"];

		_name = [decoder decodeObjectOfClass:NSString.class forKey:@"name"];
		_url = [decoder decodeObjectOfClass:NSURL.class forKey:@"url"];

		_originURL = [decoder decodeObjectOfClass:NSURL.class forKey:@"originURL"];

		_certificate = [decoder decodeObjectOfClass:OCCertificate.class forKey:@"certificate"];
		_certificateModificationDate = [decoder decodeObjectOfClass:NSDate.class forKey:@"certificateModificationDate"];

		_authenticationMethodIdentifier = [decoder decodeObjectOfClass:NSString.class forKey:@"authenticationMethodIdentifier"];
		_authenticationValidationDate = [decoder decodeObjectOfClass:NSDate.class forKey:@"authenticationValidationDate"];

		_databaseVersion = [decoder decodeIntegerForKey:@"databaseVersion"];

		_lastUsername = [decoder decodeObjectOfClass:NSString.class forKey:@"lastUsername"];

		_userInfo = [decoder decodeObjectOfClasses:OCEvent.safeClasses forKey:@"userInfo"];

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
	[coder encodeObject:_authenticationValidationDate forKey:@"authenticationValidationDate"];

	[coder encodeInteger:_databaseVersion forKey:@"databaseVersion"];

	[coder encodeObject:_lastUsername forKey:@"lastUsername"];

	if (_userInfo.count > 0)
	{
		[coder encodeObject:_userInfo forKey:@"userInfo"];
	}

	// _authenticationData is not stored in the bookmark
}

#pragma mark - Description
- (NSString *)description
{
	NSData *authData = self.authenticationData;

	return ([NSString stringWithFormat:@"<%@: %p%@%@%@%@%@%@%@%@%@%@%@>", NSStringFromClass(self.class), self,
			((_name!=nil) ? [@", name: " stringByAppendingString:_name] : @""),
			((_uuid!=nil) ? [@", uuid: " stringByAppendingString:_uuid.UUIDString] : @""),
			((_databaseVersion!=OCDatabaseVersionUnknown) ? [@", databaseVersion: " stringByAppendingString:@(_databaseVersion).stringValue] : @""),
			((_url!=nil) ? [@", url: " stringByAppendingString:_url.absoluteString] : @""),
			((_originURL!=nil) ? [@", originURL: " stringByAppendingString:_originURL.absoluteString] : @""),
			((_certificate!=nil) ? [@", certificate: " stringByAppendingString:_certificate.description] : @""),
			((_certificateModificationDate!=nil) ? [@", certificateModificationDate: " stringByAppendingString:_certificateModificationDate.description] : @""),
			((_authenticationMethodIdentifier!=nil) ? [@", authenticationMethodIdentifier: " stringByAppendingString:_authenticationMethodIdentifier] : @""),
			((authData!=nil) ? [@", authenticationData: " stringByAppendingFormat:@"%lu bytes", authData.length] : @""),
			((_authenticationValidationDate!=nil) ? [@", authenticationValidationDate: " stringByAppendingString:_authenticationValidationDate.description] : @""),
			((_userInfo!=nil) ? [@", userInfo: " stringByAppendingString:_userInfo.description] : @"")
		]);
}

#pragma mark - Copying
- (id)copyWithZone:(NSZone *)zone
{
	OCBookmark *copiedBookmark = [OCBookmark new];

	[copiedBookmark setValuesFrom:self];

	return (copiedBookmark);
}

@end

#pragma mark - IPNotificationNames
@implementation OCBookmark (IPNotificationNames)

- (OCIPCNotificationName)coreUpdateNotificationName
{
	if (_coreUpdateNotificationName == nil)
	{
		_coreUpdateNotificationName = [[NSString alloc] initWithFormat:@"com.owncloud.occore.update.%@", self.uuid.UUIDString];
	}

	return (_coreUpdateNotificationName);
}

- (OCIPCNotificationName)bookmarkAuthUpdateNotificationName
{
	if (_bookmarkAuthUpdateNotificationName == nil)
	{
		_bookmarkAuthUpdateNotificationName = [[NSString alloc] initWithFormat:@"com.owncloud.bookmark.auth-update.%@", self.uuid.UUIDString];
	}

	return (_bookmarkAuthUpdateNotificationName);
}

+ (OCIPCNotificationName)bookmarkAuthUpdateNotificationName
{
	return (@"com.owncloud.bookmark.auth-update");
}

@end

OCBookmarkUserInfoKey OCBookmarkUserInfoKeyStatusInfo = @"statusInfo";
OCBookmarkUserInfoKey OCBookmarkUserInfoKeyAllowHTTPConnection = @"OCAllowHTTPConnection";
OCBookmarkUserInfoKey OCBookmarkUserInfoKeyBookmarkCreation = @"bookmark-creation";

NSNotificationName OCBookmarkAuthenticationDataChangedNotification = @"OCBookmarkAuthenticationDataChanged";
NSNotificationName OCBookmarkUpdatedNotification = @"OCBookmarkUpdatedNotification";
