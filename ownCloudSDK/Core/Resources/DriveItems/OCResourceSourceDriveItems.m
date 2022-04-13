//
//  OCResourceSourceDriveItems.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 12.04.22.
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

#import "OCResourceSourceDriveItems.h"
#import "OCMacros.h"
#import "OCResource.h"
#import "OCResourceTypes.h"
#import "OCResourceImage.h"
#import "OCResourceText.h"
#import "OCResourceRequestDriveItem.h"
#import "OCCore.h"
#import "NSError+OCError.h"

@implementation OCResourceSourceDriveItems

- (OCResourceType)type
{
	return (OCResourceTypeDriveItem);
}

- (OCResourceSourceIdentifier)identifier
{
	return (OCResourceSourceIdentifierDriveItem);
}

- (OCResourceSourcePriority)priorityForType:(OCResourceType)type
{
	return (OCResourceSourcePriorityRemote);
}

- (OCResourceQuality)qualityForRequest:(OCResourceRequest *)request
{
	if ([request isKindOfClass:OCResourceRequestDriveItem.class] && [request.reference isKindOfClass:GADriveItem.class])
	{
		GADriveItem *driveItem;

		if ((driveItem = OCTypedCast(request.reference, GADriveItem)) != nil)
		{
			return (OCResourceQualityNormal);
		}
	}

	return (OCResourceQualityNone);
}

- (void)provideResourceForRequest:(OCResourceRequest *)request resultHandler:(OCResourceSourceResultHandler)resultHandler
{
	OCResourceRequestDriveItem *driveItemRequest;
	GADriveItem *driveItem;

	if (((driveItemRequest = OCTypedCast(request, OCResourceRequestDriveItem)) != nil) &&
	    ((driveItem = OCTypedCast(driveItemRequest.reference, GADriveItem)) != nil))
	{
		OCConnection *connection;

		if ((connection = self.core.connection) != nil)
		{
			// NSString *specID = item.thumbnailSpecID;
			NSProgress *progress = nil;
//			OCResourceImage *avatarImageResource = [request.resource.type isEqual:OCResourceTypeAvatar] ? OCTypedCast(request.resource, OCResourceImage) : nil;
//			OCFileETag existingETag = request.resource.version;

			OCHTTPRequest *httpRequest = [OCHTTPRequest requestWithURL:driveItem.webDavUrl];
			httpRequest.requiredSignals = request.waitForConnectivity ? connection.actionSignals : connection.propFindSignals;

//			if (existingETag != nil)
//			{
//				[httpRequest addHeaderFields:@{
//					@"If-None-Match" : existingETag
//				}];
//			}

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
						OCResourceImage *resource = [[OCResourceImage alloc] initWithRequest:driveItemRequest];

						resource.data = response.bodyData;

						returnResource = resource;
					}

					if ([contentType hasPrefix:@"text/"])
					{
						// Text
						OCResourceText *resource = [[OCResourceText alloc] initWithRequest:driveItemRequest];

						resource.text = response.bodyAsString; // takes encoding passed in Content-Type into account

						returnResource = resource;
					}

					if (returnResource == nil)
					{
						// Data
						returnResource = [[OCResource alloc] initWithRequest:driveItemRequest];
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

OCResourceSourceIdentifier OCResourceSourceIdentifierDriveItem = @"core.driveItem";
