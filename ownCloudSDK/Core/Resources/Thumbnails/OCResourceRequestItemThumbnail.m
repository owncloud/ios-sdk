//
//  OCResourceRequestItemThumbnail.m
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

#import "OCResourceRequestItemThumbnail.h"
#import "OCResource.h"
#import "OCItem+OCThumbnail.h"

@implementation OCResourceRequestItemThumbnail

+ (instancetype)requestThumbnailFor:(OCItem *)item maximumSize:(CGSize)requestedMaximumSizeInPoints scale:(CGFloat)scale waitForConnectivity:(BOOL)waitForConnectivity changeHandler:(OCResourceRequestChangeHandler)changeHandler
{
	OCResourceRequestItemThumbnail *request = [[self alloc] initWithType:OCResourceTypeItemThumbnail identifier:item.fileID];

	if (scale == 0)
	{
		scale = UIScreen.mainScreen.scale;
	}

	request.version = item.eTag;
	request.remoteVersion = item.eTag;
	request.structureDescription = item.thumbnailSpecID;

	request.reference = item;

	request.maxPointSize = requestedMaximumSizeInPoints;
	request.scale = scale;

	request.waitForConnectivity = waitForConnectivity;

	request.changeHandler = changeHandler;

	return (request);
}

- (OCItem *)item
{
	return (self.reference);
}

@end
