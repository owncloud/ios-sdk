//
//  OCCore+FileProvider.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 09.06.18.
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

#import "OCCore+FileProvider.h"
#import "OCCore+Internal.h"
#import "NSString+OCParentPath.h"
#import "OCLogger.h"

@implementation OCCore (FileProvider)

#pragma mark - Fileprovider tools
- (void)retrieveItemFromDatabaseForFileID:(OCFileID)fileID completionHandler:(void(^)(NSError *error, OCSyncAnchor syncAnchor, OCItem *itemFromDatabase))completionHandler
{
	[self queueBlock:^{
		dispatch_group_t waitForRetrievalGroup = dispatch_group_create();

		dispatch_group_enter(waitForRetrievalGroup);

		[self.vault.database retrieveCacheItemForFileID:fileID completionHandler:^(OCDatabase *db, NSError *error, OCSyncAnchor syncAnchor, OCItem *item) {
			dispatch_group_leave(waitForRetrievalGroup);

			completionHandler(error, syncAnchor, item);
		}];

		dispatch_group_wait(waitForRetrievalGroup, DISPATCH_TIME_FOREVER);
	}];
}

- (NSURL *)localURLForItem:(OCItem *)item
{
	return ([self.vault localURLForItem:item]);
}

#pragma mark - File provider manager
- (NSFileProviderManager *)fileProviderManager
{
	// return ([NSFileProviderManager managerForDomain:_vault.fileProviderDomain]);

	if (_fileProviderManager == nil)
	{
		@synchronized(self)
		{
			if (_fileProviderManager == nil)
			{
				_fileProviderManager = [NSFileProviderManager managerForDomain:_vault.fileProviderDomain];
			}
		}
	}

	return (_fileProviderManager);
}

#pragma mark - Singal changes for items
- (void)signalChangesForItems:(NSArray <OCItem *> *)changedItems
{
	if (self.postFileProviderNotifications)
	{
		NSMutableSet <OCFileID> *changedDirectoriesFileIDs = [NSMutableSet new];
		OCFileID rootDirectoryFileID = nil;
		BOOL addRoot = NO;

		// Coalesce IDs
		for (OCItem *item in changedItems)
		{
			switch (item.type)
			{
				case OCItemTypeFile:
					if (item.parentFileID != nil)
					{
						[changedDirectoriesFileIDs addObject:item.parentFileID];
					}
					else if ([item.path.parentPath isEqual:@"/"])
					{
						addRoot = YES;
					}
				break;

				case OCItemTypeCollection:
					if ([item.path isEqual:@"/"])
					{
						rootDirectoryFileID = item.fileID;
						addRoot = YES;
					}
					else
					{
						if (item.parentFileID != nil)
						{
							[changedDirectoriesFileIDs addObject:item.parentFileID];
						}

						if (item.fileID != nil)
						{
							[changedDirectoriesFileIDs addObject:item.fileID];
						}
					}

				break;
			}

			if ((rootDirectoryFileID==nil) && [item.path.parentPath isEqual:@"/"] && (item.parentFileID!=nil))
			{
				rootDirectoryFileID = item.parentFileID;
			}
		}

		// Remove root directory fileID
		if (rootDirectoryFileID != nil)
		{
			if ([changedDirectoriesFileIDs containsObject:rootDirectoryFileID])
			{
				[changedDirectoriesFileIDs removeObject:rootDirectoryFileID];
				addRoot = YES;
			}
		}

		// Add root directory fileID
		if (addRoot)
		{
			[changedDirectoriesFileIDs addObject:NSFileProviderRootContainerItemIdentifier];
		}

		// Signal NSFileProviderManager
		dispatch_async(dispatch_get_main_queue(), ^{
			NSFileProviderManager *fileProviderManager = [NSFileProviderManager managerForDomain:_vault.fileProviderDomain];

			for (OCFileID changedDirectoryFileID in changedDirectoriesFileIDs)
			{
				OCLogDebug(@"Signaling changes to file provider manager %@ for item file ID %@", fileProviderManager, OCLogPrivate(changedDirectoryFileID));

				[self signalEnumeratorForContainerItemIdentifier:changedDirectoryFileID];
			}
		});
	}
}

- (void)signalEnumeratorForContainerItemIdentifier:(NSFileProviderItemIdentifier)changedDirectoryFileID
{
	@synchronized(_fileProviderSignalCountByContainerItemIdentifiersLock)
	{
		NSNumber *currentSignalCount = _fileProviderSignalCountByContainerItemIdentifiers[changedDirectoryFileID];

		if (currentSignalCount == nil)
		{
			// The only/first signal for this right now => schedule right away

			_fileProviderSignalCountByContainerItemIdentifiers[changedDirectoryFileID] = @(1);

			[self _scheduleSignalForContainerItemIdentifier:changedDirectoryFileID];
		}
		else
		{
			// Another signal hasn't completed yet, so increase the counter and wait for the scheduled signal to complete
			// (at which point, another signal will be triggered)
			OCLogDebug(@"Skipped signaling %@ for changes as another signal hasn't completed yet", changedDirectoryFileID);

			_fileProviderSignalCountByContainerItemIdentifiers[changedDirectoryFileID] = @(_fileProviderSignalCountByContainerItemIdentifiers[changedDirectoryFileID].integerValue + 1);
		}
	}
}

- (void)_scheduleSignalForContainerItemIdentifier:(NSFileProviderItemIdentifier)changedDirectoryFileID
{
	dispatch_async(dispatch_get_main_queue(), ^{
		NSFileProviderManager *fileProviderManager;

		if ((fileProviderManager = [self fileProviderManager]) != nil)
		{
			@synchronized(_fileProviderSignalCountByContainerItemIdentifiersLock)
			{
				NSInteger signalCountAtStart = _fileProviderSignalCountByContainerItemIdentifiers[changedDirectoryFileID].integerValue;

				OCLogDebug(@"Signaling %@ for changes..", changedDirectoryFileID);

				[fileProviderManager signalEnumeratorForContainerItemIdentifier:changedDirectoryFileID completionHandler:^(NSError * _Nullable error) {
					OCLogDebug(@"Signaling %@ for changes ended with error %@", changedDirectoryFileID, error);

					dispatch_async(dispatch_get_main_queue(), ^{
						@synchronized(_fileProviderSignalCountByContainerItemIdentifiersLock)
						{
							NSInteger signalCountAtEnd = _fileProviderSignalCountByContainerItemIdentifiers[changedDirectoryFileID].integerValue;
							NSInteger remainingSignalCount = signalCountAtEnd - signalCountAtStart;

							if (remainingSignalCount > 0)
							{
								// There were signals after initiating the last signal => schedule another signal
								_fileProviderSignalCountByContainerItemIdentifiers[changedDirectoryFileID] = @(remainingSignalCount);

								[self _scheduleSignalForContainerItemIdentifier:changedDirectoryFileID];
							}
							else
							{
								// The last signal was sent after the last signal was requested => remove from dict
								[_fileProviderSignalCountByContainerItemIdentifiers removeObjectForKey:changedDirectoryFileID];
							}
						}
					});
				}];
			}
		}
		else
		{
			OCLogDebug(@"Signaling %@ for changes failed because the file provider manager couldn't be found.", changedDirectoryFileID);
		}

	});
}

@end
