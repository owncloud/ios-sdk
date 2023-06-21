//
//  OCResourceSourceItemLocalThumbnails.m
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

#import "OCResourceSourceItemLocalThumbnails.h"
#import "OCResourceRequestItemThumbnail.h"
#import "OCCore.h"
#import "OCMacros.h"
#import "OCResourceImage.h"
#import "OCItem+OCThumbnail.h"
#import "OCItem.h"
#import "NSError+OCError.h"

#import <QuickLookThumbnailing/QuickLookThumbnailing.h>
#import <CoreServices/CoreServices.h>

@implementation OCResourceSourceItemLocalThumbnails

- (OCResourceType)type
{
	return (OCResourceTypeItemThumbnail);
}

- (OCResourceSourceIdentifier)identifier
{
	return (OCResourceSourceIdentifierItemLocalThumbnails);
}

- (OCResourceSourcePriority)priorityForType:(OCResourceType)type
{
	return (OCResourceSourcePriorityLocal);
}

- (OCResourceQuality)qualityForRequest:(OCResourceRequest *)request
{
	if (@available(iOS 13, macOS 10.15, *))
	{
		if ([request isKindOfClass:OCResourceRequestItemThumbnail.class] && [request.reference isKindOfClass:OCItem.class])
		{
			OCItem *item;

			if ((item = OCTypedCast(request.reference, OCItem)) != nil)
			{
				if ((item.type == OCItemTypeFile) &&
				    ([self.core localCopyOfItem:item] != nil))
				{
					return (OCResourceQualityHigh);
				}
			}
		}
	}

	return (OCResourceQualityNone);
}

- (void)provideResourceForRequest:(OCResourceRequest *)request resultHandler:(OCResourceSourceResultHandler)resultHandler
{
	if (@available(iOS 13, macOS 10.15, *))
	{
		OCItem *item;

		if ((OCTypedCast(request, OCResourceRequestItemThumbnail) != nil) &&
		    ((item = OCTypedCast(request.reference, OCItem)) != nil))
		{
			NSURL *localURL;

			if ((localURL = [[self.core localCopyOfItem:item] absoluteURL]) != nil) // absoluteURL is needed. For relative URLs QLThumbnailGenerator will return error: QLThumbnailErrorDomain, Code=3 "No thumbnail in the cloud…"
			{
				QLThumbnailGenerationRequest *thumbnailRequest = [[QLThumbnailGenerationRequest alloc] initWithFileAtURL:localURL size:request.maxPointSize scale:request.scale representationTypes:(QLThumbnailGenerationRequestRepresentationTypeLowQualityThumbnail | QLThumbnailGenerationRequestRepresentationTypeThumbnail)];

				[QLThumbnailGenerator.sharedGenerator generateBestRepresentationForRequest:thumbnailRequest completionHandler:^(QLThumbnailRepresentation * _Nullable thumbnail, NSError * _Nullable error) {
					CGImageRef imageRef;

					if (error != nil)
					{
						resultHandler(error, nil);
						return;
					}

					if ((imageRef = thumbnail.CGImage) != NULL)
					{
						NSMutableData *imageData = [NSMutableData new];

						CGImageDestinationRef imageDestinationRef;

						if ((imageDestinationRef = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)imageData, kUTTypeJPEG, 1, NULL)) != NULL)
						{
							CGImageDestinationSetProperties(imageDestinationRef, (__bridge CFDictionaryRef)@{ (__bridge id)kCGImageDestinationLossyCompressionQuality : @(1.0) });
							CGImageDestinationAddImage(imageDestinationRef, imageRef, NULL);

							bool success = CGImageDestinationFinalize(imageDestinationRef);

							CFRelease(imageDestinationRef);
							imageDestinationRef = NULL;

							if (success)
							{
								OCResourceImage *thumbnailImage;

								if ((thumbnailImage = [[OCResourceImage alloc] initWithRequest:request]) != nil)
								{
									thumbnailImage.quality = OCResourceQualityHigh;

									thumbnailImage.mimeType = @"image/jpeg";
									thumbnailImage.data = imageData;

									// thumbnailImage.thumbnail.image = thumbnail.UIImage;

									resultHandler(nil, thumbnailImage);

									return;
								}
							}
						}
					}

					resultHandler(OCError(OCErrorFeatureNotSupportedForItem), nil);
				}];

				return;
			}
		}
	}

	resultHandler(OCError(OCErrorFeatureNotSupportedForItem), nil);
}

@end

OCResourceSourceIdentifier OCResourceSourceIdentifierItemLocalThumbnails = @"core.item-local-thumbnails";
