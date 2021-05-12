//
//  OCCancelAction.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 18.03.21.
//  Copyright © 2021 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2021, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCCancelAction.h"

@implementation OCCancelAction

- (void)setHandler:(OCCancelActionHandler)handler
{
	@synchronized(self)
	{
		_handler = [handler copy];
	}

	if (_cancelled)
	{
		[self cancel];
	}
}

- (BOOL)cancel
{
	BOOL didCancel = NO;

	@synchronized(self)
	{
		if (!_cancelled)
		{
			_cancelled = YES;
		}

		if (_handler != nil)
		{
			didCancel = _handler();
			_handler = nil;
		}
	}

	return (didCancel);
}

@end
