//
//  OCCore+CommandCreateFolder.m
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

@implementation OCCore (CommandCreateFolder)

#pragma mark - Command
- (NSProgress *)createFolder:(NSString *)folderName inside:(OCItem *)parentItem options:(NSDictionary *)options resultHandler:(OCCoreActionResultHandler)resultHandler
{
	if (folderName == nil) { return(nil); }
	if (parentItem == nil) { return(nil); }

	return ([self _enqueueSyncRecordWithAction:OCSyncActionCreateFolder forItem:nil allowNilItem:YES parameters:@{
			OCSyncActionParameterParentItem : parentItem,
			OCSyncActionParameterPath : folderName
		} resultHandler:resultHandler]);
}

#pragma mark - Sync Action Registration
- (void)registerCreateFolder
{
	[self registerSyncRoute:[OCCoreSyncRoute routeWithScheduler:^BOOL(OCCore *core, OCCoreSyncContext *syncContext) {
		return ([core scheduleCreateFolderWithSyncContext:syncContext]);
	} resultHandler:^BOOL(OCCore *core, OCCoreSyncContext *syncContext) {
		return ([core handleCreateFolderWithSyncContext:syncContext]);
	}] forAction:OCSyncActionCreateFolder];
}

#pragma mark - Sync
- (BOOL)scheduleCreateFolderWithSyncContext:(OCCoreSyncContext *)syncContext
{
	OCPath folderName;
	OCItem *parentItem;

	if (((folderName = syncContext.syncRecord.parameters[OCSyncActionParameterPath]) != nil) &&
	    ((parentItem = syncContext.syncRecord.parameters[OCSyncActionParameterParentItem]) != nil))
	{
		NSProgress *progress;

		if ((progress = [self.connection createFolder:folderName inside:parentItem options:nil resultTarget:[self _eventTargetWithSyncRecord:syncContext.syncRecord]]) != nil)
		{
			syncContext.syncRecord.progress = progress;

			return (YES);
		}
	}

	return (NO);
}

- (BOOL)handleCreateFolderWithSyncContext:(OCCoreSyncContext *)syncContext
{
	OCEvent *event = syncContext.event;
	OCSyncRecord *syncRecord = syncContext.syncRecord;
	BOOL canDeleteSyncRecord = NO;

	if (syncRecord.resultHandler != nil)
	{
		syncRecord.resultHandler(event.error, self, (OCItem *)event.result, nil);
	}

	if ((event.error == nil) && (event.result != nil))
	{
		syncContext.addedItems = @[ event.result ];

		canDeleteSyncRecord = YES;
	}
	else if (event.error != nil)
	{
		// Create issue for cancellation for any errors
		[self _addIssueForCancellationAndDeschedulingToContext:syncContext title:[NSString stringWithFormat:OCLocalizedString(@"Couldn't create %@", nil), syncContext.syncRecord.item.name] description:[event.error localizedDescription]];
	}

	return (canDeleteSyncRecord);
}

@end
