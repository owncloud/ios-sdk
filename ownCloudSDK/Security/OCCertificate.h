//
//  OCCertificate.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 28.02.18.
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

#import <Foundation/Foundation.h>
#import <Security/Security.h>

#import "NSData+OCHash.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, OCCertificateValidationResult)
{
	OCCertificateValidationResultNone,

	// Hard fail
	OCCertificateValidationResultError,
	OCCertificateValidationResultReject,

	// Prompt user
	OCCertificateValidationResultPromptUser,

	// Proceed
	OCCertificateValidationResultPassed,
	OCCertificateValidationResultUserAccepted
};

@interface OCCertificate : NSObject <NSSecureCoding>
{
	NSString *_hostName;

	NSData *_certificateData;
	SecCertificateRef _certificateRef;
	SecTrustRef _trustRef;

	SecKeyRef _publicKey;
	NSData *_publicKeyData;

	NSDate *_userAcceptedDate;

	NSData *_md5FingerPrint;
	NSData *_sha1FingerPrint;
	NSData *_sha256FingerPrint;
}

@property(nullable,strong,readonly) NSString *hostName;	//!< Hostname to validate the certificate against

@property(nullable,strong,nonatomic) NSData *certificateData;   //!< X.509 representation of the certificate

@property(assign,nonatomic) BOOL userAccepted; //!< Whether a certificate is saved as accepted by the user in +[OCCertificate userAcceptedCertificates] - or not.
@property(nullable,strong,readonly) NSDate *userAcceptedDate; //!< The date the user accepted the OCCertificate.

#pragma mark - User accepted certificates
@property(nullable,strong,readonly,class,nonatomic) NSArray <OCCertificate *> *userAcceptedCertificates; //!< Collection of all certificates accepted by users.

#pragma mark - Initializers
+ (instancetype)certificateWithCertificateRef:(SecCertificateRef)certificateRef hostName:(NSString *)hostName;
+ (instancetype)certificateWithCertificateData:(NSData *)certificateData hostName:(NSString *)hostName;
+ (instancetype)certificateWithTrustRef:(SecTrustRef)trustRef hostName:(NSString *)hostName;

- (instancetype)initWithCertificateRef:(SecCertificateRef)certificateRef hostName:(NSString *)hostName;
- (instancetype)initWithCertificateData:(NSData *)certificateData hostName:(NSString *)hostName;
- (instancetype)initWithCertificateTrustRef:(SecTrustRef)trustRef hostName:(NSString *)hostName;

#pragma mark - Setters / Getters (CF objects)
- (nullable SecCertificateRef)certificateRef;
- (void)setCertificateRef:(nullable SecCertificateRef)certificateRef;

- (nullable SecTrustRef)trustRef;
- (void)setTrustRef:(nullable SecTrustRef)trustRef;

#pragma mark - Evaluation
- (void)evaluateWithCompletionHandler:(void(^)(OCCertificate *certificate, OCCertificateValidationResult validationResult, NSError *error))completionHandler;

#pragma mark - Public Key
- (nullable SecKeyRef)publicKey;
- (nullable NSData *)publicKeyDataWithError:(NSError **)error; //!< Returns public key embedded in certificate in PKCS#1 format (RSA keys) or ANSI X9.63 format (04 || X || Y [ || K]) (for elliptic curve keys)

#pragma mark - Fingerprints
- (nullable NSData *)md5Fingerprint;
- (nullable NSData *)sha1Fingerprint;
- (nullable NSData *)sha256Fingerprint;

@end

extern NSNotificationName OCCertificateUserAcceptanceDidChangeNotification;

NS_ASSUME_NONNULL_END
