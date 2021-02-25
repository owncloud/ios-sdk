//
//  NSURLSessionTask+DebugTools.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 09.12.20.
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

#import "OCLogger.h"
#import "OCHTTPRequest.h"
#import "NSURLSessionTask+Debug.h"

@implementation NSURLSessionTask (DebugTools)

- (NSString *)requestIdentityDescription
{
	return ([NSString stringWithFormat:@"taskIdentifier=<%lu>, xRequestID=%@, method=%@, url=%@", self.taskIdentifier, [self.currentRequest valueForHTTPHeaderField:OCHTTPHeaderFieldNameXRequestID], self.currentRequest.HTTPMethod, OCLogPrivate(self.currentRequest.URL.absoluteString)]);
}

@end
