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

#pragma mark - Init
+ (instancetype)backgroundTaskWithName:(nullable NSString *)name expirationHandler:(OCBackgroundTaskExpirationHandler)expirationHandler
{
	return ([[self alloc] initWithName:name expirationHandler:expirationHandler]);
}

- (instancetype)initWithName:(nullable NSString *)name expirationHandler:(OCBackgroundTaskExpirationHandler)expirationHandler
{
	if ((self = [super init]) != nil)
	{
		_name = name;
		_expirationHandler = [expirationHandler copy];
	}

	return(self);
}

#pragma mark - Start and end
- (instancetype)start
{
	if ([OCBackgroundManager.sharedBackgroundManager startTask:self])
	{
		return (self);
	}

	return (nil);
}

- (void)end
{
	[OCBackgroundManager.sharedBackgroundManager endTask:self];
}

- (void)endWhenDeallocating:(id)object
{
	__weak OCBackgroundTask *weakSelf = self;

	[OCDeallocAction addAction:^{
		[weakSelf end];
	} forDeallocationOfObject:object];
}

- (void)clearExpirationHandler
{
	_expirationHandler = nil;
}

@end
