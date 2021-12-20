//
//  NSError+OCErrorTools.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 20.12.21.
//  Copyright © 2021 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2021, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "NSError+OCErrorTools.h"
#import "NSError+OCError.h"
#import "OCHTTPRequest.h"

@implementation NSError (OCErrorTools)

- (BOOL)isAuthenticationError
{
	return ([self isOCErrorWithCode:OCErrorAuthorizationFailed] ||
		[self isOCErrorWithCode:OCErrorAuthorizationMethodNotAllowed] ||
		[self isOCErrorWithCode:OCErrorAuthorizationMethodUnknown] ||
		[self isOCErrorWithCode:OCErrorAuthorizationNoMethodData] ||
		[self isOCErrorWithCode:OCErrorAuthorizationNotMatchingRequiredUserID] ||
		[self isOCErrorWithCode:OCErrorAuthorizationMissingData] ||

		([self.domain isEqual:OCHTTPStatusErrorDomain] && (self.code == OCHTTPStatusCodeUNAUTHORIZED)));
}

@end
