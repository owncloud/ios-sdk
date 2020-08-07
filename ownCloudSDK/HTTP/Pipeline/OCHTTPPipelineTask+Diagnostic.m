//
//  OCHTTPPipelineTask+Diagnostic.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 28.07.20.
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

#import "OCHTTPPipelineTask+Diagnostic.h"
#import "OCProcessManager.h"

@implementation OCHTTPPipelineTask (Diagnostic)

- (NSArray<OCDiagnosticNode *> *)diagnosticNodesWithContext:(OCDiagnosticContext *)context
{
	BOOL waitForOtherProcess = NO;

	if ([self.bundleID isEqual:OCHTTPPipelineTaskAnyBundleID])
	{
		// Task originates from a different process. Only process it, if that other process is no longer around
		OCProcessSession *processSession;

		if ((processSession = [[OCProcessManager sharedProcessManager] findLatestSessionForProcessWithBundleIdentifier:self.bundleID]) != nil)
		{
			waitForOtherProcess = ![[OCProcessManager sharedProcessManager] isAnyInstanceOfSessionProcessRunning:processSession];
		}
	}

	return (@[
		[OCDiagnosticNode withLabel:@"Task ID" content:self.taskID.stringValue],
		[OCDiagnosticNode withLabel:@"Bundle ID" content:self.bundleID],
		[OCDiagnosticNode withLabel:@"Wait for Bundle ID Process" content:@(waitForOtherProcess).stringValue],
		[OCDiagnosticNode withLabel:@"URL Session ID" content:self.urlSessionID],
		[OCDiagnosticNode withLabel:@"URL Session Task ID" content:self.urlSessionTaskID.stringValue],
		[OCDiagnosticNode withLabel:@"Partition ID" content:self.partitionID],
		[OCDiagnosticNode withLabel:@"Pipeline ID" content:self.pipelineID],
		[OCDiagnosticNode withLabel:@"Group ID" content:self.groupID],
		[OCDiagnosticNode withLabel:@"State" content:@(self.state).stringValue],
		[OCDiagnosticNode withLabel:@"Request ID" content:self.requestID],
		[OCDiagnosticNode withLabel:@"Request Method" content:self.request.method],
		[OCDiagnosticNode withLabel:@"Request URL" content:self.request.url.absoluteString],
		[OCDiagnosticNode withLabel:@"Request Final" content:@(self.requestFinal).stringValue],
		[OCDiagnosticNode withLabel:@"Response Status" content:self.response.status.description],
		[OCDiagnosticNode withLabel:@"Metrics" content:self.metrics.description],
		[OCDiagnosticNode withLabel:@"Finished" content:@(self.finished).stringValue],
	]);
}

@end
