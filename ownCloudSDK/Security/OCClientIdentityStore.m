//
//  OCClientIdentityStore.m
//  ownCloudSDK
//

/*
 * Copyright (C) 2026, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import <Security/Security.h>
#import "OCClientIdentityStore.h"
#import "OCAppIdentity.h"
#import "OCLogger.h"
#import "OCMacros.h"

NSErrorDomain OCClientIdentityErrorDomain = @"OCClientIdentityError";

static NSString *OCClientIdentityKeychainService = @"com.owncloud.client-identity";

#pragma mark - Info
@interface OCClientIdentityInfo ()
- (instancetype)initWithHost:(NSString *)host subjectSummary:(NSString *)subjectSummary expiryDate:(nullable NSDate *)expiryDate;
@end

@implementation OCClientIdentityInfo

- (instancetype)initWithHost:(NSString *)host subjectSummary:(NSString *)subjectSummary expiryDate:(nullable NSDate *)expiryDate
{
	if ((self = [super init]) != nil)
	{
		_host = host;
		_subjectSummary = subjectSummary;
		_expiryDate = expiryDate;
	}

	return (self);
}

- (BOOL)isExpired
{
	return ((_expiryDate != nil) && (_expiryDate.timeIntervalSinceNow < 0));
}

@end

#pragma mark - Cache entry
@interface OCClientIdentityCacheEntry : NSObject
@property(strong) NSData *storedData;
@property(strong) NSURLCredential *credential;
@property(strong) OCClientIdentityInfo *info;
@end

@implementation OCClientIdentityCacheEntry
@end

#pragma mark - Store
@implementation OCClientIdentityStore
{
	NSMutableDictionary<NSString *, OCClientIdentityCacheEntry *> *_cache;
}

+ (OCClientIdentityStore *)sharedStore
{
	static dispatch_once_t onceToken;
	static OCClientIdentityStore *sharedStore;

	dispatch_once(&onceToken, ^{
		sharedStore = [OCClientIdentityStore new];
	});

	return (sharedStore);
}

- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_cache = [NSMutableDictionary new];
	}

	return (self);
}

+ (NSString *)normalizedHost:(NSString *)host
{
	host = [host stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].lowercaseString;

	while ([host hasSuffix:@"."])
	{
		host = [host substringToIndex:host.length-1];
	}

	return ((host.length > 0) ? host : nil);
}

#pragma mark - Keychain
- (NSMutableDictionary<NSString *, id> *)_baseQueryForHost:(nullable NSString *)host
{
	NSMutableDictionary<NSString *, id> *query = [NSMutableDictionary new];

	query[(id)kSecClass] = (id)kSecClassGenericPassword;
	query[(id)kSecAttrService] = OCClientIdentityKeychainService;
	query[(id)kSecAttrSynchronizable] = (id)kCFBooleanFalse;

	if (host != nil)
	{
		query[(id)kSecAttrAccount] = host;
	}

	OCAppIdentity *appIdentity = OCAppIdentity.sharedAppIdentity;

	if (appIdentity.keychainAccessGroupIdentifier != nil)
	{
		// Same access group the SDK's OCKeychain uses, shared between the app and its extensions
		query[(id)kSecAttrAccessGroup] = (appIdentity.appIdentifierPrefix != nil) ? [appIdentity.appIdentifierPrefix stringByAppendingString:appIdentity.keychainAccessGroupIdentifier] : appIdentity.keychainAccessGroupIdentifier;
	}

	return (query);
}

- (nullable NSData *)_readStoredDataForHost:(NSString *)host
{
	NSMutableDictionary<NSString *, id> *query = [self _baseQueryForHost:host];
	CFTypeRef result = NULL;

	query[(id)kSecReturnData] = (id)kCFBooleanTrue;
	query[(id)kSecMatchLimit] = (id)kSecMatchLimitOne;

	if (SecItemCopyMatching((__bridge CFDictionaryRef)query, &result) == errSecSuccess)
	{
		id data = CFBridgingRelease(result); // OCTypedCast evaluates its argument twice, so never pass CFBridgingRelease() directly

		return (OCTypedCast(data, NSData));
	}

	return (nil);
}

- (OSStatus)_writeStoredData:(NSData *)data forHost:(NSString *)host
{
	NSDictionary<NSString *, id> *attributes = @{
		(id)kSecValueData : data,
		(id)kSecAttrAccessible : (id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly // readable while locked for background syncs, never restored to another device
	};
	NSMutableDictionary<NSString *, id> *query = [self _baseQueryForHost:host];
	OSStatus status;

	// Update in place, so that a failure never loses the item that was there before
	if ((status = SecItemUpdate((__bridge CFDictionaryRef)query, (__bridge CFDictionaryRef)attributes)) == errSecItemNotFound)
	{
		[query addEntriesFromDictionary:attributes];
		status = SecItemAdd((__bridge CFDictionaryRef)query, NULL);
	}

	return (status);
}

- (NSArray<NSString *> *)hosts
{
	NSMutableDictionary<NSString *, id> *query = [self _baseQueryForHost:nil];
	CFTypeRef result = NULL;
	NSMutableArray<NSString *> *hosts = [NSMutableArray new];

	query[(id)kSecReturnAttributes] = (id)kCFBooleanTrue;
	query[(id)kSecMatchLimit] = (id)kSecMatchLimitAll;

	if (SecItemCopyMatching((__bridge CFDictionaryRef)query, &result) == errSecSuccess)
	{
		id items = CFBridgingRelease(result); // OCTypedCast evaluates its argument twice

		for (NSDictionary *attributes in OCTypedCast(items, NSArray))
		{
			NSString *host;

			if ((host = OCTypedCast(OCTypedCast(attributes, NSDictionary)[(id)kSecAttrAccount], NSString)) != nil)
			{
				[hosts addObject:host];
			}
		}
	}

	return (hosts);
}

#pragma mark - PKCS#12
+ (nullable OCClientIdentityCacheEntry *)_entryFromPKCS12Data:(NSData *)pkcs12Data password:(NSString *)password host:(NSString *)host error:(NSError **)outError
{
	CFArrayRef rawItems = NULL;
	OSStatus status = SecPKCS12Import((__bridge CFDataRef)pkcs12Data, (__bridge CFDictionaryRef)@{ (id)kSecImportExportPassphrase : password }, &rawItems);
	NSArray<NSDictionary *> *items = (NSArray *)CFBridgingRelease(rawItems);

	if (status != errSecSuccess)
	{
		if (outError != NULL)
		{
			*outError = [NSError errorWithDomain:OCClientIdentityErrorDomain code:(((status == errSecAuthFailed) || (status == errSecPkcs12VerifyFailure)) ? OCClientIdentityErrorWrongPassword : OCClientIdentityErrorInvalidFile) userInfo:@{
				NSUnderlyingErrorKey : [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil]
			}];
		}
		return (nil);
	}

	for (NSDictionary *item in items)
	{
		id identityRef;

		if ((identityRef = item[(id)kSecImportItemIdentity]) != nil)
		{
			SecIdentityRef identity = (__bridge SecIdentityRef)identityRef;
			SecCertificateRef leaf = NULL;
			NSArray *chain = OCTypedCast(item[(id)kSecImportItemCertChain], NSArray);
			NSArray *intermediates = (chain.count > 1) ? [chain subarrayWithRange:NSMakeRange(1, chain.count-1)] : nil; // chain starts with the leaf, which the identity already carries
			NSString *subjectSummary = nil;
			NSDate *expiryDate = nil;

			if (SecIdentityCopyCertificate(identity, &leaf) == errSecSuccess)
			{
				subjectSummary = (NSString *)CFBridgingRelease(SecCertificateCopySubjectSummary(leaf));

				if (@available(iOS 18, macOS 15, *))
				{
					expiryDate = (NSDate *)CFBridgingRelease(SecCertificateCopyNotValidAfterDate(leaf));
				}

				CFRelease(leaf);
			}

			OCClientIdentityCacheEntry *entry = [OCClientIdentityCacheEntry new];

			entry.credential = [NSURLCredential credentialWithIdentity:identity certificates:intermediates persistence:NSURLCredentialPersistenceForSession];
			entry.info = [[OCClientIdentityInfo alloc] initWithHost:host subjectSummary:((subjectSummary != nil) ? subjectSummary : @"") expiryDate:expiryDate];

			return (entry);
		}
	}

	if (outError != NULL)
	{
		*outError = [NSError errorWithDomain:OCClientIdentityErrorDomain code:OCClientIdentityErrorNoIdentity userInfo:nil];
	}

	return (nil);
}

+ (nullable NSData *)_archiveForPKCS12Data:(NSData *)pkcs12Data password:(NSString *)password
{
	return ([NSPropertyListSerialization dataWithPropertyList:@{ @"pkcs12" : pkcs12Data, @"password" : password } format:NSPropertyListBinaryFormat_v1_0 options:0 error:NULL]);
}

#pragma mark - Lookup
- (nullable OCClientIdentityCacheEntry *)_entryForHost:(nullable NSString *)host
{
	NSData *storedData;

	if ((host = [OCClientIdentityStore normalizedHost:host]) == nil)
	{
		return (nil);
	}

	if ((storedData = [self _readStoredDataForHost:host]) == nil)
	{
		@synchronized(self)
		{
			[_cache removeObjectForKey:host];
		}
		return (nil);
	}

	@synchronized(self)
	{
		OCClientIdentityCacheEntry *entry = _cache[host];

		if ((entry != nil) && [entry.storedData isEqual:storedData])
		{
			return (entry);
		}

		NSDictionary *plist = OCTypedCast([NSPropertyListSerialization propertyListWithData:storedData options:NSPropertyListImmutable format:NULL error:NULL], NSDictionary);
		NSData *pkcs12Data = OCTypedCast(plist[@"pkcs12"], NSData);
		NSString *password = OCTypedCast(plist[@"password"], NSString);
		NSError *error = nil;

		if ((pkcs12Data != nil) && (password != nil) && ((entry = [OCClientIdentityStore _entryFromPKCS12Data:pkcs12Data password:password host:host error:&error]) != nil))
		{
			entry.storedData = storedData;
			_cache[host] = entry;
		}
		else
		{
			OCLogError(@"Stored client identity for %@ could not be loaded: %@", OCLogPrivate(host), error);
			[_cache removeObjectForKey:host];
		}

		return (entry);
	}
}

- (NSURLCredential *)credentialForHost:(NSString *)host
{
	return ([self _entryForHost:host].credential);
}

- (NSURLCredential *)credentialForChallenge:(NSURLAuthenticationChallenge *)challenge
{
	if ([challenge.protectionSpace.authenticationMethod isEqual:NSURLAuthenticationMethodClientCertificate])
	{
		NSURLCredential *credential = [self credentialForHost:challenge.protectionSpace.host];

		OCLogDebug(@"Client certificate requested by %@: %@", OCLogPrivate(challenge.protectionSpace.host), ((credential != nil) ? @"presenting stored identity" : @"none stored"));

		return (credential);
	}

	return (nil);
}

- (BOOL)hasIdentityForHost:(NSString *)host
{
	return ((host = [OCClientIdentityStore normalizedHost:host]) != nil) && ([self _readStoredDataForHost:host] != nil);
}

- (OCClientIdentityInfo *)identityInfoForHost:(NSString *)host
{
	return ([self _entryForHost:host].info);
}

#pragma mark - Mutations
- (OCClientIdentityInfo *)importPKCS12Data:(NSData *)pkcs12Data password:(NSString *)password forHost:(NSString *)host error:(NSError **)outError
{
	OCClientIdentityCacheEntry *entry;
	NSData *storedData;
	OSStatus status = errSecSuccess;

	if ((host = [OCClientIdentityStore normalizedHost:host]) == nil)
	{
		if (outError != NULL) { *outError = [NSError errorWithDomain:OCClientIdentityErrorDomain code:OCClientIdentityErrorInvalidHost userInfo:nil]; }
		return (nil);
	}

	if ((entry = [OCClientIdentityStore _entryFromPKCS12Data:pkcs12Data password:password host:host error:outError]) == nil)
	{
		return (nil);
	}

	if (((storedData = [OCClientIdentityStore _archiveForPKCS12Data:pkcs12Data password:password]) == nil) ||
	    ((status = [self _writeStoredData:storedData forHost:host]) != errSecSuccess))
	{
		if (outError != NULL)
		{
			*outError = [NSError errorWithDomain:OCClientIdentityErrorDomain code:OCClientIdentityErrorKeychain userInfo:@{
				NSUnderlyingErrorKey : [NSError errorWithDomain:NSOSStatusErrorDomain code:((storedData == nil) ? errSecParam : status) userInfo:nil]
			}];
		}
		return (nil);
	}

	entry.storedData = storedData;

	@synchronized(self)
	{
		_cache[host] = entry;
	}

	OCLogDebug(@"Imported client identity for %@", OCLogPrivate(host));

	return (entry.info);
}

- (void)removeIdentityForHost:(NSString *)host
{
	if ((host = [OCClientIdentityStore normalizedHost:host]) == nil)
	{
		return;
	}

	SecItemDelete((__bridge CFDictionaryRef)[self _baseQueryForHost:host]);

	@synchronized(self)
	{
		[_cache removeObjectForKey:host];
	}

	OCLogDebug(@"Removed client identity for %@", OCLogPrivate(host));
}

#pragma mark - Log tagging
+ (NSArray<OCLogTagName> *)logTags
{
	return (@[@"ClientIdentity"]);
}

- (NSArray<OCLogTagName> *)logTags
{
	return (@[@"ClientIdentity"]);
}

@end
