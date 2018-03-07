//
//  OCHTTPStatus.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 28.02.18.
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

#import "OCHTTPStatus.h"

@implementation OCHTTPStatus

@synthesize code = _code;

+ (instancetype)HTTPStatusWithCode:(OCHTTPStatusCode)code
{
	OCHTTPStatus *httpStatus = [self new];
	
	httpStatus.code = code;
	
	return (httpStatus);
}

- (BOOL)isSuccess
{
	return ((_code >= 200) && (_code < 300));
}

- (BOOL)isRedirection
{
	return ((_code >= 300) && (_code < 400));
}

- (BOOL)isError
{
	return (_code >= 400);
}

- (NSError *)error
{
	return ([NSError errorWithDomain:OCHTTPStatusErrorDomain code:_code userInfo:nil]);
}

- (NSError *)errorWithURL:(NSURL *)url
{
	return ([NSError errorWithDomain:OCHTTPStatusErrorDomain code:_code userInfo:((url!=nil) ? @{ @"url" : url } : nil)]);
}

- (NSError *)errorWithResponse:(NSHTTPURLResponse *)response
{
	return ([NSError errorWithDomain:OCHTTPStatusErrorDomain code:_code userInfo:((response!=nil) ? @{ @"response" : response } : nil)]);
}

@end

NSErrorDomain OCHTTPStatusErrorDomain = @"OCHTTPStatusErrorDomain";
