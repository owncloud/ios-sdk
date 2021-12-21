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

- (OCResourceSourcePriority)priorityForRequest:(OCResourceRequest *)request
{
	return (OCResourceSourcePriorityNone);
}

- (void)provideResourceForRequest:(OCResourceRequest *)request completionHandler:(void(^)(NSError * _Nullable error, OCResource * _Nullable resource))completionHandler
{
	if (completionHandler != nil)
	{
		completionHandler(OCError(OCErrorFeatureNotImplemented), nil);
	}
}

@end
