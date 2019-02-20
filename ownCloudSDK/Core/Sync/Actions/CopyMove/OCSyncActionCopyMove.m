//
//  OCSyncActionCopyMove.m
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

#import "OCSyncActionCopyMove.h"

@implementation OCSyncActionCopyMove

#pragma mark - Initializer
- (instancetype)initWithItem:(OCItem *)item action:(OCSyncActionIdentifier)actionIdentifier targetName:(NSString *)targetName targetParentItem:(OCItem *)targetParentItem isRename:(BOOL)isRename
{
	if ((self = [super initWithItem:item]) != nil)
	{
		self.identifier = actionIdentifier;

		self.targetName = targetName;
		self.targetParentItem = targetParentItem;

		self.isRename = isRename;

		if ([self.identifier isEqual:OCSyncActionIdentifierCopy])
		{
			self.actionEventType = OCEventTypeCopy;
			self.localizedDescription = [NSString stringWithFormat:OCLocalized(@"Copying %@ to %@…"), item.name, targetParentItem.name];
		}
		else if ([self.identifier isEqual:OCSyncActionIdentifierMove])
		{
			self.actionEventType = OCEventTypeMove;
			if ([item.parentFileID isEqualToString:targetParentItem.fileID])
			{
				self.localizedDescription = [NSString stringWithFormat:OCLocalized(@"Renaming %@ to %@…"), item.name, targetName];
			}
			else
			{
				self.localizedDescription = [NSString stringWithFormat:OCLocalized(@"Moving %@ to %@…"), item.name, targetParentItem.name];
			}
		}
	}

	return (self);
}

#pragma mark - Action implementation
- (void)preflightWithContext:(OCSyncContext *)syncContext
{
	if ((self.localItem != nil) && (self.targetParentItem != nil) && (self.targetName != nil))
	{
		// Perform pre-flight
		OCItem *sourceItem = self.localItem;
		OCPath targetPath = [self.targetParentItem.path stringByAppendingPathComponent:self.targetName];

		if (sourceItem.type == OCItemTypeCollection)
		{
			// Ensure directory paths end with a slash
			if (![targetPath hasSuffix:@"/"])
			{
				targetPath = [targetPath stringByAppendingString:@"/"];
			}
		}

		if ([self.identifier isEqual:OCSyncActionIdentifierCopy])
		{
			OCItem *placeholderItem = [OCItem placeholderItemOfType:sourceItem.type];

			// Copy filesystem metadata from existing item
			[placeholderItem copyFilesystemMetadataFrom:sourceItem];

			// Set path and parent folder
			placeholderItem.parentFileID = self.targetParentItem.fileID;
			placeholderItem.parentLocalID = self.targetParentItem.localID;
			placeholderItem.path = targetPath;

			// Copy actual file if it exists locally
			if (sourceItem.localRelativePath != nil)
			{
				NSError *error;
				NSURL *sourceURL, *destinationURL;

				if ((error = [self.core createDirectoryForItem:placeholderItem]) != nil)
				{
					syncContext.error = error;
					return;
				}

				sourceURL = [self.core localURLForItem:sourceItem];
				destinationURL = [self.core localURLForItem:placeholderItem];

				if ((sourceURL != nil) && (destinationURL != nil))
				{
					// Copy file
					if (![[NSFileManager defaultManager] copyItemAtURL:sourceURL toURL:destinationURL error:&error])
					{
						// Return error if it fails
						syncContext.error = error;

						// Clean up
						error = [self.core deleteDirectoryForItem:placeholderItem];
						return;
					}
				}
				else
				{
					// Something went awfully wrong internally
					syncContext.error = OCError(OCErrorInternal);
					return;
				}
			}

			// Add sync record to placeholder
			[placeholderItem addSyncRecordID:syncContext.syncRecord.recordID activity:OCItemSyncActivityCreating];

			// Save to processingItem
			self.processingItem = placeholderItem;

			// Add placeholder
			syncContext.addedItems = @[ placeholderItem ];
		}
		else if ([self.identifier isEqual:OCSyncActionIdentifierMove])
		{
			OCItem *updatedItem;

			// Add sync record reference to source item
			[sourceItem addSyncRecordID:syncContext.syncRecord.recordID activity:OCItemSyncActivityUpdating];

			// Make a copy
			updatedItem = [sourceItem copy];

			// Provide previous path for correct query updates
			updatedItem.previousPath = sourceItem.path;

			// Update location info
			updatedItem.parentLocalID = self.targetParentItem.localID;
			updatedItem.parentFileID = self.targetParentItem.fileID;
			updatedItem.path = targetPath;

			// Save to processingItem
			self.processingItem = updatedItem;

			// Update
			syncContext.updatedItems = @[ updatedItem ];
		}

		syncContext.updateStoredSyncRecordAfterItemUpdates = YES; // Update syncRecord, so the updated placeHolderItem (now with databaseID) will be stored in the database and can later be used to remove the placeHolderItem again.
	}
	else
	{
		// Return error to remove record as its action is not sufficiently specified
		syncContext.error = OCError(OCErrorInsufficientParameters);
	}
}

- (OCCoreSyncInstruction)scheduleWithContext:(OCSyncContext *)syncContext
{
	OCProgress *progress;

	if ([self.identifier isEqual:OCSyncActionIdentifierCopy])
	{
		progress = [self.core.connection copyItem:self.localItem to:self.targetParentItem withName:self.targetName options:nil resultTarget:[self.core _eventTargetWithSyncRecord:syncContext.syncRecord]];
	}
	else if ([self.identifier isEqual:OCSyncActionIdentifierMove])
	{
		progress = [self.core.connection moveItem:self.localItem to:self.targetParentItem withName:self.targetName options:nil resultTarget:[self.core _eventTargetWithSyncRecord:syncContext.syncRecord]];
	}

	if (progress != nil)
	{
		[syncContext.syncRecord addProgress:progress];
	}

	// Transition to processing
	[syncContext transitionToState:OCSyncRecordStateProcessing withWaitConditions:nil];

	// Wait for result
	return (OCCoreSyncInstructionStop);
}

- (void)descheduleWithContext:(OCSyncContext *)syncContext
{
	if (self.processingItem != nil)
	{
		OCItem *sourceItem = self.localItem;

		if ([self.identifier isEqual:OCSyncActionIdentifierCopy])
		{
			OCItem *placeholderItem = self.processingItem;

			// Remove sync record reference from placeholder item
			[placeholderItem removeSyncRecordID:syncContext.syncRecord.recordID activity:OCItemSyncActivityCreating];

			syncContext.removedItems = @[ placeholderItem ];

			[self.core deleteDirectoryForItem:placeholderItem];
		}
		else if ([self.identifier isEqual:OCSyncActionIdentifierMove])
		{
			OCItem *updatedItem = self.processingItem;

			// Remove sync record reference from source item
			[sourceItem removeSyncRecordID:syncContext.syncRecord.recordID activity:OCItemSyncActivityUpdating];

			sourceItem.previousPath = updatedItem.path;

			syncContext.updatedItems = @[ sourceItem ];
		}
	}
}

- (OCCoreSyncInstruction)handleResultWithContext:(OCSyncContext *)syncContext
{
	OCEvent *event = syncContext.event;
	OCSyncRecord *syncRecord = syncContext.syncRecord;
	OCCoreSyncInstruction resultInstruction = OCCoreSyncInstructionNone;
	BOOL isCopy = [syncContext.syncRecord.actionIdentifier isEqual:OCSyncActionIdentifierCopy];

	if ((event.error == nil) && (event.result != nil))
	{
		OCItem *sourceItem = self.localItem;
		OCItem *resultItem = nil;

		if (isCopy)
		{
			OCItem *placeholderItem;
			OCItem *newItem = OCTypedCast(event.result, OCItem);

			if ((placeholderItem = self.processingItem) != nil)
			{
				[placeholderItem removeSyncRecordID:syncContext.syncRecord.recordID activity:OCItemSyncActivityCreating];

				[newItem prepareToReplace:placeholderItem];

				newItem.previousPlaceholderFileID = placeholderItem.fileID;

				[self.core renameDirectoryFromItem:sourceItem forItem:newItem adjustLocalMetadata:YES];

				syncContext.updatedItems = @[ newItem ];
			}
			else
			{
				syncContext.addedItems = @[ newItem ];
			}

			resultItem = newItem;
		}
		else
		{
			OCItem *updatedItem = OCTypedCast(event.result, OCItem);
			OCFileID updatedParentLocalID = updatedItem.parentLocalID;

			[sourceItem removeSyncRecordID:syncContext.syncRecord.recordID activity:OCItemSyncActivityUpdating];

			[updatedItem prepareToReplace:self.localItem];
			updatedItem.parentLocalID = updatedParentLocalID;

			[self.core renameDirectoryFromItem:self.localItem forItem:updatedItem adjustLocalMetadata:YES];

			updatedItem.previousPath = self.localItem.path; // Indicate this item has been moved (to allow efficient handling of relocations to another parent directory)

			syncContext.updatedItems = @[ updatedItem ];

			resultItem = updatedItem;
		}

		// Action complete
		[syncContext completeWithError:event.error core:self.core item:resultItem parameter:nil];

		[syncContext transitionToState:OCSyncRecordStateCompleted withWaitConditions:nil];
		resultInstruction = OCCoreSyncInstructionDeleteLast;
	}
	else if (event.error.isOCError)
	{
		NSString *issueTitle=nil, *issueDescription=nil;
		OCPath targetPath;

	    	targetPath = [self.targetParentItem.path stringByAppendingString:self.targetName];

		switch (event.error.code)
		{
			case OCErrorItemOperationForbidden:
				issueTitle = OCLocalizedString(@"Operation forbidden",nil);
				if (isCopy)
				{
					issueDescription = [NSString stringWithFormat:OCLocalizedString(@"%@ can't be copied to %@.",nil), self.localItem.path, targetPath];
				}
				else
				{
					if (self.isRename)
					{
						issueDescription = [NSString stringWithFormat:OCLocalizedString(@"%@ couldn't be renamed to %@.",nil), self.localItem.name, self.targetName];
					}
					else
					{
						issueDescription = [NSString stringWithFormat:OCLocalizedString(@"%@ can't be moved to %@.",nil), self.localItem.path, targetPath];
					}
				}
			break;

			case OCErrorItemNotFound:
				issueTitle = [NSString stringWithFormat:OCLocalizedString(@"%@ not found",nil), self.localItem.name];
				issueDescription = [NSString stringWithFormat:OCLocalizedString(@"%@ wasn't found at %@.",nil), self.localItem.name, [self.localItem.path stringByDeletingLastPathComponent]];
			break;

			case OCErrorItemDestinationNotFound:
				issueTitle = [NSString stringWithFormat:OCLocalizedString(@"%@ not found",nil), [[targetPath stringByDeletingLastPathComponent] lastPathComponent]];
				issueDescription = [NSString stringWithFormat:OCLocalizedString(@"The target directory %@ doesn't seem to exist.",nil), [targetPath stringByDeletingLastPathComponent]];
			break;

			case OCErrorItemAlreadyExists:
				issueTitle = [NSString stringWithFormat:OCLocalizedString(@"%@ already exists",nil), self.targetName];
				if (isCopy)
				{
					issueDescription = [NSString stringWithFormat:OCLocalizedString(@"Couldn't copy %@ to %@, because an item called %@ already exists there.",nil), self.localItem.name, targetPath, self.targetName];
				}
				else
				{
					if (self.isRename)
					{
						issueDescription = [NSString stringWithFormat:OCLocalizedString(@"Couldn't rename %@ to %@, because another item with that name already exists.",nil), self.localItem.name, self.targetName];
					}
					else
					{
						issueDescription = [NSString stringWithFormat:OCLocalizedString(@"Couldn't move %@ to %@, because an item called %@ already exists there.",nil), self.localItem.name, targetPath, self.targetName];
					}
				}
			break;

			case OCErrorItemInsufficientPermissions:
				issueTitle = OCLocalizedString(@"Insufficient permissions",nil);
				if (isCopy)
				{
					issueDescription = [NSString stringWithFormat:OCLocalizedString(@"%@ can't be copied to %@.",nil), self.localItem.path, targetPath];
				}
				else
				{
					if (self.isRename)
					{
						issueDescription = [NSString stringWithFormat:OCLocalizedString(@"%@ couldn't be renamed to %@.",nil), self.localItem.name, self.targetName];
					}
					else
					{
						issueDescription = [NSString stringWithFormat:OCLocalizedString(@"%@ can't be moved to %@.",nil), self.localItem.path, targetPath];
					}
				}
			break;

			default:
				if (isCopy)
				{
					issueTitle = [NSString stringWithFormat:OCLocalizedString(@"Error copying %@",nil), self.localItem.path];
				}
				else
				{
					if (self.isRename)
					{
						issueTitle = [NSString stringWithFormat:OCLocalizedString(@"Error renaming %@",nil), self.localItem.name];
					}
					else
					{
						issueTitle = [NSString stringWithFormat:OCLocalizedString(@"Error moving %@",nil), self.localItem.path];
					}
				}
				issueDescription = event.error.localizedDescription;
			break;
		}

		// Action complete
		[syncContext completeWithError:event.error core:self.core item:nil parameter:nil];

		if ((issueTitle!=nil) && (issueDescription!=nil))
		{
			// Create issue for cancellation for any errors
			[self.core _addIssueForCancellationAndDeschedulingToContext:syncContext title:issueTitle description:issueDescription impact:OCSyncIssueChoiceImpactNonDestructive]; // queues a new wait condition with the issue
			[syncContext transitionToState:OCSyncRecordStateProcessing withWaitConditions:nil]; // updates the sync record with the issue wait condition
		}
	}
	else if (event.error != nil)
	{
		// Reschedule for all other errors
		[self.core rescheduleSyncRecord:syncRecord withUpdates:nil];
		resultInstruction = OCCoreSyncInstructionStop;

		// Action complete
		[syncContext completeWithError:event.error core:self.core item:nil parameter:nil];
	}

	return (resultInstruction);
}

#pragma mark - NSCoding
- (void)decodeActionData:(NSCoder *)decoder
{
	_targetName = [decoder decodeObjectOfClass:[NSString class] forKey:@"targetName"];
	_targetParentItem = [decoder decodeObjectOfClass:[OCItem class] forKey:@"targetParentItem"];

	_processingItem = [decoder decodeObjectOfClass:[OCItem class] forKey:@"processingItem"];

	_isRename = [decoder decodeBoolForKey:@"isRename"];
}

- (void)encodeActionData:(NSCoder *)coder
{
	[coder encodeObject:_targetName forKey:@"targetName"];
	[coder encodeObject:_targetParentItem forKey:@"targetParentItem"];

	[coder encodeObject:_processingItem forKey:@"processingItem"];

	[coder encodeBool:_isRename forKey:@"isRename"];
}

@end
