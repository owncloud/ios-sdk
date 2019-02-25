//
//  OCProgressManager.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 19.02.19.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2019, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCProgressManager.h"
#import "OCProgress.h"
#import "OCHTTPPipelineManager.h"
#import "OCCoreManager.h"
#import "OCCore+SyncEngine.h"

@implementation OCProgressManager

+ (OCProgressManager *)sharedProgressManager
{
	static dispatch_once_t onceToken;
	static OCProgressManager *sharedProgressManager = nil;

	dispatch_once(&onceToken, ^{
		sharedProgressManager = [OCProgressManager new];
	});

	return (sharedProgressManager);
}

- (id<OCProgressResolver>)resolverForPathElement:(OCProgressPathElementIdentifier)pathElementIdentifier withContext:(OCProgressResolutionContext)context
{
	if ([pathElementIdentifier isEqual:OCHTTPRequestGlobalPath])
	{
		return (OCHTTPPipelineManager.sharedPipelineManager);
	}

	if ([pathElementIdentifier isEqual:OCCoreGlobalRootPath])
	{
		return (OCCoreManager.sharedCoreManager);
	}

	return (nil);
}

@end
