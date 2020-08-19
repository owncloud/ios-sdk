//
//  OCHTTPPipeline+Diagnostic.m
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

#import "OCHTTPPipeline+Diagnostic.h"
#import "OCHTTPPipelineTask+Diagnostic.h"
#import "OCMacros.h"

@implementation OCHTTPPipeline (Diagnostic)

- (NSArray<OCDiagnosticNode *> *)diagnosticNodesWithContext:(OCDiagnosticContext *)context
{
	NSMutableArray<OCDiagnosticNode *> *diagnosticNodes = [NSMutableArray new];
	__weak OCHTTPPipeline *weakSelf = self;

	[diagnosticNodes addObject:[OCDiagnosticNode withLabel:@"Schedule requests" action:^(OCDiagnosticContext * _Nullable context) {
		[weakSelf setPipelineNeedsScheduling];
	}]];

	OCSyncExec(pipelineRun, {
		[self queueBlock:^{
			[self.backend enumerateTasksForPipeline:self enumerator:^(OCHTTPPipelineTask *task, BOOL *stop) {
				NSArray<OCDiagnosticNode *> *taskNodes;

				if ((taskNodes = [task diagnosticNodesWithContext:context]) != nil)
				{
					OCDiagnosticNode *taskNode;

					if ((taskNode = [OCDiagnosticNode withLabel:[NSString stringWithFormat:@"HTTP Task %@", task.taskID] children:taskNodes]) != nil)
					{
						[diagnosticNodes addObject:taskNode];
					}
				}
			}];

			OCSyncExecDone(pipelineRun);
		} withBusy:YES];
	});

	return (diagnosticNodes);
}

@end
