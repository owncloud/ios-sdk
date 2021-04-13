//
//  OCCertificate+OpenSSL.m
//  ownCloudUI
//
//  Created by Felix Schwarz on 13.03.18.
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

#import "OCCertificate+OpenSSL.h"

#import <ownCloudSDK/NSError+OCError.h>
#import <ownCloudSDK/OCLogger.h>
#import <ownCloudSDK/NSData+OCHash.h>
#import <ownCloudSDK/OCExtension+License.h>

#import <openssl/pem.h>
#import <openssl/conf.h>
#import <openssl/x509v3.h>
#import <openssl/pkcs12.h>

@implementation OCCertificate (OpenSSL)

+ (void)load
{
	[[OCExtensionManager sharedExtensionManager] addExtension:[OCExtension licenseExtensionWithIdentifier:@"license.openssl" bundle:[NSBundle bundleWithIdentifier:@"com.owncloud.openssl"] title:@"OpenSSL" resourceName:@"LICENSE" fileExtension:nil]];
}

+ (void)_initializeOpenSSL
{
	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		OpenSSL_add_all_algorithms();
		OpenSSL_add_all_ciphers();
		OpenSSL_add_all_digests();
	});
}

- (NSString *)_prettifyHexString:(NSString *)hexString
{
	NSMutableString *prettyString = [[NSMutableString alloc] initWithString:hexString];

	for (NSUInteger insertIndex = (hexString.length - (hexString.length % 2)); insertIndex > 0; insertIndex -= 2)
	{
		if (insertIndex != hexString.length)
		{
			[prettyString insertString:@" " atIndex:insertIndex];
		}
	}

	return (prettyString);
}

- (NSString *)_stringFromASN1String:(ASN1_STRING *)asn1String
{
	unsigned char *utf8String = NULL;
	int length = 0;
	NSString *string = nil;

	if ((length = ASN1_STRING_to_UTF8(&utf8String, asn1String)) > 0)
	{
		string = [[NSString alloc] initWithBytes:utf8String length:length encoding:NSUTF8StringEncoding];

		OPENSSL_free(utf8String);
	}

	return (string);
}

- (NSString *)_hexStringFromBigNum:(BIGNUM *)asn1BigNum
{
	char *bigNumHexString;
	NSString *hexString = nil;

	if ((bigNumHexString = BN_bn2hex(asn1BigNum)) != NULL)
	{
		hexString = [self _prettifyHexString:[NSString stringWithUTF8String:bigNumHexString]];

		OPENSSL_free(bigNumHexString);
	}

	return (hexString);
}

- (NSString *)_hexStringFromASN1Integer:(ASN1_INTEGER *)asn1Integer
{
	BIGNUM *asn1BigNum;
	NSString *hexString = nil;

	if ((asn1BigNum = ASN1_INTEGER_to_BN(asn1Integer, NULL)) != NULL)
	{
		hexString = [self _hexStringFromBigNum:asn1BigNum];

		BN_free(asn1BigNum);
	}

	return (hexString);
}

- (NSDictionary<OCCertificateMetadataKey, id> *)_keyValuePairsForX509Name:(X509_NAME *)x509Name
{
	NSMutableDictionary<OCCertificateMetadataKey, id> *metaData;

	if ((metaData = [NSMutableDictionary new]) != nil)
	{
		for (int i=0; i < X509_NAME_entry_count(x509Name); i++)
		{
			X509_NAME_ENTRY *nameEntry;

			if ((nameEntry = X509_NAME_get_entry(x509Name, i)) != NULL)
			{
				ASN1_OBJECT *nameEntryASN1Object;

				if ((nameEntryASN1Object = X509_NAME_ENTRY_get_object(nameEntry)) != NULL)
				{
					ASN1_STRING *asn1String;

					if ((asn1String = X509_NAME_ENTRY_get_data(nameEntry)) != NULL)
					{
						NSString *entryValue, *entryKey;

						char keyName[256];
						memset(&keyName, 0, sizeof(keyName));

						OBJ_obj2txt((char *)&keyName, sizeof(keyName)-1, nameEntryASN1Object, 0);

						if (((entryKey = [NSString stringWithCString:keyName encoding:NSUTF8StringEncoding]) != nil) &&
						    ((entryValue = [self _stringFromASN1String:asn1String]) != nil))
						{
							metaData[entryKey] = entryValue;
						}
					}
				}
			}
		}
	}

	return (metaData);
}

- (NSString *)_nameForAlgorithm:(ASN1_OBJECT *)algorithm
{
	int pkeySignatureAlgorithmNID;
	NSString *algorithmName = nil;

	if ((pkeySignatureAlgorithmNID = OBJ_obj2nid(algorithm)) != NID_undef)
	{
		const char *pkeySignatureAlgorithmName;

		if ((pkeySignatureAlgorithmName = OBJ_nid2sn(pkeySignatureAlgorithmNID)) != NULL)
		{
			if ((algorithmName = [NSString stringWithUTF8String:pkeySignatureAlgorithmName]) != nil)
			{
				NSDictionary <NSString *, NSString *> *prettyNameForAlgorithmName = @{
					@LN_rsaEncryption : @"RSA"
				};

				if (prettyNameForAlgorithmName[algorithmName] != nil)
				{
					algorithmName = prettyNameForAlgorithmName[algorithmName];
				}
			}
		}
	}

	return (algorithmName);
}

- (NSString *)_iso8601DateStringForASN1Time:(ASN1_TIME *)asn1Time
{
	BIO *bio;
	NSString *iso8601DateString = nil;

	if ((bio = BIO_new(BIO_s_mem())) != NULL)
	{
		if (ASN1_TIME_print(bio, asn1Time) > 0)
		{
			long availableBytes;
			char *p_bytes = NULL;

			BIO_flush(bio);

			if ((availableBytes = BIO_get_mem_data(bio, &p_bytes)) != 0)
			{
				iso8601DateString = [[NSString alloc] initWithBytes:(const void *)p_bytes length:availableBytes encoding:NSUTF8StringEncoding];
			}
		}

		BIO_free(bio);
	}

	return (iso8601DateString);
}

- (NSDictionary<OCCertificateMetadataKey, id> *)metaDataWithError:(NSError **)error
{
	NSMutableDictionary<OCCertificateMetadataKey, id> *metaData = nil;
	NSData *x509Data = self.certificateData;
	BOOL certificateParsable = NO;

	[[self class] _initializeOpenSSL];

	if (x509Data !=  nil)
	{
		X509 *x509Cert = NULL;
		const unsigned char *p_x509Data = [x509Data bytes];

		if ((x509Cert = d2i_X509(NULL, &p_x509Data, x509Data.length)) != NULL)
		{
			certificateParsable = YES;

			if ((metaData = [NSMutableDictionary new]) != nil)
			{
				X509_NAME *x509Name;
				ASN1_INTEGER *asn1SerialNumber;
				ASN1_TIME *asn1Time;

				// Parse subject
				if ((x509Name = X509_get_subject_name(x509Cert)) != NULL)
				{
					NSDictionary<OCCertificateMetadataKey, id> *subjectMetaData;

					if ((subjectMetaData = [self _keyValuePairsForX509Name:x509Name]) != nil)
					{
						metaData[OCCertificateMetadataSubjectKey] = subjectMetaData;
					}
				}

				// Parse issuer
				if ((x509Name = X509_get_issuer_name(x509Cert)) != NULL)
				{
					NSDictionary<OCCertificateMetadataKey, id> *issuerMetaData;

					if ((issuerMetaData = [self _keyValuePairsForX509Name:x509Name]) != nil)
					{
						metaData[OCCertificateMetadataIssuerKey] = issuerMetaData;
					}
				}

				// Version
				metaData[OCCertificateMetadataVersionKey] = @(X509_get_version(x509Cert)+1);

				// Serial Number
				if ((asn1SerialNumber = X509_get_serialNumber(x509Cert)) != NULL)
				{
					metaData[OCCertificateMetadataSerialNumberKey] = [self _hexStringFromASN1Integer:asn1SerialNumber];
				}

				// Certificate Signature Algorithm
				if ((x509Cert->cert_info!=NULL) && (x509Cert->cert_info->signature!=NULL) && (x509Cert->cert_info->signature->algorithm!=NULL))
				{
					NSString *algorithmName;

					if ((algorithmName = [self _nameForAlgorithm:x509Cert->cert_info->signature->algorithm]) != nil)
					{
						metaData[OCCertificateMetadataSignatureAlgorithmKey] = algorithmName;
					}
				}

				// Public Key
				if ((x509Cert->cert_info!=NULL) && (x509Cert->cert_info->key!=NULL))
				{
					NSMutableDictionary <NSString *, id> *publicKeyDict = [NSMutableDictionary new];

					// Public Key Signature Algorithm
					if ((x509Cert->cert_info->key->algor!=NULL) && (x509Cert->cert_info->key->algor->algorithm!=NULL))
					{
						NSString *algorithmName;

						if ((algorithmName = [self _nameForAlgorithm:x509Cert->cert_info->key->algor->algorithm]) != nil)
						{
							publicKeyDict[OCCertificateMetadataSignatureAlgorithmKey] = algorithmName;
						}
					}

					// Key bytes
					EVP_PKEY *evpPKey;

					if ((evpPKey = X509_get_pubkey(x509Cert)) != NULL)
					{
						BIO *bio;

						if ((bio = BIO_new(BIO_s_mem())) != NULL)
						{
							switch (EVP_PKEY_base_id(evpPKey))
							{
								case EVP_PKEY_RSA: {
									RSA *rsa;

									if ((rsa = EVP_PKEY_get1_RSA(evpPKey)) != NULL)
									{
										if (rsa->e != NULL)
										{
											publicKeyDict[OCCertificateMetadataKeyExponentKey] = @(BN_get_word(rsa->e)); // Exponent
										}

										if (rsa->n != NULL)
										{
											publicKeyDict[OCCertificateMetadataKeyBytesKey] = [self _hexStringFromBigNum:rsa->n]; // Modulus
										}

										publicKeyDict[OCCertificateMetadataKeySizeInBitsKey] = @(RSA_size(rsa)*8); // Key size in bits
									}
								}
								break;

								case EVP_PKEY_DSA:
								case EVP_PKEY_DH:
								case EVP_PKEY_EC:
								default: {

									if (EVP_PKEY_print_public(bio, evpPKey, 0, NULL) > 0)
									{
										long availableBytes;
										char *p_bytes = NULL;

										BIO_flush(bio);

										if ((availableBytes = BIO_get_mem_data(bio, &p_bytes)) > 0)
										{
											if (p_bytes != NULL)
											{
												publicKeyDict[OCCertificateMetadataKeyInformationKey] = [[NSString alloc] initWithBytes:(const void *)p_bytes length:availableBytes encoding:NSUTF8StringEncoding];
											}
										}
									}
								}
								break;
							}

							BIO_free(bio);
						}

						EVP_PKEY_free(evpPKey);
					}

					// Save content to metaData
					if (publicKeyDict.count > 0)
					{
						metaData[OCCertificateMetadataPublicKeyKey] = publicKeyDict;
					}
				}

				if ((x509Cert->cert_info!=NULL) && (x509Cert->cert_info->validity!=NULL))
				{
					// Validity from
					if ((asn1Time = X509_get_notBefore(x509Cert)) != NULL)
					{
						NSString *iso8601DateString;

						if ((iso8601DateString = [self _iso8601DateStringForASN1Time:asn1Time]) != nil)
						{
							metaData[OCCertificateMetadataValidFromKey] = iso8601DateString;
						}
					}

					// Validity until
					if ((asn1Time = X509_get_notAfter(x509Cert)) != NULL)
					{
						NSString *iso8601DateString;

						if ((iso8601DateString = [self _iso8601DateStringForASN1Time:asn1Time]) != nil)
						{
							metaData[OCCertificateMetadataValidUntilKey] = iso8601DateString;
						}
					}
				}

				// Extensions
				if ((x509Cert->cert_info!=NULL) && (x509Cert->cert_info->extensions!=NULL))
				{
					STACK_OF(X509_EXTENSION) *x509Extensions = x509Cert->cert_info->extensions;
					long numOfExtensions;

					if ((numOfExtensions = sk_X509_EXTENSION_num(x509Extensions)) > 0)
					{
						NSMutableArray <NSDictionary<NSString*,NSString*> *> *extensions = [NSMutableArray new];

						for (int i=0; i<numOfExtensions; i++)
						{
							X509_EXTENSION *x509Extension;

							if ((x509Extension = sk_X509_EXTENSION_value(x509Extensions, i)) != NULL)
							{
								int extensionNID;
								const char *extensionNameBuffer;
								const char *extensionIdentifierBuffer;

								extensionNID = OBJ_obj2nid(x509Extension->object);
								extensionNameBuffer = OBJ_nid2ln(extensionNID);
								extensionIdentifierBuffer = OBJ_nid2sn(extensionNID);

								NSString *extensionInfo = nil;
								NSString *extensionName = [NSString stringWithCString:extensionNameBuffer encoding:NSUTF8StringEncoding];
								NSString *extensionIdentifier = [NSString stringWithCString:extensionIdentifierBuffer encoding:NSUTF8StringEncoding];

								switch (extensionNID)
								{
									case NID_subject_alt_name:

									// break;

									default: {
										BIO *bio;

										if ((bio = BIO_new(BIO_s_mem())) != NULL)
										{
											if (X509V3_EXT_print(bio, x509Extension, 0, 0) != 0)
											{
												long availableBytes;
												char *p_bytes = NULL;

												BIO_flush(bio);

												if ((availableBytes = BIO_get_mem_data(bio, &p_bytes)) != 0)
												{
													extensionInfo = [[[NSString alloc] initWithBytes:(const void *)p_bytes length:availableBytes encoding:NSUTF8StringEncoding] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
												}
											}

											BIO_free(bio);
										}
									}
									break;
								}

								if ((extensionName != nil) && (extensionInfo != nil) && (extensionIdentifier != nil))
								{
									if ([extensionName hasPrefix:@"X509v3 "])
									{
										extensionName = [extensionName substringFromIndex:7];
									}

									[extensions addObject:@{
										OCCertificateMetadataExtensionIdentifierKey : extensionIdentifier,
										OCCertificateMetadataExtensionNameKey : extensionName,
										OCCertificateMetadataExtensionDescriptionKey : extensionInfo
									}];
								}
							}
						}

						if (extensions.count > 0)
						{
							metaData[OCCertificateMetadataExtensionsKey] = extensions;
						}
					}
				}
			}

			X509_free(x509Cert);
		}
	}

	if (!certificateParsable && (error != NULL))
	{
		*error = OCError(OCErrorCertificateInvalid);
	}

	return (metaData);
}

- (void)certificateDetailsViewNodesComparedTo:(nullable OCCertificate *)previousCertificate withValidationCompletionHandler:(void(^)(NSArray <OCCertificateDetailsViewNode *> *))validationCompletionHandler
{
	[OCCertificateDetailsViewNode certificateDetailsViewNodesForCertificate:self differencesFrom:previousCertificate withValidationCompletionHandler:^(NSArray<OCCertificateDetailsViewNode *> *detailsViewNodes) {
		validationCompletionHandler(detailsViewNodes);
	}];
}

@end

OCCertificateMetadataKey OCCertificateMetadataSubjectKey = @"subject";
OCCertificateMetadataKey OCCertificateMetadataIssuerKey = @"issuer";

OCCertificateMetadataKey OCCertificateMetadataCommonNameKey = @LN_commonName;
OCCertificateMetadataKey OCCertificateMetadataCountryNameKey = @LN_countryName;
OCCertificateMetadataKey OCCertificateMetadataLocalityNameKey = @LN_localityName;
OCCertificateMetadataKey OCCertificateMetadataStateOrProvinceNameKey = @LN_stateOrProvinceName;
OCCertificateMetadataKey OCCertificateMetadataOrganizationNameKey = @LN_organizationName;
OCCertificateMetadataKey OCCertificateMetadataOrganizationUnitNameKey = @LN_organizationalUnitName;
OCCertificateMetadataKey OCCertificateMetadataJurisdictionCountryNameKey = @LN_jurisdictionCountryName;
OCCertificateMetadataKey OCCertificateMetadataJurisdictionLocalityNameKey = @LN_jurisdictionLocalityName;
OCCertificateMetadataKey OCCertificateMetadataJurisdictionStateOrProvinceNameKey = @LN_jurisdictionStateOrProvinceName;
OCCertificateMetadataKey OCCertificateMetadataBusinessCategoryKey = @LN_businessCategory;

OCCertificateMetadataKey OCCertificateMetadataVersionKey = @"version";
OCCertificateMetadataKey OCCertificateMetadataSerialNumberKey = @"serialNumber";
OCCertificateMetadataKey OCCertificateMetadataSignatureAlgorithmKey = @"signatureAlgorithm";

OCCertificateMetadataKey OCCertificateMetadataPublicKeyKey = @"publicKey";

OCCertificateMetadataKey OCCertificateMetadataValidFromKey = @"validFrom";
OCCertificateMetadataKey OCCertificateMetadataValidUntilKey = @"validUntil";

OCCertificateMetadataKey OCCertificateMetadataKeySizeInBitsKey = @"keySizeInBits";
OCCertificateMetadataKey OCCertificateMetadataKeyExponentKey = @"keyExponent";
OCCertificateMetadataKey OCCertificateMetadataKeyBytesKey = @"keyBytes";
OCCertificateMetadataKey OCCertificateMetadataKeyInformationKey = @"keyInformation";

OCCertificateMetadataKey OCCertificateMetadataExtensionsKey = @"extensions";
OCCertificateMetadataKey OCCertificateMetadataExtensionIdentifierKey = @"identifier";
OCCertificateMetadataKey OCCertificateMetadataExtensionNameKey = @"name";
OCCertificateMetadataKey OCCertificateMetadataExtensionDescriptionKey = @"description";

