//
//  OCQuery+OCMocking.m
//  ownCloudMocking
//
//  Created by Javier Gonzalez on 13/11/2018.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2018, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCQuery+OCMocking.h"
#import "NSObject+OCSwizzle.h"

@implementation OCQuery (OCMocking)

+ (void)load
{
	[self addMockLocation:OCMockLocationOCQueryRequestChangeSetWithFlags
			  forSelector:@selector(requestChangeSetWithFlags:completionHandler:)
					 with:@selector(ocm_requestChangeSetWithFlags:completionHandler:)];
}

- (void)ocm_requestChangeSetWithFlags:(OCQueryChangeSetRequestFlag)flags completionHandler:(void(^)(OCQueryChangeSetRequestCompletionHandler))completionHandler {

	OCMockOCQueryRequestChangeSetWithFlagsBlock mockBlock;

	if ((mockBlock = [[OCMockManager sharedMockManager] mockingBlockForLocation:OCMockLocationOCQueryRequestChangeSetWithFlags]) != nil)
	{
		mockBlock(flags, completionHandler);
	}
	else
	{
		[self ocm_requestChangeSetWithFlags:flags completionHandler:completionHandler];
	}
}

OCMockLocation OCMockLocationOCQueryRequestChangeSetWithFlags = @"OCQuery.OCQueryRequestChangeSetWithFlags";

@end
