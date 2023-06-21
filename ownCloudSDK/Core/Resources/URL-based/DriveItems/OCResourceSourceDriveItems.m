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

- (OCResourceQuality)qualityForRequest:(OCResourceRequest *)request
{
	if ([request isKindOfClass:OCResourceRequestDriveItem.class] && [request.reference isKindOfClass:GADriveItem.class])
	{
		if (OCTypedCast(request.reference, GADriveItem) != nil)
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
	NSURL *url;

	if (((driveItemRequest = OCTypedCast(request, OCResourceRequestDriveItem)) != nil) &&
	    ((driveItem = OCTypedCast(driveItemRequest.reference, GADriveItem)) != nil) &&
	    ((url = driveItem.webDavUrl) != nil))
	{
		[super provideResourceForRequest:driveItemRequest url:url eTag:nil resultHandler:resultHandler];
		return;
	}

	resultHandler(OCError(OCErrorInsufficientParameters), nil);
}

@end

OCResourceSourceIdentifier OCResourceSourceIdentifierDriveItem = @"core.driveItem";
