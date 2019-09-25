//
//  OCItemPolicyProcessorDownloadExpiration.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 24.07.19.
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

#import "OCItemPolicyProcessorDownloadExpiration.h"
#import "OCCore+ItemUpdates.h"
#import "OCLogger.h"

@interface OCItemPolicyProcessorDownloadExpiration ()
{
	NSMutableArray<OCItem *> *_trimmedItems;
}
@end

@implementation OCItemPolicyProcessorDownloadExpiration

+ (void)load
{
	[self registerOCClassSettingsDefaults:@{
		OCClassSettingsKeyItemPolicyLocalCopyExpirationEnabled : @(YES), // Enabled
		OCClassSettingsKeyItemPolicyLocalCopyExpiration : @(60 * 60 * 24 * 7) // 7 days
	}];
}

- (instancetype)initWithCore:(OCCore *)core
{
	if ((self = [super initWithKind:OCItemPolicyKindDownloadExpiration core:core]) != nil)
	{
		[self _refreshCleanupCondition];
	}

	return (self);
}

#pragma mark - Parameters
- (BOOL)enabled
{
	return (((NSNumber *)[self classSettingForOCClassSettingsKey:OCClassSettingsKeyItemPolicyLocalCopyExpirationEnabled]).boolValue);
}

- (UInt64)minimumTimeSinceLastUsage
{
	NSNumber *expirationDuration = [self classSettingForOCClassSettingsKey:OCClassSettingsKeyItemPolicyLocalCopyExpiration];

	if (expirationDuration.doubleValue > 0)
	{
		return (expirationDuration.doubleValue);
	}

	return (60 * 60 * 24 * 7); // 7 days
}

#pragma mark - Computation
+ (NSNumber *)_capacityForKey:(NSURLResourceKey)urlResourceKey error:(NSError **)outError
{
	NSError *error = nil;
	NSURL *documentDirectoryURL;
	NSNumber *capacityBytesNumber = nil;

	if ((documentDirectoryURL = [NSFileManager.defaultManager URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:&error]) != nil)
	{
		if (![documentDirectoryURL getResourceValue:&capacityBytesNumber forKey:NSURLVolumeTotalCapacityKey error:&error])
		{
			OCLogError(@"Error determining %@ space: %@", urlResourceKey, error);
		}
	}
	else
	{
		OCLogError(@"Error determining document directory: %@", error);
	}

	if (outError != nil)
	{
		*outError = error;
	}

	return (capacityBytesNumber);

}

+ (NSNumber *)freeDiskSpace
{
	return ([self _capacityForKey:NSURLVolumeAvailableCapacityKey error:nil]);
}

+ (NSNumber *)totalCapacity
{
	return ([self _capacityForKey:NSURLVolumeTotalCapacityKey error:nil]);
}

//- (UInt64)effectiveLocalCopyQuota
//{
//	UInt64 permanentLocalCopyQuota = self.permanentLocalCopyQuota;
//	UInt64 minimumFreeDiskSpace = self.minimumFreeDiskSpace;
//	UInt64 availableDiskSpace = OCItemPolicyProcessorDownloadExpiration.freeDiskSpace.unsignedLongLongValue;
//
//	if (permanentLocalCopyQuota != 0)
//	{
//		 // User has set a local copy quota
//		if (minimumFreeDiskSpace != 0)
//		{
//			// User has also set a minimum amount of disk space to keep free
//		}
//	}
//}

#pragma mark - Condition creation and refresh
- (void)_refreshCleanupCondition
{
	if (self.enabled)
	{
		// Cleanup if: !removed && localCopy && (lastUsed < (now-maxAge))
		self.cleanupCondition = [[OCQueryCondition require:@[
			// Item is not "removed" from database
			[OCQueryCondition where:OCItemPropertyNameRemoved isEqualTo:@(NO)],

			// Item is of type "file"
			[OCQueryCondition where:OCItemPropertyNameType isEqualTo:@(OCItemTypeFile)],

			// Item is a local copy of the file from the server
			[OCQueryCondition where:OCItemPropertyNameCloudStatus isEqualTo:@(OCItemCloudStatusLocalCopy)],

			// Item download wasn't triggered by available offline policy processor
			[OCQueryCondition where:OCItemPropertyNameDownloadTrigger isNotEqualTo:OCItemDownloadTriggerIDAvailableOffline],

			// Last change to the item (incl. switching to "removed" is at least OCSyncAnchorTimeToLiveInSeconds ago
			[OCQueryCondition where:OCItemPropertyNameLastUsed isLessThan:@(((NSUInteger)NSDate.date.timeIntervalSince1970)-self.minimumTimeSinceLastUsage)]
		]] sortedBy:OCItemPropertyNameLastUsed ascending:NO];
	}
	else
	{
		// Disabled
		self.cleanupCondition = nil;
	}
}

#pragma mark - Trigger
- (OCItemPolicyProcessorTrigger)triggerMask
{
	if (self.enabled)
	{
		return (OCItemPolicyProcessorTriggerItemListUpdateCompleted |
			OCItemPolicyProcessorTriggerItemListUpdateCompletedWithoutChanges);
	}

	return (0); // Disabled
}

#pragma mark - Events
- (void)willEnterTrigger:(OCItemPolicyProcessorTrigger)trigger
{
	[self _refreshCleanupCondition];
}

#pragma mark - Cleanup handling
- (void)performCleanupOn:(OCItem *)cleanupItem withTrigger:(OCItemPolicyProcessorTrigger)trigger
{
	if ((cleanupItem.activeSyncRecordIDs.count == 0) && // Make sure there's no still ongoing sync activity (like f.ex. a Delete that hasn't completed yet) before removal
	    (cleanupItem.cloudStatus == OCItemCloudStatusLocalCopy) && // Make double-sure this item is only a local copy of a remote file
	    (![cleanupItem.downloadTriggerIdentifier isEqual:OCItemDownloadTriggerIDAvailableOffline]) && // Make sure item isn't an available offline item
	    !cleanupItem.fileClaim.isValid // File is no longer retained by anyone
	    )
	{
		NSError *error = nil;

		OCLogDebug(@"Trimming %@…", OCLogPrivate(cleanupItem));

		// Trim local copy
		if (cleanupItem.type == OCItemTypeFile)
		{
			error = [self.core deleteDirectoryForItem:cleanupItem]; // will return nil if the directory does not exist or was successfully removed
		}

		if (error == nil)
		{
			cleanupItem.localRelativePath = nil;
			cleanupItem.localCopyVersionIdentifier = nil;
			cleanupItem.downloadTriggerIdentifier = nil;
			cleanupItem.fileClaim = nil;

			if (_trimmedItems == nil)
			{
				_trimmedItems = [NSMutableArray new];
			}

			[_trimmedItems addObject:cleanupItem];
		}
		else
		{
			OCLogError(@"Trimming %@ failed due to error=%@", OCLogPrivate(cleanupItem), error);
		}
	}
}

- (void)endCleanupWithTrigger:(OCItemPolicyProcessorTrigger)trigger
{
	if (_trimmedItems != nil)
	{
		// Update items in database in a single transaction
		OCLogDebug(@"Updating %lu trimmed items", _trimmedItems.count);

		[self.core performUpdatesForAddedItems:nil removedItems:nil updatedItems:_trimmedItems refreshPaths:nil newSyncAnchor:nil beforeQueryUpdates:nil afterQueryUpdates:nil queryPostProcessor:nil skipDatabase:NO];

		_trimmedItems = nil;
	}
}

@end

OCItemPolicyKind OCItemPolicyKindDownloadExpiration = @"downloadExpiration";

OCClassSettingsKey OCClassSettingsKeyItemPolicyLocalCopyExpiration = @"local-copy-expiration";
OCClassSettingsKey OCClassSettingsKeyItemPolicyLocalCopyExpirationEnabled = @"local-copy-expiration-enabled";
