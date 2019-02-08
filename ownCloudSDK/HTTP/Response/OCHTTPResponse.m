//
//  OCHTTPResponse.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 06.02.19.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2019, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCHTTPResponse.h"
#import "OCHTTPRequest.h"

@implementation OCHTTPResponse

@synthesize bodyData = _bodyData;

+ (instancetype)responseWithRequest:(OCHTTPRequest *)request HTTPError:(nullable NSError *)error
{
	return ([[self alloc] initWithRequest:request HTTPError:error]);
}

- (instancetype)initWithRequest:(OCHTTPRequest *)request HTTPError:(nullable NSError *)error
{
	if ((self = [super init]) != nil)
	{
		_requestID = request.identifier;
		_httpError = error;
	}

	return(self);
}

@end
