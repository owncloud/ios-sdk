//
//  OCResourceSource.m
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

#import "OCResourceSource.h"
#import "NSError+OCError.h"

@implementation OCResourceSource

- (instancetype)initWithCore:(OCCore *)core
{
	if ((self = [super init]) != nil)
	{
		_core = core;
	}

	return (self);
}

- (OCResourceSourcePriority)priorityForType:(OCResourceType)type
{
	return (OCResourceSourcePriorityNone);
}

- (OCResourceQuality)qualityForRequest:(OCResourceRequest *)request
{
	return (OCResourceQualityNone);
}

- (void)provideResourceForRequest:(OCResourceRequest *)request shouldContinueHandler:(nullable OCResourceSourceShouldContinueHandler)shouldContinueHandler resultHandler:(OCResourceSourceResultHandler)resultHandler
{
	if (resultHandler != nil)
	{
		resultHandler(OCError(OCErrorFeatureNotImplemented), nil);
	}
}

@end
