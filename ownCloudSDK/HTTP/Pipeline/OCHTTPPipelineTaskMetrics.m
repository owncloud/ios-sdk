//
//  OCHTTPPipelineTaskMetrics.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 16.04.19.
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

#import "OCHTTPPipelineTaskMetrics.h"

@implementation OCHTTPPipelineTaskMetrics

#pragma mark - Size metrics
+ (NSUInteger)lengthOfHeaderDictionary:(nullable NSDictionary<NSString *, NSString *> *)headerDict method:(nullable NSString *)method url:(nullable NSURL *)url
{
	__block NSUInteger totalLength = 0;

	if ((method != nil) && (url != nil))
	{
		totalLength += method.length + 1 + url.absoluteString.length + 1 + 1 + 1 + 6; // Method + " " + url + " " + ("HTTP/1.1".length == "http://" + 1) + new line + "Host: "
	}

	[headerDict enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSString * _Nonnull value, BOOL * _Nonnull stop) {
		totalLength += (key.length + value.length +
				2 + // ": "
				1); // newline
	}];

	totalLength += 2; // newline + newline

	return (totalLength);
}

#pragma mark - Composition
- (instancetype)initWithURLSessionTaskMetrics:(NSURLSessionTaskMetrics *)urlSessionTaskMetrics
{
	if ((self = [super init]) != nil)
	{
		[self addMetricsFromURLSessionTaskMetrics:urlSessionTaskMetrics];
	}

	return (self);
}

- (void)addMetricsFromURLSessionTaskMetrics:(NSURLSessionTaskMetrics *)urlSessionTaskMetrics
{
	NSURLSessionTaskTransactionMetrics *transactionMetrics;

	if ((transactionMetrics = urlSessionTaskMetrics.transactionMetrics.lastObject) != nil)
	{
		NSDate *startDate = nil, *endDate = nil;

		if (transactionMetrics.fetchStartDate != nil)
		{
			_date = transactionMetrics.fetchStartDate;
		}
		else if (transactionMetrics.requestStartDate != nil)
		{
			_date = transactionMetrics.requestStartDate;
		}

		if (((startDate = transactionMetrics.domainLookupStartDate) != nil) && ((endDate = transactionMetrics.domainLookupEndDate) != nil))
		{
			_dnsTimeInterval = @([endDate timeIntervalSinceDate:startDate]);
		}

		if (((startDate = transactionMetrics.connectStartDate) != nil) && ((endDate = transactionMetrics.connectEndDate) != nil))
		{
			_connectTimeInterval = @([endDate timeIntervalSinceDate:startDate]);
		}

		if (((startDate = transactionMetrics.requestStartDate) != nil) && ((endDate = transactionMetrics.requestEndDate) != nil))
		{
			_requestSendTimeInterval = @([endDate timeIntervalSinceDate:startDate]);
		}

		if (((startDate = transactionMetrics.requestEndDate) != nil) && ((endDate = transactionMetrics.responseStartDate) != nil))
		{
			_serverProcessingTimeInterval = @([endDate timeIntervalSinceDate:startDate]);
		}

		if (((startDate = transactionMetrics.responseStartDate) != nil) && ((endDate = transactionMetrics.responseEndDate) != nil))
		{
			_responseReceiveTimeInterval = @([endDate timeIntervalSinceDate:startDate]);
		}
	}
}

- (void)addTransferSizesFromURLSessionTask:(NSURLSessionTask *)urlSessionTask
{
	_totalRequestSizeBytes = @(urlSessionTask.countOfBytesSent + [OCHTTPPipelineTaskMetrics lengthOfHeaderDictionary:urlSessionTask.currentRequest.allHTTPHeaderFields method:urlSessionTask.currentRequest.HTTPMethod url:urlSessionTask.currentRequest.URL]);

	_totalResponseSizeBytes = @(urlSessionTask.countOfBytesReceived);

	_hostname = urlSessionTask.currentRequest.URL.host;
}

#pragma mark - Computed properties
- (NSNumber *)receivedBytesPerSecond
{
	if ((_totalResponseSizeBytes != nil) && (_responseReceiveTimeInterval != nil))
	{
		return @((NSInteger)(_totalResponseSizeBytes.doubleValue / _responseReceiveTimeInterval.doubleValue));
	}

	return (nil);
}

- (NSNumber *)sentBytesPerSecond
{
	if ((_totalRequestSizeBytes != nil) && (_requestSendTimeInterval != nil))
	{
		return @((NSInteger)(_totalRequestSizeBytes.doubleValue / _requestSendTimeInterval.doubleValue));
	}

	return (nil);
}

- (NSNumber *)totalTransferDuration
{
	if ((_requestSendTimeInterval != nil) && (_responseReceiveTimeInterval != nil))
	{
		return @(_responseReceiveTimeInterval.doubleValue + _requestSendTimeInterval.doubleValue);
	}

	return (nil);
}

#pragma mark - Secure Coding
+ (BOOL)supportsSecureCoding
{
	return (YES);
}

- (void)encodeWithCoder:(nonnull NSCoder *)coder
{
	[coder encodeObject:_date forKey:@"date"];
	[coder encodeObject:_hostname forKey:@"host"];

	[coder encodeObject:_dnsTimeInterval forKey:@"dns"];
	[coder encodeObject:_connectTimeInterval forKey:@"connect"];
	[coder encodeObject:_requestSendTimeInterval forKey:@"request"];
	[coder encodeObject:_serverProcessingTimeInterval forKey:@"server"];
	[coder encodeObject:_responseReceiveTimeInterval forKey:@"response"];

	[coder encodeObject:_totalRequestSizeBytes forKey:@"totalOut"];
	[coder encodeObject:_totalResponseSizeBytes forKey:@"totalIn"];
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)decoder
{
	if ((self = [super init]) != nil)
	{
		_date = [decoder decodeObjectOfClass:[NSDate class] forKey:@"date"];
		_hostname = [decoder decodeObjectOfClass:[NSString class] forKey:@"host"];

		_dnsTimeInterval = [decoder decodeObjectOfClass:[NSNumber class] forKey:@"dns"];
		_connectTimeInterval = [decoder decodeObjectOfClass:[NSNumber class] forKey:@"connect"];
		_requestSendTimeInterval = [decoder decodeObjectOfClass:[NSNumber class] forKey:@"request"];
		_serverProcessingTimeInterval = [decoder decodeObjectOfClass:[NSNumber class] forKey:@"server"];
		_responseReceiveTimeInterval = [decoder decodeObjectOfClass:[NSNumber class] forKey:@"response"];

		_totalRequestSizeBytes = [decoder decodeObjectOfClass:[NSNumber class] forKey:@"totalOut"];
		_totalResponseSizeBytes = [decoder decodeObjectOfClass:[NSNumber class] forKey:@"totalIn"];
	}

	return (self);
}

@end
