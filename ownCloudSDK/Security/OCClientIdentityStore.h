//
//  OCClientIdentityStore.h
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

#import <Foundation/Foundation.h>
#import "OCLogger.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, OCClientIdentityError)
{
	OCClientIdentityErrorWrongPassword = 1,	//!< The password for the PKCS#12 file is wrong
	OCClientIdentityErrorInvalidFile,	//!< The file isn't a readable PKCS#12 file
	OCClientIdentityErrorNoIdentity,	//!< The file contains no certificate + private key pair
	OCClientIdentityErrorInvalidHost,	//!< No host was given
	OCClientIdentityErrorKeychain		//!< Storing the identity in the keychain failed (underlying OSStatus in NSUnderlyingErrorKey)
};

extern NSErrorDomain OCClientIdentityErrorDomain;

/// Name and expiry of a stored client certificate, for display.
@interface OCClientIdentityInfo : NSObject

@property(strong,readonly) NSString *host;
@property(strong,readonly) NSString *subjectSummary;
@property(nullable,strong,readonly) NSDate *expiryDate; //!< nil if the OS can't report it (iOS < 18)
@property(readonly,nonatomic) BOOL isExpired;

@end

/**
 Stores TLS client identities (certificate + private key, imported from PKCS#12) per server host, for
 servers or reverse proxies that require mutual TLS.

 The PKCS#12 data and its password are kept together in one keychain item per host, in the app's shared
 keychain access group (so the File Provider and other extensions can use them), accessible after first
 unlock, this device only and never synchronized. An identity is only ever presented to the exact host
 it was imported for.

 Every lookup re-reads the keychain item (lookups happen once per TLS handshake, not per request) so that
 imports or removals done in the app take effect immediately in already-running extensions. The decoded
 credential is cached as long as the stored data is unchanged.
 */
@interface OCClientIdentityStore : NSObject <OCLogTagging>

@property(class,strong,readonly,nonatomic) OCClientIdentityStore *sharedStore NS_SWIFT_NAME(shared);

/// Hosts (lowercased) that currently have a client identity.
@property(strong,readonly,nonatomic) NSArray<NSString *> *hosts;

/// The credential to answer an NSURLAuthenticationMethodClientCertificate challenge from `host` with, or nil if none is stored for it.
- (nullable NSURLCredential *)credentialForHost:(nullable NSString *)host NS_SWIFT_NAME(credential(forHost:));

/// Convenience for the challenge handlers: the credential for the challenge's host, if it is a client certificate challenge and one is stored.
- (nullable NSURLCredential *)credentialForChallenge:(NSURLAuthenticationChallenge *)challenge NS_SWIFT_NAME(credential(for:));

- (BOOL)hasIdentityForHost:(nullable NSString *)host;
- (nullable OCClientIdentityInfo *)identityInfoForHost:(nullable NSString *)host;

/// Validates the PKCS#12 data with the password and, if it holds an identity, stores it for `host` (replacing any previous one).
/// On failure, a previously stored identity for that host is left untouched.
- (nullable OCClientIdentityInfo *)importPKCS12Data:(NSData *)pkcs12Data password:(NSString *)password forHost:(NSString *)host error:(NSError * _Nullable * _Nullable)outError NS_SWIFT_NAME(importPKCS12(_:password:forHost:));

- (void)removeIdentityForHost:(nullable NSString *)host;

/// Normalizes a host for use as key (lowercased, trimmed, without trailing dot).
+ (nullable NSString *)normalizedHost:(nullable NSString *)host NS_SWIFT_NAME(normalizedHost(_:));

@end

NS_ASSUME_NONNULL_END
