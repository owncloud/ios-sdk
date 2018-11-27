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

@implementation OCSyncActionUpdate

- (instancetype)initWithItem:(OCItem *)item updateProperties:(NSArray <OCItemPropertyName> *)properties
{
	if ((self = [super initWithItem:item]) != nil)
	{
		self.identifier = OCSyncActionIdentifierUpdate;

		self.updateProperties = properties;
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
		syncContext.updatedItems = @[ self.archivedItemVersion ];
	}
}

- (BOOL)scheduleWithContext:(OCSyncContext *)syncContext
{
	if ((self.localItem != nil) && (self.updateProperties != nil))
	{
		NSProgress *progress;

		if ((progress = [self.core.connection updateItem:self.localItem properties:self.updateProperties options:nil resultTarget:[self.core _eventTargetWithSyncRecord:syncContext.syncRecord]]) != nil)
		{
			[syncContext.syncRecord addProgress:progress];

			return (YES);
		}
	}

	return (NO);
}

- (BOOL)handleResultWithContext:(OCSyncContext *)syncContext
{
	OCEvent *event = syncContext.event;
	OCSyncRecord *syncRecord = syncContext.syncRecord;
	__block BOOL canDeleteSyncRecord = NO;
	OCConnectionPropertyUpdateResult propertyUpdateResult = nil;

	if ((event.error == nil) && ((propertyUpdateResult = event.result) != nil))
	{
		canDeleteSyncRecord = YES;
		syncContext.updatedItems = @[ self.localItem ];

		[self.localItem removeSyncRecordID:syncContext.syncRecord.recordID activity:OCItemSyncActivityUpdating];

		[propertyUpdateResult enumerateKeysAndObjectsUsingBlock:^(OCItemPropertyName  _Nonnull propertyName, OCHTTPStatus * _Nonnull updateStatus, BOOL * _Nonnull stop) {
			if (!updateStatus.isSuccess)
			{
				// Property couldn't be updated successfully
				[syncContext addIssue:[OCConnectionIssue issueForMultipleChoicesWithLocalizedTitle:[NSString stringWithFormat:OCLocalizedString(@"\"%@\" metadata for %@ couldn't be updated",nil), [OCItem localizedNameForProperty:propertyName], self.localItem.name]
									 localizedDescription:[NSString stringWithFormat:OCLocalizedString(@"Update failed with status code %d",nil), updateStatus.code]
									 choices: @[
									 	[OCConnectionIssueChoice choiceWithType:OCConnectionIssueChoiceTypeCancel label:nil handler:^(OCConnectionIssue *issue, OCConnectionIssueChoice *choice) {
											// Drop sync record (also restores previous metadata)
											[self.core descheduleSyncRecord:syncRecord invokeResultHandler:NO withParameter:nil resultHandlerError:nil];
										}]
									 ]
									 completionHandler:nil
							]
				];

				// Prevent removal of sync record, so it's still around for descheduling
				canDeleteSyncRecord = NO;
			}
		}];
	}
	else if (event.error != nil)
	{
		// Create issue for cancellation for any errors
		[self.core _addIssueForCancellationAndDeschedulingToContext:syncContext title:[NSString stringWithFormat:OCLocalizedString(@"Error updating %@ metadata", nil), self.localItem.name] description:[event.error localizedDescription] invokeResultHandler:NO resultHandlerError:nil];
	}

	if (syncRecord.resultHandler != nil)
	{
		syncRecord.resultHandler(event.error, self.core, self.localItem, propertyUpdateResult);
	}

	return (canDeleteSyncRecord);
}

#pragma mark - NSCoding
- (void)decodeActionData:(NSCoder *)decoder
{
	_updateProperties = [decoder decodeObjectOfClass:[NSDictionary class] forKey:@"updateProperties"];
}

- (void)encodeActionData:(NSCoder *)coder
{
	[coder encodeObject:_updateProperties forKey:@"updateProperties"];
}

@end
