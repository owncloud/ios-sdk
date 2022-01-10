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

@implementation OCResourceSourceItemLocalThumbnails

- (OCResourceType)type
{
	return (OCResourceTypeItemThumbnail);
}

- (OCResourceSourceIdentifier)identifier
{
	return (OCResourceSourceIdentifierItemLocalThumbnails);
}

- (OCResourceQuality)qualityForRequest:(OCResourceRequest *)request
{
	if ([request isKindOfClass:OCResourceRequestItemThumbnail.class] && [request.reference isKindOfClass:OCItem.class])
	{
		OCItem *item;

		if ((item = OCTypedCast(request.reference, OCItem)) != nil)
		{
			if ((item.type == OCItemTypeFile) && (item.localRelativePath.length > 0))
			{
				return (OCResourceQualityHigh);
			}
		}
	}

	return (OCResourceQualityNone);
}

@end

OCResourceSourceIdentifier OCResourceSourceIdentifierItemLocalThumbnails = @"core.item-local-thumbnails";
