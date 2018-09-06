//
//  OCCoreSyncActionDownload.m
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

#import "OCCoreSyncActionDownload.h"

@implementation OCCoreSyncActionDownload

- (void)preflightWithContext:(OCCoreSyncContext *)syncContext
{
	OCItem *item;

	if ((item = syncContext.syncRecord.item) != nil)
	{
		[item addSyncRecordID:syncContext.syncRecord.recordID activity:OCItemSyncActivityDownloading];

		syncContext.updatedItems = @[ item ];
	}
}

- (void)descheduleWithContext:(OCCoreSyncContext *)syncContext
{
	OCItem *item;

	if ((item = syncContext.syncRecord.item) != nil)
	{
		[item removeSyncRecordID:syncContext.syncRecord.recordID activity:OCItemSyncActivityDownloading];

		syncContext.updatedItems = @[ item ];
	}
}

- (BOOL)scheduleWithContext:(OCCoreSyncContext *)syncContext
{
	OCItem *item;

	if ((item = syncContext.syncRecord.archivedServerItem) != nil)
	{
		NSProgress *progress;
		NSDictionary *options = syncContext.syncRecord.parameters[OCSyncActionParameterOptions];

		NSURL *temporaryDirectoryURL = [[NSURL fileURLWithPath:NSTemporaryDirectory()]  URLByAppendingPathComponent:[NSUUID UUID].UUIDString];
		NSURL *temporaryFileURL = [temporaryDirectoryURL URLByAppendingPathComponent:item.name];

		[[NSFileManager defaultManager] createDirectoryAtURL:temporaryDirectoryURL withIntermediateDirectories:YES attributes:nil error:NULL];

		if (self.core.postFileProviderNotifications && (item.fileID != nil) && (self.core.vault.fileProviderDomain!=nil))
		{
			NSFileProviderDomain *fileProviderDomain = self.core.vault.fileProviderDomain;

			OCConnectionRequestObserver observer = [^(OCConnectionRequest *request, OCConnectionRequestObserverEvent event) {
				if (event == OCConnectionRequestObserverEventTaskResume)
				{
					[[NSFileProviderManager managerForDomain:fileProviderDomain] registerURLSessionTask:request.urlSessionTask forItemWithIdentifier:item.fileID completionHandler:^(NSError * _Nullable error) {
						if (error != nil)
						{
							OCLogError(@"Error registering %@ for %@: %@", request.urlSessionTask, item.fileID, error);
						}

						// File provider detail: the task may not be started until after this completionHandler was called
						[request.urlSessionTask resume];
					}];

					return (YES);
				}

				return (NO);
			} copy];

			if (options == nil)
			{
				options = @{ OCConnectionOptionRequestObserverKey : observer };
			}
			else
			{
				NSMutableDictionary *mutableOptions = [options mutableCopy];

				mutableOptions[OCConnectionOptionRequestObserverKey] = observer;

				options = mutableOptions;
			}
		}

		if ((progress = [self.core.connection downloadItem:item to:temporaryFileURL options:options resultTarget:[self.core _eventTargetWithSyncRecord:syncContext.syncRecord]]) != nil)
		{
			[syncContext.syncRecord addProgress:progress];

			return (YES);
		}
	}

	return (NO);
}

- (BOOL)handleResultWithContext:(OCCoreSyncContext *)syncContext
{
	OCEvent *event = syncContext.event;
	OCFile *downloadedFile = event.file;
	OCSyncRecord *syncRecord = syncContext.syncRecord;
	BOOL canDeleteSyncRecord = NO;
	OCItem *item = syncRecord.parameters[OCSyncActionParameterItem];
	NSError *downloadError = event.error;

	// TODO: Check for newer local version (=> throw away downloaded file or ask user)
	// TODO: Validate checksum of downloaded file
	// TODO: In case of errors, offer a retry option
	// TODO: If everything's GO => update item metadata with info on local copy of file, add 1 minute retainer, so other parts of the app have a chance to add their retainers as well to keep the file around

	if ((event.error == nil) && (event.file != nil) && (item != nil))
	{
		NSError *error = nil;
		NSURL *vaultItemURL = [self.core.vault localURLForItem:item];

		[[NSFileManager defaultManager] createDirectoryAtURL:vaultItemURL.URLByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:NULL];

		if ([[NSFileManager defaultManager] fileExistsAtPath:vaultItemURL.path])
		{
			[[NSFileManager defaultManager] removeItemAtURL:vaultItemURL error:&error];
		}
		if ([[NSFileManager defaultManager] moveItemAtURL:event.file.url toURL:vaultItemURL error:&error])
		{
			item.localRelativePath = [self.core.vault relativePathForItem:item];
			downloadedFile.url = vaultItemURL;
		}

		if (error != nil)
		{
			downloadError = error;
		}
		else
		{
			[item removeSyncRecordID:syncContext.syncRecord.recordID activity:OCItemSyncActivityDownloading];
			syncContext.updatedItems = @[ item ];
		}

		canDeleteSyncRecord = YES;
	}

	if (downloadError != nil)
	{
		// Create cancellation issue for any errors (TODO: extend options to include "Retry")
		[self.core _addIssueForCancellationAndDeschedulingToContext:syncContext title:[NSString stringWithFormat:OCLocalizedString(@"Couldn't download %@", nil), syncContext.syncRecord.item.name] description:[event.error localizedDescription]];
	}

	if (syncRecord.resultHandler != nil)
	{
		syncRecord.resultHandler(downloadError, self.core, item, downloadedFile);
	}

	return (canDeleteSyncRecord);
}

@end
