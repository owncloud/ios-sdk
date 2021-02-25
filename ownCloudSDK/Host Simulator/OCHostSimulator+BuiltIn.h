//
//  OCHostSimulator+BuiltIn.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 14.10.20.
//  Copyright © 2020 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2020, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCHostSimulator.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCHostSimulator (BuiltIn)

/// Host Simulator to test behaviour where a server redirects (with 302 or 307) to a separate endpoint to clear or set cookies
/// @param requestWithoutCookiesHandler Block that's called by the Host Simulator when it receives the first request without cookies.
/// @param requestForCookiesHandler Block that's called by the Host Simulator when it receives the first request to the set cookies endpoint.
/// @param vrequestWithCookiesHandler Block that's called by the Host Simulator when it receives the first request with cookies.
+ (instancetype)cookieRedirectSimulatorWithRequestWithoutCookiesHandler:(nullable dispatch_block_t)requestWithoutCookiesHandler requestForCookiesHandler:(nullable dispatch_block_t)requestForCookiesHandler requestWithCookiesHandler:(nullable dispatch_block_t)vrequestWithCookiesHandler;

@end

NS_ASSUME_NONNULL_END
