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
#import "OCCore+FileProvider.h"
#import "OCCore+ItemUpdates.h"

@implementation OCSyncActionDownload

#pragma mark - Initializer
- (instancetype)initWithItem:(OCItem *)item options:(NSDictionary *)options
{
	if ((self = [super initWithItem:item]) != nil)
	{
		self.identifier = OCSyncActionIdentifierDownload;

		self.options = options;
	}

	return (self);
}

#pragma mark - Action implementation
- (void)preflightWithContext:(OCSyncContext *)syncContext
{
	OCItem *item;

	if ((item = self.localItem) != nil)
	{
		if ((item.localRelativePath != nil) && // Copy of item is stored locally
		    [item.itemVersionIdentifier isEqual:self.archivedServerItem.itemVersionIdentifier]) // Local item version is identical to latest known version on the server
		{
			// Item already downloaded - take some shortcuts
			syncContext.removeRecords = @[ syncContext.syncRecord ];

			syncContext.syncRecord.resultHandler(nil, self.core, item, [item fileWithCore:self.core]);
		}
		else
		{
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
		[item removeSyncRecordID:syncContext.syncRecord.recordID activity:OCItemSyncActivityDownloading];

		syncContext.updatedItems = @[ item ];
	}
}

- (BOOL)scheduleWithContext:(OCSyncContext *)syncContext
{
	OCItem *item;

	OCLogDebug(@"SE: record %@ enters download scheduling", syncContext.syncRecord);

	if ((item = self.archivedServerItem) != nil)
	{
		// Retrieve latest version from cache
		NSError *error = nil;
		OCItem *latestVersionOfItem;

		OCLogDebug(@"SE: record %@ download: retrieve latest version from cache", syncContext.syncRecord);

		if ((latestVersionOfItem = [self.core retrieveLatestVersionOfItem:item withError:&error]) != nil)
		{
			// Check for locally modified version
			if (latestVersionOfItem.locallyModified)
			{
				// Ask user to choose between keeping modifications or overwriting with server version
				OCConnectionIssue *issue;

				OCLogDebug(@"SE: record %@ download: latest version was locally modified", syncContext.syncRecord);

				issue =	[OCConnectionIssue issueForMultipleChoicesWithLocalizedTitle:OCLocalized(@"\"%@\" has been modified locally") localizedDescription:OCLocalized(@"A modified, unsynchronized version of \"%@\" is present on your device. Downloading the file from the server will overwrite it and modifications be lost.") choices:@[
						[OCConnectionIssueChoice choiceWithType:OCConnectionIssueChoiceTypeRegular label:OCLocalized(@"Overwrite modified file") handler:^(OCConnectionIssue *issue, OCConnectionIssueChoice *choice) {
							// Delete local representation and reschedule download
							[self.core rescheduleSyncRecord:syncContext.syncRecord withUpdates:^NSError *(OCSyncRecord *record) {
								OCItem *latestItem;
								NSError *error = nil;

								if ((latestItem = [self.core retrieveLatestVersionOfItem:item withError:&error]) != nil)
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

												[self.core performUpdatesForAddedItems:nil removedItems:nil updatedItems:@[ latestItem ] refreshPaths:nil newSyncAnchor:nil preflightAction:nil postflightAction:nil queryPostProcessor:nil];
											}

											OCLogDebug(@"SE: deleted %@ with error=%@ and rescheduling download", deleteFileURL, deleteError);
										}
									}
								}

								return (nil);
							}];
						}],

						[OCConnectionIssueChoice choiceWithType:OCConnectionIssueChoiceTypeCancel label:nil handler:^(OCConnectionIssue *issue, OCConnectionIssueChoice *choice) {
							// Keep local modifications and drop sync record
							[self.core descheduleSyncRecord:syncContext.syncRecord invokeResultHandler:YES withParameter:nil resultHandlerError:OCError(OCErrorCancelled)];
						}],
					] completionHandler:nil];

				[syncContext addIssue:issue];

				OCLogDebug(@"SE: record %@ download: returning from scheduling with an issue (locallyModified)", syncContext.syncRecord);

				// Prevent scheduling of download
				return (NO);
			}
		}
	}

	if (item != nil)
	{
		NSProgress *progress;
		NSDictionary *options = self.options;

		NSURL *temporaryDirectoryURL = [[NSURL fileURLWithPath:NSTemporaryDirectory()]  URLByAppendingPathComponent:[NSUUID UUID].UUIDString];
		NSURL *temporaryFileURL = [temporaryDirectoryURL URLByAppendingPathComponent:item.name];

		OCLogDebug(@"SE: record %@ download: setting up directory", syncContext.syncRecord);

		[[NSFileManager defaultManager] createDirectoryAtURL:temporaryDirectoryURL withIntermediateDirectories:YES attributes:nil error:NULL];

		if (self.core.postFileProviderNotifications && (item.fileID != nil) && (self.core.vault.fileProviderDomain!=nil))
		{
			/*
				Check if a placeholder/file already exists here before registering this URL session for the item. Otherwise, the SDK may find itself on
				the receiving end of this error:

				[default] [ERROR] Failed registering URL session task <__NSCFBackgroundDownloadTask: 0x7f81efa08010>{ taskIdentifier: 1041 } with item 00000042oc9qntjidejl; Error Domain=com.apple.FileProvider Code=-1005 "The file doesn’t exist." UserInfo={NSFileProviderErrorNonExistentItemIdentifier=00000042oc9qntjidejl}

				Error registering <__NSCFBackgroundDownloadTask: 0x7f81efa08010>{ taskIdentifier: 1041 } for 00000042oc9qntjidejl: Error Domain=com.apple.FileProvider Code=-1005 "The file doesn’t exist." UserInfo={NSFileProviderErrorNonExistentItemIdentifier=00000042oc9qntjidejl} [OCCoreSyncActionDownload.m:71|FULL]
			*/
//			NSURL *localURL = [self.core localURLForItem:item];
//
//			if ([[NSFileManager defaultManager] fileExistsAtPath:localURL.path])
//			{
//				NSFileProviderDomain *fileProviderDomain = self.core.vault.fileProviderDomain;
//
//				OCLogDebug(@"SE: record %@ will register URLTask for %@", syncContext.syncRecord, item);
//
//				OCConnectionRequestObserver observer = [^(OCConnectionRequest *request, OCConnectionRequestObserverEvent event) {
//					if (event == OCConnectionRequestObserverEventTaskResume)
//					{
//						[[NSFileProviderManager managerForDomain:fileProviderDomain] registerURLSessionTask:request.urlSessionTask forItemWithIdentifier:item.fileID completionHandler:^(NSError * _Nullable error) {
//							OCLogDebug(@"SE: record %@ returned from registering URLTask %@ for %@ with error=%@", syncContext.syncRecord, request.urlSessionTask, item, error);
//
//							if (error != nil)
//							{
//								OCLogError(@"SE: error registering %@ for %@: %@", request.urlSessionTask, item.fileID, error);
//							}
//
//							// File provider detail: the task may not be started until after this completionHandler was called
//							[request.urlSessionTask resume];
//						}];
//
//						return (YES);
//					}
//
//					return (NO);
//				} copy];
//
//				if (options == nil)
//				{
//					options = @{ OCConnectionOptionRequestObserverKey : observer };
//				}
//				else
//				{
//					NSMutableDictionary *mutableOptions = [options mutableCopy];
//
//					mutableOptions[OCConnectionOptionRequestObserverKey] = observer;
//
//					options = mutableOptions;
//				}
//			}
		}

		OCLogDebug(@"SE: record %@ download: initiating download", syncContext.syncRecord);

		if ((progress = [self.core.connection downloadItem:item to:temporaryFileURL options:options resultTarget:[self.core _eventTargetWithSyncRecord:syncContext.syncRecord]]) != nil)
		{
			OCLogDebug(@"SE: record %@ download: download initiated with progress %@", syncContext.syncRecord, progress);

			[syncContext.syncRecord addProgress:progress];

			return (YES);
		}
	}

	return (NO);
}

- (BOOL)handleResultWithContext:(OCSyncContext *)syncContext
{
	OCEvent *event = syncContext.event;
	OCFile *downloadedFile = event.file;
	OCSyncRecord *syncRecord = syncContext.syncRecord;
	BOOL canDeleteSyncRecord = NO;
	OCItem *item = self.archivedServerItem;
	NSError *downloadError = event.error;

	if ((event.error == nil) && (event.file != nil) && (item != nil))
	{
		NSError *error = nil;
		NSURL *vaultItemURL = [self.core.vault localURLForItem:item];
		NSString *vaultItemLocalRelativePath = [self.core.vault relativePathForItem:item];
		BOOL useDownloadedFile = YES;
		OCItem *latestVersionOfItem = nil;

		// Validate checksum of downloaded file
		if (useDownloadedFile)
		{
			__block BOOL checksumIsValid = NO;

			// Verify checksum and wait for result of computation
			OCSyncExec(checksumVerification, {
				[event.file.checksum verifyForFile:event.file.url completionHandler:^(NSError *error, BOOL isValid, OCChecksum *actualChecksum) {
					checksumIsValid = isValid;
					OCSyncExecDone(checksumVerification);
				}];
			});

			if (!checksumIsValid)
			{
				// Checksum of downloaded file is not valid => bring up issue
				OCConnectionIssue *issue;

				useDownloadedFile = NO;

				issue =	[OCConnectionIssue issueForMultipleChoicesWithLocalizedTitle:OCLocalized(@"Invalid checksum") localizedDescription:OCLocalized(@"The downloaded file's checksum does not match the checksum provided by the server.") choices:@[

						[OCConnectionIssueChoice choiceWithType:OCConnectionIssueChoiceTypeRegular label:OCLocalized(@"Retry") handler:^(OCConnectionIssue *issue, OCConnectionIssueChoice *choice) {
							// Reschedule sync record
							[self.core rescheduleSyncRecord:syncRecord withUpdates:nil];
						}],

						[OCConnectionIssueChoice choiceWithType:OCConnectionIssueChoiceTypeCancel label:nil handler:^(OCConnectionIssue *issue, OCConnectionIssueChoice *choice) {
							// Drop sync record
							[self.core descheduleSyncRecord:syncRecord invokeResultHandler:YES withParameter:nil resultHandlerError:OCError(OCErrorCancelled)];
						}],

					] completionHandler:nil];

				[syncContext addIssue:issue];
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
					OCConnectionIssue *issue;

					useDownloadedFile = NO;

					issue =	[OCConnectionIssue issueForMultipleChoicesWithLocalizedTitle:OCLocalized(@"File modified locally") localizedDescription:[NSString stringWithFormat:OCLocalized(@"\"%@\" was modified locally before the download completed."), item.name] choices:@[

							[OCConnectionIssueChoice choiceWithType:OCConnectionIssueChoiceTypeCancel label:nil handler:^(OCConnectionIssue *issue, OCConnectionIssueChoice *choice) {
								// Drop sync record
								[self.core descheduleSyncRecord:syncRecord invokeResultHandler:YES withParameter:nil resultHandlerError:OCError(OCErrorCancelled)];
							}],

						] completionHandler:nil];

					[syncContext addIssue:issue];
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
					downloadedFile.url = vaultItemURL;

					syncContext.updatedItems = @[ item ];
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
		canDeleteSyncRecord = YES;

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
			[item removeSyncRecordID:syncContext.syncRecord.recordID activity:OCItemSyncActivityDownloading];
			canDeleteSyncRecord = YES;
		}
		else
		{
			// Create cancellation issue for any errors (TODO: extend options to include "Retry")
			[self.core _addIssueForCancellationAndDeschedulingToContext:syncContext title:[NSString stringWithFormat:OCLocalizedString(@"Couldn't download %@", nil), self.localItem.name] description:[downloadError localizedDescription] invokeResultHandler:NO resultHandlerError:nil];
		}
	}

	if (syncRecord.resultHandler != nil)
	{
		syncRecord.resultHandler(downloadError, self.core, item, downloadedFile);
	}

	return (canDeleteSyncRecord);
}

#pragma mark - NSCoding
- (void)decodeActionData:(NSCoder *)decoder
{
	_options = [decoder decodeObjectOfClass:[NSDictionary class] forKey:@"options"];
}

- (void)encodeActionData:(NSCoder *)coder
{
	[coder encodeObject:_options forKey:@"options"];
}

@end
