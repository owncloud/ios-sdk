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
- (OCCoreSyncInstruction)scheduleWithContext:(OCSyncContext *)syncContext
{
	if ((self.localItem != nil) && (self.targetParentItem != nil) && (self.targetName != nil))
	{
		NSProgress *progress;

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

	// Remove record as its action is not sufficiently specified
	return (OCCoreSyncInstructionDeleteLast);
}

- (OCCoreSyncInstruction)handleResultWithContext:(OCSyncContext *)syncContext
{
	OCEvent *event = syncContext.event;
	OCSyncRecord *syncRecord = syncContext.syncRecord;
	OCCoreSyncInstruction resultInstruction = OCCoreSyncInstructionNone;
	BOOL isCopy = [syncContext.syncRecord.actionIdentifier isEqual:OCSyncActionIdentifierCopy];

	[syncContext completeWithError:event.error core:self.core item:(OCItem *)event.result parameter:nil];

	if ((event.error == nil) && (event.result != nil))
	{
		if (isCopy)
		{
			syncContext.addedItems = @[ event.result ];
		}
		else
		{
			if (self.localItem!=nil)
			{
				OCItem *resultItem = event.result;

				[resultItem prepareToReplace:self.localItem];

				resultItem.locallyModified = self.localItem.locallyModified;
				resultItem.localRelativePath = self.localItem.localRelativePath;
				resultItem.localCopyVersionIdentifier = self.localItem.localCopyVersionIdentifier;

				resultItem.previousPath = self.localItem.path; // Indicate this item has been moved (to allow efficient handling of relocations to another parent directory)

				syncContext.updatedItems = @[ resultItem ];
			}
		}

		// Action complete and can be removed
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
	}

	return (resultInstruction);
}

#pragma mark - NSCoding
- (void)decodeActionData:(NSCoder *)decoder
{
	_targetName = [decoder decodeObjectOfClass:[NSString class] forKey:@"targetName"];
	_targetParentItem = [decoder decodeObjectOfClass:[OCItem class] forKey:@"targetParentItem"];

	_isRename = [decoder decodeBoolForKey:@"isRename"];
}

- (void)encodeActionData:(NSCoder *)coder
{
	[coder encodeObject:_targetName forKey:@"targetName"];
	[coder encodeObject:_targetParentItem forKey:@"targetParentItem"];

	[coder encodeBool:_isRename forKey:@"isRename"];
}

@end
