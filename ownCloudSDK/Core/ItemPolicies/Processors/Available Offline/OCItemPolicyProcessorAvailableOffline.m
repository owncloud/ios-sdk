//
//  OCItemPolicyProcessorAvailableOffline.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 15.07.19.
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

#import "OCItemPolicyProcessorAvailableOffline.h"
#import "OCCore.h"
#import "OCMacros.h"

@implementation OCItemPolicyProcessorAvailableOffline

- (instancetype)initWithCore:(OCCore *)core
{
	if ((self = [super initWithKind:OCItemPolicyKindAvailableOffline core:core]) != nil)
	{
		self.localizedName = OCLocalized(@"Available Offline");

		// Show item if: !removed && type==file && localCopy // && downloadTrigger==availableOffline
		// (show all local copies, as it provides more utility than showing just the files downloaded through available offline)
		self.customQueryCondition = [OCQueryCondition require:@[
			[OCQueryCondition where:OCItemPropertyNameRemoved isEqualTo:@(NO)],
			[OCQueryCondition where:OCItemPropertyNameType isEqualTo:@(OCItemTypeFile)],
			[OCQueryCondition where:OCItemPropertyNameCloudStatus isEqualTo:@(OCItemCloudStatusLocalCopy)]
			// [OCQueryCondition where:OCItemPropertyNameDownloadTrigger isEqualTo:OCItemDownloadTriggerIDAvailableOffline]
		]];
	}

	return (self);
}

- (OCItemPolicyProcessorTrigger)triggerMask
{
	return (OCItemPolicyProcessorTriggerItemsChanged |
		OCItemPolicyProcessorTriggerItemListUpdateCompleted |
		OCItemPolicyProcessorTriggerPoliciesChanged);
}

- (void)setPolicyCondition:(OCQueryCondition *)policyCondition
{
	_policyCondition = policyCondition;

	if (_policyCondition == nil)
	{
		// Download if: never (no policy condition => no download)
		self.matchCondition = nil;

		// Cleanup if: !removed && localCopy && downloadTrigger==availableOffline
		self.cleanupCondition = [OCQueryCondition require:@[
			[OCQueryCondition where:OCItemPropertyNameRemoved isEqualTo:@(NO)],
			[OCQueryCondition where:OCItemPropertyNameCloudStatus isEqualTo:@(OCItemCloudStatusLocalCopy)],
			[OCQueryCondition where:OCItemPropertyNameDownloadTrigger isEqualTo:OCItemDownloadTriggerIDAvailableOffline]
		]];
	}
	else
	{
		// Download if: !removed && cloudOnly && policyCondition
		self.matchCondition = [OCQueryCondition require:@[
			[OCQueryCondition where:OCItemPropertyNameRemoved isEqualTo:@(NO)],
			[OCQueryCondition where:OCItemPropertyNameCloudStatus isEqualTo:@(OCItemCloudStatusCloudOnly)],
			_policyCondition
		]];

		// Cleanup if: !removed && localCopy && downloadTrigger==availableOffline && !policyCondition
		self.cleanupCondition = [OCQueryCondition require:@[
			[OCQueryCondition where:OCItemPropertyNameRemoved isEqualTo:@(NO)],
			[OCQueryCondition where:OCItemPropertyNameCloudStatus isEqualTo:@(OCItemCloudStatusLocalCopy)],
			[OCQueryCondition where:OCItemPropertyNameDownloadTrigger isEqualTo:OCItemDownloadTriggerIDAvailableOffline],
			[OCQueryCondition negating:YES condition:_policyCondition]
		]];
	}
}

- (void)performActionOn:(OCItem *)matchingItem withTrigger:(OCItemPolicyProcessorTrigger)trigger
{
	if (((matchingItem.syncActivity & OCItemSyncActivityDownloading) == 0) &&	// Download is not yet underway
	    (matchingItem.type == OCItemTypeFile) && 					// Can only download files
	    (!matchingItem.isPlaceholder) &&						// Can not download placeholders
	    (matchingItem.syncActivity == OCItemSyncActivityNone) &&			// Wait for item sync activity to cease
	    (matchingItem.removed == NO)						// Not removed
	   )
	{
		[self.core downloadItem:matchingItem options:@{
			OCCoreOptionDownloadTriggerID : OCItemDownloadTriggerIDAvailableOffline
		} resultHandler:nil];
	}
}

- (void)performCleanupOn:(OCItem *)cleanupItem withTrigger:(OCItemPolicyProcessorTrigger)trigger
{
	if (((cleanupItem.syncActivity & OCItemSyncActivityDeletingLocal) == 0) &&	// Local deletion is not yet underway
	    (cleanupItem.type == OCItemTypeFile))					// Can only delete local copies of files
	{
		[self.core deleteLocalCopyOfItem:cleanupItem resultHandler:nil];
	}
}

- (void)didPassTrigger:(OCItemPolicyProcessorTrigger)trigger
{
	if ((trigger & OCItemPolicyProcessorTriggerItemListUpdateCompleted) != 0)
	{
		[self performPoliciesAutoRemoval]; // Clean up policies when there's a consistent item list in the database
	}
}

@end

OCItemPolicyKind OCItemPolicyKindAvailableOffline = @"availableOffline";
