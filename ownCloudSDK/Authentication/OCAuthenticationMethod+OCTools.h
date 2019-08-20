//
//  OCAuthenticationMethod+OCTools.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 26.02.18.
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

#import "OCConnection.h"
#import "OCAuthenticationMethod.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCAuthenticationMethod (OCTools)

+ (NSString *)basicAuthorizationValueForUsername:(NSString *)username passphrase:(NSString *)passPhrase;

+ (nullable NSArray <NSURL *> *)detectionURLsBasedOnWWWAuthenticateMethod:(NSString *)wwwAuthenticateMethod forConnection:(OCConnection *)connection;

+ (void)detectAuthenticationMethodSupportBasedOnWWWAuthenticateMethod:(NSString *)wwwAuthenticateMethod forConnection:(OCConnection *)connection withServerResponses:(NSDictionary<NSURL *, OCHTTPRequest *> *)serverResponses completionHandler:(void(^)(OCAuthenticationMethodIdentifier _Nullable identifier, BOOL supported))completionHandler;

@end

NS_ASSUME_NONNULL_END
