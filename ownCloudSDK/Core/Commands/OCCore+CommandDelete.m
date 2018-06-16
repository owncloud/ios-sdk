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
#import "OCCoreSyncParameterSet.h"
#import "NSError+OCError.h"
#import "OCMacros.h"

@implementation OCCore (CommandDelete)

#pragma mark - Command
- (NSProgress *)deleteItem:(OCItem *)item requireMatch:(BOOL)requireMatch resultHandler:(OCCoreActionResultHandler)resultHandler
{
	return ([self _enqueueSyncRecordWithAction:OCSyncActionDeleteLocal forItem:item parameters:@{
			OCSyncActionParameterItem : item,
			OCSyncActionParameterPath : item.path,
			OCSyncActionParameterRequireMatch : @(requireMatch),
		} resultHandler:resultHandler]);
}

#pragma mark - Sync Action Registration
- (void)registerDeleteLocal
{
	// Delete Local
	[self registerSyncRoute:[OCCoreSyncRoute routeWithScheduler:^BOOL(OCCore *core, OCCoreSyncParameterSet *syncParameterSet) {
		return ([core scheduleDeleteLocalForParameterSet:syncParameterSet]);
	} resultHandler:^BOOL(OCCore *core, OCCoreSyncParameterSet *syncParameterSet) {
		return ([core handleDeleteLocalForParameterSet:syncParameterSet]);
	}] forAction:OCSyncActionDeleteLocal];
}

#pragma mark - Sync
- (BOOL)scheduleDeleteLocalForParameterSet:(OCCoreSyncParameterSet *)syncParams
{
	OCItem *item;

	if ((item = syncParams.syncRecord.archivedServerItem) != nil)
	{
		NSProgress *progress;

		if ((progress = [self.connection deleteItem:item requireMatch:((NSNumber *)syncParams.syncRecord.parameters[OCSyncActionParameterRequireMatch]).boolValue resultTarget:[self _eventTargetWithSyncRecord:syncParams.syncRecord]]) != nil)
		{
			syncParams.syncRecord.progress = progress;

			return (YES);
		}
	}

	return (NO);
}

- (BOOL)handleDeleteLocalForParameterSet:(OCCoreSyncParameterSet *)syncParams
{
	OCEvent *event = syncParams.event;
	OCSyncRecord *syncRecord = syncParams.syncRecord;
	BOOL canDeleteSyncRecord = NO;

	if (syncRecord.resultHandler != nil)
	{
		syncRecord.resultHandler(event.error, self, syncRecord.item, event.result);
	}

	if ((event.error == nil) && (event.result != nil))
	{
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

				[syncParams addIssue:issue];
			}
			break;

			case OCErrorItemNotFound:
				// The item that was supposed to be deleted could not be found => not a problem, really
				canDeleteSyncRecord = YES;
			break;

			default:
			break;
		}
	}

	return (canDeleteSyncRecord);
}

@end
