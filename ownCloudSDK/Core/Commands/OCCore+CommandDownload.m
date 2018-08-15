//
//  OCCore+CommandDownload.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 02.08.18.
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
#import "OCCore+SyncEngine.h"
#import "OCCoreSyncContext.h"
#import "NSError+OCError.h"
#import "OCMacros.h"
#import "NSString+OCParentPath.h"
#import "OCLogger.h"
#import "OCCore+FileProvider.h"
#import "OCFile.h"

@implementation OCCore (CommandDownload)

#pragma mark - Command
- (NSProgress *)downloadItem:(OCItem *)item options:(NSDictionary *)options resultHandler:(OCCoreDownloadResultHandler)resultHandler
{
	return ([self _enqueueSyncRecordWithAction:OCSyncActionDownload forItem:item allowNilItem:NO parameters:@{
			OCSyncActionParameterItem : item,
			OCSyncActionParameterPath : item.path,
			OCSyncActionParameterOptions : ((options != nil) ? options : @{})
		} resultHandler:resultHandler]);
}

#pragma mark - Sync Action Registration
- (void)registerDownload
{
	[self registerSyncRoute:[OCCoreSyncRoute routeWithPreflight:^BOOL(OCCore *core, OCCoreSyncContext *syncContext) {
		return ([core preflightDownloadWithSyncContext:syncContext]);
	} scheduler:^BOOL(OCCore *core, OCCoreSyncContext *syncContext) {
		return ([core scheduleDownloadWithSyncContext:syncContext]);
	} descheduler:^BOOL(OCCore *core, OCCoreSyncContext *syncContext) {
		return ([core descheduleDownloadWithSyncContext:syncContext]);
	} resultHandler:^BOOL(OCCore *core, OCCoreSyncContext *syncContext) {
		return ([core handleDownloadWithSyncContext:syncContext]);
	}] forAction:OCSyncActionDownload];
}

#pragma mark - Sync
- (BOOL)preflightDownloadWithSyncContext:(OCCoreSyncContext *)syncContext
{
	OCItem *item;

	if ((item = syncContext.syncRecord.item) != nil)
	{
		[item addSyncRecordID:syncContext.syncRecord.recordID activity:OCItemSyncActivityDownloading];

		syncContext.updatedItems = @[ item ];
	}

	return (YES);
}

- (BOOL)descheduleDownloadWithSyncContext:(OCCoreSyncContext *)syncContext
{
	OCItem *item;

	if ((item = syncContext.syncRecord.item) != nil)
	{
		[item removeSyncRecordID:syncContext.syncRecord.recordID activity:OCItemSyncActivityDownloading];

		syncContext.updatedItems = @[ item ];
	}

	return (YES);
}

- (BOOL)scheduleDownloadWithSyncContext:(OCCoreSyncContext *)syncContext
{
	OCItem *item;

	if ((item = syncContext.syncRecord.archivedServerItem) != nil)
	{
		NSProgress *progress;
		NSDictionary *options = syncContext.syncRecord.parameters[OCSyncActionParameterOptions];

		NSURL *temporaryDirectoryURL = [[NSURL fileURLWithPath:NSTemporaryDirectory()]  URLByAppendingPathComponent:[NSUUID UUID].UUIDString];
		NSURL *temporaryFileURL = [temporaryDirectoryURL URLByAppendingPathComponent:item.name];

		[[NSFileManager defaultManager] createDirectoryAtURL:temporaryDirectoryURL withIntermediateDirectories:YES attributes:nil error:NULL];

		if (self.postFileProviderNotifications && (item.fileID != nil) && (_vault.fileProviderDomain!=nil))
		{
			NSFileProviderDomain *fileProviderDomain = _vault.fileProviderDomain;

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

		if ((progress = [self.connection downloadItem:item to:temporaryFileURL options:options resultTarget:[self _eventTargetWithSyncRecord:syncContext.syncRecord]]) != nil)
		{
			[syncContext.syncRecord addProgress:progress];

			return (YES);
		}
	}

	return (NO);
}

- (BOOL)handleDownloadWithSyncContext:(OCCoreSyncContext *)syncContext
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
		NSURL *vaultItemURL = [self.vault localURLForItem:item];

		[[NSFileManager defaultManager] createDirectoryAtURL:vaultItemURL.URLByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:NULL];

		if ([[NSFileManager defaultManager] fileExistsAtPath:vaultItemURL.path])
		{
			[[NSFileManager defaultManager] removeItemAtURL:vaultItemURL error:&error];
		}
		if ([[NSFileManager defaultManager] moveItemAtURL:event.file.url toURL:vaultItemURL error:&error])
		{
			item.localRelativePath = [self.vault relativePathForItem:item];
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
		[self _addIssueForCancellationAndDeschedulingToContext:syncContext title:[NSString stringWithFormat:OCLocalizedString(@"Couldn't download %@", nil), syncContext.syncRecord.item.name] description:[event.error localizedDescription]];
	}

	if (syncRecord.resultHandler != nil)
	{
		syncRecord.resultHandler(downloadError, self, item, downloadedFile);
	}

	return (canDeleteSyncRecord);
}

@end
