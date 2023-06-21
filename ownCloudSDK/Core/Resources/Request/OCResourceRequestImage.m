//
//  OCResourceRequestImage.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 12.01.22.
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

#import "OCResourceRequestImage.h"
#import "OCResourceImage.h"
#import "OCMacros.h"

@implementation OCResourceRequestImage

- (BOOL)satisfiedByResource:(OCResource *)resource
{
	if ([super satisfiedByResource:resource])
	{
		return ([self resourceMeetsSizeRequirement:resource]);
	}

	return (NO);
}

- (BOOL)resourceMeetsSizeRequirement:(OCResource *)resource
{
	OCResourceImage *image;

	if ((image = OCTypedCast(resource, OCResourceImage)) != nil)
	{
		return ((self.maxPixelSize.width <= image.maxPixelSize.width) && (self.maxPixelSize.height <= image.maxPixelSize.height));
	}

	return (NO);
}

@end
