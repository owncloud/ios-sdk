//
//  OCCore+CommandDelete.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 16.06.18.
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

#import "OCCore.h"
#import "OCCore+SyncEngine.h"
#import "OCCoreSyncContext.h"
#import "NSError+OCError.h"
#import "OCMacros.h"
#import "NSString+OCParentPath.h"

@implementation OCCore (CommandDelete)

#pragma mark - Command
- (NSProgress *)deleteItem:(OCItem *)item requireMatch:(BOOL)requireMatch resultHandler:(OCCoreActionResultHandler)resultHandler
{
	return ([self _enqueueSyncRecordWithAction:OCSyncActionDeleteLocal forItem:item allowNilItem:NO parameters:@{
			OCSyncActionParameterItem : item,
			OCSyncActionParameterPath : item.path,
			OCSyncActionParameterRequireMatch : @(requireMatch),
		} resultHandler:resultHandler]);
}

#pragma mark - Sync Action Registration
- (void)registerDeleteLocal
{
	[self registerSyncRoute:[OCCoreSyncRoute routeWithScheduler:^BOOL(OCCore *core, OCCoreSyncContext *syncContext) {
		return ([core scheduleDeleteLocalWithSyncContext:syncContext]);
	} resultHandler:^BOOL(OCCore *core, OCCoreSyncContext *syncContext) {
		return ([core handleDeleteLocalWithSyncContext:syncContext]);
	}] forAction:OCSyncActionDeleteLocal];
}

#pragma mark - Sync
- (BOOL)scheduleDeleteLocalWithSyncContext:(OCCoreSyncContext *)syncContext
{
	OCItem *item;

	if ((item = syncContext.syncRecord.archivedServerItem) != nil)
	{
		NSProgress *progress;

		if ((progress = [self.connection deleteItem:item requireMatch:((NSNumber *)syncContext.syncRecord.parameters[OCSyncActionParameterRequireMatch]).boolValue resultTarget:[self _eventTargetWithSyncRecord:syncContext.syncRecord]]) != nil)
		{
			syncContext.syncRecord.progress = progress;

			return (YES);
		}
	}

	return (NO);
}

- (BOOL)handleDeleteLocalWithSyncContext:(OCCoreSyncContext *)syncContext
{
	OCEvent *event = syncContext.event;
	OCSyncRecord *syncRecord = syncContext.syncRecord;
	BOOL canDeleteSyncRecord = NO;

	if (syncRecord.resultHandler != nil)
	{
		syncRecord.resultHandler(event.error, self, syncRecord.item, event.result);
	}

	if ((event.error == nil) && (event.result != nil))
	{
		syncContext.removedItems = @[ syncRecord.item ];

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
				NSString *title = [NSString stringWithFormat:OCLocalizedString(@"%@ changed on the server. Really delete it?",nil), syncRecord.itemPath.lastPathComponent];
				NSString *description = [NSString stringWithFormat:OCLocalizedString(@"%@ has changed on the server since you requested its deletion.",nil), syncRecord.itemPath.lastPathComponent];

				syncRecord.allowsRescheduling = YES;

				issue =	[OCConnectionIssue issueForMultipleChoicesWithLocalizedTitle:title localizedDescription:description choices:@[

						[OCConnectionIssueChoice choiceWithType:OCConnectionIssueChoiceTypeCancel label:nil handler:^(OCConnectionIssue *issue, OCConnectionIssueChoice *choice) {
							// Drop sync record
							[self descheduleSyncRecord:syncRecord];
						}],

						[OCConnectionIssueChoice choiceWithType:OCConnectionIssueChoiceTypeDestructive label:OCLocalizedString(@"Delete",@"") handler:^(OCConnectionIssue *issue, OCConnectionIssueChoice *choice) {
							// Reschedule sync record with match requirement turned off
							[self rescheduleSyncRecord:syncRecord withUpdates:^NSError *(OCSyncRecord *record) {
								NSMutableDictionary<OCSyncActionParameter, id> *parameters = [record.parameters mutableCopy];

								parameters[OCSyncActionParameterRequireMatch] = @(NO);

								record.parameters = parameters;

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
				NSString *title = [NSString stringWithFormat:OCLocalizedString(@"%@ couldn't be deleted",nil), syncRecord.itemPath.lastPathComponent];
				NSString *description = [NSString stringWithFormat:OCLocalizedString(@"Please check if you have sufficient permissions to delete %@.",nil), syncRecord.itemPath.lastPathComponent];

				issue =	[OCConnectionIssue issueForMultipleChoicesWithLocalizedTitle:title localizedDescription:description choices:@[

						[OCConnectionIssueChoice choiceWithType:OCConnectionIssueChoiceTypeCancel label:nil handler:^(OCConnectionIssue *issue, OCConnectionIssueChoice *choice) {
							// Drop sync record
							[self descheduleSyncRecord:syncRecord];
						}],

					] completionHandler:nil];

				[syncContext addIssue:issue];

				canDeleteSyncRecord = YES;
			}
			break;

			case OCErrorItemNotFound:
				// The item that was supposed to be deleted could not be found on the server

				// => remove item
				syncContext.removedItems = @[ syncRecord.item ];

				// => also fetch an update of the containing dir, as the missing file could also just have been moved / renamed
				if (syncRecord.itemPath.parentPath != nil)
				{
					syncContext.refreshPaths = @[ syncRecord.itemPath.parentPath ];
				}

				// => inform the user
				{
					OCConnectionIssue *issue;

					NSString *title = [NSString stringWithFormat:OCLocalizedString(@"%@ not found on the server",nil), syncRecord.itemPath.lastPathComponent];
					NSString *description = [NSString stringWithFormat:OCLocalizedString(@"%@ may have been renamed, moved or deleted remotely.",nil), syncRecord.itemPath.lastPathComponent];

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
		[self _addIssueForCancellationAndDeschedulingToContext:syncContext title:[NSString stringWithFormat:OCLocalizedString(@"Couldn't create %@", nil), syncContext.syncRecord.item.name] description:[event.error localizedDescription]];

		// Reschedule for all other errors
		/*
			// TODO: Return issue for unknown errors (other than instead of blindly rescheduling

			https://demo.owncloud.org/remote.php/dav/files/demo/Photos/: didCompleteWithError=Error Domain=NSURLErrorDomain Code=-1009 "The Internet connection appears to be offline." UserInfo={NSUnderlyingError=0x1c4653470 {Error Domain=kCFErrorDomainCFNetwork Code=-1009 "(null)" UserInfo={_kCFStreamErrorCodeKey=50, _kCFStreamErrorDomainKey=1}}, NSErrorFailingURLStringKey=https://demo.owncloud.org/remote.php/dav/files/demo/Photos/, NSErrorFailingURLKey=https://demo.owncloud.org/remote.php/dav/files/demo/Photos/, _kCFStreamErrorDomainKey=1, _kCFStreamErrorCodeKey=50, NSLocalizedDescription=The Internet connection appears to be offline.} [OCConnectionQueue.m:506|FULL]
		*/
		[self rescheduleSyncRecord:syncRecord withUpdates:nil];
	}

	return (canDeleteSyncRecord);
}

@end
