//
//  OCSyncActionDelete.m
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

#import "OCSyncActionDelete.h"

@implementation OCSyncActionDelete

#pragma mark - Initializer
- (instancetype)initWithItem:(OCItem *)item requireMatch:(BOOL)requireMatch
{
	if ((self = [super initWithItem:item]) != nil)
	{
		self.identifier = OCSyncActionIdentifierDeleteLocal;

		self.requireMatch = requireMatch;

		self.actionEventType = OCEventTypeDelete;
		self.localizedDescription = [NSString stringWithFormat:OCLocalized(@"Deleting %@…"), item.name];
	}

	return (self);
}

#pragma mark - Action implementation
- (void)preflightWithContext:(OCSyncContext *)syncContext
{
	OCItem *itemToDelete;

	if ((itemToDelete = self.localItem) != nil)
	{
		[itemToDelete addSyncRecordID:syncContext.syncRecord.recordID activity:OCItemSyncActivityDeleting];

		syncContext.removedItems = @[ itemToDelete ];
	}
}

- (void)descheduleWithContext:(OCSyncContext *)syncContext
{
	OCItem *itemToRestore;

	if ((itemToRestore = self.localItem) != nil)
	{
		[itemToRestore removeSyncRecordID:syncContext.syncRecord.recordID activity:OCItemSyncActivityDeleting];

		itemToRestore.removed = NO;

		syncContext.updatedItems = @[ itemToRestore ];
	}
}

- (OCCoreSyncInstruction)scheduleWithContext:(OCSyncContext *)syncContext
{
	OCItem *item;

	if ((item = self.archivedServerItem) != nil)
	{
		OCProgress *progress;

		if ((progress = [self.core.connection deleteItem:item requireMatch:self.requireMatch resultTarget:[self.core _eventTargetWithSyncRecord:syncContext.syncRecord]]) != nil)
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

- (NSError *)resolveIssue:(OCSyncIssue *)issue withChoice:(OCSyncIssueChoice *)choice context:(OCSyncContext *)syncContext
{
	NSError *resolutionError = nil;

	if ((resolutionError = [super resolveIssue:issue withChoice:choice context:syncContext]) != nil)
	{
		if (![resolutionError isOCErrorWithCode:OCErrorFeatureNotImplemented])
		{
			return (resolutionError);
		}

		if ([choice.identifier isEqual:@"forceDelete"])
		{
			// Reschedule sync record with match requirement turned off
			[self.core rescheduleSyncRecord:syncContext.syncRecord withUpdates:^NSError *(OCSyncRecord *record) {
				self.requireMatch = NO;

				return (nil);
			}];

			resolutionError = nil;
		}
	}

	return (resolutionError);
}

- (OCCoreSyncInstruction)handleResultWithContext:(OCSyncContext *)syncContext
{
	OCEvent *event = syncContext.event;
	OCSyncRecord *syncRecord = syncContext.syncRecord;
	OCCoreSyncInstruction resultInstruction = OCCoreSyncInstructionNone;

	[syncContext completeWithError:event.error core:self.core item:self.localItem parameter:event.result];

	if ((event.error == nil) && (event.result != nil))
	{
		[self.localItem removeSyncRecordID:syncContext.syncRecord.recordID activity:OCItemSyncActivityDeleting];
		syncContext.removedItems = @[ self.localItem ];

		// Remove file locally
		[self.core deleteDirectoryForItem:self.localItem];

		// Action complete and can be removed
		[syncContext transitionToState:OCSyncRecordStateCompleted withWaitConditions:nil];
		resultInstruction = OCCoreSyncInstructionDeleteLast;
	}
	else if (event.error.isOCError)
	{
		OCSyncIssue *issue = nil;
		NSString *title=nil, *description=nil;

		switch (event.error.code)
		{
			case OCErrorItemChanged:
			{
				// The item that was supposed to be deleted changed on the server => prompt user
				NSString *title = [NSString stringWithFormat:OCLocalizedString(@"%@ changed on the server. Really delete it?",nil), self.localItem.name];
				NSString *description = [NSString stringWithFormat:OCLocalizedString(@"%@ has changed on the server since you requested its deletion.",nil), self.localItem.name];

				issue = [OCSyncIssue issueForSyncRecord:syncRecord level:OCIssueLevelError title:title description:description metaData:nil choices:@[
						// Drop sync record
						[OCSyncIssueChoice cancelChoiceWithImpact:OCSyncIssueChoiceImpactNonDestructive],

						// Reschedule sync record with match requirement turned off
						[OCSyncIssueChoice choiceOfType:OCIssueChoiceTypeDestructive impact:OCSyncIssueChoiceImpactDataLoss identifier:@"forceDelete" label:OCLocalizedString(@"Delete",@"") metaData:nil]
					]];
			}
			break;

			case OCErrorItemOperationForbidden:
				// The item that was supposed to be deleted changed on the server => prompt user
				title = [NSString stringWithFormat:OCLocalizedString(@"%@ couldn't be deleted",nil), self.localItem.path.lastPathComponent];
				description = [NSString stringWithFormat:OCLocalizedString(@"Please check if you have sufficient permissions to delete %@.",nil), self.localItem.path.lastPathComponent];
			break;

			case OCErrorItemNotFound:
				// The item that was supposed to be deleted could not be found on the server (may already have been deleted)

				// => remove item
				[self.localItem removeSyncRecordID:syncContext.syncRecord.recordID activity:OCItemSyncActivityDeleting];
				syncContext.removedItems = @[ self.localItem ];

				// => also fetch an update of the containing dir, as the missing file could also just have been moved / renamed
				{
					NSString *parentPath = self.localItem.path.parentPath;

					if (parentPath != nil)
					{
						syncContext.refreshPaths = @[ parentPath ];
					}
				}

				OCLogDebug(@"%@ not found on the server, %@ may have been renamed, moved or deleted remotely", self.localItem.path.lastPathComponent, self.localItem.path.lastPathComponent);

				// Remove file locally
				[self.core deleteDirectoryForItem:self.localItem];

				// Action complete and can be removed
				[syncContext transitionToState:OCSyncRecordStateCompleted withWaitConditions:nil];
				resultInstruction = OCCoreSyncInstructionDeleteLast;
			break;

			default:
				// Create issue for cancellation for any other errors
				title = [NSString stringWithFormat:OCLocalizedString(@"Error deleting %@", nil), self.localItem.name];
				description = event.error.localizedDescription;
			break;
		}

		if ((issue==nil) && (title!=nil))
		{
			issue = [OCSyncIssue issueForSyncRecord:syncRecord level:OCIssueLevelError title:title description:description metaData:nil choices:@[
					// Drop sync record
					[OCSyncIssueChoice cancelChoiceWithImpact:OCSyncIssueChoiceImpactNonDestructive],
				]];
		}

		if (issue != nil)
		{
			[syncContext addSyncIssue:issue];
			[syncContext transitionToState:OCSyncRecordStateProcessing withWaitConditions:nil]; // updates the sync record with the issue wait condition
		}
	}
	else if (event.error != nil)
	{
		// Create issue for cancellation for all other errors
		[self.core _addIssueForCancellationAndDeschedulingToContext:syncContext title:[NSString stringWithFormat:OCLocalizedString(@"Couldn't delete %@", nil), self.localItem.name] description:[event.error localizedDescription] impact:OCSyncIssueChoiceImpactDataLoss]; // queues a new wait condition with the issue
		[syncContext transitionToState:OCSyncRecordStateProcessing withWaitConditions:nil]; // updates the sync record with the issue wait condition

		// Reschedule for all other errors
		/*
			// TODO: Return issue for unknown errors (other than instead of blindly rescheduling)

			https://demo.owncloud.org/remote.php/dav/files/demo/Photos/: didCompleteWithError=Error Domain=NSURLErrorDomain Code=-1009 "The Internet connection appears to be offline." UserInfo={NSUnderlyingError=0x1c4653470 {Error Domain=kCFErrorDomainCFNetwork Code=-1009 "(null)" UserInfo={_kCFStreamErrorCodeKey=50, _kCFStreamErrorDomainKey=1}}, NSErrorFailingURLStringKey=https://demo.owncloud.org/remote.php/dav/files/demo/Photos/, NSErrorFailingURLKey=https://demo.owncloud.org/remote.php/dav/files/demo/Photos/, _kCFStreamErrorDomainKey=1, _kCFStreamErrorCodeKey=50, NSLocalizedDescription=The Internet connection appears to be offline.} [OCConnectionQueue.m:506|FULL]
		*/
		// [self.core rescheduleSyncRecord:syncRecord withUpdates:nil];
	}

	return (resultInstruction);
}

#pragma mark - Lane tags
- (NSSet<OCSyncLaneTag> *)generateLaneTags
{
	return ([self generateLaneTagsFromItems:@[
		OCSyncActionWrapNullableItem(self.localItem)
	]]);
}

#pragma mark - NSCoding
- (void)decodeActionData:(NSCoder *)decoder
{
	_requireMatch = [decoder decodeBoolForKey:@"requireMatch"];
}

- (void)encodeActionData:(NSCoder *)coder
{
	[coder encodeBool:_requireMatch forKey:@"requireMatch"];
}

@end
