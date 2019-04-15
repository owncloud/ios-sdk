//
//  OCBackgroundTask.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 15.04.19.
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

#import "OCBackgroundTask.h"
#import "OCBackgroundManager.h"
#import "OCDeallocAction.h"

@implementation OCBackgroundTask

#pragma mark - Init & Dealloc
- (instancetype)initWithName:(nullable NSString *)name expirationHandler:(dispatch_block_t)expirationHandler;
{
	if ((self = [super init]) != nil)
	{
		_name = name;
		_expirationHandler = [expirationHandler copy];
	}

	return(self);
}

- (instancetype)start
{
	[OCBackgroundManager.sharedBackgroundManager startTask:self];

	return (self);
}

- (void)end
{
	[OCBackgroundManager.sharedBackgroundManager endTask:self];
}

- (void)endWhenDeallocating:(id)object
{
	[OCDeallocAction addAction:^{
		[self end];
	} forDeallocationOfObject:object];
}

@end
