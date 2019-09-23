//
//  OCCore+NameConflicts.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 29.06.19.
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

#import "OCCore+NameConflicts.h"
#import "NSString+NameConflicts.h"
#import "NSString+OCPath.h"
#import "OCCore+Internal.h"

@implementation OCCore (NameConflicts)

#pragma mark - Name conflict resolution
- (void)suggestUnusedNameBasedOn:(NSString *)itemName atPath:(OCPath)path isDirectory:(BOOL)isDirectory usingNameStyle:(OCCoreDuplicateNameStyle)style filteredBy:(nullable OCCoreUnusedNameSuggestionFilter)filter resultHandler:(OCCoreUnusedNameSuggestionResultHandler)resultHandler
{
	[self queueBlock:^{
		[self _suggestUnusedNameBasedOn:itemName atPath:path isDirectory:isDirectory usingNameStyle:style filteredBy:filter resultHandler:resultHandler];
	} allowInlining:YES];
}

- (void)_suggestUnusedNameBasedOn:(NSString *)itemName atPath:(OCPath)path isDirectory:(BOOL)isDirectory usingNameStyle:(OCCoreDuplicateNameStyle)style filteredBy:(nullable OCCoreUnusedNameSuggestionFilter)filter resultHandler:(OCCoreUnusedNameSuggestionResultHandler)resultHandler
{
	OCCoreDuplicateNameStyle nameStyle = style;
	NSNumber *duplicateCountNumber = nil;
	NSString *baseName = nil;
	NSUInteger duplicateCount = 0;
	NSString *returnSuggestedName = nil;
	NSMutableArray <NSString *> *duplicateNames = [NSMutableArray new];

	// Extract information from itemName
	baseName = [itemName itemBaseNameWithStyle:&nameStyle
				    duplicateCount:&duplicateCountNumber
				    allowAmbiguous:isDirectory]; // Allow ambiguous styles for folders

	if (duplicateCountNumber != nil)
	{
		duplicateCount = duplicateCountNumber.unsignedIntegerValue;
	}

	if ((nameStyle == OCCoreDuplicateNameStyleNone) ||
	    (nameStyle == OCCoreDuplicateNameStyleNumbered)) // Only re-use auto-accepted numbered style if it was also provided as argument
	{
		nameStyle = style;
	}

	// Find unused name
	do
	{
		// Compute suggested name
		NSString *suggestedName;

		if (duplicateCount == 0)
		{
			suggestedName = baseName;
		}
		else
		{
			if ((style == OCCoreDuplicateNameStyleNumbered) && (duplicateCount == 1) && ((duplicateCountNumber.longValue > 1) || (duplicateCountNumber==nil)))
			{
				// Skip "Folder 1" and go directly to "Folder 2" unless itemName was "Folder 0" or "Folder 1"
				duplicateCount++;
			}
			suggestedName = [baseName itemDuplicateNameWithStyle:nameStyle duplicateCount:@(duplicateCount)];
		}

		// Apply filter
		if (filter != nil)
		{
			if (!filter(suggestedName))
			{
				[duplicateNames addObject:suggestedName];
				duplicateCount++;
				continue;
			}
		}

		// Check for existing item
		OCItem *item = nil;
		NSError *error = nil;

		if ((item = [self cachedItemInParentPath:path withName:suggestedName isDirectory:isDirectory error:&error]) != nil)
		{
			[duplicateNames addObject:suggestedName];
			duplicateCount++;
		}
		else
		{
			returnSuggestedName = suggestedName;
		}
	}while(returnSuggestedName == nil);

	resultHandler(returnSuggestedName, (duplicateNames.count > 0) ? duplicateNames : nil);
}

@end
