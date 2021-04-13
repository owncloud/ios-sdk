//
//  OCAuthenticationMethodBasicAuth.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 24.02.18.
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

#import "OCAuthenticationMethod.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCAuthenticationMethodBasicAuth : OCAuthenticationMethod

+ (nullable NSData *)authenticationDataForUsername:(NSString *)userName passphrase:(NSString *)passPhrase authenticationHeaderValue:(NSString * _Nullable * _Nullable)outAuthenticationHeaderValue error:(NSError * _Nullable * _Nullable)outError; //!< Generates authentication data for basic auth without reaching out to the server. Useful for building tests. Should not be used for anything other than implementing tests.

@end

extern OCAuthenticationMethodIdentifier OCAuthenticationMethodIdentifierBasicAuth;

NS_ASSUME_NONNULL_END
