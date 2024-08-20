//
//  OCSyncRecord+Diagnostic.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 27.07.20.
//  Copyright © 2020 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2020, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCSyncRecord+Diagnostic.h"
#import "OCProcessManager.h"
#import "OCSyncAction+Diagnostic.h"
#import "OCWaitCondition+Diagnostic.h"

@implementation OCSyncRecord (Diagnostic)

- (NSArray<OCDiagnosticNode *> *)diagnosticNodesWithContext:(OCDiagnosticContext *)context
{
	NSMutableArray<OCDiagnosticNode *> *waitConditionNodes = nil;
	NSMutableArray<OCDiagnosticNode *> *eventNodes = nil;
	NSUInteger idx = 1;

	for (OCWaitCondition *waitCondition in self.waitConditions)
	{
		if (waitConditionNodes == nil)
		{
			waitConditionNodes = [NSMutableArray new];
		}

		[waitConditionNodes addObject:[OCDiagnosticNode withLabel:[NSString stringWithFormat:@"# %lu", (unsigned long)idx] children:[waitCondition diagnosticNodesWithContext:context]]];
		idx++;
	}

	if (context.database != nil)
	{
		NSArray<OCEvent *> *events = [context.database eventsForSyncRecordID:self.recordID];

		idx = 1;

		for (OCEvent *event in events)
		{
			if (eventNodes == nil)
			{
				eventNodes = [NSMutableArray new];
			}

			[eventNodes addObject:[OCDiagnosticNode withLabel:[NSString stringWithFormat:@"# %lu", (unsigned long)idx] content:event.description]];
			idx++;
		}
	}

	return (@[
		[OCDiagnosticNode withLabel:OCLocalizedString(@"Sync Record ID",nil) 		content:_recordID.stringValue],
		[OCDiagnosticNode withLabel:OCLocalizedString(@"State",nil) 				content:@(self.state).stringValue],
		[OCDiagnosticNode withLabel:OCLocalizedString(@"In progress since",nil) 	content:self.inProgressSince.description],
		[OCDiagnosticNode withLabel:OCLocalizedString(@"Origin Process",nil)		content:_originProcessSession.description],
		[OCDiagnosticNode withLabel:OCLocalizedString(@"Origin Process Valid",nil) 	content:@([OCProcessManager.sharedProcessManager isSessionValid:_originProcessSession usingThoroughChecks:YES]).description],
		[OCDiagnosticNode withLabel:OCLocalizedString(@"Timestamp",nil) 		content:self.timestamp.description],
		[OCDiagnosticNode withLabel:OCLocalizedString(@"Lane ID",nil) 		content:self.laneID.stringValue],
		[OCDiagnosticNode withLabel:OCLocalizedString(@"Local ID",nil) 		content:self.localID],
		[OCDiagnosticNode withLabel:OCLocalizedString(@"Action ID",nil) 		content:self.actionIdentifier],

		[OCDiagnosticNode withLabel:OCLocalizedString(@"Process Sync Records",nil) action:^(OCDiagnosticContext * _Nullable context) {
			[context.core setNeedsToProcessSyncRecords];
		}],
		[OCDiagnosticNode withLabel:OCLocalizedString(@"Reschedule",nil) action:^(OCDiagnosticContext * _Nullable context) {
			[context.core rescheduleSyncRecord:self withUpdates:nil];
		}],
		[OCDiagnosticNode withLabel:OCLocalizedString(@"Deschedule (remove)",nil) action:^(OCDiagnosticContext * _Nullable context) {
			[context.core descheduleSyncRecord:self completeWithError:nil parameter:nil];
		}],

		[OCDiagnosticNode withLabel:OCLocalizedString(@"Action",nil) 			children:[self.action diagnosticNodesWithContext:context]],
		[OCDiagnosticNode withLabel:OCLocalizedString(@"Wait Conditions",nil) children:waitConditionNodes],
		[OCDiagnosticNode withLabel:OCLocalizedString(@"Events",nil) 			children:eventNodes],
	]);
}

@end
