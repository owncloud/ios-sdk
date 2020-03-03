//
//  NSError+OCNetworkFailure.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 24.02.20.
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

#import "NSError+OCNetworkFailure.h"

@implementation NSError (OCNetworkFailure)

- (BOOL)isNetworkFailureError
{
	return  ([self.domain isEqual:NSURLErrorDomain] && (
			(self.code == NSURLErrorDNSLookupFailed) ||
			(self.code == NSURLErrorCannotFindHost) ||
			(self.code == NSURLErrorCannotConnectToHost) ||
			(self.code == NSURLErrorNotConnectedToInternet) ||
			(self.code == NSURLErrorNetworkConnectionLost) ||
			(self.code == NSURLErrorDataNotAllowed) ||
			(self.code == NSURLErrorInternationalRoamingOff) ||
			(self.code == NSURLErrorCallIsActive)
		));
}

@end
