//
//  OCSyncActionUpload.m
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

#import "OCSyncActionUpload.h"
#import "OCSyncAction+FileProvider.h"
#import "OCChecksum.h"
#import "OCChecksumAlgorithmSHA1.h"

@implementation OCSyncActionUpload

#pragma mark - Initializer
- (instancetype)initWithUploadItem:(OCItem *)uploadItem parentItem:(OCItem *)parentItem filename:(NSString *)filename importFileURL:(NSURL *)importFileURL isTemporaryCopy:(BOOL)isTemporaryCopy
{
	if ((self = [super initWithItem:uploadItem]) != nil)
	{
		self.identifier = OCSyncActionIdentifierUpload;

		self.parentItem = parentItem;

		self.importFileURL = importFileURL;
		self.importFileIsTemporaryAlongsideCopy = isTemporaryCopy;
		self.filename = filename;
	}

	return (self);
}

#pragma mark - Action implementation
- (void)preflightWithContext:(OCSyncContext *)syncContext
{
	OCItem *uploadItem;

	if ((uploadItem = self.localItem) != nil)
	{
		[uploadItem addSyncRecordID:syncContext.syncRecord.recordID activity:OCItemSyncActivityUploading];

		if (uploadItem.isPlaceholder)
		{
			syncContext.addedItems = @[ uploadItem ];
		}
		else
		{
			syncContext.updatedItems = @[ uploadItem ];
		}

		syncContext.updateStoredSyncRecordAfterItemUpdates = YES; // Update syncRecord, so the updated uploadItem (now with databaseID) will be stored in the database and can later be used to remove the uploadItem again.
	}
}

- (void)descheduleWithContext:(OCSyncContext *)syncContext
{
	OCItem *uploadItem;

	if ((uploadItem = self.localItem) != nil)
	{
		[uploadItem removeSyncRecordID:syncContext.syncRecord.recordID activity:OCItemSyncActivityUploading];

		if (uploadItem.isPlaceholder)
		{
			// Import descheduled - delete entire item
			syncContext.removedItems = @[ uploadItem ];

			[self.core deleteDirectoryForItem:uploadItem];
		}
		else
		{
			// Remove temporary copy (main file should remain intact)
			if ((_importFileURL!=nil) && _importFileIsTemporaryAlongsideCopy)
			{
				NSError *error;

				[[NSFileManager defaultManager] removeItemAtURL:_importFileURL error:&error];
			}
		}
	}
}

- (BOOL)scheduleWithContext:(OCSyncContext *)syncContext
{
	OCPath remoteFileName;
	OCItem *parentItem, *uploadItem;
	NSURL *uploadURL;

	if (((remoteFileName = self.filename) != nil) &&
	    ((parentItem = self.parentItem) != nil) &&
	    ((uploadItem = self.localItem) != nil) &&
	    ((uploadURL = self.importFileURL) != nil))
	{
		NSProgress *progress;

		if (self.importFileIsTemporaryAlongsideCopy)
		{
			// uploadURL already is a copy of the file alongside item, so we can use it right away
			_uploadCopyFileURL = uploadURL;
		}
		else
		{
			// Find unoccupied filename to make a copy of the file before upload
			if ((_uploadCopyFileURL = [self.core availableTemporaryURLAlongsideItem:self.localItem fileName:NULL]) != nil)
			{
				NSError *error = nil;

				// Make a copy of the file before upload (utilizing APFS cloning, this should be both almost instant as well as cost no actual disk space thanks to APFS copy-on-write)
				if ([[NSFileManager defaultManager] copyItemAtURL:uploadURL toURL:_uploadCopyFileURL error:&error])
				{
					// Cloning succeeded - upload from the clone
					uploadURL = _uploadCopyFileURL;
					_importFileURL = _uploadCopyFileURL;
					_importFileIsTemporaryAlongsideCopy = YES;
				}
				else
				{
					// Cloning failed - continue to use the "original"
					OCLogError(@"error cloning file to import from %@ to %@: %@", uploadURL, _uploadCopyFileURL, error);

					_uploadCopyFileURL = nil;
				}
			}
		}

		// Compute checksum
		if (_uploadCopyFileURL != nil)
		{
			OCSyncExec(checksumComputation, {
				[OCChecksum computeForFile:_uploadCopyFileURL checksumAlgorithm:self.core.preferredChecksumAlgorithm completionHandler:^(NSError *error, OCChecksum *computedChecksum) {
					self.importFileChecksum = computedChecksum;
					OCSyncExecDone(checksumComputation);
				}];
			});

			// Schedule the upload
			OCItem *latestVersionOfLocalItem;
			NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
							self.importFileChecksum, 	 	OCConnectionOptionChecksumKey,		// not using @{} syntax here: if importFileChecksum is nil for any reason, that'd throw
						nil];

			if ((latestVersionOfLocalItem = [self.core retrieveLatestVersionOfItem:self.localItem withError:NULL]) == nil)
			{
				latestVersionOfLocalItem = self.localItem;
			}

			[self setupProgressSupportForItem:latestVersionOfLocalItem options:&options syncContext:syncContext];

			if ((progress = [self.core.connection uploadFileFromURL:uploadURL
								       withName:remoteFileName
									     to:parentItem
								  replacingItem:self.localItem.isPlaceholder ? nil : latestVersionOfLocalItem
									options:options
								   resultTarget:[self.core _eventTargetWithSyncRecord:syncContext.syncRecord]]) != nil)
			{
				[syncContext.syncRecord addProgress:progress];

				return (YES);
			}
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
		OCItem *uploadItem;

		if ((uploadItem = self.localItem) != nil)
		{
			OCItem *uploadedItem = (OCItem *)event.result;
			NSURL *uploadedItemURL = nil, *uploadItemURL = nil;

			if (![uploadedItem.fileID isEqual:uploadItem.fileID])
			{
				// Uploaded item an upload item have different fileIDs (=> uploadItem could have been a placeholder)

				// Move file from uploadItem to uploadedItem backing storage
				if (((uploadItemURL = [self.core.vault localURLForItem:uploadItem]) != nil) &&
				    ((uploadedItemURL = [self.core.vault localURLForItem:uploadedItem]) != nil))
				{
					NSError *error;
					NSURL *placeholderItemContainerURL = [uploadItemURL URLByDeletingLastPathComponent];

					// Create directory to house file for new item
					if ((error = [self.core createDirectoryForItem:uploadedItem]) != nil)
					{
						OCLogError(@"Upload completion target directory creation failed for %@ with error %@", OCLogPrivate(uploadedItem), error);
					}

					// Use _uploadCopyFileURL as source if available
					if (_uploadCopyFileURL != nil)
					{
						uploadItemURL = _uploadCopyFileURL;
					}

					// Move file from placeholder to uploaded item URL
					if ([[NSFileManager defaultManager] moveItemAtURL:uploadItemURL toURL:uploadedItemURL error:&error])
					{
						// => File move successful

						// Update uploaded item with local relative path and remove the reference from placeholderItem
						// - the locallyModified property is not mirrored to the uploadedItem as the file is now the same on the server
						uploadedItem.localRelativePath = [self.core.vault relativePathForItem:uploadedItem];
						uploadItem.localRelativePath = nil;

						uploadedItem.localCopyVersionIdentifier = uploadItem.itemVersionIdentifier;
						uploadedItem.parentFileID = uploadItem.parentFileID;

						// Update uploaded item with local relative path
						syncContext.addedItems = @[ uploadedItem ];

						// Remove placeholder item
						syncContext.removedItems = @[ uploadItem ];

						// Remove sync record from placeholder
						[uploadItem removeSyncRecordID:syncContext.syncRecord.recordID activity:OCItemSyncActivityUploading];

						// Remove placeholder directory (may still contain a copy of the file after all) if no other sync records are active on it
						if (uploadItem.activeSyncRecordIDs.count == 0)
						{
							[[NSFileManager defaultManager] removeItemAtURL:placeholderItemContainerURL error:&error];
						}
					}
					else
					{
						// => Error moving placeholder item file to uploaded item file
						OCLogWarning(@"Upload completion failed moving file of placeholder (%@) to final destination (%@): %@", OCLogPrivate(uploadItemURL), OCLogPrivate(uploadedItemURL), OCLogPrivate(error));
					}
				}
				else
				{
					OCLogWarning(@"Upload completion failed retrieving placeholder and upload URLs");
				}
			}
			else
			{
				// Upload from modified item complete!

				// Prepare uploadedItem to replace uploadItem
				[uploadedItem prepareToReplace:uploadItem];

				// Update uploaded item with local relative path
				uploadedItem.localRelativePath = [self.core.vault relativePathForItem:uploadedItem];

				// Compute checksum to determine if the current main file of this file is identical to this upload action's version
				OCSyncExec(checksumComputation, {
					[OCChecksum computeForFile:[self.core localURLForItem:uploadedItem] checksumAlgorithm:self.importFileChecksum.algorithmIdentifier completionHandler:^(NSError *error, OCChecksum *computedChecksum) {
						// Set locallyModified to NO if checksums match, YES if they don't
						uploadedItem.locallyModified = ![self.importFileChecksum isEqual:computedChecksum];

						OCSyncExecDone(checksumComputation);
					}];
				});

				// Remove sync record from placeholder
				[uploadedItem removeSyncRecordID:syncContext.syncRecord.recordID activity:OCItemSyncActivityUploading];

				// Indicate item update
				syncContext.updatedItems = @[ uploadedItem ];

				// Update localItem
				self.localItem = uploadedItem;

				// Remove temporary copy
				if (_importFileIsTemporaryAlongsideCopy)
				{
					NSError *error;

					[[NSFileManager defaultManager] removeItemAtURL:_importFileURL error:&error];
				}
			}
		}
		else
		{
			OCLogWarning(@"Upload completion failed retrieving placeholder item");
		}

		canDeleteSyncRecord = YES;
	}

	if (syncRecord.resultHandler != nil)
	{
		// Call resultHandler (and give file provider a chance to attach an uploadingError
		syncRecord.resultHandler(event.error, self.core, (OCItem *)event.result, self.localItem);
	}

	if (event.error != nil)
	{
		// Create issue for cancellation for any errors
		[self.core _addIssueForCancellationAndDeschedulingToContext:syncContext title:[NSString stringWithFormat:OCLocalizedString(@"Couldn't upload %@", nil), self.localItem.name] description:[event.error localizedDescription] invokeResultHandler:NO resultHandlerError:nil];
	}

	return (canDeleteSyncRecord);
}

#pragma mark - NSCoding
- (void)decodeActionData:(NSCoder *)decoder
{
	_filename = [decoder decodeObjectOfClass:[NSString class] forKey:@"filename"];

	_importFileURL = [decoder decodeObjectOfClass:[NSURL class] forKey:@"importFileURL"];
	_importFileChecksum = [decoder decodeObjectOfClass:[OCChecksum class] forKey:@"importFileChecksum"];
	_importFileIsTemporaryAlongsideCopy = [decoder decodeBoolForKey:@"importFileIsTemporaryAlongsideCopy"];

	_parentItem = [decoder decodeObjectOfClass:[OCItem class] forKey:@"parentItem"];

	_uploadCopyFileURL = [decoder decodeObjectOfClass:[NSURL class] forKey:@"uploadCopyFileURL"];
}

- (void)encodeActionData:(NSCoder *)coder
{
	[coder encodeObject:_filename forKey:@"filename"];

	[coder encodeObject:_importFileURL forKey:@"importFileURL"];
	[coder encodeObject:_importFileChecksum forKey:@"importFileChecksum"];
	[coder encodeBool:_importFileIsTemporaryAlongsideCopy forKey:@"importFileIsTemporaryAlongsideCopy"];

	[coder encodeObject:_parentItem forKey:@"parentItem"];

	[coder encodeObject:_uploadCopyFileURL forKey:@"uploadCopyFileURL"];
}

@end
