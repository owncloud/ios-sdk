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

+ (instancetype)resultHandlerContextWith:(OCSyncRecord *)syncRecord event:(OCEvent *)event issues:(NSMutableArray <OCConnectionIssue *> *)issues
{
	OCSyncContext *syncContext = [OCSyncContext new];

	syncContext.syncRecord = syncRecord;
	syncContext.event = event;
	syncContext.issues = issues;

	return (syncContext);
}

- (void)addIssue:(OCConnectionIssue *)issue
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

@end
