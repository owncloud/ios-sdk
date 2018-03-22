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

@interface OCConnectionRequest (OCHostSimulatorInjection)

- (void)applySimulatorResponse:(OCHostSimulatorResponse *)response;

@end

@implementation OCConnectionRequest (OCHostSimulatorInjection)

- (void)applySimulatorResponse:(OCHostSimulatorResponse *)response
{
	if (response.url == nil)
	{
		response.url = self.url;
	}

	_injectedResponse = response.response;

	if (self.downloadRequest)
	{
		self.downloadedFile = self.bodyURL;
	}
	else
	{
		self.responseBodyData = [self.bodyData mutableCopy];
	}
}

@end

@implementation OCHostSimulator

#pragma mark - Init & Dealloc
- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		self.unroutableRequestHandler = ^BOOL(OCConnection *connection, OCConnectionRequest *request, OCHostSimulatorResponseHandler responseHandler) {
			// By default, answer all unroutable requests with 404 Not Found codes

			responseHandler(nil, [OCHostSimulatorResponse responseWithURL:request.url statusCode:OCHTTPStatusCodeNOT_FOUND headers:nil contentType:@"text/html" body:@"<html><body>Page not found</body></html>"]);

			return (YES);
		};
	}

	return(self);
}

- (void)_applyResponse:(OCHostSimulatorResponse *)response toRequest:(OCConnectionRequest *)request
{
	[request applySimulatorResponse:response];
	request.responseCertificate = self.certificate;
}

- (BOOL)connection:(OCConnection *)connection queue:(OCConnectionQueue *)queue handleRequest:(OCConnectionRequest *)request completionHandler:(void(^)(NSError *error))completionHandler
{
	OCHostSimulatorResponse *response = nil;
	BOOL handlesRequest = YES;
	OCHostSimulatorResponseHandler responseHandler = ^(NSError *error, OCHostSimulatorResponse *response) {
		if (response != nil)
		{
			[self _applyResponse:response toRequest:request];
		}

		dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
			OCLogDebug(@"Host Simulator: sent response for %@", request.url);

			if (request.responseCertificate != nil)
			{
				[queue evaluateCertificate:request.responseCertificate forRequest:request proceedHandler:^(BOOL proceed, NSError *proceedError){
					if (proceed)
					{
						completionHandler(proceedError);
					}
					else
					{
						request.error = (proceedError != nil) ? proceedError : OCError(OCErrorRequestServerCertificateRejected);
						completionHandler(proceedError);
					}

				}];
			}

			completionHandler(error);
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
