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
#import "OCCellularManager.h"

static OCMessageTemplateIdentifier OCMessageTemplateIdentifierUploadKeepBoth = @"upload.keep-both";
static OCMessageTemplateIdentifier OCMessageTemplateIdentifierUploadRetry = @"upload.retry";

@implementation OCSyncActionUpload

OCSYNCACTION_REGISTER_ISSUETEMPLATES

+ (OCSyncActionIdentifier)identifier
{
	return(OCSyncActionIdentifierUpload);
}

+ (NSArray<OCMessageTemplate *> *)actionIssueTemplates
{
	return (@[
		// Keep both
		[OCMessageTemplate templateWithIdentifier:OCMessageTemplateIdentifierUploadKeepBoth categoryName:nil choices:@[
			[OCSyncIssueChoice cancelChoiceWithImpact:OCSyncIssueChoiceImpactDataLoss],
			[OCSyncIssueChoice choiceOfType:OCIssueChoiceTypeDestructive impact:OCSyncIssueChoiceImpactDataLoss identifier:@"replaceExisting" label:OCLocalized(@"Replace") metaData:nil],
			[OCSyncIssueChoice choiceOfType:OCIssueChoiceTypeDefault impact:OCSyncIssueChoiceImpactNonDestructive identifier:@"keepBoth" label:OCLocalized(@"Keep both") metaData:nil]
		] options:nil],

		// Retry
		[OCMessageTemplate templateWithIdentifier:OCMessageTemplateIdentifierUploadRetry categoryName:nil choices:@[
			[OCSyncIssueChoice cancelChoiceWithImpact:OCSyncIssueChoiceImpactDataLoss],
			[OCSyncIssueChoice retryChoice]
		] options:nil]
	]);
}

#pragma mark - Initializer
- (instancetype)initWithUploadItem:(OCItem *)uploadItem parentItem:(OCItem *)parentItem filename:(NSString *)filename importFileURL:(NSURL *)importFileURL isTemporaryCopy:(BOOL)isTemporaryCopy options:(NSDictionary<OCCoreOption,id> *)options
{
	if ((self = [super initWithItem:uploadItem]) != nil)
	{
		self.parentItem = parentItem;

		self.importFileURL = importFileURL;
		self.importFileIsTemporaryAlongsideCopy = isTemporaryCopy;
		self.filename = filename;

		self.actionEventType = OCEventTypeUpload;
		self.localizedDescription = [NSString stringWithFormat:OCLocalized(@"Uploading %@…"), ((filename!=nil) ? filename : uploadItem.name)];

		self.options = options;

		self.categories = @[
			OCSyncActionCategoryAll, OCSyncActionCategoryTransfer,

			OCSyncActionCategoryUpload,

			([OCCellularManager.sharedManager cellularAccessAllowedFor:options[OCCoreOptionDependsOnCellularSwitch] transferSize:uploadItem.size] ?
				OCSyncActionCategoryUploadWifiAndCellular :
				OCSyncActionCategoryUploadWifiOnly)
		];
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
				NSError *error = nil;

				[[NSFileManager defaultManager] removeItemAtURL:_importFileURL error:&error];

				OCFileOpLog(@"rm", error, @"Deleted descheduled import at %@", _importFileURL.path);
			}

			// Remove local copy
			uploadItem.locallyModified = NO;
			[uploadItem clearLocalCopyProperties];

			[self.core deleteDirectoryForItem:uploadItem];

			// Update item
			syncContext.updatedItems = @[ uploadItem ];
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
				BOOL success = [[NSFileManager defaultManager] copyItemAtURL:uploadURL toURL:_uploadCopyFileURL error:&error];

				OCFileOpLog(@"cp", error, @"Cloning file to import %@ as %@", uploadURL.path, _uploadCopyFileURL.path);

				if (success)
				{
					// Cloning succeeded - upload from the clone
					uploadURL = _uploadCopyFileURL;
					_importFileURL = _uploadCopyFileURL;
					_importFileIsTemporaryAlongsideCopy = YES;
				}
				else
				{
					// Cloning failed - report error and offer to cancel upload
					OCLogError(@"error cloning file to import from %@ to %@: %@", uploadURL, _uploadCopyFileURL, error);

					_uploadCopyFileURL = nil;

					[self _addIssueForCancellationAndDeschedulingToContext:syncContext title:[NSString stringWithFormat:OCLocalizedString(@"Error uploading %@", nil), self.localItem.name] description:error.localizedDescription impact:OCSyncIssueChoiceImpactDataLoss];
					[syncContext transitionToState:OCSyncRecordStateProcessing withWaitConditions:nil]; // updates the sync record with the issue wait condition

					// Wait for result
					return (OCCoreSyncInstructionStop);
				}
			}
		}

		// Check for pre-existing item
		{
			OCItem *preExistingItem;

			if ((preExistingItem = [self _preExistingItem]) != nil)
			{
				// Create issue with other options for all other errors
				OCSyncIssue *issue;

				issue = [OCSyncIssue issueFromTemplate:OCMessageTemplateIdentifierUploadKeepBoth
							 forSyncRecord:syncContext.syncRecord
								 level:OCIssueLevelError
								 title:[NSString stringWithFormat:OCLocalizedString(@"Couldn't upload %@", nil), self.localItem.name]
							   description:[NSString stringWithFormat:OCLocalizedString(@"Another item named %@ already exists in %@.",nil), self.localItem.name, self.parentItem.name]
							      metaData:nil];

				[syncContext addSyncIssue:issue];
				[syncContext transitionToState:OCSyncRecordStateProcessing withWaitConditions:nil]; // updates the sync record with the issue wait condition

				// Wait for result
				return (OCCoreSyncInstructionStop);
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

			// Determine cellular switch ID dependency
			OCCellularSwitchIdentifier cellularSwitchID;

			if ((cellularSwitchID = self.options[OCCoreOptionDependsOnCellularSwitch]) == nil)
			{
				cellularSwitchID = OCCellularSwitchIdentifierMain;
			}

			// Create segment folder
			NSURL *segmentFolderURL = [[self.core.vault.rootURL URLByAppendingPathComponent:@"TUS"] URLByAppendingPathComponent:NSUUID.UUID.UUIDString];

			// Schedule the upload
			NSDate *lastModificationDate = ((uploadItem.lastModified != nil) ? uploadItem.lastModified : [NSDate new]);
			NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
							segmentFolderURL,								OCConnectionOptionTemporarySegmentFolderURLKey,
							lastModificationDate,								OCConnectionOptionLastModificationDateKey,
							cellularSwitchID,								OCConnectionOptionRequiredCellularSwitchKey,
							@(((NSNumber *)self.options[OCConnectionOptionForceReplaceKey]).boolValue),	OCConnectionOptionForceReplaceKey,
							self.importFileChecksum, 	 						OCConnectionOptionChecksumKey,		// not using @{} syntax here: if importFileChecksum is nil for any reason, that'd throw
						nil];

			[self setupProgressSupportForItem:self.latestVersionOfLocalItem options:&options syncContext:syncContext];

			if ((progress = [self.core.connection uploadFileFromURL:uploadURL
								       withName:remoteFileName
									     to:parentItem
								  replacingItem:(self.replaceItem != nil) ? self.replaceItem : (self.localItem.isPlaceholder ? nil : self.latestVersionOfLocalItem)
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
				NSError *error = nil;

				[[NSFileManager defaultManager] removeItemAtURL:_importFileURL error:&error];

				OCFileOpLog(@"rm", error, @"Deleted temporary copy at %@", _importFileURL.path);
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

	// Call resultHandler (and give file provider a chance to attach an uploadingError)
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
			// Create issue with other options for all other errors
			OCSyncIssue *issue;
			BOOL alreadyExists = [event.error isOCErrorWithCode:OCErrorItemAlreadyExists];

			issue = [OCSyncIssue issueFromTemplate:(alreadyExists ? OCMessageTemplateIdentifierUploadKeepBoth : OCMessageTemplateIdentifierUploadRetry)
						 forSyncRecord:syncContext.syncRecord
							 level:OCIssueLevelError
							 title:[NSString stringWithFormat:OCLocalizedString(@"Couldn't upload %@", nil), self.localItem.name]
						   description:event.error.localizedDescription
						      metaData:nil];

			[issue setAutoChoiceError:event.error forChoiceWithIdentifier:OCSyncIssueChoiceIdentifierRetry];

			[syncContext addSyncIssue:issue];
			[syncContext transitionToState:OCSyncRecordStateProcessing withWaitConditions:nil]; // updates the sync record with the issue wait condition
		}
	}

	return (resultInstruction);
}

#pragma mark - Issue resolution
- (OCItem *)_preExistingItem
{
	__block OCItem *itemToReplace = nil;
	OCLocalID localItemLocalID;

	if ((localItemLocalID = self.localItem.localID) != nil)
	{
		[self.core.vault.database retrieveCacheItemsAtPath:self.localItem.path itemOnly:NO completionHandler:^(OCDatabase *db, NSError *error, OCSyncAnchor syncAnchor, NSArray<OCItem *> *items) {
			for (OCItem *item in items)
			{
				if (![item.localID isEqual:localItemLocalID])
				{
					itemToReplace = item;
					break;
				}
			}
		}];
	}

	return (itemToReplace);
}

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
				NSString *dateString = [[NSDate new] compactLocalTimeZoneString];
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

				// Decouple from existing file ID and eTag to prevent collissions and duplicates
 				self.localItem.eTag = OCFileETagPlaceholder;
 				self.localItem.fileID = [OCItem generatePlaceholderFileID];

				// No longer replacing another item
 				self.replaceItem = nil;

 				// Move underlying file
 				NSURL *newLocalURL = [self.core localURLForItem:self.localItem];
 				NSError *error = nil;

 				if (![[NSFileManager defaultManager] moveItemAtURL:previousLocalURL toURL:newLocalURL error:&error])
 				{
 					OCLogError(@"Renaming local copy of file from %@ to %@ during `keepBoth` issue resolution returned an error=%@", previousLocalURL, newLocalURL, error);
				}

				OCFileOpLog(@"mv", error, @"Renamed local copy of file from %@ to %@ during `keepBoth` issue resolution", previousLocalURL.path, newLocalURL.path);

				// Update item
				syncContext.updatedItems = @[ self.localItem ];

				// Initiate scan to get the item that took this item's place
				OCPath parentPath;
				if ((parentPath = self.localItem.path.parentPath) != nil)
				{
					syncContext.refreshPaths = @[ parentPath ];
				}
				syncContext.updateStoredSyncRecordAfterItemUpdates = YES;
			}

			// Reschedule
			[syncContext transitionToState:OCSyncRecordStateReady withWaitConditions:nil];

			resolutionError = nil;
		}

		if ([choice.identifier isEqual:@"replaceExisting"])
		{
			// Replace existing (force replace)
			NSMutableDictionary<OCCoreOption,id> *options = (_options != nil) ? [_options mutableCopy] : [NSMutableDictionary new];
			options[OCConnectionOptionForceReplaceKey] = @(YES);
			self.options = options;

			syncContext.updateStoredSyncRecordAfterItemUpdates = YES;

			[syncContext transitionToState:OCSyncRecordStateReady withWaitConditions:nil];

			resolutionError = nil;
		}
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

	_options = [decoder decodeObjectOfClasses:OCEvent.safeClasses forKey:@"options"];
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

	[coder encodeObject:_options forKey:@"options"];
}

@end

OCSyncActionCategory OCSyncActionCategoryUpload = @"upload";
OCSyncActionCategory OCSyncActionCategoryUploadWifiOnly = @"upload-wifi-only";
OCSyncActionCategory OCSyncActionCategoryUploadWifiAndCellular = @"upload-cellular-and-wifi";
