//
//  OCAction.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 29.05.22.
//  Copyright © 2022 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2022, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCAction.h"

@interface OCAction ()
{
	OCDataItemReference _reference;
}
@end

@implementation OCAction

- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_reference = NSUUID.UUID.UUIDString;
		_properties = [NSMutableDictionary new];
	}

	return (self);
}

- (instancetype)initWithTitle:(NSString *)title icon:(nullable UIImage *)icon action:(nullable OCActionBlock)actionBlock
{
	if ((self = [self init]) != nil)
	{
		_title = title;
		_icon = icon;
		self.actionBlock = actionBlock;
	}

	return (self);
}

- (void)runActionWithOptions:(OCActionRunOptions)options completionHandler:(void(^)(NSError * _Nullable error))completionHandler
{
	if (completionHandler == nil)
	{
		// Provide dummy completionHandler if none is provided
		completionHandler = ^(NSError *error){
		};
	}

	if (_actionBlock != nil)
	{
		_actionBlock(self, options, completionHandler);
	}
	else
	{
		completionHandler(nil);
	}
}

- (OCDataItemReference)dataItemReference
{
	return ((_identifier != nil) ? _identifier : _reference);
}

- (OCDataItemType)dataItemType
{
	return (OCDataItemTypeAction);
}

- (OCDataItemVersion)dataItemVersion
{
	return ((_version != nil) ? _version : _reference);
}

@end
