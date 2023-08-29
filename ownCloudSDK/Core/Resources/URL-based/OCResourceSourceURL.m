//
//  OCResourceSourceURL.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 22.05.23.
//  Copyright © 2023 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2023, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCResourceSourceURL.h"
#import "OCCore.h"
#import "OCConnection.h"
#import "OCMacros.h"
#import "OCResourceImage.h"
#import "OCResourceText.h"
#import "NSError+OCError.h"

@implementation OCResourceSourceURL

- (OCResourceSourcePriority)priorityForType:(OCResourceType)type
{
	return (OCResourceSourcePriorityRemote);
}

- (void)provideResourceForRequest:(OCResourceRequest *)resourceRequest url:(NSURL *)url eTag:(nullable OCFileETag)eTag customizeRequest:(nullable OCResourceSourceURLHTTPRequestCustomizer)requestCustomizer resultHandler:(OCResourceSourceResultHandler)resultHandler
{
	if (url != nil)
	{
		OCConnection *connection;

		if ((connection = self.core.connection) != nil)
		{
			NSProgress *progress = nil;
			OCResource *existingResource = resourceRequest.resource;
			OCFileETag existingETag = existingResource.remoteVersion;

			OCHTTPRequest *httpRequest = [OCHTTPRequest requestWithURL:url];
			httpRequest.requiredSignals = resourceRequest.waitForConnectivity ? connection.actionSignals : connection.propFindSignals;
			httpRequest.redirectPolicy = OCHTTPRequestRedirectPolicyAllowSameHost;

			if (existingETag != nil)
			{
				[httpRequest addHeaderFields:@{
					@"If-None-Match" : existingETag
				}];
			}

			if (requestCustomizer != nil)
			{
				httpRequest = requestCustomizer(httpRequest);
			}

			progress = [connection sendRequest:httpRequest ephermalCompletionHandler:^(OCHTTPRequest * _Nonnull request, OCHTTPResponse * _Nullable response, NSError * _Nullable error) {
				if (error != nil)
				{
					resultHandler(error, nil);
				}
				else if (response.status.code == OCHTTPStatusCodeOK)
				{
					NSString *contentType = response.contentType;
					OCResource *returnResource = nil;

					resourceRequest.remoteVersion = response.headerFields[OCHTTPHeaderFieldNameETag]; // propagate ETag to resource init calls

					if ([contentType hasPrefix:@"image/"])
					{
						// Image
						OCResourceImage *resource = [[OCResourceImage alloc] initWithRequest:resourceRequest];

						resource.data = response.bodyData;

						returnResource = resource;
					}

					if ([contentType hasPrefix:@"text/"])
					{
						// Text
						OCResourceText *resource = [[OCResourceText alloc] initWithRequest:resourceRequest];

						resource.text = [response bodyAsStringWithFallbackEncoding:NSUTF8StringEncoding]; // takes encoding passed in Content-Type into account, defaults to UTF-8

						returnResource = resource;
					}

					if (returnResource == nil)
					{
						// Data
						returnResource = [[OCResource alloc] initWithRequest:resourceRequest];
					}

					returnResource.quality = OCResourceQualityNormal;
					returnResource.mimeType = contentType;

					resultHandler(nil, returnResource);
				}
				else if (response.status.code == OCHTTPStatusCodeNOT_MODIFIED)
				{
					// Remote URL resource has not been modified (If-None-Match fulfilled)
					//
					// Passing back no resource since the existing resource already is identical:
					// - considered passing back the existing resource with an updated version, but this
					//   would likely only create unnecessary overhead for storing the same data again and
					//   sending out updates
					// - resource job processing should complete regardless because the result handler was called
					resultHandler(nil, nil);
				}
				else if (response.status.code == OCHTTPStatusCodeNOT_FOUND)
				{
					resultHandler(OCError(OCErrorResourceDoesNotExist), nil);
				}
				else
				{
					resultHandler(response.status.error, nil);
				}
			}];

			resourceRequest.job.cancellationHandler = ^{
				[progress cancel];
			};

			return;
		}
	}

	resultHandler(OCError(OCErrorInsufficientParameters), nil);
}

@end
