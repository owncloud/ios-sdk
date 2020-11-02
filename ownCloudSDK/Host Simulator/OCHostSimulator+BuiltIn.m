//
//  OCHostSimulator+BuiltIn.m
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

#import "OCHostSimulator+BuiltIn.h"
#import "OCHostSimulatorManager.h"
#import "OCExtensionManager.h"
#import "OCExtension+HostSimulation.h"

#import <objc/runtime.h>

static OCHostSimulationIdentifier OCHostSimulationIdentifierRejectDownloads500 = @"reject-downloads-500";
static OCHostSimulationIdentifier OCHostSimulationIdentifierOnly404 = @"only-404";
static OCHostSimulationIdentifier OCHostSimulationIdentifierFiveSecondsOf404 = @"five-seconds-of-404";

@implementation OCHostSimulator (BuiltIn)

+ (void)load
{
	// Reject Downloads 500
	[OCExtensionManager.sharedExtensionManager addExtension:[OCExtension hostSimulationExtensionWithIdentifier:OCHostSimulationIdentifierRejectDownloads500 locations:@[ OCExtensionLocationIdentifierAllCores ] metadata:nil provider:^id<OCConnectionHostSimulator> _Nullable(OCExtension * _Nonnull extension, OCExtensionContext * _Nonnull context, NSError * _Nullable __autoreleasing * _Nullable error) {
		return ([self simulateRejectDownloads500]);
	}]];

	// Only 404
	[OCExtensionManager.sharedExtensionManager addExtension:[OCExtension hostSimulationExtensionWithIdentifier:OCHostSimulationIdentifierOnly404 locations:@[ OCExtensionLocationIdentifierAllCores ] metadata:nil provider:^id<OCConnectionHostSimulator> _Nullable(OCExtension * _Nonnull extension, OCExtensionContext * _Nonnull context, NSError * _Nullable __autoreleasing * _Nullable error) {
		return ([self simulateOnly404]);
	}]];

	// Five seconds of 404
	[OCExtensionManager.sharedExtensionManager addExtension:[OCExtension hostSimulationExtensionWithIdentifier:OCHostSimulationIdentifierFiveSecondsOf404 locations:@[ OCExtensionLocationIdentifierAllCores ] metadata:nil provider:^id<OCConnectionHostSimulator> _Nullable(OCExtension * _Nonnull extension, OCExtensionContext * _Nonnull context, NSError * _Nullable __autoreleasing * _Nullable error) {
		return ([self fiveSecondsOf404]);
	}]];
}

+ (OCHostSimulator *)hostSimulatorWithRequestHandler:(OCHostSimulatorRequestHandler)requestHandler
{
	OCHostSimulator *hostSimulator;

	hostSimulator = [OCHostSimulator new];

	hostSimulator.requestHandler = requestHandler;
	hostSimulator.unroutableRequestHandler = nil;

	return (hostSimulator);
}

#pragma mark - Reject Downloads 500
+ (OCHostSimulator *)simulateRejectDownloads500
{
	// Rejects all GET requests to the WebDAV endpoint with a 500 server errror
	return ([self hostSimulatorWithRequestHandler:^BOOL(OCConnection * _Nonnull connection, OCHTTPRequest * _Nonnull request, OCHostSimulatorResponseHandler  _Nonnull responseHandler) {
		NSURL *davBaseURL = [connection URLForEndpoint:OCConnectionEndpointIDWebDAV options:nil];

		if ([request.url.path hasPrefix:davBaseURL.path] && [request.method isEqual:OCHTTPMethodGET])
		{
			responseHandler(nil, [OCHostSimulatorResponse responseWithURL:request.url statusCode:OCHTTPStatusCodeINTERNAL_SERVER_ERROR headers:@{} contentType:@"text/html" body:nil]);

			return (YES);
		}

		return (NO);
	}]);
}

#pragma mark - Only 404
+ (OCHostSimulator *)simulateOnly404
{
	// Respond to all requests with a 404 server errror
	return ([self hostSimulatorWithRequestHandler:^BOOL(OCConnection * _Nonnull connection, OCHTTPRequest * _Nonnull request, OCHostSimulatorResponseHandler  _Nonnull responseHandler) {
		responseHandler(nil, [OCHostSimulatorResponse responseWithURL:request.url statusCode:OCHTTPStatusCodeNOT_FOUND headers:@{} contentType:@"text/html" body:nil]);

		return (YES);
	}]);
}

#pragma mark - Five seconds of 404
+ (OCHostSimulator *)fiveSecondsOf404
{
	static NSString *fiveSecondsOf404StartDateKey = @"fiveSecondsOf404";

	// Respond to all requests with a 404 server errror
	return ([self hostSimulatorWithRequestHandler:^BOOL(OCConnection * _Nonnull connection, OCHTTPRequest * _Nonnull request, OCHostSimulatorResponseHandler  _Nonnull responseHandler) {
		NSDate *startDate;

		if ((startDate = objc_getAssociatedObject(connection, (__bridge void *)fiveSecondsOf404StartDateKey)) == nil)
		{
			startDate = [NSDate new];
			objc_setAssociatedObject(connection, (__bridge void *)fiveSecondsOf404StartDateKey, startDate, OBJC_ASSOCIATION_RETAIN);
		}

		if (startDate.timeIntervalSinceNow > -5)
		{
			responseHandler(nil, [OCHostSimulatorResponse responseWithURL:request.url statusCode:OCHTTPStatusCodeNOT_FOUND headers:@{} contentType:@"text/html" body:nil]);

			return (YES);
		}

		return (NO);
	}]);
}

@end
