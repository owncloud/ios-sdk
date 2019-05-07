//
//  OCVault+Internal.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 07.05.19.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
//

#import "OCVault+Internal.h"

@implementation OCVault (Internal)

- (void)compactInContext:(nullable void(^)(void(^blockToRunInContext)(OCSyncAnchor syncAnchor)))runInContext withSelector:(OCVaultCompactSelector)selector completionHandler:(nullable OCCompletionHandler)completionHandler
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

		runInContext = ^(void(^blockToRunInContext)(OCSyncAnchor syncAnchor)) {
			[self.database increaseValueForCounter:OCCoreSyncAnchorCounter withProtectedBlock:^NSError *(NSNumber *previousCounterValue, NSNumber *newCounterValue) {
				blockToRunInContext(newCounterValue);
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

		runInContext(^(OCSyncAnchor newAnchor){
			NSFileManager *fileManager = [NSFileManager new];
			fileManager.delegate = self;

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
				}

				OCTLogDebug(@[@"Compact"], @"Closing database");

				[self.database closeWithCompletionHandler:^(OCDatabase *db, NSError *closeError) {
					OCTLogDebug(@[@"Compact"], @"Closed database with error=%@", error);

					completionHandler(sender, (error != nil) ? error : closeError);
				}];
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

							if ([fileManager copyItemAtURL:removeFolderURL toURL:copyURL error:&error])
							{
								if ([fileManager removeItemAtURL:removeFolderURL error:&error])
								{
									// Update item in database
									__block NSError *updateError = nil;

									item.localRelativePath = nil;

									[self.database updateCacheItems:@[item] syncAnchor:newAnchor completionHandler:^(OCDatabase *db, NSError *error) {
										updateError = error;
									}];

									if (updateError != nil)
									{
										endIterationHandler(self, updateError);
										*stop = YES;

										return;
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

@end
