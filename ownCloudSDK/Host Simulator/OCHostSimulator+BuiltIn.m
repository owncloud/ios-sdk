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
#import "OCServerLocatorWebFinger.h"

#import <objc/runtime.h>

static OCHostSimulationIdentifier OCHostSimulationIdentifierRejectDownloads500 = @"reject-downloads-500";
static OCHostSimulationIdentifier OCHostSimulationIdentifierOnly404 = @"only-404";
static OCHostSimulationIdentifier OCHostSimulationIdentifierFiveSecondsOf404 = @"five-seconds-of-404";
static OCHostSimulationIdentifier OCHostSimulationIdentifierSimpleAPM = @"simple-apm";
static OCHostSimulationIdentifier OCHostSimulationIdentifierRecoveringAPM = @"recovering-apm";
static OCHostSimulationIdentifier OCHostSimulationIdentifierWebFinger = @"web-finger";
static OCHostSimulationIdentifier OCHostSimulationIdentifierAuthRaceCondition = @"auth-race-condition";

@implementation OCHostSimulator (BuiltIn)

+ (void)load
{
	// Reject Downloads 500
	[OCExtensionManager.sharedExtensionManager addExtension:[OCExtension hostSimulationExtensionWithIdentifier:OCHostSimulationIdentifierRejectDownloads500 locations:@[ OCExtensionLocationIdentifierAllCores ] metadata:@{
		OCExtensionMetadataKeyDescription : @"Reject Downloads with status 500 responses."
	} provider:^id<OCConnectionHostSimulator> _Nullable(OCExtension * _Nonnull extension, OCExtensionContext * _Nonnull context, NSError * _Nullable __autoreleasing * _Nullable error) {
		return ([self simulateRejectDownloads500]);
	}]];

	// Only 404
	[OCExtensionManager.sharedExtensionManager addExtension:[OCExtension hostSimulationExtensionWithIdentifier:OCHostSimulationIdentifierOnly404 locations:@[ OCExtensionLocationIdentifierAllCores ] metadata:@{
		OCExtensionMetadataKeyDescription : @"Return status code 404 for every request."
	} provider:^id<OCConnectionHostSimulator> _Nullable(OCExtension * _Nonnull extension, OCExtensionContext * _Nonnull context, NSError * _Nullable __autoreleasing * _Nullable error) {
		return ([self simulateOnly404]);
	}]];

	// Five seconds of 404
	[OCExtensionManager.sharedExtensionManager addExtension:[OCExtension hostSimulationExtensionWithIdentifier:OCHostSimulationIdentifierFiveSecondsOf404 locations:@[ OCExtensionLocationIdentifierAllCores ] metadata:@{
		OCExtensionMetadataKeyDescription : @"Return status code 404 for every request for the first five seconds."
	} provider:^id<OCConnectionHostSimulator> _Nullable(OCExtension * _Nonnull extension, OCExtensionContext * _Nonnull context, NSError * _Nullable __autoreleasing * _Nullable error) {
		return ([self fiveSecondsOf404]);
	}]];

	// Simple APM
	[OCExtensionManager.sharedExtensionManager addExtension:[OCExtension hostSimulationExtensionWithIdentifier:OCHostSimulationIdentifierSimpleAPM locations:@[ OCExtensionLocationIdentifierAllCores, OCExtensionLocationIdentifierAccountSetup ] metadata:@{
		OCExtensionMetadataKeyDescription : @"Redirect any request without cookies to a cookie-setting endpoint, where cookies are set - and then redirect back."
	} provider:^id<OCConnectionHostSimulator> _Nullable(OCExtension * _Nonnull extension, OCExtensionContext * _Nonnull context, NSError * _Nullable __autoreleasing * _Nullable error) {
		return ([self cookieRedirectSimulatorWithRequestWithoutCookiesHandler:nil requestForCookiesHandler:nil requestWithCookiesHandler:nil]);
	}]];

	// Recovering APM
	[OCExtensionManager.sharedExtensionManager addExtension:[OCExtension hostSimulationExtensionWithIdentifier:OCHostSimulationIdentifierRecoveringAPM locations:@[ OCExtensionLocationIdentifierAllCores, OCExtensionLocationIdentifierAccountSetup ] metadata:@{
		OCExtensionMetadataKeyDescription : @"Redirect any request without cookies to a bogus endpoint for 30 seconds, then to a cookie-setting endpoint, where cookies are set - and then redirect back."
	} provider:^id<OCConnectionHostSimulator> _Nullable(OCExtension * _Nonnull extension, OCExtensionContext * _Nonnull context, NSError * _Nullable __autoreleasing * _Nullable error) {
		return ([self cookieRedirectSimulatorWithRequestWithoutCookiesHandler:nil requestForCookiesHandler:nil requestWithCookiesHandler:nil bogusTimeout:30]);
	}]];

	// WebFinger
	[OCExtensionManager.sharedExtensionManager addExtension:[OCExtension hostSimulationExtensionWithIdentifier:OCHostSimulationIdentifierWebFinger locations:@[ OCExtensionLocationIdentifierAllCores, OCExtensionLocationIdentifierAccountSetup ] metadata:@{
		OCExtensionMetadataKeyDescription : @"Responds to all .well-known/webfinger requests with server-instance responses."
	} provider:^id<OCConnectionHostSimulator> _Nullable(OCExtension * _Nonnull extension, OCExtensionContext * _Nonnull context, NSError * _Nullable __autoreleasing * _Nullable error) {
		return ([self webFingerSimulator]);
	}]];

	// AuthRaceCondition
	[OCExtensionManager.sharedExtensionManager addExtension:[OCExtension hostSimulationExtensionWithIdentifier:OCHostSimulationIdentifierAuthRaceCondition locations:@[ OCExtensionLocationIdentifierAllCores, OCExtensionLocationIdentifierAccountSetup ] metadata:@{
		OCExtensionMetadataKeyDescription : @"Responds to all .well-known/webfinger requests with server-instance responses."
	} provider:^id<OCConnectionHostSimulator> _Nullable(OCExtension * _Nonnull extension, OCExtensionContext * _Nonnull context, NSError * _Nullable __autoreleasing * _Nullable error) {
		return ([self authRaceConditionSimulator]);
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

#pragma mark - Cookie redirection / APM simulator
+ (instancetype)cookieRedirectSimulatorWithRequestWithoutCookiesHandler:(dispatch_block_t)requestWithoutCookiesHandler requestForCookiesHandler:(dispatch_block_t)requestForCookiesHandler requestWithCookiesHandler:(dispatch_block_t)requestWithCookiesHandler
{
	return ([self cookieRedirectSimulatorWithRequestWithoutCookiesHandler:requestWithoutCookiesHandler requestForCookiesHandler:requestForCookiesHandler requestWithCookiesHandler:requestWithCookiesHandler bogusTimeout:0]);
}

+ (instancetype)cookieRedirectSimulatorWithRequestWithoutCookiesHandler:(dispatch_block_t)requestWithoutCookiesHandler requestForCookiesHandler:(dispatch_block_t)requestForCookiesHandler requestWithCookiesHandler:(dispatch_block_t)requestWithCookiesHandler bogusTimeout:(NSTimeInterval)bogusTimeout
{
	OCHostSimulator *hostSimulator;
	__block NSURL *originallyRequestedURL = nil;
	__block dispatch_block_t requestWithoutCookiesHandlerBlock = requestWithoutCookiesHandler;
	__block dispatch_block_t requestForCookiesHandlerBlock = requestForCookiesHandler;
	__block dispatch_block_t requestWithCookiesHandlerBlock = requestWithCookiesHandler;
	__block NSDate *firstRequestDate = nil;

	hostSimulator = [OCHostSimulator new];
	hostSimulator.requestHandler = ^BOOL(OCConnection *connection, OCHTTPRequest *request, OCHostSimulatorResponseHandler responseHandler) {
		if (bogusTimeout > 0)
		{
			if (firstRequestDate == nil)
			{
				firstRequestDate = [NSDate new];
			}

			if ((-[firstRequestDate timeIntervalSinceNow]) < bogusTimeout)
			{
				responseHandler(nil, [OCHostSimulatorResponse responseWithURL:request.url statusCode:OCHTTPStatusCodeTEMPORARY_REDIRECT headers:@{
					@"Location" : @"/bogus/endpoint"
				} contentType:@"text/html" body:nil]);

				return (YES);
			}
		}

		if ([request.url.path isEqual:@"/set/cookies"])
		{
			NSString *originalURLString = originallyRequestedURL.absoluteString;

			responseHandler(nil, [OCHostSimulatorResponse responseWithURL:request.url statusCode:OCHTTPStatusCodeTEMPORARY_REDIRECT headers:@{
				@"Location" 	: originalURLString,
				@"Set-Cookie"	: @"sessionCookie=value; Max-Age=2592000; Path=/"
			} contentType:@"text/html" body:nil]);

			if (requestForCookiesHandlerBlock != nil)
			{
				requestForCookiesHandlerBlock();
				requestForCookiesHandlerBlock = nil;
			}

			return (YES);
		}

		if (request.headerFields[@"Cookie"] == nil)
		{
			originallyRequestedURL = request.url;

			responseHandler(nil, [OCHostSimulatorResponse responseWithURL:request.url statusCode:OCHTTPStatusCodeTEMPORARY_REDIRECT headers:@{
				@"Location" : @"/set/cookies"
			} contentType:@"text/html" body:nil]);

			if (requestWithoutCookiesHandlerBlock != nil)
			{
				requestWithoutCookiesHandlerBlock();
				requestWithoutCookiesHandlerBlock = nil;
			}

			return (YES);
		}
		else
		{
			if (requestWithCookiesHandlerBlock != nil)
			{
				requestWithCookiesHandlerBlock();
				requestWithCookiesHandlerBlock = nil;
			}
		}

		return (NO);
	};

	hostSimulator.unroutableRequestHandler = nil;

	return (hostSimulator);
}

#pragma mark - Web Finger
+ (instancetype)webFingerSimulator
{
	OCHostSimulator *hostSimulator;

	hostSimulator = [OCHostSimulator new];
	hostSimulator.requestHandler = ^BOOL(OCConnection *connection, OCHTTPRequest *request, OCHostSimulatorResponseHandler responseHandler) {
		if ([request.url.path isEqual:@"/.well-known/webfinger"])
		{
			OCHTTPStatusCode statusCode = OCHTTPStatusCodeOK;
			NSString *resource = request.parameters[@"resource"];
			NSDictionary<NSString *, id> *jsonResponseDict = @{
				@"subject" : resource,
				@"links" : @[
					@{
						@"rel" : OCServerLocatorWebFingerRelServerInstance,
						@"href" : @"https://demo.owncloud.com/"
					}
				]
			};

			if ([request.parameters[@"resource"] isEqual:@"acct:fail"])
			{
				// Return empty dictionary and status code NOT FOUND
				jsonResponseDict = @{};

				statusCode = OCHTTPStatusCodeNOT_FOUND;
			}

			responseHandler(nil, [OCHostSimulatorResponse responseWithURL:request.url statusCode:statusCode headers:nil contentType:@"application/jrd+json" bodyData:[NSJSONSerialization dataWithJSONObject:jsonResponseDict options:NSJSONWritingPrettyPrinted error:NULL]]);

			return (YES);
		}

		return (NO);
	};

	hostSimulator.unroutableRequestHandler = nil;

	return (hostSimulator);
}

#pragma mark - Auth Race Condition Simulator
+ (instancetype)authRaceConditionSimulator
{
	OCHostSimulator *hostSimulator;

	NSMutableSet<NSString *> *disruptedAuthHeaders = [NSMutableSet new];
	__block NSUInteger requestCounter = 0;

	hostSimulator = [OCHostSimulator new];
	hostSimulator.requestHandler = ^BOOL(OCConnection *connection, OCHTTPRequest *request, OCHostSimulatorResponseHandler responseHandler) {
		NSString *authorizationHeader = request.headerFields[@"Authorization"];
		NSString *invalidAuthContent = @"INVALID";

		if ((authorizationHeader != nil) && ![authorizationHeader isEqual:invalidAuthContent] && ![disruptedAuthHeaders containsObject:authorizationHeader])
		{
			requestCounter++;

			if (requestCounter < 5)
			{
				request.headerFields[@"Authorization"] = invalidAuthContent;
				request.authenticationDataID = invalidAuthContent;

				responseHandler(nil, [OCHostSimulatorResponse responseWithURL:request.url statusCode:OCHTTPStatusCodeUNAUTHORIZED headers:nil contentType:@"text/html" bodyData:nil]);

				return (YES);
			}
			else
			{
				[disruptedAuthHeaders addObject:authorizationHeader];
			}
		}

		return (NO);
	};

	hostSimulator.unroutableRequestHandler = nil;

	return (hostSimulator);
}

@end
