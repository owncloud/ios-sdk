//
//  OCCertificateStore.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 08.12.22.
//  Copyright © 2022 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2022, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import <Foundation/Foundation.h>
#import "OCCertificate.h"
#import "OCCertificateStoreRecord.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCCertificateStore : NSObject <NSSecureCoding>

- (instancetype)initWithMigrationOfCertificate:(OCCertificate *)certificate forHostname:(NSString *)hostname lastModifiedDate:(NSDate *)lastModifiedDate; //!< Convenience initializer for migration from bookmarks without certificate store

#pragma mark - Store & retrieve certificates
- (void)storeCertificate:(OCCertificate *)certificate forHostname:(NSString *)hostname; //!< Stores the provided certificate for the provided hostname
- (nullable OCCertificate *)certificateForHostname:(nullable NSString *)hostname lastModified:(NSDate * _Nullable * _Nullable)outLastModified; //!< Returns the certificate and last modified date for the provided hostname

- (nullable NSArray<NSString *> *)hostnamesForCertificate:(OCCertificate *)certificate; //!< Returns all host names (or nil) for which the provided certificate is stored

@property(readonly,nonatomic,strong) NSArray<OCCertificateStoreRecord *> *allRecords; //!< Returns the contents of the certificate store

#pragma mark - Remove certificates
- (BOOL)removeCertificateForHostname:(NSString *)hostname; //!< Returns YES if a certificate for the provided hostname was removed
- (void)removeAllCertificates; //!< Removes all certificates from the store

@end

NS_ASSUME_NONNULL_END
