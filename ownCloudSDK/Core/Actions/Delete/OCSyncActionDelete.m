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

- (instancetype)initWithItem:(OCItem *)item requireMatch:(BOOL)requireMatch
{
	if ((self = [super initWithItem:item]) != nil)
	{
		self.identifier = OCSyncActionIdentifierDeleteLocal;

		self.requireMatch = requireMatch;
	}

	return (self);
}

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

- (BOOL)scheduleWithContext:(OCSyncContext *)syncContext
{
	OCItem *item;

	if ((item = self.archivedServerItem) != nil)
	{
		NSProgress *progress;

		if ((progress = [self.core.connection deleteItem:item requireMatch:self.requireMatch resultTarget:[self.core _eventTargetWithSyncRecord:syncContext.syncRecord]]) != nil)
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
	BOOL canDeleteSyncRecord = NO;

	if (syncRecord.resultHandler != nil)
	{
		syncRecord.resultHandler(event.error, self.core, self.localItem, event.result);
	}

	if ((event.error == nil) && (event.result != nil))
	{
		[self.localItem removeSyncRecordID:syncContext.syncRecord.recordID activity:OCItemSyncActivityDeleting];
		syncContext.removedItems = @[ self.localItem ];

		canDeleteSyncRecord = YES;
	}
	else if (event.error.isOCError)
	{
		switch (event.error.code)
		{
			case OCErrorItemChanged:
			{
				// The item that was supposed to be deleted changed on the server => prompt user
				OCConnectionIssue *issue;
				NSString *title = [NSString stringWithFormat:OCLocalizedString(@"%@ changed on the server. Really delete it?",nil), self.localItem.name];
				NSString *description = [NSString stringWithFormat:OCLocalizedString(@"%@ has changed on the server since you requested its deletion.",nil), self.localItem.name];

				syncRecord.allowsRescheduling = YES;

				issue =	[OCConnectionIssue issueForMultipleChoicesWithLocalizedTitle:title localizedDescription:description choices:@[

						[OCConnectionIssueChoice choiceWithType:OCConnectionIssueChoiceTypeCancel label:nil handler:^(OCConnectionIssue *issue, OCConnectionIssueChoice *choice) {
							// Drop sync record
							[self.core descheduleSyncRecord:syncRecord invokeResultHandler:YES resultHandlerError:OCError(OCErrorCancelled)];
						}],

						[OCConnectionIssueChoice choiceWithType:OCConnectionIssueChoiceTypeDestructive label:OCLocalizedString(@"Delete",@"") handler:^(OCConnectionIssue *issue, OCConnectionIssueChoice *choice) {
							// Reschedule sync record with match requirement turned off
							[self.core rescheduleSyncRecord:syncRecord withUpdates:^NSError *(OCSyncRecord *record) {
								self.requireMatch = NO;

								return (nil);
							}];
						}]

					] completionHandler:nil];

				[syncContext addIssue:issue];
			}
			break;

			case OCErrorItemOperationForbidden:
			{
				// The item that was supposed to be deleted changed on the server => prompt user
				OCConnectionIssue *issue;
				NSString *title = [NSString stringWithFormat:OCLocalizedString(@"%@ couldn't be deleted",nil), self.localItem.path.lastPathComponent];
				NSString *description = [NSString stringWithFormat:OCLocalizedString(@"Please check if you have sufficient permissions to delete %@.",nil), self.localItem.path.lastPathComponent];

				issue =	[OCConnectionIssue issueForMultipleChoicesWithLocalizedTitle:title localizedDescription:description choices:@[

						[OCConnectionIssueChoice choiceWithType:OCConnectionIssueChoiceTypeCancel label:nil handler:^(OCConnectionIssue *issue, OCConnectionIssueChoice *choice) {
							// Drop sync record
							[self.core descheduleSyncRecord:syncRecord invokeResultHandler:YES resultHandlerError:OCError(OCErrorCancelled)];
						}],

					] completionHandler:nil];

				[syncContext addIssue:issue];

				canDeleteSyncRecord = YES;
			}
			break;

			case OCErrorItemNotFound:
				// The item that was supposed to be deleted could not be found on the server

				// => remove item
				[self.localItem removeSyncRecordID:syncContext.syncRecord.recordID activity:OCItemSyncActivityDeleting];
				syncContext.removedItems = @[ self.localItem ];

				// => also fetch an update of the containing dir, as the missing file could also just have been moved / renamed
				if (self.localItem.path.parentPath != nil)
				{
					syncContext.refreshPaths = @[ self.localItem.path.parentPath ];
				}

				// => inform the user
				{
					OCConnectionIssue *issue;

					NSString *title = [NSString stringWithFormat:OCLocalizedString(@"%@ not found on the server",nil), self.localItem.path.lastPathComponent];
					NSString *description = [NSString stringWithFormat:OCLocalizedString(@"%@ may have been renamed, moved or deleted remotely.",nil), self.localItem.path.lastPathComponent];

					issue =	[OCConnectionIssue issueForMultipleChoicesWithLocalizedTitle:title localizedDescription:description choices:@[
							[OCConnectionIssueChoice choiceWithType:OCConnectionIssueChoiceTypeCancel label:nil handler:nil],
						] completionHandler:nil];

					[syncContext addIssue:issue];
				}

				canDeleteSyncRecord = YES;
			break;

			default:
			break;
		}
	}
	else if (event.error != nil)
	{
		// Create issue for cancellation for all other errors
		[self.core _addIssueForCancellationAndDeschedulingToContext:syncContext title:[NSString stringWithFormat:OCLocalizedString(@"Couldn't delete %@", nil), self.localItem.name] description:[event.error localizedDescription] invokeResultHandler:NO resultHandlerError:nil];

		// Reschedule for all other errors
		/*
			// TODO: Return issue for unknown errors (other than instead of blindly rescheduling

			https://demo.owncloud.org/remote.php/dav/files/demo/Photos/: didCompleteWithError=Error Domain=NSURLErrorDomain Code=-1009 "The Internet connection appears to be offline." UserInfo={NSUnderlyingError=0x1c4653470 {Error Domain=kCFErrorDomainCFNetwork Code=-1009 "(null)" UserInfo={_kCFStreamErrorCodeKey=50, _kCFStreamErrorDomainKey=1}}, NSErrorFailingURLStringKey=https://demo.owncloud.org/remote.php/dav/files/demo/Photos/, NSErrorFailingURLKey=https://demo.owncloud.org/remote.php/dav/files/demo/Photos/, _kCFStreamErrorDomainKey=1, _kCFStreamErrorCodeKey=50, NSLocalizedDescription=The Internet connection appears to be offline.} [OCConnectionQueue.m:506|FULL]
		*/
		[self.core rescheduleSyncRecord:syncRecord withUpdates:nil];
	}

	return (canDeleteSyncRecord);
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
