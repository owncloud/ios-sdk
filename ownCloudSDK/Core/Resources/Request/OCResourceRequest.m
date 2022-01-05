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

@interface OCResourceRequest ()
{
	__weak OCResourceManagerJob *_job;
}

@end

@implementation OCResourceRequest

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
