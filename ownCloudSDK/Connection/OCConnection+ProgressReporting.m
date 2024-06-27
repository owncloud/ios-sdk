//
//  OCConnection+ProgressReporting.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 26.06.24.
//  Copyright © 2024 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2024, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCConnection.h"
#import "NSProgress+OCExtensions.h"

@implementation OCConnection (ProgressReporting)

- (NSProgress *)progressForActionTrackingID:(OCActionTrackingID)trackingID provider:(nullable NSProgress *(^)(NSProgress *progress))progressProvider
{
	if (trackingID == nil) {
		return (nil);
	}

	NSProgress *progress = nil;

	@synchronized(_progressByActionTrackingID)
	{
		if ((progress = _progressByActionTrackingID[trackingID]) == nil)
		{
			progress = NSProgress.indeterminateProgress;

			if (progressProvider != nil)
			{
				progress = progressProvider(progress);
			}

			if (progress != nil)
			{
				_progressByActionTrackingID[trackingID] = progress;
			}
		}
	}

	return (progress);
}

- (void)finishActionWithTrackingID:(OCActionTrackingID)trackingID
{
	if (trackingID == nil) {
		return;
	}

	@synchronized(_progressByActionTrackingID)
	{
		_progressByActionTrackingID[trackingID] = nil;
	}
}

@end
