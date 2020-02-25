//
//  OCWaitConditionMetaDataRefresh.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 24.02.20.
//  Copyright © 2020 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2020, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCWaitConditionMetaDataRefresh.h"
#import "OCCore.h"
#import "OCCore+SyncEngine.h"

@interface OCWaitConditionMetaDataRefresh ()
{
	OCCoreItemTracking _itemTracker;
}

@end

@implementation OCWaitConditionMetaDataRefresh

+ (instancetype)waitForPath:(OCPath)path versionOtherThan:(OCItemVersionIdentifier *)itemVersionIdentifier until:(NSDate * _Nullable)expirationDate
{
	OCWaitConditionMetaDataRefresh *waitCondition = [OCWaitConditionMetaDataRefresh new];

	waitCondition.itemPath = path;
	waitCondition.itemVersionIdentifier = itemVersionIdentifier;
	waitCondition.expirationDate = expirationDate;

	return (waitCondition);
}

- (void)evaluateWithOptions:(OCWaitConditionOptions)options completionHandler:(OCWaitConditionEvaluationResultHandler)completionHandler
{
	OCWaitConditionState state = OCWaitConditionStateWait;

	if (completionHandler == nil) { return; }

	// Check if the meta data has changed
	OCCore *core = nil;
	OCSyncRecord *syncRecord = options[OCWaitConditionOptionSyncRecord];
	OCSyncRecordID syncRecordID = syncRecord.recordID;

	if ((core = options[OCWaitConditionOptionCore]) != nil)
	{
		NSError *error = nil;
		OCItem *cachedItem = nil;

		if ((cachedItem = [core cachedItemAtPath:self.itemPath error:&error]) != nil)
		{
			// Get latest remote version
			cachedItem = (cachedItem.remoteItem != nil) ? cachedItem.remoteItem : cachedItem;

			if (self.itemVersionIdentifier != nil)
			{
				if (![cachedItem.itemVersionIdentifier isEqual:self.itemVersionIdentifier])
				{
					// Item version identifier has changed
					OCLogDebug(@"Metadata refresh wait condition found change of %@: %@ vs %@ - proceeding with sync record %@", self.itemPath, self.itemVersionIdentifier, cachedItem.itemVersionIdentifier, syncRecordID);

					state = OCWaitConditionStateProceed;
				}
			}
		}
		else
		{
			// Item is gone
			state = OCWaitConditionStateProceed;
		}
	}

	// Check if the condition has expired
	if ((_expirationDate != nil) && ([_expirationDate timeIntervalSinceNow] < 0) && (state == OCWaitConditionStateWait))
	{
		OCLogDebug(@"Metadata refresh wait condition timed out for %@, sync record %@", self.itemPath, syncRecordID);
		state = OCWaitConditionStateProceed;
	}

	// Watch path
	if (state == OCWaitConditionStateWait)
	{
		if (_itemTracker == nil)
		{
			__weak OCWaitConditionMetaDataRefresh *weakSelf = self;
			__block BOOL didNotify = NO;

			_itemTracker = [core trackItemAtPath:self.itemPath trackingHandler:^(NSError * _Nullable error, OCItem * _Nullable item, BOOL isInitial) {

				item = (item.remoteItem != nil) ? item.remoteItem : item;

				if (![item.itemVersionIdentifier isEqual:self.itemVersionIdentifier])
				{
					if (!didNotify)
					{
						didNotify = YES;

						OCWTLogDebug(nil, @"Metadata refresh wait condition notified of change of %@: %@ vs %@ - waking up sync record %@", weakSelf.itemPath, weakSelf.itemVersionIdentifier, item.itemVersionIdentifier, syncRecordID);
						[core wakeupSyncRecord:syncRecordID waitCondition:self userInfo:nil result:nil];
					}
				}
			}];
		}
	}

	completionHandler(state, NO, nil);
}

#pragma mark - Event handling
- (BOOL)handleEvent:(OCEvent *)event withOptions:(OCWaitConditionOptions)options sender:(id)sender
{
	if (event.eventType == OCEventTypeWakeupSyncRecord)
	{
		return (YES);
	}

	return ([super handleEvent:event withOptions:options sender:sender]);
}

#pragma mark - Secure Coding
+ (BOOL)supportsSecureCoding
{
	return (YES);
}

- (void)encodeWithCoder:(nonnull NSCoder *)coder
{
	[super encodeWithCoder:coder];

	[coder encodeObject:_itemPath forKey:@"itemPath"];
	[coder encodeObject:_expirationDate forKey:@"expirationDate"];
	[coder encodeObject:_itemVersionIdentifier forKey:@"itemVersionIdentifier"];
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)decoder
{
	if ((self = [super initWithCoder:decoder]) != nil)
	{
		_itemPath = [decoder decodeObjectOfClass:[NSString class] forKey:@"itemPath"];
		_expirationDate = [decoder decodeObjectOfClass:[NSDate class] forKey:@"expirationDate"];
		_itemVersionIdentifier = [decoder decodeObjectOfClass:[OCItemVersionIdentifier class] forKey:@"itemVersionIdentifier"];
	}

	return (self);
}

@end
