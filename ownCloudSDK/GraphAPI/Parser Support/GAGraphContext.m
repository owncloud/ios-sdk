//
//  GAGraphContext.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 26.01.22.
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

#import "GAGraphContext.h"

@implementation GAGraphContext

+ (GAGraphContext *)defaultContext
{
	// Use defaults (return error if required value is missing)
	return (nil);
}

+ (GAGraphContext *)relaxedContext
{
	static dispatch_once_t onceToken;
	static GAGraphContext *relaxedContext;

	dispatch_once(&onceToken, ^{
		relaxedContext = [GAGraphContext new];
		relaxedContext.ignoreRequirements = YES; // Do not return an error if a required value is missing
	});

	return (relaxedContext);
}

@end
