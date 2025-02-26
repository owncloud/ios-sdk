//
//  OCCore+DriveManagement.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 04.02.25.
//  Copyright © 2025 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2025, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCCore.h"
#import "OCCore+ItemList.h"
#import "OCDataRenderer.h"
#import "NSProgress+OCExtensions.h"
#import "GADrive.h"
#import "GADriveItem.h"
#import "NSError+OCError.h"

@implementation OCCore (DriveManagement)

// Creation
- (nullable NSProgress *)createDriveWithName:(NSString *)name description:(nullable NSString *)description quota:(nullable NSNumber *)quotaBytes template:(nullable OCDriveTemplate)template completionHandler:(OCCoreDriveCompletionHandler)completionHandler
{
	return ([self.connection createDriveWithName:name description:description quota:quotaBytes template:template completionHandler:^(NSError * _Nullable error, OCDrive * _Nullable newDrive) {
		if (error == nil) {
			[self fetchUpdatesWithCompletionHandler:nil];
		}
		completionHandler(error, newDrive);
	}]);
}

// Disable/Restore/Delete
- (nullable NSProgress *)disableDrive:(OCDrive *)drive completionHandler:(OCCoreCompletionHandler)completionHandler
{
	return ([self.connection disableDrive:drive completionHandler:^(NSError * _Nullable error) {
		if (error == nil) {
			[self fetchUpdatesWithCompletionHandler:nil];
		}
		completionHandler(error);
	}]);
}

- (nullable NSProgress *)restoreDrive:(OCDrive *)drive completionHandler:(OCCoreCompletionHandler)completionHandler
{
	return ([self.connection restoreDrive:drive completionHandler:^(NSError * _Nullable error) {
		if (error == nil) {
			[self fetchUpdatesWithCompletionHandler:nil];
		}
		completionHandler(error);
	}]);
}

- (nullable NSProgress *)deleteDrive:(OCDrive *)drive completionHandler:(OCCoreCompletionHandler)completionHandler
{
	return ([self.connection deleteDrive:drive completionHandler:^(NSError * _Nullable error) {
		if (error == nil) {
			[self fetchUpdatesWithCompletionHandler:nil];
		}
		completionHandler(error);
	}]);
}

// Change attributes
- (nullable NSProgress *)updateDrive:(OCDrive *)drive properties:(NSDictionary<OCDriveProperty, id> *)updateProperties completionHandler:(OCCoreDriveCompletionHandler)completionHandler
{
	return ([self.connection updateDrive:drive properties:updateProperties completionHandler:^(NSError * _Nullable error, OCDrive * _Nullable newDrive) {
		if (error == nil) {
			[self fetchUpdatesWithCompletionHandler:nil];
		}
		if (completionHandler != nil) {
			completionHandler(error, newDrive);
		}
	}]);
}

- (void)retrieveDrive:(OCDrive *)drive itemForResource:(OCDriveResource)resource completionHandler:(nonnull OCCoreItemCompletionHandler)completionHandler
{
	GADriveItem *driveItem = nil;

	if ([resource isEqual:OCDriveResourceCoverImage]) {
		// Use special "image" drive item from GADrive
		driveItem = [drive.gaDrive specialDriveItemFor:GASpecialFolderNameImage];
	} else if ([resource isEqual:OCDriveResourceCoverDescription]) {
		// Use special "readme" drive item from GADrive
		driveItem = [drive.gaDrive specialDriveItemFor:GASpecialFolderNameReadme];
	} else if ([resource isEqual:OCDriveResourceSpaceFolder]) {
		// Use APIs to determine .space folder and find an item for it, creating it if needed
		OCPath spacesFolderPath;
		if ((spacesFolderPath = [self classSettingForOCClassSettingsKey:OCCoreSpaceResourceFolderPath]) != nil)
		{
			OCLocation *spacesFolderLocation = [[OCLocation alloc] initWithDriveID:drive.identifier path:[NSString stringWithFormat:@"/%@/", spacesFolderPath]]; // Add leading and trailing / to spaces folder path
			__block OCCoreItemTracking itemTracking;
			__weak OCCore *weakCore = self;
			dispatch_queue_t queue = _queue;
			itemTracking = [self trackItemAtLocation:spacesFolderLocation trackingHandler:^(NSError * _Nullable error, OCItem * _Nullable item, BOOL isInitial) {
				if (isInitial)
				{
					dispatch_async(queue, ^{
						// End tracking
						itemTracking = nil;

						// Check for errors
						if (error != nil)
						{
							completionHandler(error, nil);
							return;
						}

						// Folder found -> return
						if (item != nil)
						{
							completionHandler(nil, item);
							return;
						}

						// Folder not found -> create it
						OCCore *strongCore;

						if ((strongCore = weakCore) == nil)
						{
							completionHandler(OCError(OCErrorInternal), nil);
							return;
						}

						[strongCore.vault.database retrieveCacheItemsAtLocation:drive.rootLocation itemOnly:YES completionHandler:^(OCDatabase *db, NSError *error, OCSyncAnchor syncAnchor, NSArray<OCItem *> *items) {
							// Determine root item
							if (error != nil)
							{
								completionHandler(error, nil);
								return;
							}

							OCItem *rootItem = items.firstObject;
							if (rootItem != nil)
							{
								// Create folder
								OCCore *strongCore;
								if ((strongCore = weakCore) == nil)
								{
									completionHandler(OCError(OCErrorInternal), nil);
									return;
								}

								[strongCore createFolder:spacesFolderPath inside:rootItem options:nil resultHandler:^(NSError * _Nullable error, OCCore * _Nonnull core, OCItem * _Nullable item, id  _Nullable parameter) {
									// Return created folder result
									completionHandler(error, item);
								}];
							}
						}];
					});
				}
			}];
		}
		return;
	} else {
		// Unknown/unsupported resource type -> return error
		completionHandler(OCError(OCErrorInvalidParameter), nil);
	}

	if ((driveItem != nil) && (driveItem.identifier != nil))
	{
		// GADriveItem.id is the FileID of the item, so fetch it from the database
		[self.vault.database retrieveCacheItemForFileID:driveItem.identifier completionHandler:^(OCDatabase *db, NSError *error, OCSyncAnchor syncAnchor, OCItem *item) {
			completionHandler(error, item);
		}];
	}
	else
	{
		// No drive item of type found for drive
		completionHandler(OCError(OCErrorResourceNotFound), nil);
	}
}

- (nullable NSProgress *)updateDrive:(OCDrive *)drive resourceFor:(OCDriveResource)resource withItem:(nullable OCItem *)item completionHandler:(nullable OCCoreDriveCompletionHandler)completionHandler
{
	return ([self.connection updateDrive:drive resourceFor:resource withItem:item completionHandler:^(NSError * _Nullable error, OCDrive * _Nullable drive) {
		if (error == nil) {
			[self fetchUpdatesWithCompletionHandler:nil];
		}
		if (completionHandler != nil) {
			completionHandler(error, drive);
		}
	}]);
}

@end
