//
//  OCHostSimulatorResponse.m
//  ownCloudSDKTests
//
//  Created by Felix Schwarz on 20.03.18.
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

#import "OCHostSimulatorResponse.h"
#import "OCHTTPRequest.h"

@implementation OCHostSimulatorResponse

+ (instancetype)responseWithURL:(NSURL *)url statusCode:(OCHTTPStatusCode)statusCode headers:(NSDictionary<NSString *,NSString *> *)headers contentType:(NSString *)contentType body:(NSString *)bodyString
{
	return ([self responseWithURL:url statusCode:statusCode headers:headers contentType:contentType bodyData:[bodyString dataUsingEncoding:NSUTF8StringEncoding]]);
}

+ (instancetype)responseWithURL:(NSURL *)url statusCode:(OCHTTPStatusCode)statusCode headers:(NSDictionary<NSString *,NSString *> *)headers contentType:(NSString *)contentType bodyData:(NSData *)bodyData;
{
	OCHostSimulatorResponse *simulatorResponse;
	NSMutableDictionary *mutableHeaders = [NSMutableDictionary dictionaryWithDictionary:((headers!=nil) ? headers : @{})];

	if (contentType != nil)
	{
		mutableHeaders[OCHTTPHeaderFieldNameContentType] = contentType;
	}

	mutableHeaders[OCHTTPHeaderFieldNameContentLength] = [@(bodyData.length) stringValue];

	simulatorResponse = [[OCHostSimulatorResponse alloc] init];
	simulatorResponse.url = url;
	simulatorResponse.statusCode = statusCode;
	simulatorResponse.httpHeaders = mutableHeaders;
	simulatorResponse.bodyData = bodyData;

	return (simulatorResponse);
}

- (NSHTTPURLResponse *)response
{
	if (_response == nil)
	{
		_response = [[NSHTTPURLResponse alloc] initWithURL:self.url statusCode:self.statusCode HTTPVersion:@"HTTP/1.1" headerFields:self.httpHeaders];
	}

	return (_response);
}

- (NSData *)bodyData
{
	if (_bodyData != nil)
	{
		return (_bodyData);
	}

	if (_bodyURL != nil)
	{
		return ([NSData dataWithContentsOfURL:_bodyURL]);
	}

	return (nil);
}

@end
