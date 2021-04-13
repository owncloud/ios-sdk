//
//  OCDeallocAction.m
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

#import "OCDeallocAction.h"
#import <objc/runtime.h>

@interface OCDeallocAction ()
{
	dispatch_block_t _action;
}

@end

@implementation OCDeallocAction

+ (void)addAction:(dispatch_block_t)action forDeallocationOfObject:(id)object;
{
	OCDeallocAction *deallocAction = [[OCDeallocAction alloc] initWithAction:action];

	objc_setAssociatedObject(object, (__bridge const void *)deallocAction, deallocAction, OBJC_ASSOCIATION_RETAIN);
}

- (instancetype)initWithAction:(dispatch_block_t)action
{
	if ((self = [super init]) != nil)
	{
		_action = [action copy];
	}

	return (self);
}

- (void)dealloc
{
	if (_action != nil)
	{
		_action();
		_action = nil;
	}
}

@end
