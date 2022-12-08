//
//  OCCertificateStoreRecord.h
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

@interface OCCertificateStoreRecord : NSObject <NSSecureCoding>

@property(strong) NSString *hostname; //!< Hostname this certificate is used for
@property(strong) NSDate *lastModifiedDate; //!< Date the certificate stored in this record was last modified.
@property(strong) OCCertificate *certificate;

- (instancetype)initWithCertificate:(OCCertificate *)certificate forHostname:(NSString *)hostname;

@end

NS_ASSUME_NONNULL_END
