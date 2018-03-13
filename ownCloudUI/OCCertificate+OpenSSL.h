//
//  OCCertificate+OpenSSL.h
//  ownCloudUI
//
//  Created by Felix Schwarz on 13.03.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

#import <ownCloudSDK/OCCertificate.h>

typedef NSString* OCCertificateMetadataKey NS_TYPED_ENUM;

@interface OCCertificate (OpenSSL)

- (NSDictionary<OCCertificateMetadataKey, id> *)metaDataWithError:(NSError **)error;

// - (NSAttributedString *)metaDataStringWithTitleFont:(UIFont *)titleFont itemFont:(UIFont *)itemFont valueFont:(UIFont *)valueFont fixedFont:(UIFont *)fixedFont;

@end

extern OCCertificateMetadataKey OCCertificateMetadataSubjectKey;
extern OCCertificateMetadataKey OCCertificateMetadataIssuerKey;

extern OCCertificateMetadataKey OCCertificateMetadataCommonNameKey;
extern OCCertificateMetadataKey OCCertificateMetadataCountryNameKey;
extern OCCertificateMetadataKey OCCertificateMetadataLocalityNameKey;
extern OCCertificateMetadataKey OCCertificateMetadataStateOrProvinceNameKey;
extern OCCertificateMetadataKey OCCertificateMetadataOrganizationNameKey;
extern OCCertificateMetadataKey OCCertificateMetadataOrganizationUnitNameKey;
extern OCCertificateMetadataKey OCCertificateMetadataJurisdictionCountryNameKey;
extern OCCertificateMetadataKey OCCertificateMetadataJurisdictionLocalityNameKey;
extern OCCertificateMetadataKey OCCertificateMetadataJurisdictionStateOrProvinceNameKey;
extern OCCertificateMetadataKey OCCertificateMetadataBusinessCategoryKey;

extern OCCertificateMetadataKey OCCertificateMetadataVersionKey;
extern OCCertificateMetadataKey OCCertificateMetadataSerialNumberKey;
extern OCCertificateMetadataKey OCCertificateMetadataSignatureAlgorithmKey;

extern OCCertificateMetadataKey OCCertificateMetadataPublicKeyKey;

extern OCCertificateMetadataKey OCCertificateMetadataValidFromKey;
extern OCCertificateMetadataKey OCCertificateMetadataValidUntilKey;

extern OCCertificateMetadataKey OCCertificateMetadataKeySizeInBitsKey;
extern OCCertificateMetadataKey OCCertificateMetadataKeyExponentKey;
extern OCCertificateMetadataKey OCCertificateMetadataKeyBytesKey;
extern OCCertificateMetadataKey OCCertificateMetadataKeyInformationKey;

extern OCCertificateMetadataKey OCCertificateMetadataExtensionsKey;
extern OCCertificateMetadataKey OCCertificateMetadataExtensionIdentifierKey;
extern OCCertificateMetadataKey OCCertificateMetadataExtensionNameKey;
extern OCCertificateMetadataKey OCCertificateMetadataExtensionDescriptionKey;
