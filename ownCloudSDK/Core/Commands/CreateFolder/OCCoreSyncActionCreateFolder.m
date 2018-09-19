//
//  OCCoreSyncActionCreateFolder.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 06.09.18.
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

#import "OCCoreSyncActionCreateFolder.h"

@implementation OCCoreSyncActionCreateFolder

- (void)preflightWithContext:(OCCoreSyncContext *)syncContext
{
	OCItem *placeholderItem;

	if ((placeholderItem = syncContext.syncRecord.parameters[OCSyncActionParameterPlaceholderItem]) != nil)
	{
		[placeholderItem addSyncRecordID:syncContext.syncRecord.recordID activity:OCItemSyncActivityCreating];

		syncContext.addedItems = @[ placeholderItem ];

		syncContext.updateStoredSyncRecordAfterItemUpdates = YES; // Update syncRecord, so the updated placeHolderItem (now with databaseID) will be stored in the database and can later be used to remove the placeHolderItem again.
	}
}

- (void)descheduleWithContext:(OCCoreSyncContext *)syncContext
{
	OCItem *placeholderItem;

	if ((placeholderItem = syncContext.syncRecord.parameters[OCSyncActionParameterPlaceholderItem]) != nil)
	{
		[placeholderItem removeSyncRecordID:syncContext.syncRecord.recordID activity:OCItemSyncActivityCreating];

		syncContext.removedItems = @[ placeholderItem ];
	}
}

- (BOOL)scheduleWithContext:(OCCoreSyncContext *)syncContext
{
	OCPath folderName;
	OCItem *parentItem;

	if (((folderName = syncContext.syncRecord.parameters[OCSyncActionParameterTargetName]) != nil) &&
	    ((parentItem = syncContext.syncRecord.parameters[OCSyncActionParameterParentItem]) != nil))
	{
		NSProgress *progress;

		if ((progress = [self.core.connection createFolder:folderName inside:parentItem options:nil resultTarget:[self.core _eventTargetWithSyncRecord:syncContext.syncRecord]]) != nil)
		{
			[syncContext.syncRecord addProgress:progress];

			return (YES);
		}
	}

	return (NO);
}

- (BOOL)handleResultWithContext:(OCCoreSyncContext *)syncContext
{
	OCEvent *event = syncContext.event;
	OCSyncRecord *syncRecord = syncContext.syncRecord;
	BOOL canDeleteSyncRecord = NO;
	OCItem *newItem = nil;

	if ((event.error == nil) && ((newItem = event.result) != nil))
	{
		OCItem *placeholderItem;

		if ((placeholderItem = syncRecord.parameters[OCSyncActionParameterPlaceholderItem]) != nil)
		{
			[placeholderItem removeSyncRecordID:syncContext.syncRecord.recordID activity:OCItemSyncActivityCreating];

			syncContext.removedItems = @[ placeholderItem ];
		}

		newItem.parentFileID = placeholderItem.parentFileID;

		syncContext.addedItems = @[ newItem ];

		canDeleteSyncRecord = YES;
	}
	else if (event.error != nil)
	{
		// Create issue for cancellation for any errors
		[self.core _addIssueForCancellationAndDeschedulingToContext:syncContext title:[NSString stringWithFormat:OCLocalizedString(@"Couldn't create %@", nil), syncContext.syncRecord.item.name] description:[event.error localizedDescription] invokeResultHandler:NO resultHandlerError:nil];
	}

	if (syncRecord.resultHandler != nil)
	{
		syncRecord.resultHandler(event.error, self.core, newItem, nil);
	}

	return (canDeleteSyncRecord);
}

@end
