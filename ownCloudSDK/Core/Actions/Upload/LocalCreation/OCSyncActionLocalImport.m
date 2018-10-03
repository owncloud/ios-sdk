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

		// Find unoccupied filename to make a copy of the file before upload
		for (NSUInteger uploadFileNamingAttempt=0; uploadFileNamingAttempt < 100; uploadFileNamingAttempt++)
		{
			NSURL *uploadCopyFileURLCandidate = [uploadURL URLByAppendingPathExtension:[NSString stringWithFormat:@"upld-%lu-%@", (unsigned long)uploadFileNamingAttempt, NSUUID.UUID.UUIDString]];

			if (![[NSFileManager defaultManager] fileExistsAtPath:uploadCopyFileURLCandidate.path])
			{
				_uploadCopyFileURL = uploadCopyFileURLCandidate;
			}
		}

		// Make a copy of the file before upload (utilizing APFS cloning, this should be both almost instant as well as cost no actual disk space thanks to APFS copy-on-write)
		if (_uploadCopyFileURL != nil)
		{
			NSError *error = nil;

			if ([[NSFileManager defaultManager] copyItemAtURL:uploadURL toURL:_uploadCopyFileURL error:&error])
			{
				// Cloning succeeded - upload from the clone
				uploadURL = _uploadCopyFileURL;
			}
			else
			{
				// Cloning failed - continue to use the "original"
				_uploadCopyFileURL = nil;

				OCLogError(@"SE: error cloning file to import from %@ to %@: %@", uploadURL, _uploadCopyFileURL, error);
			}
		}

		// Schedule the upload
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
				NSURL *placeholderItemContainerURL = [uploadedItemURL URLByDeletingLastPathComponent];

				// Create directory to house file for new item
				if (![[NSFileManager defaultManager] fileExistsAtPath:[placeholderItemContainerURL path]])
				{
					if (![[NSFileManager defaultManager] createDirectoryAtURL:placeholderItemContainerURL withIntermediateDirectories:YES attributes:nil error:&error])
					{
						OCLogError(@"Upload completion target directory creation failed for %@ with error %@", OCLogPrivate(uploadedItemURL), error);
					}
				}
				else
				{
					OCLogWarning(@"Upload completion target directory already exists for %@", OCLogPrivate(uploadedItemURL));
				}

				// Use _uploadCopyFileURL as source if available
				if (_uploadCopyFileURL != nil)
				{
					placeholderItemURL = _uploadCopyFileURL;
				}

				// Move file from placeholder to uploaded item URL
				if ([[NSFileManager defaultManager] moveItemAtURL:placeholderItemURL toURL:uploadedItemURL error:&error])
				{
					// => File move successful

					// Update uploaded item with local relative path and remove the reference from placeholderItem
					// - the locallyModified property is not mirrored to the uploadedItem as the file is now the same on the server
					uploadedItem.localRelativePath = [self.core.vault relativePathForItem:uploadedItem];
					placeholderItem.localRelativePath = nil;

					uploadedItem.parentFileID = placeholderItem.parentFileID;

					// Update uploaded item with local relative path
					syncContext.addedItems = @[ uploadedItem ];

					// Remove placeholder item
					syncContext.removedItems = @[ placeholderItem ];

					// Remove sync record from placeholder
					[placeholderItem removeSyncRecordID:syncContext.syncRecord.recordID activity:OCItemSyncActivityUploading];

					// Remove placeholder directory (may still contain a copy of the file after all) if no other sync records are active on it
					if (placeholderItem.activeSyncRecordIDs.count == 0)
					{
						[[NSFileManager defaultManager] removeItemAtURL:placeholderItemContainerURL error:&error];
					}
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
	_uploadCopyFileURL = [decoder decodeObjectOfClass:[NSURL class] forKey:@"uploadCopyFileURL"];
}

- (void)encodeActionData:(NSCoder *)coder
{
	[coder encodeObject:_filename forKey:@"filename"];
	[coder encodeObject:_importFileURL forKey:@"importFileURL"];
	[coder encodeObject:_placeholderItem forKey:@"placeholderItem"];
	[coder encodeObject:_uploadCopyFileURL forKey:@"uploadCopyFileURL"];
}

@end
