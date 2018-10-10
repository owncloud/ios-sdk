//
//  OCSyncActionCreateFolder.m
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

#import "OCSyncActionCreateFolder.h"

@implementation OCSyncActionCreateFolder

- (instancetype)initWithParentItem:(OCItem *)parentItem folderName:(NSString *)folderName
{
	if ((self = [super initWithItem:parentItem]) != nil)
	{
		OCItem *placeholderItem;

		self.identifier = OCSyncActionIdentifierCreateFolder;

		self.folderName = folderName;

		if ((placeholderItem = [OCItem placeholderItemOfType:OCItemTypeCollection]) != nil)
		{
			placeholderItem.parentFileID = parentItem.fileID;
			placeholderItem.path = [parentItem.path stringByAppendingPathComponent:folderName];
			placeholderItem.lastModified = [NSDate date];

			self.placeholderItem = placeholderItem;
		}
	}

	return (self);
}

- (void)preflightWithContext:(OCSyncContext *)syncContext
{
	if (self.placeholderItem != nil)
	{
		[_placeholderItem addSyncRecordID:syncContext.syncRecord.recordID activity:OCItemSyncActivityCreating];

		syncContext.addedItems = @[ _placeholderItem ];

		syncContext.updateStoredSyncRecordAfterItemUpdates = YES; // Update syncRecord, so the updated placeHolderItem (now with databaseID) will be stored in the database and can later be used to remove the placeHolderItem again.
	}
}

- (void)descheduleWithContext:(OCSyncContext *)syncContext
{
	if (self.placeholderItem != nil)
	{
		[_placeholderItem removeSyncRecordID:syncContext.syncRecord.recordID activity:OCItemSyncActivityCreating];

		syncContext.removedItems = @[ _placeholderItem ];
	}
}

- (BOOL)scheduleWithContext:(OCSyncContext *)syncContext
{
	OCPath folderName;
	OCItem *parentItem;

	if (((folderName = self.folderName) != nil) &&
	    ((parentItem = self.localItem) != nil))
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

- (BOOL)handleResultWithContext:(OCSyncContext *)syncContext
{
	OCEvent *event = syncContext.event;
	OCSyncRecord *syncRecord = syncContext.syncRecord;
	BOOL canDeleteSyncRecord = NO;
	OCItem *newItem = nil;

	if ((event.error == nil) && ((newItem = event.result) != nil))
	{
		OCItem *placeholderItem;

		if ((placeholderItem = self.placeholderItem) != nil)
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
		[self.core _addIssueForCancellationAndDeschedulingToContext:syncContext title:[NSString stringWithFormat:OCLocalizedString(@"Couldn't create %@", nil), self.folderName] description:[event.error localizedDescription] invokeResultHandler:NO resultHandlerError:nil];
	}

	if (syncRecord.resultHandler != nil)
	{
		syncRecord.resultHandler(event.error, self.core, newItem, nil);
	}

	return (canDeleteSyncRecord);
}

#pragma mark - NSCoding
- (void)decodeActionData:(NSCoder *)decoder
{
	_folderName = [decoder decodeObjectOfClass:[NSString class] forKey:@"folderName"];
	_placeholderItem = [decoder decodeObjectOfClass:[OCItem class] forKey:@"placeholderItem"];
}

- (void)encodeActionData:(NSCoder *)coder
{
	[coder encodeObject:_folderName forKey:@"folderName"];
	[coder encodeObject:_placeholderItem forKey:@"placeholderItem"];
}

@end
