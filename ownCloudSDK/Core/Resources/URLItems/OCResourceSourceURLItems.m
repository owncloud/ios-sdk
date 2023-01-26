//
//  OCResourceSourceURLItems.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 07.09.22.
//  Copyright © 2022 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2022, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCResourceSourceURLItems.h"
#import "OCResourceRequestURLItem.h"

@implementation OCResourceSourceURLItems

- (OCResourceType)type
{
	return (OCResourceTypeURLItem);
}

- (OCResourceSourceIdentifier)identifier
{
	return (OCResourceSourceIdentifierURLItem);
}

- (OCResourceSourcePriority)priorityForType:(OCResourceType)type
{
	return (OCResourceSourcePriorityRemote);
}

- (OCResourceQuality)qualityForRequest:(OCResourceRequest *)request
{
	if ([request isKindOfClass:OCResourceRequestURLItem.class] && [request.reference isKindOfClass:NSURL.class])
	{
		if (OCTypedCast(request.reference, NSURL) != nil)
		{
			return (OCResourceQualityNormal);
		}
	}

	return (OCResourceQualityNone);
}

- (void)provideResourceForRequest:(OCResourceRequest *)request resultHandler:(OCResourceSourceResultHandler)resultHandler
{
	OCResourceRequestURLItem *urlItemRequest;
	NSURL *url;

	if (((urlItemRequest = OCTypedCast(request, OCResourceRequestURLItem)) != nil) &&
	    ((url = OCTypedCast(urlItemRequest.reference, NSURL)) != nil))
	{
		OCConnection *connection;

		if ((connection = self.core.connection) != nil)
		{
			NSProgress *progress = nil;

			OCHTTPRequest *httpRequest = [OCHTTPRequest requestWithURL:url];
			httpRequest.requiredSignals = request.waitForConnectivity ? connection.actionSignals : connection.propFindSignals;
			httpRequest.redirectPolicy = OCHTTPRequestRedirectPolicyAllowSameHost;

			progress = [connection sendRequest:httpRequest ephermalCompletionHandler:^(OCHTTPRequest * _Nonnull request, OCHTTPResponse * _Nullable response, NSError * _Nullable error) {
				if (error != nil)
				{
					resultHandler(error, nil);
				}
				else if (response.status.code == OCHTTPStatusCodeOK)
				{
					NSString *contentType = response.contentType;
					OCResource *returnResource = nil;

					if ([contentType hasPrefix:@"image/"])
					{
						// Image
						OCResourceImage *resource = [[OCResourceImage alloc] initWithRequest:urlItemRequest];

						resource.data = response.bodyData;

						returnResource = resource;
					}

					if ([contentType hasPrefix:@"text/"])
					{
						// Text
						OCResourceText *resource = [[OCResourceText alloc] initWithRequest:urlItemRequest];

						resource.text = [response bodyAsStringWithFallbackEncoding:NSUTF8StringEncoding]; // takes encoding passed in Content-Type into account, defaults to UTF-8

						returnResource = resource;
					}

					if (returnResource == nil)
					{
						// Data
						returnResource = [[OCResource alloc] initWithRequest:urlItemRequest];
					}

					returnResource.quality = OCResourceQualityNormal;
					returnResource.mimeType = contentType;

					resultHandler(nil, returnResource);
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

			request.job.cancellationHandler = ^{
				[progress cancel];
			};

			return;
		}
	}

	resultHandler(OCError(OCErrorInsufficientParameters), nil);
}

@end

OCResourceSourceIdentifier OCResourceSourceIdentifierURLItem = @"core.urlItem";
