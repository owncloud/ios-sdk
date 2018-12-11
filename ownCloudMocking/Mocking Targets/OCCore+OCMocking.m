//
//  OCCore+OCMocking.m
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

#import "OCCore+OCMocking.h"
#import "NSObject+OCSwizzle.h"

@implementation OCCore (OCMocking)

+ (void)load
{
	[self addMockLocation:OCMockLocationOCCoreCreateFolder
			  forSelector:@selector(createFolder:inside:options:resultHandler:)
					 with:@selector(ocm_createFolder:inside:options:resultHandler:)];
}

- (NSProgress *)ocm_createFolder:(NSString *)folderName inside:(OCItem *)parentItem options:(NSDictionary<OCCoreOption,id> *)options resultHandler:(OCCoreActionResultHandler)resultHandler {

	OCMockOCCoreCreateFolderBlock mockBlock;

	if ((mockBlock = [[OCMockManager sharedMockManager] mockingBlockForLocation:OCMockLocationOCCoreCreateFolder]) != nil)
	{
		return mockBlock(folderName, parentItem, options, resultHandler);
	}
	else
	{
		return [self ocm_createFolder:folderName inside:parentItem options:options resultHandler:resultHandler];
	}
}

OCMockLocation OCMockLocationOCCoreCreateFolder = @"OCCore.OCCoreCreateFolder";

@end
