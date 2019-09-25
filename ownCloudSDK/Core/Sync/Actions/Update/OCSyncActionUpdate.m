//
//  OCSyncActionUpdate.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 09.11.18.
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

#import "OCSyncActionUpdate.h"
#import "OCMacros.h"

@implementation OCSyncActionUpdate

- (instancetype)initWithItem:(OCItem *)item updateProperties:(NSArray <OCItemPropertyName> *)properties
{
	if ((self = [super initWithItem:item]) != nil)
	{
		self.identifier = OCSyncActionIdentifierUpdate;

		self.updateProperties = properties;

		self.actionEventType = OCEventTypeUpdate;
		self.localizedDescription = [NSString stringWithFormat:OCLocalized(@"Updating metadata for '%@'…"), item.name];
	}

	return (self);
}

- (void)preflightWithContext:(OCSyncContext *)syncContext
{
	if (self.localItem != nil)
	{
		NSError *error = nil;
		OCItem *latestItemVersion = nil;
		BOOL updateLocalItem = YES;

		[self.localItem addSyncRecordID:syncContext.syncRecord.recordID activity:OCItemSyncActivityUpdating];

		// Special handling for local attributes
		if ((latestItemVersion = [self.core retrieveLatestVersionOfItem:self.localItem withError:&error]) != nil)
		{
			// Archive latest version
			self.archivedItemVersion = latestItemVersion;

			if (latestItemVersion.localAttributesLastModified > self.localItem.localAttributesLastModified)
			{
				if ([_updateProperties containsObject:OCItemPropertyNameLocalAttributes])
				{
					// This action is supposed to update the local attributes, but the database already has newer version of local attributes
					// => return error (which also deschedules the action)
					syncContext.error = OCError(OCErrorNewerVersionExists);
					updateLocalItem = NO;
				}
				else
				{
					// Database item has newer localAttributes
					// => merge in newer version
					self.localItem.localAttributes = latestItemVersion.localAttributes;
					self.localItem.localAttributesLastModified = latestItemVersion.localAttributesLastModified;
				}
			}
		}

		if ([_updateProperties containsObject:OCItemPropertyNameLocalAttributes] && (_updateProperties.count == 1))
		{
			// Remove localAttributes-only updates, as these are handled entirely in preflight
			syncContext.removeRecords = @[ syncContext.syncRecord ];
		}
		else
		{
			// Update syncRecord, so any updates to the localItem will be stored in the database and will be around in other calls
			syncContext.updateStoredSyncRecordAfterItemUpdates = YES;
		}

		if (updateLocalItem)
		{
			syncContext.updatedItems = @[ self.localItem ];
		}
	}
}

- (void)descheduleWithContext:(OCSyncContext *)syncContext
{
	if (self.localItem != nil)
	{
		[self.localItem removeSyncRecordID:syncContext.syncRecord.recordID activity:OCItemSyncActivityUpdating];

		// Restore archived latest version
		self.archivedItemVersion.databaseID = self.localItem.databaseID;

		syncContext.updatedItems = @[ self.archivedItemVersion ];
	}
}

- (OCCoreSyncInstruction)scheduleWithContext:(OCSyncContext *)syncContext
{
	if ((self.localItem != nil) && (self.updateProperties != nil))
	{
		OCProgress *progress;

		if ((progress = [self.core.connection updateItem:self.localItem properties:self.updateProperties options:nil resultTarget:[self.core _eventTargetWithSyncRecord:syncContext.syncRecord]]) != nil)
		{
			[syncContext.syncRecord addProgress:progress];

			[syncContext transitionToState:OCSyncRecordStateProcessing withWaitConditions:nil];
		}
	}

	return (OCCoreSyncInstructionStop);
}

- (OCCoreSyncInstruction)handleResultWithContext:(OCSyncContext *)syncContext
{
	OCEvent *event = syncContext.event;
	OCCoreSyncInstruction resultInstruction = OCCoreSyncInstructionNone;
	OCConnectionPropertyUpdateResult propertyUpdateResult = nil;

	if ((event.error == nil) && ((propertyUpdateResult = OCTypedCast(event.result, NSDictionary)) != nil))
	{
		__block BOOL allChangesSuccessful = YES;
		syncContext.updatedItems = @[ self.localItem ];

		[self.localItem removeSyncRecordID:syncContext.syncRecord.recordID activity:OCItemSyncActivityUpdating];

		[propertyUpdateResult enumerateKeysAndObjectsUsingBlock:^(OCItemPropertyName  _Nonnull propertyName, OCHTTPStatus * _Nonnull updateStatus, BOOL * _Nonnull stop) {
			if (!updateStatus.isSuccess)
			{
				// Property couldn't be updated successfully
				[syncContext addSyncIssue:[OCSyncIssue issueForSyncRecord:syncContext.syncRecord
										    level:OCIssueLevelError
										    title:[NSString stringWithFormat:OCLocalizedString(@"\"%@\" metadata for %@ couldn't be updated",nil), [OCItem localizedNameForProperty:propertyName], self.localItem.name]
									      description:[NSString stringWithFormat:OCLocalizedString(@"Update failed with status code %d",nil), updateStatus.code]
										 metaData:nil
										  choices:@[
												// Drop sync record (also restores previous metadata)
										  		[OCSyncIssueChoice cancelChoiceWithImpact:OCSyncIssueChoiceImpactNonDestructive]
											   ]
							  ]
				];

				// Prevent removal of sync record, so it's still around for descheduling
				allChangesSuccessful = NO;
			}
		}];

		if (allChangesSuccessful)
		{
			[syncContext completeWithError:event.error core:self.core item:self.localItem parameter:propertyUpdateResult];

			// Action complete and can be removed
			[syncContext transitionToState:OCSyncRecordStateCompleted withWaitConditions:nil];
			resultInstruction = OCCoreSyncInstructionDeleteLast;
		}
		else
		{
			[syncContext transitionToState:OCSyncRecordStateProcessing withWaitConditions:nil]; // updates the sync record with the issue wait conditions
		}
	}
	else if (event.error != nil)
	{
		// Create issue for cancellation for any errors
		[self.core _addIssueForCancellationAndDeschedulingToContext:syncContext title:[NSString stringWithFormat:OCLocalizedString(@"Error updating %@ metadata", nil), self.localItem.name] description:[event.error localizedDescription] impact:OCSyncIssueChoiceImpactDataLoss]; // queues a new wait condition with the issue
		[syncContext transitionToState:OCSyncRecordStateProcessing withWaitConditions:nil]; // updates the sync record with the issue wait condition
	}

	return (resultInstruction);
}

#pragma mark - Lane tags
- (NSSet<OCSyncLaneTag> *)generateLaneTags
{
	return ([self generateLaneTagsFromItems:@[
		OCSyncActionWrapNullableItem(self.localItem),
		OCSyncActionWrapNullableItem(self.archivedItemVersion)
	]]);
}

#pragma mark - NSCoding
- (void)decodeActionData:(NSCoder *)decoder
{
	_updateProperties = [decoder decodeObjectOfClasses:[[NSSet alloc] initWithObjects:NSArray.class, NSString.class, nil] forKey:@"updateProperties"];
	_archivedItemVersion = [decoder decodeObjectOfClass:[OCItem class] forKey:@"archivedItemVersion"];
}

- (void)encodeActionData:(NSCoder *)coder
{
	[coder encodeObject:_updateProperties forKey:@"updateProperties"];
	[coder encodeObject:_archivedItemVersion forKey:@"archivedItemVersion"];
}

@end
