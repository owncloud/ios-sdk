//
//  OCSyncActionLocalCopyDelete.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 16.07.19.
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

#import "OCSyncActionLocalCopyDelete.h"

@implementation OCSyncActionLocalCopyDelete

+ (OCSyncActionIdentifier)identifier
{
	return(OCSyncActionIdentifierDeleteLocalCopy);
}

#pragma mark - Initializer
- (instancetype)initWithItem:(OCItem *)item
{
	if ((self = [super initWithItem:item]) != nil)
	{
		self.actionEventType = OCEventTypeDelete;
		self.localizedDescription = [NSString stringWithFormat:OCLocalized(@"Removing local copy of %@…"), item.name];
	}

	return (self);
}

#pragma mark - Action implementation
- (void)preflightWithContext:(OCSyncContext *)syncContext
{
	OCItem *itemToDelete;

	if ((itemToDelete = self.localItem) != nil)
	{
		[itemToDelete addSyncRecordID:syncContext.syncRecord.recordID activity:OCItemSyncActivityDeletingLocal];
		syncContext.updatedItems = @[ itemToDelete ];
	}
}

- (void)descheduleWithContext:(OCSyncContext *)syncContext
{
	OCItem *itemToRestore;

	if ((itemToRestore = self.localItem) != nil)
	{
		[itemToRestore removeSyncRecordID:syncContext.syncRecord.recordID activity:OCItemSyncActivityDeletingLocal];
		syncContext.updatedItems = @[ itemToRestore ];
	}
}

- (OCCoreSyncInstruction)scheduleWithContext:(OCSyncContext *)syncContext
{
	OCItem *item;
	OCCoreSyncInstruction resultInstruction = OCCoreSyncInstructionDeleteLast;

	if ((item = self.localItem) != nil)
	{
		if (item.locallyModified || item.fileClaim.isValid)
		{
			// don't delete local modified versions or items that are still in use
			OCLogError(@"Skipping deletion of local copy of locally modified or in-use item: %@", item);
		}
		else
		{
			// delete local copy
			NSURL *deleteFileURL;
			BOOL didRemove = NO;

			if ((deleteFileURL = [self.core localURLForItem:item]) != nil)
			{
				NSError *deleteError = nil;

				if ((didRemove = [[NSFileManager defaultManager] removeItemAtURL:deleteFileURL error:&deleteError]) == NO)
				{
					OCLogError(@"Error removing %@: %@", deleteFileURL, deleteError);

					if (![[NSFileManager defaultManager] fileExistsAtPath:deleteFileURL.path])
					{
						didRemove = YES;
					}
				}
				OCFileOpLog(@"rm", deleteError, @"Deleted local copy at %@", deleteFileURL.path);

				if (didRemove)
				{
					[item clearLocalCopyProperties];
				}
			}
		}

		// Remove OCItemSyncActivityDeletingLocal activity from item
		[item removeSyncRecordID:syncContext.syncRecord.recordID activity:OCItemSyncActivityDeletingLocal];
		syncContext.updatedItems = @[ item ];

		[syncContext transitionToState:OCSyncRecordStateCompleted withWaitConditions:nil];
	}

	return (resultInstruction);
}

#pragma mark - Lane tags
- (NSSet<OCSyncLaneTag> *)generateLaneTags
{
	return ([self generateLaneTagsFromItems:@[
		OCSyncActionWrapNullableItem(self.localItem)
	]]);
}

@end
