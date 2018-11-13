//
//  OCQuery+OCMocking.m
//  ownCloudMocking
//
//  Created by Javier Gonzalez on 13/11/2018.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

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
