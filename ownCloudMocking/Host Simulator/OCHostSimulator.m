//
//  OCHostSimulator.m
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


#import "OCHostSimulator.h"

@implementation OCHostSimulator

#pragma mark - Init & Dealloc
- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		self.unroutableRequestHandler = ^BOOL(OCConnection *connection, OCHTTPRequest *request, OCHostSimulatorResponseHandler responseHandler) {
			// By default, answer all unroutable requests with 404 Not Found codes

			responseHandler(nil, [OCHostSimulatorResponse responseWithURL:request.url statusCode:OCHTTPStatusCodeNOT_FOUND headers:nil contentType:@"text/html" body:@"<html><body>Page not found</body></html>"]);

			return (YES);
		};
	}

	return(self);
}

- (OCHTTPResponse *)_responseForRequest:(OCHTTPRequest *)request withResponse:(OCHostSimulatorResponse *)simulatorResponse error:(NSError *)error
{
	OCHTTPResponse *httpResponse;

	if (simulatorResponse.url == nil)
	{
		simulatorResponse.url = request.url;
	}

	httpResponse = [OCHTTPResponse responseWithRequest:request HTTPError:error];

	if (simulatorResponse.response != nil)
	{
		httpResponse.httpURLResponse = simulatorResponse.response;
	}

	if (request.downloadRequest)
	{
		httpResponse.bodyURL = simulatorResponse.bodyURL;
		httpResponse.bodyURLIsTemporary = NO;
	}
	else
	{
		httpResponse.bodyData = [simulatorResponse.bodyData mutableCopy];
	}

	httpResponse.certificate = self.certificate;

	return (httpResponse);
}

- (BOOL)connection:(OCConnection *)connection pipeline:(OCHTTPPipeline *)pipeline simulateRequestHandling:(OCHTTPRequest *)request completionHandler:(void (^)(OCHTTPResponse * _Nonnull))completionHandler
{
	OCHostSimulatorResponse *response = nil;
	BOOL handlesRequest = YES;
	OCHostSimulatorResponseHandler responseHandler = ^(NSError *error, OCHostSimulatorResponse *response) {
		OCHTTPResponse *httpResponse = [self _responseForRequest:request withResponse:response error:error];

		dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
			OCLogDebug(@"Host Simulator: sent response for %@", request.url);
//
//			if (response.certificate != nil)
//			{
//				[pipeline evaluateCertificate:response.certificate forTask:task proceedHandler:^(BOOL proceed, NSError *proceedError){
//					if (proceed)
//					{
//						completionHandler(httpResponse);
//					}
//					else
//					{
//						task.request.error = (proceedError != nil) ? proceedError : OCError(OCErrorRequestServerCertificateRejected);
//						completionHandler(proceedError);
//					}
//
//				}];
//			}

			completionHandler(httpResponse);
		});
	};

	OCLogDebug(@"Host Simulator: received request for %@", request.url);

	if (request.url.path != nil)
	{
		response = _responseByPath[request.url.path];
	}

	if (response == nil)
	{
		BOOL willHandleRequest = NO;

		if (self.requestHandler != nil)
		{
			willHandleRequest = self.requestHandler(connection, request, responseHandler);
		}

		if (!willHandleRequest && (self.unroutableRequestHandler!=nil))
		{
			willHandleRequest = self.unroutableRequestHandler(connection, request, responseHandler);
		}

		handlesRequest = willHandleRequest;
	}
	else
	{
		responseHandler(nil, response);
	}

	return (!handlesRequest); // Return NO if we handled the request, YES if yes, the queue should continue to take care of handling it
}

@end
