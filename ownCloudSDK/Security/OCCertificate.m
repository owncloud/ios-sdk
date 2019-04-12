//
//  OCCertificate.m
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

#import "OCCertificate.h"
#import "OCAppIdentity.h"
#import "NSData+OCHash.h"

static NSString *OCCertificateKeychainAccount = @"OCCertificateKeychainAccount";
static NSString *OCCertificateKeychainPath = @"UserAcceptedCertificates";

@implementation OCCertificate

@synthesize hostName = _hostName;
@synthesize commonName = _commonName;

@synthesize userAcceptedDate = _userAcceptedDate;
@synthesize certificateData = _certificateData;

@synthesize parentCertificate = _parentCertificate;

#pragma mark - User Accepted Certificates
+ (void)_mutateUserAcceptedCertificates:(void(^)(NSMutableSet<OCCertificate *> *userAcceptedCertificates, NSMutableDictionary<NSData *, OCCertificate *> *userAcceptedCertificatesBySHA256Fingerprints))mutationBlock
{
	static NSMutableSet<OCCertificate *> *userAcceptedCertificates;
	static NSMutableDictionary<NSData *, OCCertificate *> *userAcceptedCertificatesBySHA256Fingerprints;
	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		NSData *storedUserAcceptedCertificatesData;
		
		userAcceptedCertificatesBySHA256Fingerprints = [NSMutableDictionary new];
		
		// Try to load userAcceptedCertificates from keychain on first call
		if ((storedUserAcceptedCertificatesData = [[OCAppIdentity sharedAppIdentity].keychain readDataFromKeychainItemForAccount:OCCertificateKeychainAccount path:OCCertificateKeychainPath]) != nil)
		{
			userAcceptedCertificates = [NSKeyedUnarchiver unarchiveObjectWithData:storedUserAcceptedCertificatesData];
		}
		
		// Alternatively, create an empty set
		if (userAcceptedCertificates == nil)
		{
			userAcceptedCertificates = [NSMutableSet new];
		}
		
		// Populate SHA256 hashes
		for (OCCertificate *certificate in userAcceptedCertificates)
		{
			NSData *sha256Fingerprint;
		
			if ((sha256Fingerprint = [certificate sha256Fingerprint]) != nil)
			{
				[userAcceptedCertificatesBySHA256Fingerprints setObject:certificate forKey:sha256Fingerprint];
			}
		}
	});
	
	@synchronized(self)
	{
		mutationBlock(userAcceptedCertificates, userAcceptedCertificatesBySHA256Fingerprints);
	}
}

+ (NSArray<OCCertificate *> *)userAcceptedCertificates
{
	__block NSArray<OCCertificate *> *returnUserAcceptedCertificates = nil;
	
	[self _mutateUserAcceptedCertificates:^(NSMutableSet<OCCertificate *> *userAcceptedCertificates, NSMutableDictionary<NSData *, OCCertificate *> *userAcceptedCertificatesBySHA256Fingerprints) {
		returnUserAcceptedCertificates = [userAcceptedCertificates allObjects];
	}];
	
	return (returnUserAcceptedCertificates);
}

+ (void)_saveUserAcceptedCertificates
{
	[self _mutateUserAcceptedCertificates:^(NSMutableSet<OCCertificate *> *userAcceptedCertificates, NSMutableDictionary<NSData *, OCCertificate *> *userAcceptedCertificatesBySHA256Fingerprints) {
		NSData *userAcceptedCertificatesData = nil;

		// Serialize user-accepted certificates
		if (userAcceptedCertificates != nil)
		{
			if (userAcceptedCertificates.count > 0)
			{
				userAcceptedCertificatesData = [NSKeyedArchiver archivedDataWithRootObject:userAcceptedCertificates];
			}
		}
	
		// Save to keychain
		[[OCAppIdentity sharedAppIdentity].keychain writeData:userAcceptedCertificatesData toKeychainItemForAccount:OCCertificateKeychainAccount path:OCCertificateKeychainPath];
	}];
}

#pragma mark - Init & Dealloc
+ (instancetype)certificateWithCertificateRef:(SecCertificateRef)certificateRef hostName:(NSString *)hostName
{
	return ([[self alloc] initWithCertificateRef:certificateRef hostName:hostName]);
}

+ (instancetype)certificateWithCertificateData:(NSData *)certificateData hostName:(NSString *)hostName
{
	return ([[self alloc] initWithCertificateData:certificateData hostName:hostName]);
}

+ (instancetype)certificateWithTrustRef:(SecTrustRef)trustRef hostName:(NSString *)hostName
{
	return ([[self alloc] initWithCertificateTrustRef:trustRef hostName:hostName]);
}

- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_userAcceptedDate = [NSDate date];
	}
	
	return(self);
}

- (instancetype)initWithCertificateRef:(SecCertificateRef)certificateRef hostName:(NSString *)hostName
{
	if ((self = [self init]) != nil)
	{
		_certificateRef = certificateRef;
		CFRetain(_certificateRef);

		_hostName = hostName;
	}
	
	return(self);
}

- (instancetype)initWithCertificateData:(NSData *)certificateData hostName:(NSString *)hostName
{
	if ((self = [self init]) != nil)
	{
		_certificateData = certificateData;
		_hostName = hostName;
	}
	
	return(self);
}

- (instancetype)initWithCertificateTrustRef:(SecTrustRef)trustRef hostName:(NSString *)hostName
{
	if ((self = [self init]) != nil)
	{
		_trustRef = trustRef;
		CFRetain(_trustRef);

		_hostName = hostName;
	}
	
	return(self);
}

- (void)dealloc
{
	self.certificateRef = NULL;

	if (_publicKey != NULL)
	{
		CFRelease(_publicKey);
		_publicKey = NULL;
	}
}

#pragma mark - Getters and Setters
- (SecCertificateRef)certificateRef
{
	@synchronized(self)
	{
		if ((_certificateRef==NULL) && (_certificateData != nil))
		{
			_certificateRef = SecCertificateCreateWithData(kCFAllocatorDefault, (__bridge CFDataRef)_certificateData);
		}

		if ((_certificateRef==NULL) && (_trustRef != NULL))
		{
			CFIndex certificateCount = SecTrustGetCertificateCount(_trustRef);

			if (certificateCount > 0)
			{
				OCCertificate *topCertificate = self;

				for (CFIndex idx=0; idx < certificateCount; idx++)
				{
					if (idx == 0)
					{
						if ((_certificateRef = SecTrustGetCertificateAtIndex(_trustRef, idx)) != NULL)
						{
							CFRetain(_certificateRef);
						}
					}
					else
					{
						SecCertificateRef parentCertificateRef;

						if ((parentCertificateRef = SecTrustGetCertificateAtIndex(_trustRef, idx)) != NULL)
						{
							OCCertificate *parentCertificate;

							if ((parentCertificate = [OCCertificate certificateWithCertificateRef:parentCertificateRef hostName:nil]) != nil)
							{
								topCertificate.parentCertificate = parentCertificate;
								topCertificate = parentCertificate;
							}
						}
					}
				}
			}
		}

		return (_certificateRef);
	}
}

- (void)setCertificateRef:(SecCertificateRef)certificateRef
{
	@synchronized(self)
	{
		if (certificateRef != NULL)
		{
			CFRetain(certificateRef);
		}

		if (_certificateRef != NULL)
		{
			CFRelease(_certificateRef);
		}
		
		_certificateRef = certificateRef;
		
		// Clear other representations
		_certificateData = nil;
		
		if (_trustRef != NULL)
		{
			CFRelease(_trustRef);
			_trustRef = NULL;
		}
		
		[self _clearFingerPrints];
	}
}

- (NSData *)certificateData
{
	@synchronized(self)
	{
		if ((_certificateData==nil) && (_certificateRef==NULL) && (_trustRef!=NULL))
		{
			// Attempt to get a certificateRef from the trustRef, which is then converted to the data in the next step
			[self certificateRef];
		}

		if ((_certificateData==nil) && (_certificateRef!=NULL))
		{
			_certificateData = (NSData *)CFBridgingRelease(SecCertificateCopyData(_certificateRef));
		}
	
		return (_certificateData);
	}
}

- (void)setCertificateData:(NSData *)certificateData
{
	@synchronized(self)
	{
		_certificateData = certificateData;
		
		// Clear other representations
		if (_certificateRef != NULL)
		{
			CFRelease(_certificateRef);
			_certificateRef = NULL;
		}

		if (_trustRef != NULL)
		{
			CFRelease(_trustRef);
			_trustRef = NULL;
		}
		
		[self _clearFingerPrints];
	}
}

- (SecTrustRef)trustRef
{
	@synchronized(self)
	{
		if (_trustRef == NULL)
		{
			SecCertificateRef certificateRef;
		
			if ((certificateRef = self.certificateRef) != NULL)
			{
				SecPolicyRef policyRef;

				if ((policyRef = SecPolicyCreateSSL(true, (__bridge CFStringRef)_hostName)) != NULL)
				{
					NSArray <OCCertificate *> *certificateChain = [self chainInReverse:NO];
					NSMutableArray *certificateRefs = [NSMutableArray new];

					for (OCCertificate *certificate in certificateChain)
					{
						SecCertificateRef certificateRef;

						if ((certificateRef = certificate.certificateRef) != NULL)
						{
							[certificateRefs addObject:(__bridge id)certificateRef];
						}
					}

					SecTrustCreateWithCertificates((__bridge CFArrayRef)certificateRefs, policyRef, &_trustRef);
					
					CFRelease(policyRef);
				}
			}
		}

		return (_trustRef);
	}
}

- (void)setTrustRef:(SecTrustRef)trustRef
{
	@synchronized(self)
	{
		if (trustRef != NULL)
		{
			CFRetain(trustRef);
		}

		if (_trustRef != NULL)
		{
			CFRelease(_trustRef);
		}
		
		_trustRef = trustRef;
		
		// Clear other representations
		_certificateData = nil;

		if (_certificateRef != NULL)
		{
			CFRelease(_certificateRef);
			_certificateRef = NULL;
		}

		[self _clearFingerPrints];

		// Clear parent certificate
		_parentCertificate = nil;
	}
}

- (OCCertificate *)parentCertificate
{
	@synchronized (self)
	{
		if (_trustRef != NULL)
		{
			// Ensure the SecTrustRef has been parsed into certificates and parent certificate
			[self certificateRef];
		}

		return (_parentCertificate);
	}
}

- (void)setParentCertificate:(OCCertificate *)parentCertificate
{
	@synchronized (self)
	{
		_parentCertificate = parentCertificate;
	}
}

- (BOOL)userAccepted
{
	__block BOOL userAccepted = NO;
	NSData *sha256Fingerprint;
	
	if ((sha256Fingerprint = [self sha256Fingerprint]) != nil)
	{
		[[self class] _mutateUserAcceptedCertificates:^(NSMutableSet<OCCertificate *> *userAcceptedCertificates, NSMutableDictionary<NSData *, OCCertificate *> *userAcceptedCertificatesBySHA256Fingerprints) {
			OCCertificate *savedCertificate = userAcceptedCertificatesBySHA256Fingerprints[sha256Fingerprint];

			userAccepted = (savedCertificate != nil);
			
			if (savedCertificate != self)
			{
				self->_userAcceptedDate = savedCertificate.userAcceptedDate;
			}
		}];
	}
	
	return (userAccepted);
}

- (void)setUserAccepted:(BOOL)userAccepted
{
	NSData *sha256Fingerprint;
	
	if ((sha256Fingerprint = [self sha256Fingerprint]) != nil)
	{
		[[self class] _mutateUserAcceptedCertificates:^(NSMutableSet<OCCertificate *> *userAcceptedCertificates, NSMutableDictionary<NSData *, OCCertificate *> *userAcceptedCertificatesBySHA256Fingerprints) {
			if (userAccepted)
			{
				// Add if not already in there
				if (userAcceptedCertificatesBySHA256Fingerprints[sha256Fingerprint] == nil)
				{
					[userAcceptedCertificates addObject:self];
					[userAcceptedCertificatesBySHA256Fingerprints setObject:self forKey:sha256Fingerprint];
					
					// Save accepted date
					self->_userAcceptedDate = [NSDate date];

					// Save change
					[[self class] _saveUserAcceptedCertificates];
				}
			}
			else
			{
				// Remove
				OCCertificate *storedCertificate;
				
				if ((storedCertificate = userAcceptedCertificatesBySHA256Fingerprints[sha256Fingerprint]) != nil)
				{
					[userAcceptedCertificates removeObject:storedCertificate];
					[userAcceptedCertificatesBySHA256Fingerprints removeObjectForKey:sha256Fingerprint];
				}
				
				// Wipe accepted date
				self->_userAcceptedDate = nil;

				// Save change
				[[self class] _saveUserAcceptedCertificates];
			}
		}];
	}

	[[NSNotificationCenter defaultCenter] postNotificationName:OCCertificateUserAcceptanceDidChangeNotification object:self];
}

- (NSDate *)userAcceptedDate
{
	if (_userAcceptedDate==nil)
	{
		NSData *sha256Fingerprint;
		
		if ((sha256Fingerprint = [self sha256Fingerprint]) != nil)
		{
			[[self class] _mutateUserAcceptedCertificates:^(NSMutableSet<OCCertificate *> *userAcceptedCertificates, NSMutableDictionary<NSData *, OCCertificate *> *userAcceptedCertificatesBySHA256Fingerprints) {
				OCCertificate *savedCertificate;
				
				if ((savedCertificate = userAcceptedCertificatesBySHA256Fingerprints[sha256Fingerprint]) != nil)
				{
					if (savedCertificate != self)
					{
						self->_userAcceptedDate = savedCertificate.userAcceptedDate;
					}
				}
			}];
		}
	}
	
	return (_userAcceptedDate);
}

#pragma mark - Common name
- (NSString *)commonName
{
	@synchronized(self)
	{
		if (_commonName == nil)
		{
			SecCertificateRef certificateRef;

			if ((certificateRef = self.certificateRef) != NULL)
			{
				CFStringRef commonNameString = NULL;

				if (SecCertificateCopyCommonName(certificateRef, &commonNameString) == noErr)
				{
					_commonName = CFBridgingRelease(commonNameString);
				}
			}
		}

		return (_commonName);
	}
}

#pragma mark - Evaluation
- (void)evaluateWithCompletionHandler:(void(^)(OCCertificate *certificate, OCCertificateValidationResult validationResult, NSError *error))completionHandler
{
	dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
		SecTrustRef trustRef;

		if ((trustRef = self.trustRef) != NULL)
		{
			OSStatus status;
			SecTrustResultType trustResult;

			if ((status = SecTrustGetTrustResult(trustRef, &trustResult)) != errSecSuccess)
			{
				status = SecTrustEvaluate(trustRef, &trustResult);
			}

			// OCLogDebug(@"Server trust: %@ Status: %d Result: %d", trustRef, status, trustResult);

			if (status == errSecSuccess)
			{
				OCCertificateValidationResult validationResult = OCCertificateValidationResultError;
				
				switch (trustResult)
				{
					case kSecTrustResultDeny:
						// User explicitly chose to not trust this certificate
						
						// -> Reject
						validationResult = OCCertificateValidationResultReject;
					break;

					case kSecTrustResultRecoverableTrustFailure:
						// Don't trust the chain as-is (often indicating self-signed), ask user
						
						if (self.userAccepted)
						{
							// -> Proceed
							validationResult = OCCertificateValidationResultUserAccepted;
						}
						else
						{
							// -> Prompt User
							validationResult = OCCertificateValidationResultPromptUser;
						}
					break;
					
					case kSecTrustResultProceed:
						// User explicitly chose to trust this certificate
					case kSecTrustResultUnspecified:
						// Evaluation went fine. Apple recommends most apps should be default trust this chain.
						
						// -> Proceed
						validationResult = OCCertificateValidationResultPassed;
					break;

					case kSecTrustResultFatalTrustFailure:
						// Critical defect in certificate chain makes evaluation fail
					case kSecTrustResultOtherError:
						// Certificate may have been revoked - or an OS-level error has occured
					case kSecTrustResultInvalid:
						// Usually indicates an internal SecTrustEvaluate error
					default:
						// Avoid deprecation warning for kSecTrustResultConfirm (which is no longer used)
						
						// -> Error
						validationResult = OCCertificateValidationResultError;
					break;
				}
				
				completionHandler(self, validationResult, nil);
			}
			else
			{
				// Evaluation of trust failed
				completionHandler(self, OCCertificateValidationResultError, [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil]);
			}
		}
		else
		{
			// ERROR
			completionHandler(self, OCCertificateValidationResultError, nil);
		}
	});
}

#pragma mark - Public Key
- (SecKeyRef)publicKey
{
	if (_publicKey == NULL)
	{
		SecCertificateRef certificateRef;

		if ((certificateRef = self.certificateRef) != NULL)
		{
			_publicKey = SecCertificateCopyPublicKey(self.certificateRef);
		}
	}

	return (_publicKey);
}

- (NSData *)publicKeyDataWithError:(NSError **)error
{
	if (_publicKeyData == NULL)
	{
		SecKeyRef keyRef;

		if ((keyRef = self.publicKey) != NULL)
		{
			CFErrorRef errorRef = NULL;
			CFDataRef keyDataRef = NULL;

			if ((keyDataRef = SecKeyCopyExternalRepresentation(keyRef, &errorRef)) != NULL)
			{
				_publicKeyData = CFBridgingRelease(keyDataRef);
			}

			if ((errorRef != NULL) && (error!=NULL))
			{
				*error = CFBridgingRelease(errorRef);
			}
		}
	}

	return (_publicKeyData);
}

#pragma mark - Digests
- (void)_clearFingerPrints
{
	_md5FingerPrint = nil;
	_sha1FingerPrint = nil;
	_sha256FingerPrint = nil;
}

- (NSData *)md5Fingerprint
{
	@synchronized(self)
	{
		if (_md5FingerPrint==nil)
		{
			_md5FingerPrint = [[self certificateData] md5Hash];
		}
		
		return (_md5FingerPrint);
	}
}

- (NSData *)sha1Fingerprint
{
	@synchronized(self)
	{
		if (_sha1FingerPrint==nil)
		{
			_sha1FingerPrint = [[self certificateData] sha1Hash];
		}
		
		return (_sha1FingerPrint);
	}
}

- (NSData *)sha256Fingerprint
{
	@synchronized(self)
	{
		if (_sha256FingerPrint==nil)
		{
			_sha256FingerPrint = [[self certificateData] sha256Hash];
		}
		
		return (_sha256FingerPrint);
	}
}


#pragma mark - NSSecureCoding
+ (BOOL)supportsSecureCoding
{
	return(YES);
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
	if ((self = [self init]) != nil)
	{
		_hostName = [decoder decodeObjectOfClass:[NSString class] forKey:@"hostName"];
		_certificateData = [decoder decodeObjectOfClass:[NSData class] forKey:@"certificateData"];

		_userAcceptedDate = [decoder decodeObjectOfClass:[NSDate class] forKey:@"userAcceptedDate"];

		_parentCertificate = [decoder decodeObjectOfClass:[OCCertificate class] forKey:@"parentCertificate"];
	}
	
	return (self);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:self.hostName forKey:@"hostName"];
	[coder encodeObject:self.certificateData forKey:@"certificateData"];

	[coder encodeObject:self.userAcceptedDate forKey:@"userAcceptedDate"];

	[coder encodeObject:self.parentCertificate forKey:@"parentCertificate"];
}

#pragma mark - Comparisons
- (BOOL)hasIdenticalPublicKeyAs:(OCCertificate *)otherCertificate error:(NSError * _Nullable * _Nullable )error
{
	BOOL isIdentical = NO;
	NSError *publicKeyDataError = nil;
	NSData *publicKeyData;

	if ((publicKeyData = [self publicKeyDataWithError:&publicKeyDataError]) != nil)
	{
		NSData *otherCertificatePublicKeyData;

		if ((otherCertificatePublicKeyData = [otherCertificate publicKeyDataWithError:&publicKeyDataError]) != nil)
		{
			isIdentical = [otherCertificatePublicKeyData isEqualToData:publicKeyData];
		}
		else
		{
			NSLog(@"Failed to extract public key from otherCertificate with error=%@", publicKeyDataError);
		}
	}
	else
	{
		NSLog(@"Failed to extract public key from certificate with error=%@", publicKeyDataError);
	}

	if (error != NULL)
	{
		*error = publicKeyDataError;
	}

	return (isIdentical);
}

#pragma mark - Comparison support
- (BOOL)isEqual:(id)object
{
	if ([object isKindOfClass:[OCCertificate class]])
	{
		// Compare hashes
		if (((OCCertificate *)object).hash == self.hash)
		{
			// Compare SHA 256 fingerprint data
			return ([[((OCCertificate *)object) sha256Fingerprint] isEqualToData:[self sha256Fingerprint]]);
		}
	}
	
	return (NO);
}

- (NSUInteger)hash
{
	return (self.certificateData.hash ^ self.hostName.hash ^ ((NSUInteger)0x1827364554637281)); // Use hash of certificateData and hostName
}

#pragma mark - Chain
- (OCCertificate *)rootCertificate
{
	OCCertificate *rootCertificate = self;

	while (rootCertificate.parentCertificate != nil)
	{
		rootCertificate = rootCertificate.parentCertificate;
	};

	return (rootCertificate);
}

- (NSArray <OCCertificate *> *)chainInReverse:(BOOL)inReverse
{
	if (self.parentCertificate != nil)
	{
		OCCertificate *certificate = self;
		NSMutableArray<OCCertificate *> *certificateChain = [NSMutableArray new];

		while (certificate != nil)
		{
			if (inReverse)
			{
				[certificateChain insertObject:certificate atIndex:0];
			}
			else
			{
				[certificateChain addObject:certificate];
			}

			certificate = certificate.parentCertificate;
		};

		return (certificateChain);
	}
	else
	{
		return (@[ self ]);
	}
}

+ (OCCertificate *)assembleChain:(NSArray <OCCertificate *> *)certificates
{
	OCCertificate *previousCertificate = nil;

	for (OCCertificate *certificate in certificates)
	{
		certificate.parentCertificate = previousCertificate;
		previousCertificate = certificate;
	}

	return (previousCertificate);
}

#pragma mark - Description
- (NSString *)description
{
	return ([NSString stringWithFormat:@"<%@: %p%@%@%@>", NSStringFromClass(self.class), self, ((self.hostName != nil) ? [NSString stringWithFormat:@", hostName=%@", self.hostName] : @""),  ((self.commonName != nil) ? [NSString stringWithFormat:@", commonName=%@", self.commonName] : @""), ((self.parentCertificate != nil) ? [NSString stringWithFormat:@", parent: %@", self.parentCertificate] : @"")]);
}

@end

NSNotificationName OCCertificateUserAcceptanceDidChangeNotification = @"OCCertificateUserAcceptanceDidChangeNotification";
