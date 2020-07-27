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

@implementation OCSyncRecord (Diagnostic)

- (NSArray<OCDiagnosticNode *> *)diagnosticNodesWithContext:(OCDiagnosticContext *)context
{
	NSMutableArray<OCDiagnosticNode *> *waitConditionNodes = nil;
	NSMutableArray<OCDiagnosticNode *> *eventNodes = nil;

	for (OCWaitCondition *waitCondition in self.waitConditions)
	{
		if (waitConditionNodes == nil)
		{
			waitConditionNodes = [NSMutableArray new];
		}

		[waitConditionNodes addObject:[OCDiagnosticNode withLabel:@"Wait Condition" content:waitCondition.description]];
	}

	if (context.database != nil)
	{
		NSArray<OCEvent *> *events = [context.database eventsForSyncRecordID:self.recordID];

		for (OCEvent *event in events)
		{
			if (eventNodes == nil)
			{
				eventNodes = [NSMutableArray new];
			}

			[eventNodes addObject:[OCDiagnosticNode withLabel:@"Event" content:event.description]];
		}
	}

	return (@[
		[OCDiagnosticNode withLabel:@"Sync Record ID" 		content:_recordID.stringValue],
		[OCDiagnosticNode withLabel:@"State" 			content:@(self.state).stringValue],
		[OCDiagnosticNode withLabel:@"In progress since" 	content:self.inProgressSince.description],
		[OCDiagnosticNode withLabel:@"Origin Process" 		content:_originProcessSession.description],
		[OCDiagnosticNode withLabel:@"Origin Process Valid" 	content:@([OCProcessManager.sharedProcessManager isSessionValid:_originProcessSession usingThoroughChecks:YES]).description],
		[OCDiagnosticNode withLabel:@"Timestamp" 		content:self.timestamp.description],
		[OCDiagnosticNode withLabel:@"Lane ID" 			content:self.laneID.stringValue],
		[OCDiagnosticNode withLabel:@"Local ID" 		content:self.localID],
		[OCDiagnosticNode withLabel:@"Action ID" 		content:self.actionIdentifier],
		[OCDiagnosticNode withLabel:@"Action" 			children:[self.action diagnosticNodesWithContext:context]],
		[OCDiagnosticNode withLabel:@"Wait Conditions" 		children:waitConditionNodes],
		[OCDiagnosticNode withLabel:@"Events" 			children:eventNodes],
	]);
}

@end
