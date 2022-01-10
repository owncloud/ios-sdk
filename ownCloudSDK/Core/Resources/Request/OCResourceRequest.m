//
//  OCResourceRequest.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 30.09.20.
//  Copyright © 2020 ownCloud GmbH. All rights reserved.
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

#import "OCResourceRequest.h"
#import "OCResourceRequest+Internal.h"
#import "OCResourceManagerJob.h"
#import "OCLogger.h"

@interface OCResourceRequest ()
{
	__weak OCResourceManagerJob *_job;
}

@end

@implementation OCResourceRequest

- (instancetype)initWithType:(OCResourceType)type identifier:(OCResourceIdentifier)identifier
{
	if ((self = [super init]) != nil)
	{
		_type = type;
		_identifier= identifier;
	}

	return (self);
}

- (void)dealloc
{
	OCLogDebug(@"Deallocating OCResourceManagerJob");
}

- (OCResourceRequestRelation)relationWithRequest:(OCResourceRequest *)otherRequest
{
	return (OCResourceRequestRelationDistinct);
}

- (void)setResource:(OCResource *)resource
{
	OCResource *previousResource = _resource;

	_resource = resource;

	if (_changeHandler != nil)
	{
		_changeHandler(self, nil, previousResource, resource);
	}
}

- (CGSize)maxPixelSize
{
	CGSize pointSize = self.maxPointSize;
	CGFloat scale = self.scale;

	if (scale == 0)
	{
		scale = 1.0;
	}

	return (CGSizeMake(pointSize.width * scale, pointSize.height * scale));
}

@end

@implementation OCResourceRequest (Internal)

- (OCResourceManagerJob *)job
{
	return (_job);
}

- (void)setJob:(OCResourceManagerJob *)job
{
	_job = job;
}

@end
