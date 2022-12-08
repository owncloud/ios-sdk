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

NS_ASSUME_NONNULL_BEGIN

@interface OCCertificateStore : NSObject <NSSecureCoding>

#pragma mark - Store & retrieve certificates
- (void)storeCertificate:(OCCertificate *)certificate forHostname:(NSString *)hostname; //!< Stores the provided certificate for the provided hostname
- (nullable OCCertificate *)certificateForHostname:(NSString *)hostname lastModified:(NSDate * _Nullable * _Nullable)outLastModified; //!< Returns the 

- (nullable NSArray<NSString *> *)hostnamesForCertificate:(OCCertificate *)certificate; //!< Returns all host names (or nil) for which the provided certificate is stored

#pragma mark - Remove certificates
- (BOOL)removeCertificateForHostname:(NSString *)hostname; //!< Returns YES if a certificate for the provided hostname was removed

@end

NS_ASSUME_NONNULL_END
