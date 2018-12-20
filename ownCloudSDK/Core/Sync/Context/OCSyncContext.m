//
//  OCSyncContext.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 15.06.18.
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

#import "OCSyncContext.h"
#import "OCLogger.h"
#import "OCSyncRecord.h"

@implementation OCSyncContext

+ (instancetype)preflightContextWithSyncRecord:(OCSyncRecord *)syncRecord
{
	OCSyncContext *syncContext = [OCSyncContext new];

	syncContext.syncRecord = syncRecord;

	return (syncContext);
}

+ (instancetype)schedulerContextWithSyncRecord:(OCSyncRecord *)syncRecord
{
	OCSyncContext *syncContext = [OCSyncContext new];

	syncContext.syncRecord = syncRecord;

	return (syncContext);
}

+ (instancetype)descheduleContextWithSyncRecord:(OCSyncRecord *)syncRecord
{
	OCSyncContext *syncContext = [OCSyncContext new];

	syncContext.syncRecord = syncRecord;

	return (syncContext);
}

+ (instancetype)resultHandlerContextWith:(OCSyncRecord *)syncRecord event:(OCEvent *)event issues:(NSMutableArray <OCIssue *> *)issues
{
	OCSyncContext *syncContext = [OCSyncContext new];

	syncContext.syncRecord = syncRecord;
	syncContext.event = event;
	syncContext.issues = issues;

	return (syncContext);
}

+ (instancetype)issueResolutionContextWith:(OCSyncRecord *)syncRecord
{
	OCSyncContext *syncContext = [OCSyncContext new];

	syncContext.syncRecord = syncRecord;

	return (syncContext);
}

- (void)addIssue:(OCIssue *)issue
{
	if (issue == nil) { return; }

	if (self.issues == nil)
	{
		self.issues = [[NSMutableArray alloc] initWithObjects:issue, nil];
	}
	else
	{
		[self.issues addObject:issue];
	}
}

- (void)addSyncIssue:(OCSyncIssue *)syncIssue
{
	if (syncIssue == nil) { return; }

	if (self.issue != nil)
	{
		OCLogWarning(@"!! Dropping issue %@ and replacing it with %@", self.issue, syncIssue);
	}

	self.issue = syncIssue;

	self.syncRecord.issue = syncIssue;
}

- (void)resolvedSyncIssue:(OCSyncIssue *)syncIssue
{
	self.syncRecord.issue = nil;
}

@end
