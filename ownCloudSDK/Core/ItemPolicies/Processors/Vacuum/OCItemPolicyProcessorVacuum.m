//
//  OCItemPolicyProcessorVacuum.m
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

#import "OCItemPolicyProcessorVacuum.h"

@interface OCItemPolicyProcessorVacuum ()
{
	NSMutableArray<OCDatabaseID> *_purgeDatabaseIDs;
}
@end

@implementation OCItemPolicyProcessorVacuum

+ (void)load
{
	[self registerOCClassSettingsDefaults:@{
		OCClassSettingsKeyItemPolicyVacuumSyncAnchorTTL : @(OCSyncAnchorTimeToLiveInSeconds)
	} metadata:@{
		OCClassSettingsKeyItemPolicyVacuumSyncAnchorTTL : @{
			OCClassSettingsMetadataKeyType 	      	 : OCClassSettingsMetadataTypeBoolean,
			OCClassSettingsMetadataKeyDescription 	 : @"Number of seconds since the removal of an item after which the metadata entry may be finally removed.",
			OCClassSettingsMetadataKeyCategory    	 : @"Policies",
			OCClassSettingsMetadataKeyStatus	 : OCClassSettingsKeyStatusDebugOnly
		}
	}];
}

- (instancetype)initWithCore:(OCCore *)core
{
	if ((self = [super initWithKind:OCItemPolicyKindVacuum core:core]) != nil)
	{
		[self _refreshCleanupCondition];
	}

	return (self);
}

#pragma mark - Condition creation and refresh
- (void)_refreshCleanupCondition
{
	NSNumber *vacuumSyncAnchorTTLNumber;
	NSUInteger syncAnchorTTL = OCSyncAnchorTimeToLiveInSeconds;

	if ((vacuumSyncAnchorTTLNumber = [self classSettingForOCClassSettingsKey:OCClassSettingsKeyItemPolicyVacuumSyncAnchorTTL]) != nil)
	{
		if (vacuumSyncAnchorTTLNumber.integerValue > 0)
		{
			syncAnchorTTL = vacuumSyncAnchorTTLNumber.unsignedIntegerValue;
		}
	}

	// Cleanup if: removed && (mdTimestamp < (now-SyncAnchorTTL))
	self.cleanupCondition = [OCQueryCondition require:@[
		// Item is "removed" from database
		[OCQueryCondition where:OCItemPropertyNameRemoved isEqualTo:@(YES)],

		// Last change to the item (incl. switching to "removed" is at least OCSyncAnchorTimeToLiveInSeconds ago
		[OCQueryCondition where:OCItemPropertyNameDatabaseTimestamp isLessThan:@(((NSUInteger)NSDate.timeIntervalSinceReferenceDate)-syncAnchorTTL)]
	]];
}

#pragma mark - Trigger
- (OCItemPolicyProcessorTrigger)triggerMask
{
	return (OCItemPolicyProcessorTriggerItemListUpdateCompleted |
		OCItemPolicyProcessorTriggerItemListUpdateCompletedWithoutChanges);
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
	    cleanupItem.removed) // Make double-sure this item has been marked as removed already
	{
		NSError *error = nil;

		OCLogDebug(@"Vacuuming %@…", OCLogPrivate(cleanupItem));

		// Remove
		if (cleanupItem.type == OCItemTypeFile)
		{
			error = [self.core deleteDirectoryForItem:cleanupItem]; // will return nil if the directory does not exist or was successfully removed
		}

		if (error == nil)
		{
			if (_purgeDatabaseIDs == nil)
			{
				_purgeDatabaseIDs = [NSMutableArray new];
			}

			[_purgeDatabaseIDs addObject:cleanupItem.databaseID];
		}
		else
		{
			OCLogError(@"Vacuuming %@ failed due to error=%@", OCLogPrivate(cleanupItem), error);
		}
	}
}

- (void)endCleanupWithTrigger:(OCItemPolicyProcessorTrigger)trigger
{
	if (_purgeDatabaseIDs != nil)
	{
		// Purge from database in a single transaction
		OCLogDebug(@"Vacuuming items with database IDs %@", _purgeDatabaseIDs);

		[self.core.vault.database purgeCacheItemsWithDatabaseIDs:_purgeDatabaseIDs completionHandler:nil];
		_purgeDatabaseIDs = nil;
	}
}

@end

OCItemPolicyKind OCItemPolicyKindVacuum = @"vacuum";

OCClassSettingsKey OCClassSettingsKeyItemPolicyVacuumSyncAnchorTTL = @"vacuum-sync-anchor-ttl";
