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
		OCResourceSourceURLItems *weakSelf = self;

		[super provideResourceForRequest:urlItemRequest url:url eTag:nil customizeRequest:^OCHTTPRequest * _Nonnull(OCHTTPRequest * _Nonnull httpRequest) {
			// Cancel connection on certificate errors, do not prompt user (addresses https://github.com/owncloud/core/issues/40953#issuecomment-1695979509)
			// Temporary solution, to be superseded by implementation of https://github.com/owncloud/ios-app/issues/1176
			httpRequest.ephermalRequestCertificateProceedHandler = ^(OCHTTPRequest * _Nonnull request, OCCertificate * _Nonnull certificate, OCCertificateValidationResult validationResult, NSError * _Nonnull certificateValidationError, OCConnectionCertificateProceedHandler  _Nonnull proceedHandler) {
				if ((validationResult == OCCertificateValidationResultPassed) || (validationResult == OCCertificateValidationResultUserAccepted))
				{
					proceedHandler(YES, certificateValidationError);
				}
				else
				{
					OCWLogDebug(@"Cancelled request to %@ due to certificate issue (validation=%lu, error=%@)", request.url, validationResult, certificateValidationError);
					proceedHandler(NO, nil);
				}
			};

			return (httpRequest);
		} resultHandler:resultHandler];

		return;
	}

	resultHandler(OCError(OCErrorInsufficientParameters), nil);
}

@end

OCResourceSourceIdentifier OCResourceSourceIdentifierURLItem = @"core.urlItem";
