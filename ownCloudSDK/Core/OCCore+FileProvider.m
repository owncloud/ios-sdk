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
#import "OCMacros.h"

static BOOL sOCCoreFileProviderHostHasFileProvider = NO;

@implementation OCCore (FileProvider)

#pragma mark - Fileprovider capability
+ (BOOL)hostHasFileProvider
{
	static BOOL didAutoDetectFromInfoPlist = NO;

	if (!didAutoDetectFromInfoPlist)
	{
		NSNumber *hasFileProvider;

		if ((hasFileProvider = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"OCHasFileProvider"]) != nil)
		{
			sOCCoreFileProviderHostHasFileProvider = [hasFileProvider boolValue];
		}

		didAutoDetectFromInfoPlist = YES;
	}

	return (sOCCoreFileProviderHostHasFileProvider);
}

+ (void)setHostHasFileProvider:(BOOL)hostHasFileProvider
{
	sOCCoreFileProviderHostHasFileProvider = hostHasFileProvider;
}

#pragma mark - Fileprovider tools
- (void)retrieveItemFromDatabaseForFileID:(OCFileID)fileID completionHandler:(void(^)(NSError * __nullable error, OCSyncAnchor __nullable syncAnchor, OCItem * __nullable itemFromDatabase))completionHandler
{
	[self queueBlock:^{
		OCSyncExec(cacheItemRetrieval, {
			[self.vault.database retrieveCacheItemForFileID:fileID completionHandler:^(OCDatabase *db, NSError *error, OCSyncAnchor syncAnchor, OCItem *item) {
				completionHandler(error, syncAnchor, item);

				OCSyncExecDone(cacheItemRetrieval);
			}];
		});
	}];
}

#pragma mark - File provider manager
- (NSFileProviderManager *)fileProviderManager
{
	// return ([NSFileProviderManager managerForDomain:_vault.fileProviderDomain]);

	if (_fileProviderManager == nil)
	{
		if (OCCore.hostHasFileProvider)
		{
			@synchronized(self)
			{
				if (_fileProviderManager == nil)
				{
					_fileProviderManager = [NSFileProviderManager managerForDomain:_vault.fileProviderDomain];
				}
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
		if (OCCore.hostHasFileProvider)
		{
			dispatch_async(dispatch_get_main_queue(), ^{
				NSFileProviderManager *fileProviderManager = [NSFileProviderManager managerForDomain:self->_vault.fileProviderDomain];

				for (OCFileID changedDirectoryFileID in changedDirectoriesFileIDs)
				{
					OCLogDebug(@"[FP] Signaling changes to file provider manager %@ for item file ID %@", fileProviderManager, OCLogPrivate(changedDirectoryFileID));

					[self signalEnumeratorForContainerItemIdentifier:changedDirectoryFileID];
				}
			});
		}
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
			OCLogDebug(@"[FP] Skipped signaling %@ for changes as another signal hasn't completed yet", changedDirectoryFileID);

			_fileProviderSignalCountByContainerItemIdentifiers[changedDirectoryFileID] = @(_fileProviderSignalCountByContainerItemIdentifiers[changedDirectoryFileID].integerValue + 1);
		}
	}
}

- (void)_scheduleSignalForContainerItemIdentifier:(NSFileProviderItemIdentifier)changedDirectoryFileID
{
	NSTimeInterval minimumSignalInterval = 0.2; // effectively throttle FP container update notifications to at most once per [minimumSignalInterval]

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(minimumSignalInterval * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		NSFileProviderManager *fileProviderManager;

		if ((fileProviderManager = [self fileProviderManager]) != nil)
		{
			@synchronized(self->_fileProviderSignalCountByContainerItemIdentifiersLock)
			{
				NSInteger signalCountAtStart = self->_fileProviderSignalCountByContainerItemIdentifiers[changedDirectoryFileID].integerValue;

				OCLogDebug(@"[FP] Signaling %@ for changes..", changedDirectoryFileID);

				[fileProviderManager signalEnumeratorForContainerItemIdentifier:changedDirectoryFileID completionHandler:^(NSError * _Nullable error) {
					OCLogDebug(@"[FP] Signaling %@ for changes ended with error %@", changedDirectoryFileID, error);

					dispatch_async(dispatch_get_main_queue(), ^{
						@synchronized(self->_fileProviderSignalCountByContainerItemIdentifiersLock)
						{
							NSInteger signalCountAtEnd = self->_fileProviderSignalCountByContainerItemIdentifiers[changedDirectoryFileID].integerValue;
							NSInteger remainingSignalCount = signalCountAtEnd - signalCountAtStart;

							if (remainingSignalCount > 0)
							{
								// There were signals after initiating the last signal => schedule another signal
								self->_fileProviderSignalCountByContainerItemIdentifiers[changedDirectoryFileID] = @(remainingSignalCount);

								[self _scheduleSignalForContainerItemIdentifier:changedDirectoryFileID];
							}
							else
							{
								// The last signal was sent after the last signal was requested => remove from dict
								[self->_fileProviderSignalCountByContainerItemIdentifiers removeObjectForKey:changedDirectoryFileID];
							}
						}
					});
				}];
			}
		}
		else
		{
			OCLogDebug(@"[FP] Signaling %@ for changes failed because the file provider manager couldn't be found.", changedDirectoryFileID);
		}

	});
}

@end
