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

@implementation OCCore (FileProvider)

#pragma mark - Fileprovider capability
+ (BOOL)hostHasFileProvider
{
	static BOOL didAutoDetectFromInfoPlist = NO;
	static BOOL hostHasFileProvider = NO;

	if (!didAutoDetectFromInfoPlist)
	{
		NSNumber *hasFileProvider;

		if ((hasFileProvider = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"OCHasFileProvider"]) != nil)
		{
			hostHasFileProvider = [hasFileProvider boolValue];
		}

		didAutoDetectFromInfoPlist = YES;
	}

	return (hostHasFileProvider);
}

#pragma mark - Fileprovider tools
- (void)retrieveItemFromDatabaseForLocalID:(OCLocalID)localID completionHandler:(void(^)(NSError * __nullable error, OCSyncAnchor __nullable syncAnchor, OCItem * __nullable itemFromDatabase))completionHandler
{
	[self queueBlock:^{
		OCSyncExec(cacheItemRetrieval, {
			[self.vault.database retrieveCacheItemForLocalID:localID completionHandler:^(OCDatabase *db, NSError *error, OCSyncAnchor syncAnchor, OCItem *item) {
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
		NSMutableSet <OCLocalID> *changedDirectoriesLocalIDs = [NSMutableSet new];
		OCLocalID rootDirectoryLocalID = nil;
		BOOL addRoot = NO;

		// Coalesce IDs
		for (OCItem *item in changedItems)
		{
			switch (item.type)
			{
				case OCItemTypeFile:
					if (item.parentLocalID != nil)
					{
						[changedDirectoriesLocalIDs addObject:item.parentLocalID];
					}
					else if ([item.path.parentPath isEqual:@"/"])
					{
						addRoot = YES;
					}
				break;

				case OCItemTypeCollection:
					if ([item.path isEqual:@"/"])
					{
						rootDirectoryLocalID = item.localID;
						addRoot = YES;
					}
					else
					{
						if (item.parentLocalID != nil)
						{
							[changedDirectoriesLocalIDs addObject:item.parentLocalID];
						}

						if (item.localID != nil)
						{
							[changedDirectoriesLocalIDs addObject:item.localID];
						}
					}

				break;
			}

			if ((rootDirectoryLocalID==nil) && [item.path.parentPath isEqual:@"/"] && (item.parentLocalID!=nil))
			{
				rootDirectoryLocalID = item.parentLocalID;
			}
		}

		// Remove root directory localID
		if (rootDirectoryLocalID != nil)
		{
			if ([changedDirectoriesLocalIDs containsObject:rootDirectoryLocalID])
			{
				[changedDirectoriesLocalIDs removeObject:rootDirectoryLocalID];
				addRoot = YES;
			}
		}

		// Add root directory localID
		if (addRoot)
		{
			[changedDirectoriesLocalIDs addObject:NSFileProviderRootContainerItemIdentifier];
		}

		// Signal NSFileProviderManager
		if (OCCore.hostHasFileProvider)
		{
			dispatch_async(dispatch_get_main_queue(), ^{
				NSFileProviderManager *fileProviderManager = [NSFileProviderManager managerForDomain:self->_vault.fileProviderDomain];

				for (OCLocalID changedDirectoryLocalID in changedDirectoriesLocalIDs)
				{
					OCLogDebug(@"Signaling changes to file provider manager %@ for item localID=%@", fileProviderManager, OCLogPrivate(changedDirectoryLocalID));

					[self signalEnumeratorForContainerItemIdentifier:changedDirectoryLocalID];
				}
			});
		}
	}
}

- (void)signalEnumeratorForContainerItemIdentifier:(NSFileProviderItemIdentifier)changedDirectoryLocalID
{
	@synchronized(_fileProviderSignalCountByContainerItemIdentifiersLock)
	{
		NSNumber *currentSignalCount = _fileProviderSignalCountByContainerItemIdentifiers[changedDirectoryLocalID];

		if (currentSignalCount == nil)
		{
			// The only/first signal for this right now => schedule right away

			_fileProviderSignalCountByContainerItemIdentifiers[changedDirectoryLocalID] = @(1);

			[self _scheduleSignalForContainerItemIdentifier:changedDirectoryLocalID];
		}
		else
		{
			// Another signal hasn't completed yet, so increase the counter and wait for the scheduled signal to complete
			// (at which point, another signal will be triggered)
			OCLogDebug(@"Skipped signaling %@ for changes as another signal hasn't completed yet", changedDirectoryLocalID);

			_fileProviderSignalCountByContainerItemIdentifiers[changedDirectoryLocalID] = @(_fileProviderSignalCountByContainerItemIdentifiers[changedDirectoryLocalID].integerValue + 1);
		}
	}
}

- (void)_scheduleSignalForContainerItemIdentifier:(NSFileProviderItemIdentifier)changedDirectoryLocalID
{
	NSTimeInterval minimumSignalInterval = 0.2; // effectively throttle FP container update notifications to at most once per [minimumSignalInterval]

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(minimumSignalInterval * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		NSFileProviderManager *fileProviderManager;

		if ((fileProviderManager = [self fileProviderManager]) != nil)
		{
			@synchronized(self->_fileProviderSignalCountByContainerItemIdentifiersLock)
			{
				NSInteger signalCountAtStart = self->_fileProviderSignalCountByContainerItemIdentifiers[changedDirectoryLocalID].integerValue;

				OCLogDebug(@"Signaling %@ for changes..", changedDirectoryLocalID);

				[fileProviderManager signalEnumeratorForContainerItemIdentifier:changedDirectoryLocalID completionHandler:^(NSError * _Nullable error) {
					OCLogDebug(@"Signaling %@ for changes ended with error %@", changedDirectoryLocalID, error);

					dispatch_async(dispatch_get_main_queue(), ^{
						@synchronized(self->_fileProviderSignalCountByContainerItemIdentifiersLock)
						{
							NSInteger signalCountAtEnd = self->_fileProviderSignalCountByContainerItemIdentifiers[changedDirectoryLocalID].integerValue;
							NSInteger remainingSignalCount = signalCountAtEnd - signalCountAtStart;

							if (remainingSignalCount > 0)
							{
								// There were signals after initiating the last signal => schedule another signal
								self->_fileProviderSignalCountByContainerItemIdentifiers[changedDirectoryLocalID] = @(remainingSignalCount);

								[self _scheduleSignalForContainerItemIdentifier:changedDirectoryLocalID];
							}
							else
							{
								// The last signal was sent after the last signal was requested => remove from dict
								[self->_fileProviderSignalCountByContainerItemIdentifiers removeObjectForKey:changedDirectoryLocalID];
							}
						}
					});
				}];
			}
		}
		else
		{
			OCLogDebug(@"Signaling %@ for changes failed because the file provider manager couldn't be found.", changedDirectoryLocalID);
		}

	});
}

@end
