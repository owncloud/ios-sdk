//
//  OCHTTPPipelineTaskMetrics.h
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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface OCHTTPPipelineTaskMetrics : NSObject <NSSecureCoding>

#pragma mark - Time metrics
@property(nullable,strong) NSDate *date; //!< Date the metrics were recorded
@property(nullable,strong) NSString *hostname; //!< Name of the host the metrics were recorded for

@property(nullable,strong) NSNumber *dnsTimeInterval; //!< Number of seconds it took to resolve the host name
@property(nullable,strong) NSNumber *connectTimeInterval; //!< Number of seconds it took to open the connection

@property(nullable,strong) NSNumber *requestSendTimeInterval; //!< Number of seconds it took to send the request
@property(nullable,strong) NSNumber *serverProcessingTimeInterval; //!< Number of seconds it took between the request was fully sent and the response started to be received
@property(nullable,strong) NSNumber *responseReceiveTimeInterval; //!< Number of seconds it took to transfer the response

#pragma mark - Size metrics
@property(nullable,strong) NSNumber *totalRequestSizeBytes; //!< Total number of bytes of the request
@property(nullable,strong) NSNumber *totalResponseSizeBytes; //!< Total number of bytes of the response

+ (NSUInteger)lengthOfHeaderDictionary:(nullable NSDictionary<NSString *, NSString *> *)headerDict method:(nullable NSString *)method url:(nullable NSURL *)url;

#pragma mark - Computed properties
@property(nullable, readonly, nonatomic) NSNumber *receivedBytesPerSecond; //!< Number of bytes received per second
@property(nullable, readonly, nonatomic) NSNumber *sentBytesPerSecond; //!< Number of bytes sent per second

@property(nullable, readonly, nonatomic) NSNumber *totalTransferDuration; //!< Number of seconds a transfer took place (requestSendTimeInterval + responseReceiveTimeInterval)

#pragma mark - Composition
- (instancetype)initWithURLSessionTaskMetrics:(NSURLSessionTaskMetrics *)urlSessionTaskMetrics;

- (void)addMetricsFromURLSessionTaskMetrics:(NSURLSessionTaskMetrics *)urlSessionTaskMetrics;
- (void)addTransferSizesFromURLSessionTask:(NSURLSessionTask *)urlSessionTask;

@end

NS_ASSUME_NONNULL_END
