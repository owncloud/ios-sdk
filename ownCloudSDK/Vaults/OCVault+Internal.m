//
//  OCVault+Internal.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 07.05.19.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2019, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCVault+Internal.h"
#import "OCBookmark+IPNotificationNames.h"
#import "OCDatabase.h"
#import "OCCore.h"
#import "OCLogger.h"
#import "NSString+OCPath.h"
#import "OCFeatureAvailability.h"

@implementation OCVault (Internal)

#pragma mark - Compacting
- (void)compactInContext:(nullable void(^)(void(^blockToRunInContext)(OCSyncAnchor syncAnchor, void(^updateHandler)(NSSet<OCLocalID> *updateDirectoryLocalIDs))))runInContext withSelector:(OCVaultCompactSelector)selector completionHandler:(nullable OCCompletionHandler)completionHandler
{
	NSURL *compactTargetURL = nil;

	// Create temporary compacting directory
	if ((compactTargetURL = [self.filesRootURL URLByAppendingPathComponent:[NSString stringWithFormat:@"_compact.%f", NSDate.timeIntervalSinceReferenceDate] isDirectory:YES]) != nil)
	{
		NSError *createError = nil;

		// Create temporary compacting directory (where items get moved to - and then deleted on successful commit - or moved back in case of error)
		if (![[NSFileManager defaultManager] createDirectoryAtURL:compactTargetURL withIntermediateDirectories:YES attributes:@{ NSFileProtectionKey : NSFileProtectionCompleteUntilFirstUserAuthentication } error:&createError])
		{
			OCTLogError(@[@"Compact"], @"Error creating compactTargetURL %@: %@", compactTargetURL, createError);

			completionHandler(self, createError);
			return;
		}
	}

	// Create default runInContext block if needed
	if (runInContext == nil)
	{
		OCTLogDebug(@[@"Compact"], @"Using default runInContext block");

		runInContext = ^(void(^blockToRunInContext)(OCSyncAnchor syncAnchor, void(^updateHandler)(NSSet<OCLocalID> *updateDirectoryLocalIDs))) {
			[self.database increaseValueForCounter:OCCoreSyncAnchorCounter withProtectedBlock:^NSError *(NSNumber *previousCounterValue, NSNumber *newCounterValue) {
				// Run updates
				blockToRunInContext(newCounterValue, ^(NSSet<OCLocalID> *updateDirectoryLocalIDs){
					// Post update notification
					[OCIPNotificationCenter.sharedNotificationCenter postNotificationForName:self.bookmark.coreUpdateNotificationName ignoreSelf:NO];

					// Post File Provider change notification
					[self signalChangesInDirectoriesWithVFSItemIDs:updateDirectoryLocalIDs];
				 });

				return (nil);
			} completionHandler:nil];
		};
	}

	// Open database
	OCTLogDebug(@[@"Compact"], @"Opening database");
	[self.database openWithCompletionHandler:^(OCDatabase *db, NSError *error) {
		if (error != nil)
		{
			OCTLogError(@[@"Compact"], @"Error opening database: %@", error);

			completionHandler(self, error);
			return;
		}

		// Run in context
		OCTLogDebug(@[@"Compact"], @"Initiating compacting");

		runInContext(^(OCSyncAnchor newAnchor, void(^updateHandler)(NSSet<OCLocalID> *updateDirectoryLocalIDs)){
			NSFileManager *fileManager = [NSFileManager new];
			fileManager.delegate = self;

			__block NSMutableSet<OCLocalID> *updateDirectoryLocalIDs = [NSMutableSet new];

			OCTLogDebug(@[@"Compact"], @"Starting compacting");

			__block OCCompletionHandler iterationCompletionHandler = ^(id sender, NSError *error) {
				OCTLogDebug(@[@"Compact"], @"Compacting completed with error=%@", error);

				if (error != nil)
				{
					// Move back item dirs from compacting directory
					NSDirectoryEnumerator <NSURL *> *moveBackEnumerator;

					OCTLogError(@[@"Compact"], @"Error %@ saving changes - moving back all item folders", error);

					if ((moveBackEnumerator = [fileManager enumeratorAtURL:compactTargetURL includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsSubdirectoryDescendants errorHandler:^BOOL(NSURL * _Nonnull url, NSError * _Nonnull error) { return (YES); }]) != nil)
					{
						for (NSURL *moveBackURL in moveBackEnumerator)
						{
							NSError *moveError = nil;

							if (![fileManager moveItemAtURL:moveBackURL toURL:self.filesRootURL error:&moveError])
							{
								OCTLogError(@[@"Compact"], @"Error moving back %@ to %@: %@", moveBackURL, self.filesRootURL, moveError);
							}

							OCFileOpLog(@"mv", moveError, @"Moved back %@ to %@", moveBackURL.path, self.filesRootURL.path);
						}
					}
				}
				else
				{
					// Delete compacting dir
					NSError *removeError = nil;

					OCTLogDebug(@[@"Compact"], @"Successfully compacted vault - deleting temporary compacting URL %@", compactTargetURL);

					if (![fileManager removeItemAtURL:compactTargetURL error:&removeError])
					{
						OCTLogError(@[@"Compact"], @"Error deleting temporary compacting URL %@: %@", compactTargetURL, removeError);
					}

					OCFileOpLog(@"rm", removeError, @"Deleted temporary compacting folder %@", compactTargetURL.path);
				}

				OCTLogDebug(@[@"Compact"], @"Closing database");

				[self.database closeWithCompletionHandler:^(OCDatabase *db, NSError *closeError) {
					OCTLogDebug(@[@"Compact"], @"Closed database with error=%@", error);

					completionHandler(sender, (error != nil) ? error : closeError);
				}];

				// Notify of changes
				updateHandler(updateDirectoryLocalIDs);
			};

			OCCompletionHandler endIterationHandler = ^(id sender, NSError *error) {
				if (iterationCompletionHandler != nil)
				{
					iterationCompletionHandler(sender, error);
					iterationCompletionHandler = nil;
				}
			};

			[self.database iterateCacheItemsWithIterator:^(NSError *error, OCSyncAnchor syncAnchor, OCItem *item, BOOL *stop) {
				// Call completion handler when done
				if ((item == nil) && (stop == NULL))
				{
					// Done
					OCTLogDebug(@[@"Compact"], @"Iteration complete");

					endIterationHandler(self, error);
					return;
				}

				// Stop on errors
				if (error != nil)
				{
					OCTLogError(@[@"Compact"], @"Iteration error=%@", error);

					endIterationHandler(self, error);
					if (stop != NULL)
					{
						*stop = YES;
					}

					return;
				}

				// Check item
				if ((item != nil) && selector(syncAnchor, item))
				{
					OCTLogDebug(@[@"Compact"], @"Item %@ selected for deletion", item);

					// Item's local copy should be removed
					if (item.localRelativePath != nil)
					{
						// Remove item folder
						NSURL *removeFolderURL = nil;

						if ((removeFolderURL = [self localFolderURLForItem:item]) != nil)
						{
							NSURL *copyURL = [compactTargetURL URLByAppendingPathComponent:removeFolderURL.lastPathComponent];

							OCFileOpLog(@"cp", nil, @"Cloning item folder %@ as %@", removeFolderURL.path, copyURL.path);

							if ([fileManager copyItemAtURL:removeFolderURL toURL:copyURL error:&error])
							{
								OCFileOpLog(@"rm", nil, @"Removing item folder %@", removeFolderURL.path);

								if ([fileManager removeItemAtURL:removeFolderURL error:&error])
								{
									// Update item in database
									__block NSError *updateError = nil;

									[item clearLocalCopyProperties];

									[self.database updateCacheItems:@[item] syncAnchor:newAnchor completionHandler:^(OCDatabase *db, NSError *error) {
										updateError = error;
									}];

									if (updateError != nil)
									{
										endIterationHandler(self, updateError);
										*stop = YES;

										return;
									}
									else
									{
										OCPath parentPath = item.path.parentPath;

										if ([parentPath isEqualToString:@"/"] || [parentPath isEqualToString:@""])
										{
											#if OC_FEATURE_AVAILABLE_FILEPROVIDER
											if (OCVault.hostHasFileProvider)
											{
												[updateDirectoryLocalIDs addObject:NSFileProviderRootContainerItemIdentifier];
											}
											#endif /* OC_FEATURE_AVAILABLE_FILEPROVIDER */
										}
										else if (item.parentLocalID != nil)
										{
											[updateDirectoryLocalIDs addObject:item.parentLocalID];
										}
									}
								}
								else
								{
									OCTLogError(@[@"Compact"], @"Error removing %@: %@", removeFolderURL, error);
								}
							}
							else
							{
								OCTLogError(@[@"Compact"], @"Error copying %@ to %@: %@", removeFolderURL, copyURL, error);
							}
						}
					}
					else
					{
						OCTLogWarning(@[@"Compact"], @"Selected item %@ does not have a local copy", item);
					}
				}
			}];
		});
	}];
}

- (BOOL)fileManager:(NSFileManager *)fileManager shouldRemoveItemAtURL:(NSURL *)URL
{
	return (YES);
}

#pragma mark - File Provider
- (nullable NSArray<OCLocalID> *)translatedParentIDsForItem:(OCItem *)item suggestedRootFolderID:(nullable OCLocalID)suggestedRootFolderID
{
	// Translation without VFS
	NSArray<OCLocalID>* translatedIDs = nil;

	switch (item.type)
	{
		case OCItemTypeFile:
			if (item.path.parentPath.isRootPath)
			{
				#if OC_FEATURE_AVAILABLE_FILEPROVIDER
				translatedIDs = @[ ((suggestedRootFolderID != nil) ? suggestedRootFolderID : item.parentLocalID) ];
				#endif
			}
			else if (item.parentLocalID != nil)
			{
				translatedIDs = @[ item.parentLocalID ];
			}
		break;

		case OCItemTypeCollection:
			if (item.path.isRootPath)
			{
				#if OC_FEATURE_AVAILABLE_FILEPROVIDER
				translatedIDs = @[ ((suggestedRootFolderID != nil) ? suggestedRootFolderID : item.localID) ];
				#endif
			}
			else
			{
				if (item.parentLocalID != nil)
				{
					OCLocalID parentLocalID = item.path.parentPath.isRootPath ? ((suggestedRootFolderID != nil) ? suggestedRootFolderID : item.parentLocalID) : item.parentLocalID;

					if (item.localID != nil)
					{
						translatedIDs = @[ parentLocalID, item.localID ];
					}
					else
					{
						translatedIDs = @[ parentLocalID ];
					}
				}
			}
		break;
	}

	return (translatedIDs);
}

- (void)signalDriveChangesWithAdditions:(NSArray <OCDrive *> *)addedDrives updates:(NSArray<OCDrive *> *)updates removals:(NSArray<OCDrive *> *)removedDrives
{
	NSSet <OCVFSItemID> *changedDirectoriesVFSItemIDs = nil;

	if ([self conformsToProtocol:@protocol(OCVaultVFSTranslation)])
	{
		changedDirectoriesVFSItemIDs = [(id<OCVaultVFSTranslation>)self vfsRefreshIDsForDriveChangesWithAdditions:addedDrives updates:updates removals:removedDrives];
	}
	else
	{
		changedDirectoriesVFSItemIDs = [NSSet setWithObject:OCVFSItemIDRoot];
	}

	// Signal NSFileProviderManager
	[self signalChangesInDirectoriesWithVFSItemIDs:changedDirectoriesVFSItemIDs];
}

- (void)signalChangesForItems:(NSArray <OCItem *> *)changedItems
{
	NSMutableSet <OCVFSItemID> *changedDirectoriesVFSItemIDs = [NSMutableSet new];

	// Check for translation availability
	if (![self conformsToProtocol:@protocol(OCVaultVFSTranslation)])
	{
		OCLogError(@"Signalling changes for %@ failed: OCVault lacks OCVaultVFSTranslation conformance", changedItems);
		return;
	}

	// Coalesce IDs
//	OCLocalID rootDirectoryLocalID = nil;
//	BOOL addRoot = NO;

	for (OCItem *item in changedItems)
	{
		NSArray<OCVFSItemID> *translatedItemIDs;

		if ((translatedItemIDs = [(id<OCVaultVFSTranslation>)self vfsRefreshParentIDsForItem:item]) != nil)
		{
			[changedDirectoriesVFSItemIDs addObjectsFromArray:translatedItemIDs];
		}
	}

	// Signal NSFileProviderManager
	[self signalChangesInDirectoriesWithVFSItemIDs:changedDirectoriesVFSItemIDs];
}

- (void)signalChangesInDirectoriesWithVFSItemIDs:(NSSet <OCVFSItemID> *)changedDirectoriesVFSIDs
{
	#if OC_FEATURE_AVAILABLE_FILEPROVIDER
	if (OCVault.hostHasFileProvider)
	{
		dispatch_async(dispatch_get_main_queue(), ^{
			NSFileProviderManager *fileProviderManager = [self fileProviderManager];

			for (OCLocalID changedDirectoryVFSID in changedDirectoriesVFSIDs)
			{
				OCLogDebug(@"Signaling changes to file provider manager %@ for container with vfsItemID=%@", fileProviderManager, OCLogPrivate(changedDirectoryVFSID));

				[self signalEnumeratorForContainerItemIdentifier:changedDirectoryVFSID];
			}
		});
	}
	#endif /* OC_FEATURE_AVAILABLE_FILEPROVIDER */
}

#if OC_FEATURE_AVAILABLE_FILEPROVIDER
- (void)signalEnumeratorForContainerItemIdentifier:(OCVFSItemID)changedDirectoryVFSItemID
{
	if (!OCVault.hostHasFileProvider)
	{
		return;
	}

	if ([changedDirectoryVFSItemID isEqual:OCVFSItemIDRoot])
	{
		changedDirectoryVFSItemID = NSFileProviderRootContainerItemIdentifier;
	}

	@synchronized(_fileProviderSignalCountByContainerItemIdentifiersLock)
	{
		NSNumber *currentSignalCount = _fileProviderSignalCountByContainerItemIdentifiers[changedDirectoryVFSItemID];

		if (currentSignalCount == nil)
		{
			// The only/first signal for this right now => schedule right away

			_fileProviderSignalCountByContainerItemIdentifiers[changedDirectoryVFSItemID] = @(1);

			[self _scheduleSignalForContainerItemIdentifier:changedDirectoryVFSItemID];
		}
		else
		{
			// Another signal hasn't completed yet, so increase the counter and wait for the scheduled signal to complete
			// (at which point, another signal will be triggered)
			OCLogDebug(@"Skipped signaling %@ for changes as another signal hasn't completed yet", changedDirectoryVFSItemID);

			_fileProviderSignalCountByContainerItemIdentifiers[changedDirectoryVFSItemID] = @(_fileProviderSignalCountByContainerItemIdentifiers[changedDirectoryVFSItemID].integerValue + 1);
		}
	}
}

- (void)_scheduleSignalForContainerItemIdentifier:(OCVFSItemID)changedDirectoryVFSItemID
{
	NSTimeInterval minimumSignalInterval = 0.2; // effectively throttle FP container update notifications to at most once per [minimumSignalInterval]

	if (!OCVault.hostHasFileProvider)
	{
		return;
	}

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(minimumSignalInterval * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		NSFileProviderManager *fileProviderManager;

		if ((fileProviderManager = [self fileProviderManager]) != nil)
		{
			@synchronized(self->_fileProviderSignalCountByContainerItemIdentifiersLock)
			{
				NSInteger signalCountAtStart = self->_fileProviderSignalCountByContainerItemIdentifiers[changedDirectoryVFSItemID].integerValue;

				OCLogDebug(@"Signaling %@ for changes..", changedDirectoryVFSItemID);

				[fileProviderManager signalEnumeratorForContainerItemIdentifier:changedDirectoryVFSItemID completionHandler:^(NSError * _Nullable error) {
					OCLogDebug(@"Signaling %@ for changes ended with error %@", changedDirectoryVFSItemID, error);

					dispatch_async(dispatch_get_main_queue(), ^{
						@synchronized(self->_fileProviderSignalCountByContainerItemIdentifiersLock)
						{
							NSInteger signalCountAtEnd = self->_fileProviderSignalCountByContainerItemIdentifiers[changedDirectoryVFSItemID].integerValue;
							NSInteger remainingSignalCount = signalCountAtEnd - signalCountAtStart;

							if (remainingSignalCount > 0)
							{
								// There were signals after initiating the last signal => schedule another signal
								self->_fileProviderSignalCountByContainerItemIdentifiers[changedDirectoryVFSItemID] = @(remainingSignalCount);

								[self _scheduleSignalForContainerItemIdentifier:changedDirectoryVFSItemID];
							}
							else
							{
								// The last signal was sent after the last signal was requested => remove from dict
								[self->_fileProviderSignalCountByContainerItemIdentifiers removeObjectForKey:changedDirectoryVFSItemID];
							}
						}
					});
				}];
			}
		}
		else
		{
			OCLogDebug(@"Signaling %@ for changes failed because the file provider manager couldn't be found.", changedDirectoryVFSItemID);
		}
	});
}
#endif /* OC_FEATURE_AVAILABLE_FILEPROVIDER */

@end
