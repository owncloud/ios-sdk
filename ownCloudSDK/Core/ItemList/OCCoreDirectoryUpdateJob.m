//
//  OCCoreDirectoryUpdateJob.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 27.05.19.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2019, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCCoreDirectoryUpdateJob.h"

@implementation OCCoreDirectoryUpdateJob

+ (instancetype)withPath:(OCPath)path
{
	OCCoreDirectoryUpdateJob *updateScanPath = [OCCoreDirectoryUpdateJob new];

	updateScanPath.path = path;

	return (updateScanPath);
}

- (NSSet<OCCoreDirectoryUpdateJobID> *)representedJobIDs
{
	@synchronized(self)
	{
		if ((_representedJobIDs == nil) && (_identifier != nil))
		{
			_representedJobIDs = [NSSet setWithObject:_identifier];
		}
	}

	return (_representedJobIDs);
}

- (void)addRepresentedJobID:(OCCoreDirectoryUpdateJobID)jobID
{
	if (jobID == nil) { return; }

	@synchronized(self)
	{
		NSSet<OCCoreDirectoryUpdateJobID> *representedJobIDs = self.representedJobIDs;

		if (representedJobIDs != nil)
		{
			_representedJobIDs = [representedJobIDs setByAddingObject:jobID];
		}
		else
		{
			_representedJobIDs = [NSSet setWithObject:jobID];
		}
	}
}

- (BOOL)isForQuery
{
	return (_identifier == nil);
}

#pragma mark - Description
- (NSString *)description
{
	return ([NSString stringWithFormat:@"<%@: %p, jobID: %@, path: %@, isForQuery: %d, representedJobIDs: %@>", NSStringFromClass(self.class), self, _identifier, _path, self.isForQuery, self.representedJobIDs]);
}

@end
