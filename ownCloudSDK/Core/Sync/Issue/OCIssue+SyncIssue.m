//
//  OCIssue+SyncIssue.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 20.12.18.
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

#import "OCIssue+SyncIssue.h"
#import "OCCore+SyncEngine.h"
#import "OCMessageQueue.h"
#import "OCMessage.h"

@implementation OCIssue (SyncIssue)

+ (instancetype)issueFromSyncIssue:(OCSyncIssue *)syncIssue resolutionResultHandler:(OCCoreSyncIssueResolutionResultHandler)resolutionResultHandler
{
	OCIssue *issue;
	NSMutableArray <OCIssueChoice *> *choices = [NSMutableArray new];

	for (OCSyncIssueChoice *syncChoice in syncIssue.choices)
	{
		OCIssueChoice *choice;

		if ((choice = [OCIssueChoice choiceWithType:syncChoice.type label:syncChoice.label handler:nil]) != nil)
		{
			choice.userInfo = syncChoice;
			choice.autoChoiceForError = syncChoice.autoChoiceForError;

			[choices addObject:choice];
		}
	}

	issue = [OCIssue issueForMultipleChoicesWithLocalizedTitle:syncIssue.localizedTitle localizedDescription:syncIssue.localizedDescription choices:choices completionHandler:^(OCIssue *issue, OCIssueDecision decision) {
		OCSyncIssueChoice *syncChoice = (OCSyncIssueChoice *)issue.selectedChoice.userInfo;

		resolutionResultHandler(syncChoice);
	}];

	issue.uuid = syncIssue.uuid;

	return (issue);
}

+ (instancetype)issueFromSyncIssue:(OCSyncIssue *)syncIssue forCore:(OCCore *)core
{
	OCIssue *issue;
	__weak OCCore *weakCore = core;

	issue = [OCIssue issueFromSyncIssue:syncIssue resolutionResultHandler:^(OCSyncIssueChoice *choice) {
		[weakCore resolveSyncIssue:syncIssue withChoice:choice userInfo:syncIssue.routingInfo completionHandler:nil];
	}];

	return (issue);
}

@end
