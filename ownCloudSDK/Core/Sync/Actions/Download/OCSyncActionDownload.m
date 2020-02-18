//
//  OCSyncActionDownload.m
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

#import "OCSyncActionDownload.h"
#import "OCSyncAction+FileProvider.h"
#import "OCCore+FileProvider.h"
#import "OCCore+ItemUpdates.h"
#import "OCCore+Claims.h"

@implementation OCSyncActionDownload

#pragma mark - Initializer
- (instancetype)initWithItem:(OCItem *)item options:(NSDictionary<OCCoreOption,id> *)options
{
	if ((self = [super initWithItem:item]) != nil)
	{
		self.identifier = OCSyncActionIdentifierDownload;

		self.options = options;

		self.actionEventType = OCEventTypeDownload;
		self.localizedDescription = [NSString stringWithFormat:OCLocalized(@"Downloading %@…"), item.name];

		self.categories = @[ OCSyncActionCategoryAll, OCSyncActionCategoryTransfer, OCSyncActionCategoryDownload ];
	}

	return (self);
}

#pragma mark - Action implementation
- (void)preflightWithContext:(OCSyncContext *)syncContext
{
	OCItem *item;
	BOOL returnImmediately = ((NSNumber *)self.options[OCCoreOptionReturnImmediatelyIfOfflineOrUnavailable]).boolValue;

	if ((item = self.localItem) != nil)
	{
		item.lastUsed = [NSDate new];

		if ((item.localRelativePath != nil) && // Copy of item is stored locally
		    [item.itemVersionIdentifier isEqual:self.archivedServerItem.itemVersionIdentifier]) // Local item version is identical to latest known version on the server
		{
			// Item already downloaded - take some shortcuts
			syncContext.removeRecords = @[ syncContext.syncRecord ];

			// Make sure the lastUsed property is updated regardless
			syncContext.updatedItems = @[ item ];

			OCFile *file = [item fileWithCore:self.core];

			// Add / generate claim according to options
			OCClaim *addClaim = self.options[OCCoreOptionAddFileClaim];
			OCCoreClaimPurpose claimPurpose = OCCoreClaimPurposeNone;

			if (self.options[OCCoreOptionAddTemporaryClaimForPurpose] != nil)
			{
				claimPurpose = ((NSNumber *)self.options[OCCoreOptionAddTemporaryClaimForPurpose]).integerValue;
			}

			if (claimPurpose != OCCoreClaimPurposeNone)
			{
				OCClaim *temporaryClaim;

				if ((temporaryClaim = [self.core generateTemporaryClaimForPurpose:claimPurpose]) != nil)
				{
					addClaim = [OCClaim combining:addClaim with:temporaryClaim usingOperator:OCClaimGroupOperatorOR];
					file.claim = temporaryClaim;

					[self.core removeClaim:temporaryClaim onItem:item afterDeallocationOf:@[file]];
				}
			}

			if (addClaim != nil)
			{
				[self.core addClaim:addClaim onItem:item completionHandler:nil];
			}

			[syncContext completeWithError:nil core:self.core item:item parameter:file];
		}
		else if (returnImmediately && (self.core.connectionStatus != OCCoreConnectionStatusOnline))
		{
			// Item not available and asked to return immediately

			syncContext.removeRecords = @[ syncContext.syncRecord ];

			[syncContext completeWithError:OCError(OCErrorItemNotAvailableOffline) core:self.core item:item parameter:nil];
		}
		else
		{
			// Download item
			[item addSyncRecordID:syncContext.syncRecord.recordID activity:OCItemSyncActivityDownloading];

			syncContext.updatedItems = @[ item ];
		}
	}
}

- (void)descheduleWithContext:(OCSyncContext *)syncContext
{
	OCItem *item;

	if ((item = self.localItem) != nil)
	{
		OCItem *latestVersionOfItem;

		if ((latestVersionOfItem = [self.core retrieveLatestVersionOfItem:item withError:nil]) != nil)
		{
			[latestVersionOfItem prepareToReplace:item];

			OCLogDebug(@"Descheduling - and updating %@ with replacement %@", item, latestVersionOfItem);

			item = latestVersionOfItem;
		}

		[item removeSyncRecordID:syncContext.syncRecord.recordID activity:OCItemSyncActivityDownloading];

		syncContext.updatedItems = @[ item ];
	}
}

- (OCCoreSyncInstruction)scheduleWithContext:(OCSyncContext *)syncContext
{
	OCItem *item;

	OCLogDebug(@"record %@ enters download scheduling", syncContext.syncRecord);

	if ((item = self.archivedServerItem) != nil)
	{
		// Retrieve latest version from cache
		NSError *error = nil;
		OCItem *latestVersionOfItem;

		OCLogDebug(@"record %@ download: retrieve latest version from cache", syncContext.syncRecord);

		if ((latestVersionOfItem = [self.core retrieveLatestVersionOfItem:item withError:&error]) != nil)
		{
			// Check for locally modified version
			if (latestVersionOfItem.locallyModified)
			{
				// Ask user to choose between keeping modifications or overwriting with server version
				OCSyncIssue *issue;

				OCLogDebug(@"record %@ download: latest version was locally modified", syncContext.syncRecord);

				issue = [OCSyncIssue issueForSyncRecord:syncContext.syncRecord level:OCIssueLevelWarning title:[NSString stringWithFormat:OCLocalized(@"\"%@\" has been modified locally"), item.name] description:[NSString stringWithFormat:OCLocalized(@"A modified, unsynchronized version of \"%@\" is present on your device. Downloading the file from the server will overwrite it and modifications be lost."), item.name] metaData:nil choices:@[
						// Delete local representation and reschedule download
						[OCSyncIssueChoice choiceOfType:OCIssueChoiceTypeRegular impact:OCSyncIssueChoiceImpactDataLoss identifier:@"overwriteModifiedFile" label:OCLocalized(@"Overwrite modified file") metaData:nil],

						// Keep local modifications and drop sync record
						[OCSyncIssueChoice cancelChoiceWithImpact:OCSyncIssueChoiceImpactNonDestructive]
				]];

				OCLogDebug(@"record %@ download: returning from scheduling with an issue (locallyModified)", syncContext.syncRecord);

				[syncContext addSyncIssue:issue];

				// Prevent scheduling of download
				[syncContext transitionToState:OCSyncRecordStateReady withWaitConditions:nil]; // schedule issue
				return (OCCoreSyncInstructionStop);
			}
		}
	}

	if (item != nil)
	{
		OCProgress *progress;
		NSDictionary *options = self.options;

		NSURL *temporaryDirectoryURL = self.core.vault.temporaryDownloadURL;
		NSURL *temporaryFileURL = [temporaryDirectoryURL URLByAppendingPathComponent:[NSUUID UUID].UUIDString];

		OCLogDebug(@"record %@ download: setting up directory", syncContext.syncRecord);

		if (![[NSFileManager defaultManager] fileExistsAtPath:temporaryDirectoryURL.path])
		{
			[[NSFileManager defaultManager] createDirectoryAtURL:temporaryDirectoryURL withIntermediateDirectories:YES attributes:nil error:NULL];
		}

		[self setupProgressSupportForItem:item options:&options syncContext:syncContext];

		OCLogDebug(@"record %@ download: initiating download", syncContext.syncRecord);

		if ((progress = [self.core.connection downloadItem:item to:temporaryFileURL options:options resultTarget:[self.core _eventTargetWithSyncRecord:syncContext.syncRecord]]) != nil)
		{
			OCLogDebug(@"record %@ download: download initiated with progress %@", syncContext.syncRecord, progress);

			[syncContext.syncRecord addProgress:progress];

			if (syncContext.syncRecord.progress.progress != nil)
			{
				[self.core registerProgress:syncContext.syncRecord.progress.progress forItem:item];
			}
		}

		// Transition to processing
		[syncContext transitionToState:OCSyncRecordStateProcessing withWaitConditions:nil];

		// Wait for result
		return (OCCoreSyncInstructionStop);
	}

	// Remove record as its action is not sufficiently specified
	return (OCCoreSyncInstructionDeleteLast);
}

- (OCCoreSyncInstruction)handleResultWithContext:(OCSyncContext *)syncContext
{
	OCEvent *event = syncContext.event;
	OCFile *downloadedFile = event.file;
	OCSyncRecord *syncRecord = syncContext.syncRecord;
	OCCoreSyncInstruction resultInstruction = OCCoreSyncInstructionNone;
	OCItem *item = self.archivedServerItem;
	NSError *downloadError = event.error;

	if ((event.error == nil) && (event.file != nil) && (item != nil))
	{
		NSError *error = nil;
		NSURL *vaultItemURL = [self.core.vault localURLForItem:item];
		NSString *vaultItemLocalRelativePath = [self.core.vault relativePathForItem:item];
		BOOL useDownloadedFile = YES;
		OCItem *latestVersionOfItem = nil;

		// Using archivedServerItem for item, which can sometimes differ from localItem, so make sure to carry info over
		[item prepareToReplace:self.localItem];

		// Validate checksum of downloaded file
		if (useDownloadedFile)
		{
			__block BOOL checksumIsValid = NO;

			if (event.file.checksum != nil)
			{
				// Verify checksum and wait for result of computation
				OCSyncExec(checksumVerification, {
					[event.file.checksum verifyForFile:event.file.url completionHandler:^(NSError *error, BOOL isValid, OCChecksum *actualChecksum) {
						checksumIsValid = isValid;
						OCSyncExecDone(checksumVerification);
					}];
				});
			}
			else
			{
				// No checksum available ¯\_(ツ)_/¯
				checksumIsValid = YES;
			}

			if (!checksumIsValid)
			{
				// Checksum of downloaded file is not valid => bring up issue
				OCSyncIssue *issue;

				useDownloadedFile = NO;

				issue = [OCSyncIssue issueForSyncRecord:syncRecord level:OCIssueLevelError title:OCLocalized(@"Invalid checksum") description:OCLocalized(@"The downloaded file's checksum does not match the checksum provided by the server.") metaData:nil choices:@[
					// Reschedule sync record
					[OCSyncIssueChoice retryChoice],

					// Drop sync record
					[OCSyncIssueChoice cancelChoiceWithImpact:OCSyncIssueChoiceImpactNonDestructive],
				]];

				[syncContext addSyncIssue:issue];
			}
		}

		// Check for locally modified version
		if (useDownloadedFile)
		{
			if ((latestVersionOfItem = [self.core retrieveLatestVersionOfItem:item withError:NULL]) != nil)
			{
				// This catches the edge case where a file was locally modified WHILE a download of the same file was already scheduled
				// The case where a download is initiated when a locally modified version exists is caught in download scheduling
				if (latestVersionOfItem.locallyModified)
				{
					OCSyncIssue *issue;

					useDownloadedFile = NO;

					issue = [OCSyncIssue issueForSyncRecord:syncRecord level:OCIssueLevelError title:OCLocalized(@"File modified locally") description:[NSString stringWithFormat:OCLocalized(@"\"%@\" was modified locally before the download completed."), item.name] metaData:nil choices:@[
						// Drop sync record
						[OCSyncIssueChoice cancelChoiceWithImpact:OCSyncIssueChoiceImpactNonDestructive],
					]];

					[syncContext addSyncIssue:issue];
				}
			}
		}

		// Use downloaded file?
		if (useDownloadedFile)
		{
			NSURL *vaultItemParentURL = vaultItemURL.URLByDeletingLastPathComponent;
			NSURL *existingFileTemporaryURL = nil;

			if (![[NSFileManager defaultManager] fileExistsAtPath:vaultItemParentURL.path])
			{
				// Create target directory
				[[NSFileManager defaultManager] createDirectoryAtURL:vaultItemParentURL withIntermediateDirectories:YES attributes:nil error:&error];
			}
			else
			{
				// Target directory exists
				if ([[NSFileManager defaultManager] fileExistsAtPath:vaultItemURL.path])
				{
					// Move existing file out of the way
					if ((existingFileTemporaryURL = [vaultItemURL URLByAppendingPathExtension:[NSString stringWithFormat:@".%@.octmp", NSUUID.UUID.UUIDString]]) != nil)
					{
						[[NSFileManager defaultManager] moveItemAtURL:vaultItemURL toURL:existingFileTemporaryURL error:&error];
					}
				}
			}

			if (error == nil)
			{
				// Move download to item path
				if ([[NSFileManager defaultManager] moveItemAtURL:event.file.url toURL:vaultItemURL error:&error])
				{
					// Switch to "remoteItem" or latestVersionOfItem if eTag of downloaded file doesn't match
					if (![item.eTag isEqual:event.file.eTag])
					{
						if (![item.remoteItem.eTag isEqual:event.file.eTag])
						{
							[item.remoteItem prepareToReplace:item];
							item = item.remoteItem;
						}
						else if (![latestVersionOfItem.eTag isEqual:event.file.eTag])
						{
							[latestVersionOfItem prepareToReplace:item];
							item = latestVersionOfItem;
						}
					}

					item.localRelativePath = vaultItemLocalRelativePath;
					item.localCopyVersionIdentifier = [[OCItemVersionIdentifier alloc] initWithFileID:event.file.fileID eTag:event.file.eTag];

					item.downloadTriggerIdentifier = self.options[OCCoreOptionDownloadTriggerID];
					item.fileClaim = self.options[OCCoreOptionAddFileClaim];

					downloadedFile.url = vaultItemURL;

					// Add temporary claim
					OCCoreClaimPurpose claimPurpose = OCCoreClaimPurposeNone;

					if (self.options[OCCoreOptionAddTemporaryClaimForPurpose] != nil)
					{
						claimPurpose = ((NSNumber *)self.options[OCCoreOptionAddTemporaryClaimForPurpose]).integerValue;
					}

					if (claimPurpose != OCCoreClaimPurposeNone)
					{
						OCClaim *temporaryClaim;

						if ((temporaryClaim = [self.core generateTemporaryClaimForPurpose:claimPurpose]) != nil)
						{
							item.fileClaim = [OCClaim combining:item.fileClaim with:temporaryClaim usingOperator:OCClaimGroupOperatorOR];
							event.file.claim = temporaryClaim;

							[self.core removeClaim:temporaryClaim onItem:item afterDeallocationOf:@[event.file]];
						}
					}
				}

				// Remove any previously existing file
				if (existingFileTemporaryURL != nil)
				{
					if (error == nil)
					{
						// Moving downloaded file successful => remove existing file
						[[NSFileManager defaultManager] removeItemAtURL:existingFileTemporaryURL error:&error];
					}
					else
					{
						// Moving downloaded file failed => put existing file back in place
						[[NSFileManager defaultManager] moveItemAtURL:existingFileTemporaryURL toURL:vaultItemURL error:&error];
					}
				}
			}
		}

		[item removeSyncRecordID:syncContext.syncRecord.recordID activity:OCItemSyncActivityDownloading];
		syncContext.updatedItems = @[ item ];

		// Action complete and can be removed
		[syncContext transitionToState:OCSyncRecordStateCompleted withWaitConditions:nil];
		resultInstruction = OCCoreSyncInstructionDeleteLast;

		[syncContext completeWithError:downloadError core:self.core item:item parameter:downloadedFile];

		if (error != nil)
		{
			downloadError = error;
		}
	}
	else
	{
		if (downloadError == nil)
		{
			// Result is incomplete, but can't be attributed to any error, either
			downloadError = OCError(OCErrorInternal);
		}
	}

	if (downloadError != nil)
	{
		if ([downloadError isOCErrorWithCode:OCErrorCancelled])
		{
			// Download has been cancelled by the user => create no issue, remove sync record reference and the record itself instead
			if (item != nil)
			{
				[item removeSyncRecordID:syncContext.syncRecord.recordID activity:OCItemSyncActivityDownloading];
				syncContext.updatedItems = @[ item ];
			}

			// Action complete and can be removed
			[syncContext transitionToState:OCSyncRecordStateCompleted withWaitConditions:nil];
			resultInstruction = OCCoreSyncInstructionDeleteLast;

			[syncContext completeWithError:downloadError core:self.core item:item parameter:downloadedFile];
		}
		else
		{
			BOOL handledError = NO;

			if ([downloadError.domain isEqual:OCHTTPStatusErrorDomain] && (downloadError.code == OCHTTPStatusCodePRECONDITION_FAILED))
			{
				// Precondition failed: ETag of the file to download has changed on the server
				// For Available Offline, this can be handled automatically
				OCLogError(@"Download %@ error %@ => ETag on the server likely changed from the last known ETag", item, downloadError);

				if ([self.options[OCCoreOptionDownloadTriggerID] isEqual:OCItemDownloadTriggerIDAvailableOffline])
				{
					OCLogError(@"Download %@ is an available offline download => descheduling automatically without raising an issue", item);

					[self.core descheduleSyncRecord:syncContext.syncRecord completeWithError:downloadError parameter:nil];
					handledError = YES;
				}
			}

			if (!handledError)
			{
				// Create cancellation issue for any errors (TODO: extend options to include "Retry")
				OCLogError(@"Wrapping download %@ error %@ into cancellation issue", item, downloadError);

				[self.core _addIssueForCancellationAndDeschedulingToContext:syncContext title:[NSString stringWithFormat:OCLocalizedString(@"Couldn't download %@", nil), self.localItem.name] description:[downloadError localizedDescription] impact:OCSyncIssueChoiceImpactNonDestructive]; // queues a new wait condition with the issue
				[syncContext transitionToState:OCSyncRecordStateProcessing withWaitConditions:nil]; // updates the sync record with the issue wait condition
			}
		}
	}

	return (resultInstruction);
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

		if ([choice.identifier isEqual:@"overwriteModifiedFile"])
		{
			// Delete local representation and reschedule download
			[self.core rescheduleSyncRecord:syncContext.syncRecord withUpdates:^NSError *(OCSyncRecord *record) {
				OCItem *latestItem;
				NSError *error = nil;

				if ((latestItem = [self.core retrieveLatestVersionOfItem:self.archivedServerItem withError:&error]) != nil)
				{
					if (latestItem.locallyModified)
					{
						NSURL *deleteFileURL;

						if ((deleteFileURL = [self.core localURLForItem:latestItem]) != nil)
						{
							NSError *deleteError = nil;

							if ([[NSFileManager defaultManager] removeItemAtURL:deleteFileURL error:&deleteError])
							{
								// Replace locally modified item with latest version
								if (latestItem.remoteItem != nil)
								{
									[latestItem.remoteItem prepareToReplace:latestItem];
									latestItem = latestItem.remoteItem;
								}

								latestItem.locallyModified = NO;
								latestItem.localRelativePath = nil;
								latestItem.localCopyVersionIdentifier = nil;
								latestItem.downloadTriggerIdentifier = nil;

								syncContext.updatedItems = @[ latestItem ];
							}

							OCLogDebug(@"deleted %@ with error=%@ and rescheduling download", deleteFileURL, deleteError);
						}
					}
				}

				return (error);
			}];

			resolutionError = nil;
		}
	}

	return (resolutionError);
}

#pragma mark - Restore progress
- (OCItem *)itemToRestoreProgressRegistrationFor
{
	return (self.archivedServerItem);
}

#pragma mark - Lane tags
- (NSSet<OCSyncLaneTag> *)generateLaneTags
{
	return ([self generateLaneTagsFromItems:@[
		OCSyncActionWrapNullableItem(self.localItem)
	]]);
}

#pragma mark - NSCoding
- (void)decodeActionData:(NSCoder *)decoder
{
	_options = [decoder decodeObjectOfClasses:OCEvent.safeClasses forKey:@"options"];
}

- (void)encodeActionData:(NSCoder *)coder
{
	[coder encodeObject:_options forKey:@"options"];
}

@end

OCSyncActionCategory OCSyncActionCategoryDownload = @"download";
