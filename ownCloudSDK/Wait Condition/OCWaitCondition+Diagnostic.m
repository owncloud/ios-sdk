//
//  OCWaitCondition+Diagnostic.m
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

#import "OCWaitCondition+Diagnostic.h"
#import "OCMacros.h"

@implementation OCWaitCondition (Diagnostic)

- (NSArray<OCDiagnosticNode *> *)diagnosticNodesWithContext:(OCDiagnosticContext *)context
{
	NSArray<OCDiagnosticNode *> *nodes;

	nodes = @[
		[OCDiagnosticNode withLabel:@"Type" content:NSStringFromClass(self.class)],
		[OCDiagnosticNode withLabel:@"UUID" content:self.uuid.UUIDString]
	];

	OCWaitConditionIssue *issueCondition;
	if ((issueCondition = OCTypedCast(self, OCWaitConditionIssue)) != nil)
	{
		nodes = [nodes arrayByAddingObjectsFromArray:@[
			[OCDiagnosticNode withLabel:@"Issue" content:issueCondition.issue.description],
			[OCDiagnosticNode withLabel:@"ProcessSession" content:issueCondition.processSession.description],
			[OCDiagnosticNode withLabel:@"Resolved" content:@(issueCondition.resolved).stringValue]
		]];
	}

	OCWaitConditionMetaDataRefresh *mdRefreshCondition;
	if ((mdRefreshCondition = OCTypedCast(self, OCWaitConditionMetaDataRefresh)) != nil)
	{
		nodes = [nodes arrayByAddingObjectsFromArray:@[
			[OCDiagnosticNode withLabel:@"Item Path" content:mdRefreshCondition.itemPath],
			[OCDiagnosticNode withLabel:@"Item Version" content:mdRefreshCondition.itemVersionIdentifier.description],
			[OCDiagnosticNode withLabel:@"Expiration Date" content:mdRefreshCondition.expirationDate.description]
		]];
	}

	return (nodes);
}

@end
