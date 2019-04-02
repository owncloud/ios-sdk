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

		self.actionEventType = OCEventTypeUpload;
		self.localizedDescription = [NSString stringWithFormat:OCLocalized(@"Uploading %@…"), ((filename!=nil) ? filename : uploadItem.name)];
	}

	return (self);
}

#pragma mark - Action implementation
- (void)preflightWithContext:(OCSyncContext *)syncContext
{
	OCItem *uploadItem;

	if ((uploadItem = self.localItem) != nil)
	{
		uploadItem.lastUsed = [NSDate new];
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

- (OCCoreSyncInstruction)scheduleWithContext:(OCSyncContext *)syncContext
{
	OCPath remoteFileName;
	OCItem *parentItem, *uploadItem;
	NSURL *uploadURL;

	if (((remoteFileName = self.filename) != nil) &&
	    ((parentItem = self.parentItem) != nil) &&
	    ((uploadItem = self.localItem) != nil) &&
	    ((uploadURL = self.importFileURL) != nil))
	{
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
			OCProgress *progress;

			OCSyncExec(checksumComputation, {
				[OCChecksum computeForFile:_uploadCopyFileURL checksumAlgorithm:self.core.preferredChecksumAlgorithm completionHandler:^(NSError *error, OCChecksum *computedChecksum) {
					self.importFileChecksum = computedChecksum;
					OCSyncExecDone(checksumComputation);
				}];
			});

			// Schedule the upload
			OCItem *latestVersionOfLocalItem;
			NSDate *lastModificationDate = ((uploadItem.lastModified != nil) ? uploadItem.lastModified : [NSDate new]);
			NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
							lastModificationDate,			OCConnectionOptionLastModificationDateKey,
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

				if (syncContext.syncRecord.progress.progress != nil)
				{
					[self.core registerProgress:syncContext.syncRecord.progress.progress forItem:self.localItem];
				}
			}

			// Transition to processing
			[syncContext transitionToState:OCSyncRecordStateProcessing withWaitConditions:nil];

			// Wait for result
			return (OCCoreSyncInstructionStop);
		}
	}

	// Remove record as its action is not sufficiently specified
	return (OCCoreSyncInstructionDeleteLast);
}

- (OCCoreSyncInstruction)handleResultWithContext:(OCSyncContext *)syncContext
{
	OCEvent *event = syncContext.event;
	OCCoreSyncInstruction resultInstruction = OCCoreSyncInstructionNone;

	if ((event.error == nil) && (event.result != nil))
	{
		OCItem *uploadItem;
		OCItem *uploadedItem = (OCItem *)event.result;

		if ((uploadItem = self.localItem) != nil)
		{
			// Transfer localID
			uploadedItem.localID = uploadItem.localID;
			uploadedItem.parentLocalID = uploadItem.parentLocalID;

			// Propagte previousPlaceholderFileID
			if (![uploadedItem.fileID isEqual:uploadItem.fileID])
			{
				uploadedItem.previousPlaceholderFileID = uploadItem.fileID;
			}

			// Prepare uploadedItem to replace uploadItem
			[uploadedItem prepareToReplace:uploadItem];
			uploadedItem.lastUsed = uploadItem.lastUsed;

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

			// Add version information if local and uploaded item version are identical
			if (!uploadedItem.locallyModified)
			{
				uploadedItem.localCopyVersionIdentifier = uploadedItem.itemVersionIdentifier;
			}

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
		else
		{
			OCLogWarning(@"Upload completion failed retrieving localItem/placeholder");
		}

		// Action complete and can be removed
		[syncContext transitionToState:OCSyncRecordStateCompleted withWaitConditions:nil];
		resultInstruction = OCCoreSyncInstructionDeleteLast;
	}

	// Call resultHandler (and give file provider a chance to attach an uploadingError
	[syncContext completeWithError:event.error core:self.core item:(OCItem *)event.result parameter:self.localItem];

	if (event.error != nil)
	{
		if ([event.error isOCErrorWithCode:OCErrorCancelled] || [event.error isOCErrorWithCode:OCErrorRequestCancelled])
		{
			OCLogDebug(@"Upload has been cancelled - descheduling");
			[self.core _descheduleSyncRecord:syncContext.syncRecord completeWithError:syncContext.error parameter:nil];

			syncContext.error = nil;

			resultInstruction = OCCoreSyncInstructionProcessNext;
		}
		else
		{
			// Create issue for cancellation for all other errors
			[self.core _addIssueForCancellationAndDeschedulingToContext:syncContext title:[NSString stringWithFormat:OCLocalizedString(@"Couldn't upload %@", nil), self.localItem.name] description:[event.error localizedDescription] impact:OCSyncIssueChoiceImpactDataLoss]; // queues a new wait condition with the issue
			[syncContext transitionToState:OCSyncRecordStateProcessing withWaitConditions:nil]; // updates the sync record with the issue wait condition
		}
	}

	return (resultInstruction);
}

#pragma mark - Restore progress
- (OCItem *)itemToRestoreProgressRegistrationFor
{
	return (self.localItem);
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
