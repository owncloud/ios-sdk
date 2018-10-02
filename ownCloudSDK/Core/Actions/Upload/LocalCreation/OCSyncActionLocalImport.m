//
//  OCSyncActionLocalImport.m
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

#import "OCSyncActionLocalImport.h"

@implementation OCSyncActionLocalImport

- (instancetype)initWithParentItem:(OCItem *)parentItem filename:(NSString *)filename importFileURL:(NSURL *)importFileURL placeholderItem:(OCItem *)placeholderItem
{
	if ((self = [super initWithItem:parentItem]) != nil)
	{
		self.identifier = OCSyncActionIdentifierLocalImport;

		self.filename = filename;
		self.importFileURL = importFileURL;
		self.placeholderItem = placeholderItem;
	}

	return (self);
}

- (void)preflightWithContext:(OCSyncContext *)syncContext
{
	OCItem *placeholderItem;

	if ((placeholderItem = self.placeholderItem) != nil)
	{
		[placeholderItem addSyncRecordID:syncContext.syncRecord.recordID activity:OCItemSyncActivityUploading];

		syncContext.addedItems = @[ placeholderItem ];

		syncContext.updateStoredSyncRecordAfterItemUpdates = YES; // Update syncRecord, so the updated placeHolderItem (now with databaseID) will be stored in the database and can later be used to remove the placeHolderItem again.
	}
}

- (void)descheduleWithContext:(OCSyncContext *)syncContext
{
	OCItem *placeholderItem;

	if ((placeholderItem = self.placeholderItem) != nil)
	{
		[placeholderItem removeSyncRecordID:syncContext.syncRecord.recordID activity:OCItemSyncActivityUploading];

		syncContext.removedItems = @[ placeholderItem ];
	}
}

- (BOOL)scheduleWithContext:(OCSyncContext *)syncContext
{
	OCPath newItemName;
	OCItem *parentItem, *placeholderItem;
	NSURL *uploadURL;

	if (((newItemName = self.filename) != nil) &&
	    ((parentItem = self.localItem) != nil) &&
	    ((placeholderItem = self.placeholderItem) != nil) &&
	    ((uploadURL = self.importFileURL) != nil))
	{
		NSProgress *progress;

		if ((progress = [self.core.connection uploadFileFromURL:uploadURL withName:newItemName to:parentItem replacingItem:nil options:nil resultTarget:[self.core _eventTargetWithSyncRecord:syncContext.syncRecord]]) != nil)
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

	if ((event.error == nil) && (event.result != nil))
	{
		OCItem *placeholderItem;

		if ((placeholderItem = self.placeholderItem) != nil)
		{
			OCItem *uploadedItem = (OCItem *)event.result;
			NSURL *uploadedItemURL = nil, *placeholderItemURL = nil;

			// Move file from placeholder to uploadedItem backing storage
			if (((placeholderItemURL = [self.core.vault localURLForItem:placeholderItem]) != nil) &&
			    ((uploadedItemURL = [self.core.vault localURLForItem:uploadedItem]) != nil))
			{
				NSError *error;

				// Create directory to house file for new item
				if (![[NSFileManager defaultManager] fileExistsAtPath:[[uploadedItemURL URLByDeletingLastPathComponent] path]])
				{
					if (![[NSFileManager defaultManager] createDirectoryAtURL:[uploadedItemURL URLByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:&error])
					{
						OCLogError(@"Upload completion target directory creation failed for %@ with error %@", OCLogPrivate(uploadedItemURL), error);
					}
				}
				else
				{
					OCLogWarning(@"Upload completion target directory already exists for %@", OCLogPrivate(uploadedItemURL));
				}

				// Move file from placeholder to uploaded item URL
				if ([[NSFileManager defaultManager] moveItemAtURL:placeholderItemURL toURL:uploadedItemURL error:&error])
				{
					// => File move successful

					// Update uploaded item with local relative path and remove the reference from placeholderItem
					uploadedItem.localRelativePath = [self.core.vault relativePathForItem:uploadedItem];
					placeholderItem.localRelativePath = nil;

					uploadedItem.parentFileID = placeholderItem.parentFileID;

					// Update uploaded item with local relative path
					syncContext.addedItems = @[ uploadedItem ];

					// Remove placeholder item
					syncContext.removedItems = @[ placeholderItem ];

					// Remove sync record from placeholder
					[placeholderItem removeSyncRecordID:syncContext.syncRecord.recordID activity:OCItemSyncActivityUploading];
				}
				else
				{
					// => Error moving placeholder item file to uploaded item file
					OCLogWarning(@"Upload completion failed moving file of placeholder (%@) to final destination (%@): %@", OCLogPrivate(placeholderItemURL), OCLogPrivate(uploadedItemURL), OCLogPrivate(error));
				}
			}
			else
			{
				OCLogWarning(@"Upload completion failed retrieving placeholder and upload URLs");
			}
		}
		else
		{
			OCLogWarning(@"Upload completion failed retrieving placeholder item");
		}

		canDeleteSyncRecord = YES;
	}
	else if (event.error != nil)
	{
		// Create issue for cancellation for any errors
		[self.core _addIssueForCancellationAndDeschedulingToContext:syncContext title:[NSString stringWithFormat:OCLocalizedString(@"Couldn't upload %@", nil), self.localItem.name] description:[event.error localizedDescription] invokeResultHandler:NO resultHandlerError:nil];
	}

	if (syncRecord.resultHandler != nil)
	{
		syncRecord.resultHandler(event.error, self.core, (OCItem *)event.result, nil);
	}

	return (canDeleteSyncRecord);
}

#pragma mark - NSCoding
- (void)decodeActionData:(NSCoder *)decoder
{
	_filename = [decoder decodeObjectOfClass:[NSString class] forKey:@"filename"];
	_importFileURL = [decoder decodeObjectOfClass:[NSURL class] forKey:@"importFileURL"];
	_placeholderItem = [decoder decodeObjectOfClass:[OCItem class] forKey:@"placeholderItem"];
}

- (void)encodeActionData:(NSCoder *)coder
{
	[coder encodeObject:_filename forKey:@"filename"];
	[coder encodeObject:_importFileURL forKey:@"importFileURL"];
	[coder encodeObject:_placeholderItem forKey:@"placeholderItem"];
}

@end
