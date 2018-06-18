//
//  OCCoreSyncContext.m
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

#import "OCCoreSyncContext.h"

@implementation OCCoreSyncContext

+ (instancetype)schedulerSetWithSyncRecord:(OCSyncRecord *)syncRecord
{
	OCCoreSyncContext *parameterSet = [OCCoreSyncContext new];

	parameterSet.syncRecord = syncRecord;

	return (parameterSet);
}

+ (instancetype)resultHandlerSetWith:(OCSyncRecord *)syncRecord event:(OCEvent *)event issues:(NSMutableArray <OCConnectionIssue *> *)issues
{
	OCCoreSyncContext *parameterSet = [OCCoreSyncContext new];

	parameterSet.syncRecord = syncRecord;
	parameterSet.event = event;
	parameterSet.issues = issues;

	return (parameterSet);
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
