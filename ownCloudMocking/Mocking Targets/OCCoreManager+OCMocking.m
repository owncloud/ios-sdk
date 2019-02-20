//
//  OCCoreManager+OCMocking.m
//  ownCloudMocking
//
//  Created by Javier Gonzalez on 09/11/2018.
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

#import "OCCoreManager+OCMocking.h"
#import "NSObject+OCSwizzle.h"

@implementation OCCoreManager (OCMocking)

+ (void)load
{
	[self addMockLocation:OCMockLocationOCCoreManagerRequestCoreForBookmark
			  forSelector:@selector(requestCoreForBookmark:setup:completionHandler:)
					 with:@selector(ocm_requestCoreForBookmark:setup:completionHandler:)];
}

- (void)ocm_requestCoreForBookmark:(OCBookmark *)bookmark setup:(void(^)(OCCore *core, NSError *))setupHandler completionHandler:(void (^)(OCCore *core, NSError *error))completionHandler {

	OCMockOCCoreManagerRequestCoreForBookmarkBlock mockBlock;

	if ((mockBlock = [[OCMockManager sharedMockManager] mockingBlockForLocation:OCMockLocationOCCoreManagerRequestCoreForBookmark]) != nil)
	{
		return(mockBlock(bookmark, setupHandler, completionHandler));
	}
	else
	{
		return([self ocm_requestCoreForBookmark:bookmark setup:setupHandler completionHandler:completionHandler]);
	}
}

OCMockLocation OCMockLocationOCCoreManagerRequestCoreForBookmark = @"OCCoreManager.requestCoreForBookmark";

@end
