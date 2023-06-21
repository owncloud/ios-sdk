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
		[super provideResourceForRequest:urlItemRequest url:url eTag:nil resultHandler:resultHandler];
		return;
	}

	resultHandler(OCError(OCErrorInsufficientParameters), nil);
}

@end

OCResourceSourceIdentifier OCResourceSourceIdentifierURLItem = @"core.urlItem";
