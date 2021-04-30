//
//  OCItemPolicyProcessorVersionUpdates.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 23.03.20.
//  Copyright © 2020 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2020, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCItemPolicyProcessorVersionUpdates.h"

@implementation OCItemPolicyProcessorVersionUpdates

- (instancetype)initWithCore:(OCCore *)core
{
	if ((self = [super initWithKind:OCItemPolicyKindVersionUpdates core:core]) != nil)
	{
		self.matchCondition = [OCQueryCondition where:OCItemPropertyNameType isEqualTo:@(OCItemTypeFile)]; // Match all files
	}

	return (self);
}

- (OCItemPolicyProcessorTrigger)triggerMask
{
	return (OCItemPolicyProcessorTriggerItemsChanged);
}

- (void)performActionOn:(OCItem *)matchingItem withTrigger:(OCItemPolicyProcessorTrigger)trigger
{
	if ((trigger & OCItemPolicyProcessorTriggerItemsChanged) != 0)
	{
		if ((!matchingItem.locallyModified) && // don't delete local modified versions
		    (matchingItem.type == OCItemTypeFile) && 					// Can only download files
		    (matchingItem.localRelativePath != nil) && // is there a local copy to delete?
		    (matchingItem.localCopyVersionIdentifier != nil) && // is there anything to compare against?
		    (![matchingItem.itemVersionIdentifier isEqual:matchingItem.localCopyVersionIdentifier]))  // different versions?
		{
			if (matchingItem.fileClaim.isValid)  // don't delete claimed files
			{
				// Determine lock type of claim
				if (matchingItem.fileClaim.typeOfLock == OCClaimLockTypeRead)
				{
					// Read lock that allows and encourages updating
					if (!matchingItem.removed && // Item is not representing a removed item
					    (matchingItem.syncActivity == OCItemSyncActivityNone)) // Item has no sync activity (=> not already being downloaded)
					{
						OCLogDebug(@"Downloading new version of claimed local copy of %@ (%@ vs %@)", matchingItem, matchingItem.itemVersionIdentifier, matchingItem.localCopyVersionIdentifier);
						[self.core downloadItem:matchingItem options:nil resultHandler:^(NSError * _Nullable error, OCCore * _Nonnull core, OCItem * _Nullable item, OCFile * _Nullable file) {
							OCLogDebug(@"Download finished for %@", matchingItem);
						}];
					}
				}
			}
			else
			{
				// Delete outdated local copy
				NSURL *deleteFileURL;

				if ((deleteFileURL = [self.core localURLForItem:matchingItem]) != nil)
				{
					NSError *deleteError = nil;

					OCLogDebug(@"Deleting outdated, unclaimed local copy of %@ (%@ vs %@)", matchingItem, matchingItem.itemVersionIdentifier, matchingItem.localCopyVersionIdentifier);

					[matchingItem clearLocalCopyProperties];

					if ([[NSFileManager defaultManager] removeItemAtURL:deleteFileURL error:&deleteError])
					{
						if (deleteError != nil)
						{
							OCLogDebug(@"Deletion of %@ resulted in error=%@", deleteFileURL, deleteError);
						}
						else
						{
							OCLogDebug(@"Deletion of %@ succeeded", deleteFileURL);
						}
					}

					OCFileOpLog(@"rm", deleteError, @"Deleted outdated, unclaimed local copy at %@", deleteFileURL.path);

					[self.core performUpdatesForAddedItems:nil removedItems:nil updatedItems:@[ matchingItem ] refreshPaths:nil newSyncAnchor:nil beforeQueryUpdates:nil afterQueryUpdates:nil queryPostProcessor:nil skipDatabase:NO];
				}
			}
		}
	}
}

+ (NSArray<OCLogTagName> *)logTags
{
	return (@[@"ItemPolicy", @"VersionUpdates"]);
}

- (NSArray<OCLogTagName> *)logTags
{
	return (@[@"ItemPolicy", @"VersionUpdates"]);
}

@end

OCItemPolicyKind OCItemPolicyKindVersionUpdates = @"versionUpdates";

