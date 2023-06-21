//
//  OCResourceSourceItemThumbnails.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 27.02.21.
//  Copyright © 2021 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2021, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCResourceSourceItemThumbnails.h"
#import "OCResourceRequestItemThumbnail.h"
#import "OCCore.h"
#import "OCMacros.h"
#import "OCResourceImage.h"
#import "OCItem+OCThumbnail.h"
#import "OCItem.h"
#import "NSError+OCError.h"

@implementation OCResourceSourceItemThumbnails

- (OCResourceType)type
{
	return (OCResourceTypeItemThumbnail);
}

- (OCResourceSourceIdentifier)identifier
{
	return (OCResourceSourceIdentifierItemThumbnails);
}

- (OCResourceSourcePriority)priorityForType:(OCResourceType)type
{
	return (OCResourceSourcePriorityRemote);
}

- (OCResourceQuality)qualityForRequest:(OCResourceRequest *)request
{
	if ([request isKindOfClass:OCResourceRequestItemThumbnail.class] && [request.reference isKindOfClass:OCItem.class])
	{
		OCItem *item;

		if ((item = OCTypedCast(request.reference, OCItem)) != nil)
		{
			if (item.type == OCItemTypeFile)
			{
				return (OCResourceQualityNormal);
			}
		}
	}

	return (OCResourceQualityNone);
}

- (void)provideResourceForRequest:(OCResourceRequest *)request resultHandler:(OCResourceSourceResultHandler)resultHandler
{
	OCResourceRequestItemThumbnail *thumbnailRequest;
	OCItem *item;

	if (((thumbnailRequest = OCTypedCast(request, OCResourceRequestItemThumbnail)) != nil) &&
	    ((item = OCTypedCast(thumbnailRequest.reference, OCItem)) != nil))
	{
		OCConnection *connection;

		if (item.thumbnailAvailability == OCItemThumbnailAvailabilityNone)
		{
			// Do not initiate a thumbnail request for items that indicate no thumbnail is available
			resultHandler(nil, nil);
			return;
		}

		if ((connection = self.core.connection) != nil)
		{
			NSString *specID = item.thumbnailSpecID;
			NSProgress *progress = nil;

			progress = [connection retrieveThumbnailFor:item to:nil maximumSize:request.maxPixelSize waitForConnectivity:request.waitForConnectivity resultTarget:[OCEventTarget eventTargetWithEphermalEventHandlerBlock:^(OCEvent * _Nonnull event, id  _Nonnull sender) {
				OCItemThumbnail *thumbnail;

				if (event.error != nil)
				{
					resultHandler(event.error, nil);
				}
				else if ((thumbnail = event.result) != nil)
				{
					OCResourceImage *resource = [[OCResourceImage alloc] initWithRequest:request];

					// Map thumbnail to corresponding resource fields
					resource.identifier = thumbnail.itemVersionIdentifier.fileID;
					resource.version = thumbnail.itemVersionIdentifier.eTag;
					resource.structureDescription = specID;

					// Transfer thumbnail image properties / data to resource
					resource.maxPixelSize = thumbnail.maxPixelSize;
					resource.data = thumbnail.data;

					resource.image = thumbnail;

					resource.quality = OCResourceQualityNormal;

					resultHandler(nil, resource);
				}
			} userInfo:nil ephermalUserInfo:nil]];

			request.job.cancellationHandler = ^{
				[progress cancel];
			};

			return;
		}
	}

	resultHandler(OCError(OCErrorInsufficientParameters), nil);
}

@end

OCResourceSourceIdentifier OCResourceSourceIdentifierItemThumbnails = @"core.item-thumbnails";
