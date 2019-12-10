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

#import "OCCore.h"
#import "OCSyncActionUpload.h"
#import "OCSyncAction+FileProvider.h"
#import "OCChecksum.h"
#import "OCChecksumAlgorithmSHA1.h"
#import "NSDate+OCDateParser.h"

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

		self.categories = @[ OCSyncActionCategoryAll, OCSyncActionCategoryTransfer, OCSyncActionCategoryUpload ];
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

		if (uploadItem.isPlaceholder && (uploadItem.databaseID == nil))
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
								  replacingItem:(self.replaceItem != nil) ? self.replaceItem : (self.localItem.isPlaceholder ? nil : latestVersionOfLocalItem)
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

		if ((uploadItem = self.latestVersionOfLocalItem) != nil)
		{
			// Transfer localID
			uploadedItem.localID = uploadItem.localID;
			uploadedItem.parentLocalID = uploadItem.parentLocalID;

			// Propagate previousPlaceholderFileID
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

			// Set download trigger to available offline if the item is targeted by available offline, as it might
			// otherwise be removed and re-downloaded
			NSArray<OCItemPolicy *> *availableOfflineItemPoliciesCoveringItem;

			if (((availableOfflineItemPoliciesCoveringItem =  [self.core retrieveAvailableOfflinePoliciesCoveringItem:uploadedItem completionHandler:nil]) != nil) && (availableOfflineItemPoliciesCoveringItem.count > 0))
			{
				uploadedItem.downloadTriggerIdentifier = OCItemDownloadTriggerIDAvailableOffline;
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
			OCSyncIssue *issue;
			NSMutableArray <OCSyncIssueChoice *> *choices = [NSMutableArray new];

			[choices addObject:[OCSyncIssueChoice cancelChoiceWithImpact:OCSyncIssueChoiceImpactDataLoss]];

			if ([event.error isOCErrorWithCode:OCErrorItemAlreadyExists])
			{
				[choices addObject:[OCSyncIssueChoice choiceOfType:OCIssueChoiceTypeDefault impact:OCSyncIssueChoiceImpactNonDestructive identifier:@"keepBoth" label:OCLocalized(@"Keep both") metaData:nil]];
//				[choices addObject:[OCSyncIssueChoice choiceOfType:OCIssueChoiceTypeDefault impact:OCSyncIssueChoiceImpactDataLoss identifier:@"replaceExisting" label:OCLocalized(@"Replace existing") metaData:nil]];
			}
			else
			{
				[choices addObject:[OCSyncIssueChoice retryChoice]];
			}

			issue = [OCSyncIssue issueForSyncRecord:syncContext.syncRecord
							  level:OCIssueLevelError
							  title:[NSString stringWithFormat:OCLocalizedString(@"Couldn't upload %@", nil), self.localItem.name]
						    description:event.error.localizedDescription
						       metaData:nil
							choices:choices];

			[syncContext addSyncIssue:issue];
			[syncContext transitionToState:OCSyncRecordStateProcessing withWaitConditions:nil]; // updates the sync record with the issue wait condition
		}
	}

	return (resultInstruction);
}

#pragma mark - Issue resolution
- (NSError *)resolveIssue:(OCSyncIssue *)issue withChoice:(OCSyncIssueChoice *)choice context:(OCSyncContext *)syncContext
{
	NSError *resolutionError = nil;

	if ((resolutionError = [super resolveIssue:issue withChoice:choice context:syncContext]) != nil)
	{
		if (![resolutionError isOCErrorWithCode:OCErrorFeatureNotImplemented])
		{
			return (resolutionError);
		}

		if ([choice.identifier isEqual:@"keepBoth"])
		{
			// Keep both
			if (self.filename != nil)
			{
				NSString *filename = [self.filename stringByDeletingPathExtension];
				NSString *extension = [self.filename pathExtension];
				NSString *dateString = [[NSDate new] compactUTCString];
				NSURL *previousLocalURL = [self.core localURLForItem:self.localItem];

				if (filename.length > 0)
				{
					filename = [filename stringByAppendingFormat:@" (%@)", dateString];
				}
				else
				{
					filename = @"";
					extension = [extension stringByAppendingFormat:@" (%@)", dateString];
				}

				// Create filename with timestamp
				self.filename = [NSString stringWithFormat:@"%@.%@", filename, extension];

				// Adapt paths
 				self.localItem.path = [self.localItem.path.parentPath stringByAppendingPathComponent:self.filename];
 				self.localItem.localRelativePath = [self.core.vault relativePathForItem:self.localItem];

 				// Move underlying file
 				NSURL *newLocalURL = [self.core localURLForItem:self.localItem];
 				NSError *error = nil;

 				if (![[NSFileManager defaultManager] moveItemAtURL:previousLocalURL toURL:newLocalURL error:&error])
 				{
 					OCLogError(@"Renaming local copy of file from %@ to %@ during `keepBoth` issue resolution returned an error=%@", previousLocalURL, newLocalURL, error);
				}

				syncContext.updatedItems = @[ self.localItem ];
			}

			// Reschedule
			[syncContext transitionToState:OCSyncRecordStateReady withWaitConditions:nil];

			resolutionError = nil;
		}

//		Needs more work and probably worth new APIs for general (re-)use
//
//		if ([choice.identifier isEqual:@"replaceExisting"])
//		{
//			// Replace existing
//			NSError *error = nil;
//			OCItem *latestVersionItem = nil;
//			OCItem *replaceItem = nil;
//
//			if ((latestVersionItem = [self.core retrieveLatestVersionOfItem:self.localItem withError:&error]) != nil)
//			{
//				if (latestVersionItem.isPlaceholder)
//				{
//					if (latestVersionItem.remoteItem != nil)
//					{
//						replaceItem = latestVersionItem.remoteItem;
//					}
//				}
//				else
//				{
//					replaceItem = latestVersionItem;
//				}
//
//				if (replaceItem != nil)
//				{
//					// Avoid conflicts with other ongoing sync activities
//					if ((replaceItem.syncActivity == OCItemSyncActivityNone) && (replaceItem.activeSyncRecordIDs.count == 0))
//					{
//						OCItem *placeholderItemCopy;
//
//						// Replace existing item
//						self.replaceItem = replaceItem;
//
//						// Remove item with new placeholder ID
//						if ((placeholderItemCopy = [self.localItem copy]) != nil)
//						{
//							syncContext.removedItems = @[ placeholderItemCopy ];
//						}
//
//						// Move upload item to existing localID
//						[self.localItem prepareToReplace:self.replaceItem];
//
//						// Carry over fileID
//						self.localItem.fileID = self.replaceItem.fileID;
//
//						// Carry over sync status
//						self.localItem.syncActivity = placeholderItemCopy.syncActivity;
//						self.localItem.activeSyncRecordIDs = placeholderItemCopy.activeSyncRecordIDs;
//
//						// Carry over locally modified status
//						self.localItem.locallyModified = placeholderItemCopy.locallyModified;
//
//						// Move over file to upload
//						NSURL *replacedItemFileURL;
//
//						if ((replacedItemFileURL = [self.core localURLForItem:self.localItem]) != nil)
//						{
//							NSError *error = nil;
//
//							// Make a copy of the file before upload (utilizing APFS cloning, this should be both almost instant as well as cost no actual disk space thanks to APFS copy-on-write)
//							if (![[NSFileManager defaultManager] removeItemAtURL:replacedItemFileURL error:&error])
//							{
//								if (error != nil)
//								{
//									OCLogError(@"Error %@ removing file %@", error, replacedItemFileURL);
//								}
//							}
//
// 							TODO: Clarify roles of _uploadCopyFileURL and _importFileURL. Adapt path and localRelativePath. Also remove placeholder item directory afterwards. Finish implementation.
//							if ([[NSFileManager defaultManager] copyItemAtURL:_uploadCopyFileURL toURL:replacedItemFileURL error:&error])
//							{
//								// Cloning succeeded - upload from the clone
//								_uploadCopyFileURL = replacedItemFileURL;
//
//								_importFileURL = _uploadCopyFileURL;
//								_importFileIsTemporaryAlongsideCopy = NO;
//							}
//							else
//							{
//								// Cloning failed - continue to use the "original"
//								OCLogError(@"error cloning file to import from %@ to %@: %@", _uploadCopyFileURL, replacedItemFileURL, error);
//
//								_uploadCopyFileURL = nil;
//							}
//						}
//
//						// Update with existing localID
//						syncContext.updatedItems = @[ self.localItem ];
//
//						// Make sure this is stored
//						syncContext.updateStoredSyncRecordAfterItemUpdates = YES;
//
//						// Reschedule
//						[syncContext transitionToState:OCSyncRecordStateReady withWaitConditions:nil];
//					}
//					else
//					{
//						replaceItem = nil;
//					}
//				}
//			}
//
//			if (replaceItem == nil)
//			{
//				// No item to replace found / available => turn into ordinary retry
//				[self.core rescheduleSyncRecord:syncContext.syncRecord withUpdates:nil];
//			}
//
//			resolutionError = nil;
//		}
	}

	return (resolutionError);
}

#pragma mark - Restore progress
- (OCItem *)itemToRestoreProgressRegistrationFor
{
	return (self.localItem);
}

#pragma mark - Lane tags
- (NSSet<OCSyncLaneTag> *)generateLaneTags
{
	return ([self generateLaneTagsFromItems:@[
		OCSyncActionWrapNullableItem(self.localItem),
		OCSyncActionWrapNullableItem(self.replaceItem)
	]]);
}

#pragma mark - NSCoding
- (void)decodeActionData:(NSCoder *)decoder
{
	_filename = [decoder decodeObjectOfClass:[NSString class] forKey:@"filename"];

	_importFileURL = [decoder decodeObjectOfClass:[NSURL class] forKey:@"importFileURL"];
	_importFileChecksum = [decoder decodeObjectOfClass:[OCChecksum class] forKey:@"importFileChecksum"];
	_importFileIsTemporaryAlongsideCopy = [decoder decodeBoolForKey:@"importFileIsTemporaryAlongsideCopy"];

	_parentItem = [decoder decodeObjectOfClass:[OCItem class] forKey:@"parentItem"];
	_replaceItem = [decoder decodeObjectOfClass:[OCItem class] forKey:@"replaceItem"];

	_uploadCopyFileURL = [decoder decodeObjectOfClass:[NSURL class] forKey:@"uploadCopyFileURL"];
}

- (void)encodeActionData:(NSCoder *)coder
{
	[coder encodeObject:_filename forKey:@"filename"];

	[coder encodeObject:_importFileURL forKey:@"importFileURL"];
	[coder encodeObject:_importFileChecksum forKey:@"importFileChecksum"];
	[coder encodeBool:_importFileIsTemporaryAlongsideCopy forKey:@"importFileIsTemporaryAlongsideCopy"];

	[coder encodeObject:_parentItem forKey:@"parentItem"];
	[coder encodeObject:_replaceItem forKey:@"replaceItem"];

	[coder encodeObject:_uploadCopyFileURL forKey:@"uploadCopyFileURL"];
}

@end

OCSyncActionCategory OCSyncActionCategoryUpload = @"upload";
