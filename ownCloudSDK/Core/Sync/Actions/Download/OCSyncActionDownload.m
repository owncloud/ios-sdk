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
#import "OCWaitConditionMetaDataRefresh.h"
#import "OCCellularManager.h"

static OCMessageTemplateIdentifier OCMessageTemplateIdentifierDownloadOverwrite = @"download.overwrite";
static OCMessageTemplateIdentifier OCMessageTemplateIdentifierDownloadRetry = @"download.retry";
static OCMessageTemplateIdentifier OCMessageTemplateIdentifierDownloadCancel = @"download.cancel";

@implementation OCSyncActionDownload

OCSYNCACTION_REGISTER_ISSUETEMPLATES

+ (OCSyncActionIdentifier)identifier
{
	return(OCSyncActionIdentifierDownload);
}

+ (NSArray<OCMessageTemplate *> *)actionIssueTemplates
{
	return (@[
		// Overwrite
		[OCMessageTemplate templateWithIdentifier:OCMessageTemplateIdentifierDownloadOverwrite categoryName:nil choices:@[
			// Delete local representation and reschedule download
			[OCSyncIssueChoice choiceOfType:OCIssueChoiceTypeRegular impact:OCSyncIssueChoiceImpactDataLoss identifier:@"overwriteModifiedFile" label:OCLocalized(@"Overwrite modified file") metaData:nil],

			// Keep local modifications and drop sync record
			[OCSyncIssueChoice cancelChoiceWithImpact:OCSyncIssueChoiceImpactNonDestructive]
		] options:nil],

		// Retry
		[OCMessageTemplate templateWithIdentifier:OCMessageTemplateIdentifierDownloadRetry categoryName:nil choices:@[
			// Reschedule sync record
			[OCSyncIssueChoice retryChoice],

			// Drop sync record
			[OCSyncIssueChoice cancelChoiceWithImpact:OCSyncIssueChoiceImpactNonDestructive],
		] options:nil],

		// Cancel
		[OCMessageTemplate templateWithIdentifier:OCMessageTemplateIdentifierDownloadCancel categoryName:nil choices:@[
			// Drop sync record
			[OCSyncIssueChoice cancelChoiceWithImpact:OCSyncIssueChoiceImpactNonDestructive],
		] options:nil],
	]);
}

#pragma mark - Initializer
- (instancetype)initWithItem:(OCItem *)item options:(NSDictionary<OCCoreOption,id> *)options
{
	if ((self = [super initWithItem:item]) != nil)
	{
		self.options = options;

		self.actionEventType = OCEventTypeDownload;
		self.localizedDescription = [NSString stringWithFormat:OCLocalized(@"Downloading %@…"), item.name];

		self.categories = @[
			OCSyncActionCategoryAll, OCSyncActionCategoryTransfer,

			OCSyncActionCategoryDownload,

			([OCCellularManager.sharedManager cellularAccessAllowedFor:options[OCCoreOptionDependsOnCellularSwitch] transferSize:item.size] ?
				OCSyncActionCategoryDownloadWifiAndCellular :
				OCSyncActionCategoryDownloadWifiOnly)
		];
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

		OCLogDebug(@"Preflight on item=%@\narchivedServerItem=%@\n- item.itemVersionIdentifier=%@\n- item.localCopyVersionIdentifier=%@\n- archivedServerItem.itemVersionIdentifier=%@", item, self.archivedServerItem, item.itemVersionIdentifier, item.localCopyVersionIdentifier, self.archivedServerItem.itemVersionIdentifier);

		// Check if local copy actually exists
		if (item.localRelativePath != nil)
		{
			NSURL *localURL;
			BOOL exists = NO;

			if ((localURL = [self.core localURLForItem:item]) != nil)
			{
				exists = [NSFileManager.defaultManager fileExistsAtPath:localURL.path];
			}

			if (!exists)
			{
				// File has vanished
				[item clearLocalCopyProperties];

				self.localItem = item;

				syncContext.updatedItems = @[ item ];
				syncContext.updateStoredSyncRecordAfterItemUpdates = YES;
			}
		}

		if ((item.localRelativePath != nil) && // Copy of item is stored locally
		    [item.itemVersionIdentifier isEqual:self.archivedServerItem.itemVersionIdentifier] &&  // Local item version is identical to latest known version on the server
		    ( (item.localCopyVersionIdentifier == nil) || // Either the local copy has no item version (typical for uploading files) …
		     ((item.localCopyVersionIdentifier != nil) && [item.localCopyVersionIdentifier isEqual:self.archivedServerItem.itemVersionIdentifier])))  // … or the item version exists and is identical to the latest item version (typical for downloaded files - or after upload completion)
		{
			OCLogDebug(@"Latest item version already downloaded");

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
				[self.core addClaim:addClaim onItem:item refreshItem:NO completionHandler:nil];
			}

			[syncContext completeWithError:nil core:self.core item:item parameter:file];
		}
		else if (returnImmediately && (self.core.connectionStatus != OCCoreConnectionStatusOnline))
		{
			// Item not available and asked to return immediately
			syncContext.removeRecords = @[ syncContext.syncRecord ];

			[syncContext completeWithError:OCError(OCErrorItemNotAvailableOffline) core:self.core item:item parameter:nil];

			OCLogDebug(@"Connection offline and returnImmediately flag set => canceled download");
		}
		else
		{
			// Download item
			[item addSyncRecordID:syncContext.syncRecord.recordID activity:OCItemSyncActivityDownloading];

			syncContext.updatedItems = @[ item ];

			OCLogDebug(@"Preflight completed for downloading %@", item);
		}
	}
}

- (void)descheduleWithContext:(OCSyncContext *)syncContext
{
	OCItem *item;

	if ((item = self.latestVersionOfLocalItem) != nil)
	{
		[item removeSyncRecordID:syncContext.syncRecord.recordID activity:OCItemSyncActivityDownloading];

		if (item.remoteItem != nil)
		{
			[item.remoteItem prepareToReplace:item];

			OCLogDebug(@"record %@ download: descheduling and replacing item %@ with newer remoteItem %@", syncContext.syncRecord, item, item.remoteItem);

			item = item.remoteItem;
		}

		syncContext.updatedItems = @[ item ];
	}
}

- (OCCoreSyncInstruction)scheduleWithContext:(OCSyncContext *)syncContext
{
	OCItem *item;
	BOOL isTriggeredDownload = (self.options[OCCoreOptionDownloadTriggerID] != nil);

	OCLogDebug(@"record %@ enters download scheduling", syncContext.syncRecord);

	if ((item = self.archivedServerItem) != nil)
	{
		// Retrieve latest version from cache
		NSError *error = nil;
		OCItem *latestVersionOfItem;

		OCLogDebug(@"record %@ download: retrieve latest version from cache", syncContext.syncRecord);

		latestVersionOfItem = [self.core retrieveLatestVersionForLocalIDOfItem:item withError:&error];

		OCLogDebug(@"record %@ download: latest version from cache: %@", syncContext.syncRecord, latestVersionOfItem);

		if ((latestVersionOfItem.remoteItem != nil) && ![latestVersionOfItem.remoteItem.path isEqual:latestVersionOfItem.path])
		{
			// File to download has been renamed, so cancel the download
			OCLogDebug(@"record %@ download: newer server item version with different path: %@", syncContext.syncRecord, latestVersionOfItem.remoteItem);
			latestVersionOfItem = nil;
		}

		if (latestVersionOfItem != nil)
		{
			// Check for locally modified version
			if (latestVersionOfItem.locallyModified)
			{
				// Ask user to choose between keeping modifications or overwriting with server version
				OCSyncIssue *issue;

				OCLogDebug(@"record %@ download: latest version was locally modified", syncContext.syncRecord);

				issue = [OCSyncIssue issueFromTemplate:OCMessageTemplateIdentifierDownloadOverwrite forSyncRecord:syncContext.syncRecord level:OCIssueLevelWarning title:[NSString stringWithFormat:OCLocalized(@"\"%@\" has been modified locally"), item.name] description:[NSString stringWithFormat:OCLocalized(@"A modified, unsynchronized version of \"%@\" is present on your device. Downloading the file from the server will overwrite it and modifications be lost."), item.name] metaData:nil];

				issue.muted = isTriggeredDownload;

				OCLogDebug(@"record %@ download: returning from scheduling with an issue (locallyModified)", syncContext.syncRecord);

				[syncContext addSyncIssue:issue];

				// Prevent scheduling of download
				[syncContext transitionToState:OCSyncRecordStateReady withWaitConditions:nil]; // schedule issue
				return (OCCoreSyncInstructionStop);
			}
			else
			{
				// No locally modified version
				OCItem *latestItemVersion = (latestVersionOfItem.remoteItem != nil) ? latestVersionOfItem.remoteItem : latestVersionOfItem;

				OCLogDebug(@"record %@ download: item=%@, latestItemVersion=%@", syncContext.syncRecord, item, latestItemVersion);

				if (![item.itemVersionIdentifier isEqual:latestItemVersion.itemVersionIdentifier])
				{
					// Database has a newer item version -> update archived server item
					OCLogDebug(@"record %@ updating item=%@ with latestItemVersion=%@", syncContext.syncRecord, item, latestItemVersion);

					_archivedServerItem = latestItemVersion;
					_archivedServerItemData = nil; // necessary to ensure _archivedServerItem is encoded and written out
					item = latestItemVersion;

					syncContext.updateStoredSyncRecordAfterItemUpdates = YES; // Update sync record in db, so new archivedServerItem is persisted
				}
				else
				{
					NSURL *localURL = nil;

					if ([item.localCopyVersionIdentifier isEqual:latestItemVersion.itemVersionIdentifier] && // Local copy and latest known version are identical
					    ((localURL = [self.core localCopyOfItem:item]) != nil)) // Local copy actually exists
					{
						if ([NSFileManager.defaultManager fileExistsAtPath:localURL.path]) // Check that file actually exists and hasn't been removed
						{
							// Exact same file already downloaded -> prevent scheduling of download
							[self.core descheduleSyncRecord:syncContext.syncRecord completeWithError:nil parameter:nil];

							return (OCCoreSyncInstructionStop);
						}
					}
				}
			}
		}
		else
		{
			// Item couldn't be found in the cache and likely no longer exists
			OCLogWarning(@"record %@ download: no item at %@ => cancelling/descheduling", syncContext.syncRecord, item);

			[self.core descheduleSyncRecord:syncContext.syncRecord completeWithError:nil parameter:nil];

			return (OCCoreSyncInstructionStop);
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
			[[NSFileManager defaultManager] createDirectoryAtURL:temporaryDirectoryURL withIntermediateDirectories:YES attributes:@{ NSFileProtectionKey : NSFileProtectionCompleteUntilFirstUserAuthentication } error:NULL];
		}

		[self setupProgressSupportForItem:item options:&options syncContext:syncContext];

		if (options != nil)
		{
			NSMutableDictionary *mutableOptions = [options mutableCopy];

			// Determine cellular switch ID dependency
			OCCellularSwitchIdentifier cellularSwitchID;

			if ((cellularSwitchID = options[OCCoreOptionDependsOnCellularSwitch]) == nil)
			{
				cellularSwitchID = OCCellularSwitchIdentifierMain;
			}

			mutableOptions[OCConnectionOptionRequiredCellularSwitchKey] = cellularSwitchID;

			options = mutableOptions;
		}

		OCLogDebug(@"record %@ download: initiating download (requiredCellularSwitch=%@) of %@", syncContext.syncRecord, options[OCConnectionOptionRequiredCellularSwitchKey], item);

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
	BOOL isTriggeredDownload = (self.options[OCCoreOptionDownloadTriggerID] != nil);

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

				issue = [OCSyncIssue issueFromTemplate:OCMessageTemplateIdentifierDownloadRetry forSyncRecord:syncRecord level:OCIssueLevelError title:OCLocalized(@"Invalid checksum") description:OCLocalized(@"The downloaded file's checksum does not match the checksum provided by the server.") metaData:nil];

				issue.muted = isTriggeredDownload;

				[syncContext addSyncIssue:issue];
			}
		}

		// Check for locally modified version
		if (useDownloadedFile)
		{
			if ((latestVersionOfItem = [self.core retrieveLatestVersionAtPathOfItem:item withError:NULL]) != nil)
			{
				// This catches the edge case where a file was locally modified WHILE a download of the same file was already scheduled
				// The case where a download is initiated when a locally modified version exists is caught in download scheduling
				if (latestVersionOfItem.locallyModified)
				{
					OCSyncIssue *issue;

					useDownloadedFile = NO;

					issue = [OCSyncIssue issueFromTemplate:OCMessageTemplateIdentifierDownloadCancel forSyncRecord:syncRecord level:OCIssueLevelError title:OCLocalized(@"File modified locally") description:[NSString stringWithFormat:OCLocalized(@"\"%@\" was modified locally before the download completed."), item.name] metaData:nil];

					issue.muted = isTriggeredDownload;

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
				[[NSFileManager defaultManager] createDirectoryAtURL:vaultItemParentURL withIntermediateDirectories:YES attributes:@{ NSFileProtectionKey : NSFileProtectionCompleteUntilFirstUserAuthentication } error:&error];
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

						OCFileOpLog(@"mv", error, @"Move existing file %@ out of the way to %@", vaultItemURL.path, existingFileTemporaryURL.path);
					}
				}
			}

			if (error == nil)
			{
				// Move download to item path
				BOOL success = [[NSFileManager defaultManager] moveItemAtURL:event.file.url toURL:vaultItemURL error:&error];

				OCFileOpLog(@"mv", error, @"Move downloaded file %@ to item path %@", event.file.url.path, vaultItemURL.path);

				if (success)
				{
					// Switch to "remoteItem" or latestVersionOfItem if eTag of downloaded file doesn't match
					if (![item.eTag isEqual:event.file.eTag])
					{
						if ((![item.remoteItem.eTag isEqual:event.file.eTag]) && (item.remoteItem != nil))
						{
							[item.remoteItem prepareToReplace:item];
							item = item.remoteItem;
						}
						else if (![latestVersionOfItem.eTag isEqual:event.file.eTag] && (latestVersionOfItem != nil))
						{
							[latestVersionOfItem prepareToReplace:item];
							item = latestVersionOfItem;
						}
					}

					item.localRelativePath = vaultItemLocalRelativePath;
					item.localCopyVersionIdentifier = [[OCItemVersionIdentifier alloc] initWithFileID:event.file.fileID eTag:event.file.eTag];

					item.downloadTriggerIdentifier = self.options[OCCoreOptionDownloadTriggerID];
					item.fileClaim = [OCClaim combining:self.localItem.fileClaim with:self.options[OCCoreOptionAddFileClaim] usingOperator:OCClaimGroupOperatorOR];

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
						OCFileOpLog(@"rm", error, @"Deleted temporary file at %@", existingFileTemporaryURL.path)
					}
					else
					{
						// Moving downloaded file failed => put existing file back in place
						[[NSFileManager defaultManager] moveItemAtURL:existingFileTemporaryURL toURL:vaultItemURL error:&error];
						OCFileOpLog(@"mv", error, @"Moved temporary file from %@ to %@", existingFileTemporaryURL.path, vaultItemURL.path);
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
			NSString *errorDescription = nil;

			if ([downloadError isOCErrorWithCode:OCErrorItemNotFound])
			{
				// The item wasn't found on the server (either a 404 or a failed precondition HTTP status with respective Sabre error message)

				// Request refresh of parent path
				if (item.path.parentPath != nil)
				{
					syncContext.refreshPaths = @[ item.path.parentPath ];
				}

				if ([self.options[OCCoreOptionDownloadTriggerID] isEqual:OCItemDownloadTriggerIDAvailableOffline])
				{
					// Available offline download => restore item and end download effort
					[self descheduleWithContext:syncContext];
					syncContext.removedItems = syncContext.updatedItems;
					syncContext.updatedItems = nil;

					// Action complete and can be removed
					[syncContext transitionToState:OCSyncRecordStateCompleted withWaitConditions:nil];
					resultInstruction = OCCoreSyncInstructionDeleteLast;
				}
				else
				{
					// Manual download => inform user
					OCSyncIssue *issue = [OCSyncIssue issueFromTemplate:OCMessageTemplateIdentifierDownloadRetry forSyncRecord:syncContext.syncRecord level:OCIssueLevelError title:[NSString stringWithFormat:OCLocalizedString(@"Couldn't download %@", nil), self.localItem.name] description:OCLocalized(@"The file no longer exists on the server in this location.") metaData:nil];

					issue.muted = isTriggeredDownload;

					[syncContext addSyncIssue:issue];
					[syncContext transitionToState:OCSyncRecordStateProcessing withWaitConditions:nil]; // updates the sync record with the issue wait condition
				}

				handledError = YES;
			}

			if ([downloadError isOCErrorWithCode:OCErrorItemChanged] || // newer SDK error (pre-parsed by OCConnection)
			    ([downloadError.domain isEqual:OCHTTPStatusErrorDomain] && (downloadError.code == OCHTTPStatusCodePRECONDITION_FAILED))) // older SDK error (raw from OCConnection)
			{
				// Precondition failed: ETag of the file to download has changed on the server
				OCLogError(@"Download %@ error %@ => ETag on the server likely changed from the last known ETag", item, downloadError);

				// Request refresh of parent path
				if (item.path.parentPath != nil)
				{
					syncContext.refreshPaths = @[ item.path.parentPath ];
				}

				// For anything else: wait for metadata update to happen
				if ((_resolutionRetries < 3) && (item.path != nil)) // limit retries until bringing up a user-facing error
				{
					_resolutionRetries++;

					syncContext.updateStoredSyncRecordAfterItemUpdates = YES; // Update sync record in db, so resolutionRetries is persisted

					[syncContext transitionToState:OCSyncRecordStateReady withWaitConditions:@[
						[[OCWaitConditionMetaDataRefresh waitForPath:item.path versionOtherThan:item.itemVersionIdentifier until:[NSDate dateWithTimeIntervalSinceNow:120.0]] withLocalizedDescription:OCLocalized(@"Waiting for metadata refresh")]
					]];

					handledError = YES;
				}
				else
				{
					errorDescription = OCLocalizedString(@"The contents of the file on the server has changed since initiating download - or the file is no longer available on the server.", nil);
				}
			}

			if (!handledError && isTriggeredDownload)
			{
				NSUInteger maxResolutionRetries = 3;

				// Retry triggered downloads up to 3 times, when metadata is updated - or after 10 seconds
				if ((_resolutionRetries < maxResolutionRetries) && (item.path != nil)) // limit retries until bringing up a user-facing error
				{
					_resolutionRetries++;

					syncContext.updateStoredSyncRecordAfterItemUpdates = YES; // Update sync record in db, so resolutionRetries is persisted

					[syncContext transitionToState:OCSyncRecordStateReady withWaitConditions:@[
						[[OCWaitConditionMetaDataRefresh waitForPath:item.path versionOtherThan:item.itemVersionIdentifier until:[NSDate dateWithTimeIntervalSinceNow:10.0]] withLocalizedDescription:[NSString stringWithFormat:OCLocalized(@"Waiting to retry (%ld of %ld)"), _resolutionRetries, maxResolutionRetries]]
					]];

					// NSLog(@"Retry:retries=%lu", (unsigned long)_resolutionRetries);

					handledError = YES;
				}
			}

			if (!handledError)
			{
				// Create cancellation issue for any errors
				OCLogError(@"Wrapping download %@ error %@ into cancellation issue", item, downloadError);

				// The item wasn't found on the server (either a 404 or a failed precondition HTTP status with respective Sabre error message)
				OCSyncIssue *issue = [OCSyncIssue issueFromTemplate:OCMessageTemplateIdentifierDownloadRetry forSyncRecord:syncContext.syncRecord level:OCIssueLevelError title:[NSString stringWithFormat:OCLocalizedString(@"Couldn't download %@", nil), self.localItem.name] description:((errorDescription != nil) ? errorDescription : downloadError.localizedDescription) metaData:nil];

				issue.muted = isTriggeredDownload;

				[syncContext addSyncIssue:issue];

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

				if ((latestItem = [self.core retrieveLatestVersionAtPathOfItem:self.archivedServerItem withError:&error]) != nil)
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

								[latestItem clearLocalCopyProperties];

								syncContext.updatedItems = @[ latestItem ];
							}

							OCFileOpLog(@"rm", deleteError, @"Deleted outdated local copy at %@", deleteFileURL.path);

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

#pragma mark - Description
- (NSString *)internalsDescription
{
	if (self.options[OCCoreOptionDownloadTriggerID] != nil)
	{
		return ([@"downloadTriggerID: " stringByAppendingString:self.options[OCCoreOptionDownloadTriggerID]]);
	}

	return (nil);
}

#pragma mark - NSCoding
- (void)decodeActionData:(NSCoder *)decoder
{
	_options = [decoder decodeObjectOfClasses:OCEvent.safeClasses forKey:@"options"];
	_resolutionRetries = (NSUInteger)[decoder decodeIntForKey:@"resolutionRetries"];
}

- (void)encodeActionData:(NSCoder *)coder
{
	[coder encodeObject:_options forKey:@"options"];
	[coder encodeInteger:_resolutionRetries forKey:@"resolutionRetries"];
}

@end

OCSyncActionCategory OCSyncActionCategoryDownload = @"download";
OCSyncActionCategory OCSyncActionCategoryDownloadWifiOnly = @"download-wifi-only";
OCSyncActionCategory OCSyncActionCategoryDownloadWifiAndCellular = @"download-wifi-and-cellular";
