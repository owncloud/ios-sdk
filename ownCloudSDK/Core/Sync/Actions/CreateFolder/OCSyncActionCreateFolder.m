//
//  OCSyncActionCreateFolder.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 06.09.18.
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

#import "OCSyncActionCreateFolder.h"

@implementation OCSyncActionCreateFolder

#pragma mark - Initializer
- (instancetype)initWithParentItem:(OCItem *)parentItem folderName:(NSString *)folderName placeholderCompletionHandler:(nullable OCCorePlaceholderCompletionHandler)placeholderCompletionHandler
{
	if ((self = [super initWithItem:parentItem]) != nil)
	{
		OCItem *placeholderItem;

		self.identifier = OCSyncActionIdentifierCreateFolder;

		self.folderName = folderName;

		if ((placeholderItem = [OCItem placeholderItemOfType:OCItemTypeCollection]) != nil)
		{
			placeholderItem.parentFileID = parentItem.fileID;
			placeholderItem.parentLocalID = parentItem.localID;
			placeholderItem.path = [parentItem.path pathForSubdirectoryWithName:folderName];
			placeholderItem.lastModified = [NSDate date];

			self.placeholderItem = placeholderItem;
		}

		self.actionEventType = OCEventTypeCreateFolder;
		self.localizedDescription = [NSString stringWithFormat:OCLocalized(@"Creating folder %@…"), folderName];

		if (placeholderCompletionHandler != nil)
		{
			self.ephermalParameters = [[NSDictionary alloc] initWithObjectsAndKeys: [placeholderCompletionHandler copy], OCCoreOptionPlaceholderCompletionHandler, nil];
		}
	}

	return (self);
}

#pragma mark - Action implementation
- (void)preflightWithContext:(OCSyncContext *)syncContext
{
	if (self.placeholderItem != nil)
	{
		OCCorePlaceholderCompletionHandler placeholderCompletionHandler = nil;

		[_placeholderItem addSyncRecordID:syncContext.syncRecord.recordID activity:OCItemSyncActivityCreating];

		syncContext.addedItems = @[ _placeholderItem ];

		if ((placeholderCompletionHandler = self.ephermalParameters[OCCoreOptionPlaceholderCompletionHandler]) != nil)
		{
			placeholderCompletionHandler(nil, _placeholderItem);
			self.ephermalParameters = nil;
		}

		syncContext.updateStoredSyncRecordAfterItemUpdates = YES; // Update syncRecord, so the updated placeHolderItem (now with databaseID) will be stored in the database and can later be used to remove the placeHolderItem again.
	}
}

- (void)descheduleWithContext:(OCSyncContext *)syncContext
{
	if (self.placeholderItem != nil)
	{
		[_placeholderItem removeSyncRecordID:syncContext.syncRecord.recordID activity:OCItemSyncActivityCreating];

		syncContext.removedItems = @[ _placeholderItem ];
	}
}

- (OCCoreSyncInstruction)scheduleWithContext:(OCSyncContext *)syncContext
{
	OCPath folderName;
	OCItem *parentItem;

	if (((folderName = self.folderName) != nil) &&
	    ((parentItem = self.localItem) != nil))
	{
		OCProgress *progress;

		if ((progress = [self.core.connection createFolder:folderName inside:parentItem options:nil resultTarget:[self.core _eventTargetWithSyncRecord:syncContext.syncRecord]]) != nil)
		{
			[syncContext.syncRecord addProgress:progress];
		}

		// Transition to processing
		[syncContext transitionToState:OCSyncRecordStateProcessing withWaitConditions:nil];

		// Wait for result
		return (OCCoreSyncInstructionStop);
	}

	// Remove record as its action is not sufficiently specified
	return (OCCoreSyncInstructionDeleteLast);
}

- (OCCoreSyncInstruction)handleResultWithContext:(OCSyncContext *)syncContext
{
	OCEvent *event = syncContext.event;
	OCCoreSyncInstruction resultInstruction = OCCoreSyncInstructionNone;
	OCItem *newItem = nil;

	if ((event.error == nil) && ((newItem = OCTypedCast(event.result, OCItem)) != nil))
	{
		OCItem *placeholderItem;

		if ((placeholderItem = self.placeholderItem) != nil)
		{
			[placeholderItem removeSyncRecordID:syncContext.syncRecord.recordID activity:OCItemSyncActivityCreating];

			newItem.previousPlaceholderFileID = placeholderItem.fileID;
			newItem.parentFileID = placeholderItem.parentFileID;

			newItem.localID = placeholderItem.localID;
			newItem.parentLocalID = placeholderItem.parentLocalID;

			placeholderItem.localID = nil;

			syncContext.removedItems = @[ placeholderItem ];
		}

		syncContext.addedItems = @[ newItem ];

		// Action complete and can be removed
		[syncContext transitionToState:OCSyncRecordStateCompleted withWaitConditions:nil];
		resultInstruction = OCCoreSyncInstructionDeleteLast;
	}
	else if (event.error != nil)
	{
		// Create issue for cancellation for any errors
		[self.core _addIssueForCancellationAndDeschedulingToContext:syncContext title:[NSString stringWithFormat:OCLocalizedString(@"Couldn't create %@", nil), self.folderName] description:[event.error localizedDescription]  impact:OCSyncIssueChoiceImpactNonDestructive]; // queues a new wait condition with the issue
		[syncContext transitionToState:OCSyncRecordStateProcessing withWaitConditions:nil]; // updates the sync record with the issue wait condition
	}

	[syncContext completeWithError:event.error core:self.core item:newItem parameter:nil];

	return (resultInstruction);
}

#pragma mark - Lane tags
- (NSSet<OCSyncLaneTag> *)generateLaneTags
{
	return ([self generateLaneTagsFromItems:@[
		OCSyncActionWrapNullableItem(self.placeholderItem)
	]]);
}

#pragma mark - NSCoding
- (void)decodeActionData:(NSCoder *)decoder
{
	_folderName = [decoder decodeObjectOfClass:[NSString class] forKey:@"folderName"];
	_placeholderItem = [decoder decodeObjectOfClass:[OCItem class] forKey:@"placeholderItem"];
}

- (void)encodeActionData:(NSCoder *)coder
{
	[coder encodeObject:_folderName forKey:@"folderName"];
	[coder encodeObject:_placeholderItem forKey:@"placeholderItem"];
}

@end
