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
					[changedDirectoriesFileIDs addObject:item.parentFileID];
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
				OCLogDebug(@"Signalling changes to file provider manager %@ for item file ID %@", fileProviderManager, OCLogPrivate(changedDirectoryFileID));

				[fileProviderManager signalEnumeratorForContainerItemIdentifier:(NSFileProviderItemIdentifier)changedDirectoryFileID completionHandler:^(NSError * _Nullable error) {
					OCLogDebug(@"Signaled changed to file provider manager %@ for item file ID %@ with error %@", fileProviderManager, OCLogPrivate(changedDirectoryFileID), error);
				}];
			}
		});
	}
}

@end
