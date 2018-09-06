//
//  OCCoreSyncActionCopyMove.m
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

#import "OCCoreSyncActionCopyMove.h"

@implementation OCCoreSyncActionCopyMove

- (BOOL)scheduleWithContext:(OCCoreSyncContext *)syncContext
{
	OCItem *item, *parentItem;
	NSString *targetName;

	if (((item = syncContext.syncRecord.item) != nil) &&
	    ((parentItem = (OCItem *)syncContext.syncRecord.parameters[OCSyncActionParameterTargetItem]) != nil) &&
	    ((targetName = (NSString *)syncContext.syncRecord.parameters[OCSyncActionParameterTargetName]) != nil))
	{
		NSProgress *progress;

		if ([syncContext.syncRecord.action isEqual:OCSyncActionCopy])
		{
			progress = [self.core.connection copyItem:item to:parentItem withName:targetName options:nil resultTarget:[self.core _eventTargetWithSyncRecord:syncContext.syncRecord]];
		}
		else if ([syncContext.syncRecord.action isEqual:OCSyncActionMove])
		{
			progress = [self.core.connection moveItem:item to:parentItem withName:targetName options:nil resultTarget:[self.core _eventTargetWithSyncRecord:syncContext.syncRecord]];
		}

		if (progress != nil)
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
	BOOL isCopy = [syncContext.syncRecord.action isEqual:OCSyncActionCopy];
	BOOL isRename = ((NSNumber *)syncContext.syncRecord.parameters[@"isRename"]).boolValue;

	if (syncRecord.resultHandler != nil)
	{
		syncRecord.resultHandler(event.error, self.core, (OCItem *)event.result, nil);
	}

	if ((event.error == nil) && (event.result != nil))
	{
		syncContext.addedItems = @[ event.result ];

		if (!isCopy && (syncContext.syncRecord.item!=nil))
		{
			syncContext.removedItems = @[ syncContext.syncRecord.item ];
		}

		canDeleteSyncRecord = YES;
	}
	else if (event.error.isOCError)
	{
		NSString *issueTitle=nil, *issueDescription=nil;
		OCItem *item, *parentItem;
		NSString *targetName;
		OCPath targetPath;

		item = syncContext.syncRecord.item;
		parentItem = (OCItem *)syncContext.syncRecord.parameters[OCSyncActionParameterTargetItem];
	    	targetName = (NSString *)syncContext.syncRecord.parameters[OCSyncActionParameterTargetName];

	    	targetPath = [parentItem.path stringByAppendingString:targetName];

		switch (event.error.code)
		{
			case OCErrorItemOperationForbidden:
				issueTitle = OCLocalizedString(@"Operation forbidden",nil);
				if (isCopy)
				{
					issueDescription = [NSString stringWithFormat:OCLocalizedString(@"%@ can't be copied to %@.",nil), item.path, targetPath];
				}
				else
				{
					if (isRename)
					{
						issueDescription = [NSString stringWithFormat:OCLocalizedString(@"%@ couldn't be renamed to %@.",nil), item.name, targetName];
					}
					else
					{
						issueDescription = [NSString stringWithFormat:OCLocalizedString(@"%@ can't be moved to %@.",nil), item.path, targetPath];
					}
				}
			break;

			case OCErrorItemNotFound:
				issueTitle = [NSString stringWithFormat:OCLocalizedString(@"%@ not found",nil), item.name];
				issueDescription = [NSString stringWithFormat:OCLocalizedString(@"%@ wasn't found at %@.",nil), item.name, [item.path stringByDeletingLastPathComponent]];
			break;

			case OCErrorItemDestinationNotFound:
				issueTitle = [NSString stringWithFormat:OCLocalizedString(@"%@ not found",nil), [targetPath lastPathComponent]];
				issueDescription = [NSString stringWithFormat:OCLocalizedString(@"The target directory %@ doesn't seem to exist.",nil), targetPath];
			break;

			case OCErrorItemAlreadyExists:
				issueTitle = [NSString stringWithFormat:OCLocalizedString(@"%@ already exists",nil), targetName];
				if (isCopy)
				{
					issueDescription = [NSString stringWithFormat:OCLocalizedString(@"Couldn't copy %@ to %@, because an item called %@ already exists there.",nil), item.name, targetPath, targetName];
				}
				else
				{
					if (isRename)
					{
						issueDescription = [NSString stringWithFormat:OCLocalizedString(@"Couldn't rename %@ to %@, because another item with that name already exists.",nil), item.name, targetName];
					}
					else
					{
						issueDescription = [NSString stringWithFormat:OCLocalizedString(@"Couldn't move %@ to %@, because an item called %@ already exists there.",nil), item.name, targetPath, targetName];
					}
				}
			break;

			case OCErrorItemInsufficientPermissions:
				issueTitle = OCLocalizedString(@"Insufficient permissions",nil);
				if (isCopy)
				{
					issueDescription = [NSString stringWithFormat:OCLocalizedString(@"%@ can't be copied to %@.",nil), item.path, targetPath];
				}
				else
				{
					if (isRename)
					{
						issueDescription = [NSString stringWithFormat:OCLocalizedString(@"%@ couldn't be renamed to %@.",nil), item.name, targetName];
					}
					else
					{
						issueDescription = [NSString stringWithFormat:OCLocalizedString(@"%@ can't be moved to %@.",nil), item.path, targetPath];
					}
				}
			break;

			default:
				if (isCopy)
				{
					issueTitle = [NSString stringWithFormat:OCLocalizedString(@"Error copying %@",nil), item.path];
				}
				else
				{
					if (isRename)
					{
						issueTitle = [NSString stringWithFormat:OCLocalizedString(@"Error renaming %@",nil), item.name];
					}
					else
					{
						issueTitle = [NSString stringWithFormat:OCLocalizedString(@"Error moving %@",nil), item.path];
					}
				}
				issueDescription = event.error.localizedDescription;
			break;
		}

		if ((issueTitle!=nil) && (issueDescription!=nil))
		{
			[self.core _addIssueForCancellationAndDeschedulingToContext:syncContext title:issueTitle description:issueDescription];
		}
	}
	else if (event.error != nil)
	{
		// Reschedule for all other errors
		[self.core rescheduleSyncRecord:syncRecord withUpdates:nil];
	}

	return (canDeleteSyncRecord);
}

@end