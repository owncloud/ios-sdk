//
//  OCCoreManager+OCMocking.m
//  ownCloudMocking
//
//  Created by Javier Gonzalez on 09/11/2018.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import "OCCoreManager+OCMocking.h"
#import "NSObject+OCSwizzle.h"

@implementation OCCoreManager (OCMocking)

+ (void)load
{
	[self addMockLocation:OCMockLocationOCCoreManagerRequestCoreForBookmark
			  forSelector:@selector(requestCoreForBookmark:completionHandler:)
					 with:@selector(ocm_requestCoreForBookmark:completionHandler:)];
}

- (OCCore *)ocm_requestCoreForBookmark:(OCBookmark *)bookmark completionHandler:(void (^)(OCCore *core, NSError *error))completionHandler {

	OCMockOCCoreManagerRequestCoreForBookmarkBlock mockBlock;

	if ((mockBlock = [[OCMockManager sharedMockManager] mockingBlockForLocation:OCMockLocationOCCoreManagerRequestCoreForBookmark]) != nil)
	{
		return(mockBlock(bookmark, completionHandler));
	}
	else
	{
		return([self ocm_requestCoreForBookmark:bookmark completionHandler:completionHandler]);
	}
}

OCMockLocation OCMockLocationOCCoreManagerRequestCoreForBookmark = @"OCCoreManager.requestCoreForBookmark";

@end
